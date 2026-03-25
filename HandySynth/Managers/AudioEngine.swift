import AVFoundation
import os

private enum AudioConstants {
    static let filterMinAlpha: Float = 0.01
    static let volumeSmoothingRate: Float = 0.01
    static let mainVolume: Float = 0.7
    static let defaultDelayTime: TimeInterval = 0.3
    static let defaultDelayFeedback: Float = 30
    static let defaultReverbWetDry: Float = 20
    static let padDetuneAmounts: [Float] = [1.0, 1.005, 0.995, 1.01, 0.99]
    static let padAmplitudes: [Float] = [0.35, 0.2, 0.2, 0.12, 0.13]
}

class AudioEngine: ObservableObject {
    @Published var isPlaying = false
    @Published var currentFrequency: Float = 440.0
    @Published var currentNoteName: String = "A4"
    @Published var currentVolume: Float = 0.0

    private let engine = AVAudioEngine()
    private var sourceNode: AVAudioSourceNode?
    private let reverb = AVAudioUnitReverb()
    private let delay = AVAudioUnitDelay()

    // Audio thread parameters — accessed via os_unfair_lock
    private var paramLock = os_unfair_lock()
    private var audioParams = AudioParams()

    // Phase accumulators (audio thread only)
    private var phase: Float = 0.0
    private var padPhases: [Float] = [0, 0, 0, 0, 0]
    private var vibratoPhase: Float = 0.0
    private var smoothedVolume: Float = 0.0
    private var smoothedFrequency: Float = 440.0
    private var filterState: Float = 0.0 // one-pole LPF state
    private var envelopeLevel: Float = 0.0
    private var envelopeActive: Bool = false

    // Finger polyphony state (audio thread only)
    private var fingerPhases: (Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0)
    private var fingerEnvelopes: (Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0)

    // Chord voices (audio thread only)
    private var chordPhase2: Float = 0.0
    private var chordPhase3: Float = 0.0
    private var chordSmoothedFreq2: Float = 440.0
    private var chordSmoothedFreq3: Float = 440.0

    // FM synthesis (audio thread only)
    private var modPhase: Float = 0.0

    // Throttle for UI updates
    private var lastDisplayUpdate: CFAbsoluteTime = 0
    private let displayUpdateInterval: CFAbsoluteTime = 1.0 / 15.0

    // Settings
    var baseOctave: Int = 3
    var octaveRange: Int = 3
    var scale: Scale = .major
    var rootNote: RootNote = .C
    var portamentoSpeed: Float = 0.02
    var attackTimeMs: Float = 10.0
    var releaseTimeMs: Float = 100.0
    var fmRatio: Float = 2.0
    var fmDepth: Float = 1.0

    // Audio tap for visualizer
    var audioTapHandler: (([Float]) -> Void)?

    private let sampleRate: Float = 44100.0

    struct AudioParams {
        var frequency: Float = 440.0
        var volume: Float = 0.0
        var filterCutoff: Float = 1.0
        var vibratoDepth: Float = 0.0
        var vibratoRate: Float = 5.0
        var waveform: Waveform = .sine
        var isMuted: Bool = true
        var reverbMix: Float = 0.2
        var delayMix: Float = 0.0
        var attackTimeMs: Float = 10.0
        var releaseTimeMs: Float = 100.0

        // Finger-per-note polyphony
        var fingerMode: Bool = false
        var fingerFrequencies: (Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0)
        var fingerActive: (Bool, Bool, Bool, Bool, Bool) = (false, false, false, false, false)

        // Chord harmonization
        var chordMode: Bool = false
        var chordFreq2: Float = 440.0
        var chordFreq3: Float = 440.0

        // Pad detune depth (0=unison, 1=full spread)
        var detune: Float = 0.0

        // FM synthesis
        var fmRatio: Float = 2.0
        var fmDepth: Float = 1.0

        // Distortion
        var distortion: Float = 0.0
    }

    init() {
        reverb.loadFactoryPreset(.mediumHall)
        reverb.wetDryMix = AudioConstants.defaultReverbWetDry
        delay.delayTime = AudioConstants.defaultDelayTime
        delay.feedback = AudioConstants.defaultDelayFeedback
        delay.wetDryMix = 0
    }

    func start() {
        guard !isPlaying else { return }

        let stereoFormat = AVAudioFormat(standardFormatWithSampleRate: Double(sampleRate), channels: 2)!

        sourceNode = AVAudioSourceNode(format: stereoFormat) { [weak self] isSilence, _, frameCount, audioBufferList -> OSStatus in
            guard let self = self else { return noErr }
            isSilence.pointee = false
            return self.renderAudio(frameCount: frameCount, audioBufferList: audioBufferList)
        }

        guard let sourceNode = sourceNode else { return }

        engine.attach(sourceNode)
        engine.attach(reverb)
        engine.attach(delay)

        engine.connect(sourceNode, to: reverb, format: stereoFormat)
        engine.connect(reverb, to: delay, format: stereoFormat)
        engine.connect(delay, to: engine.mainMixerNode, format: stereoFormat)

        engine.mainMixerNode.outputVolume = AudioConstants.mainVolume

        // Audio tap for visualizer FFT
        let tapFormat = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: 1024, format: tapFormat) { [weak self] buffer, _ in
            guard let self = self, let handler = self.audioTapHandler else { return }
            guard let channelData = buffer.floatChannelData else { return }
            let frameLength = Int(buffer.frameLength)
            let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameLength))
            handler(samples)
        }

        do {
            try engine.start()
            DispatchQueue.main.async {
                self.isPlaying = true
            }
        } catch {
            print("AudioEngine start failed: \(error)")
        }
    }

    func stop() {
        engine.mainMixerNode.removeTap(onBus: 0)
        engine.stop()
        if let sourceNode = sourceNode {
            engine.detach(sourceNode)
        }
        engine.detach(reverb)
        engine.detach(delay)
        sourceNode = nil
        DispatchQueue.main.async {
            self.isPlaying = false
        }
    }

    /// Updates audio parameters from the gesture pipeline. Called on background queue.
    func updateParameters(_ params: MusicalParameters) {
        let frequency: Float
        if params.fingerMode {
            // In finger mode, individual finger frequencies are in fingerFrequencies
            frequency = params.fingerFrequencies.0 // use first finger for display
        } else if let arpFreq = params.arpFrequency {
            frequency = arpFreq
        } else if params.isSustaining {
            os_unfair_lock_lock(&paramLock)
            frequency = audioParams.frequency
            os_unfair_lock_unlock(&paramLock)
        } else {
            frequency = ScaleHelper.positionToFrequency(
                position: params.pitch,
                baseOctave: baseOctave,
                octaveRange: octaveRange,
                scale: scale,
                rootNote: rootNote,
                quantize: params.isQuantized
            )
        }

        let volume = params.isMuted ? Float(0.0) : params.volume

        // Chord frequencies — computed on camera queue before lock
        let chordMode = params.chordMode
        var cf2: Float = 440; var cf3: Float = 440
        if chordMode { (cf2, cf3) = computeChordFrequencies(baseFreq: frequency) }

        os_unfair_lock_lock(&paramLock)
        audioParams.frequency = frequency
        audioParams.volume = volume
        audioParams.filterCutoff = params.filterCutoff
        audioParams.vibratoDepth = params.vibratoDepth
        audioParams.vibratoRate = params.vibratoRate
        audioParams.waveform = params.waveform
        audioParams.isMuted = params.isMuted
        audioParams.reverbMix = params.reverbMix
        audioParams.delayMix = params.delayMix
        audioParams.attackTimeMs = self.attackTimeMs
        audioParams.releaseTimeMs = self.releaseTimeMs
        audioParams.fingerMode = params.fingerMode
        audioParams.fingerFrequencies = params.fingerFrequencies
        audioParams.fingerActive = params.fingerActive
        audioParams.chordMode = chordMode
        audioParams.chordFreq2 = cf2
        audioParams.chordFreq3 = cf3
        audioParams.detune = params.detune
        audioParams.fmRatio = self.fmRatio
        audioParams.fmDepth = self.fmDepth
        audioParams.distortion = params.distortion
        os_unfair_lock_unlock(&paramLock)

        // Update effects on main/caller thread (safe for these properties)
        reverb.wetDryMix = params.reverbMix * 100.0
        delay.wetDryMix = params.delayMix * 100.0

        // Throttled UI updates
        let now = CFAbsoluteTimeGetCurrent()
        if now - lastDisplayUpdate >= displayUpdateInterval {
            lastDisplayUpdate = now
            let noteName = ScaleHelper.noteName(for: frequency)
            DispatchQueue.main.async { [weak self] in
                self?.currentFrequency = frequency
                self?.currentNoteName = noteName
                self?.currentVolume = volume
            }
        }
    }

    /// Computes scale-aware chord frequencies for the 3rd and 5th above a base frequency.
    /// Runs on the camera queue inside updateParameters() — never called from the audio thread.
    private func computeChordFrequencies(baseFreq: Float) -> (Float, Float) {
        let semitones = scale.semitones
        guard semitones.count >= 5 else {
            let baseMidi = ScaleHelper.frequencyToMidiNote(baseFreq)
            return (ScaleHelper.midiNoteToFrequency(baseMidi + 4),
                    ScaleHelper.midiNoteToFrequency(baseMidi + 7))
        }
        let baseMidi = Int(roundf(ScaleHelper.frequencyToMidiNote(baseFreq)))
        let rootMidi = (baseOctave + 1) * 12 + rootNote.semitoneOffset
        let offsetInOctave = ((baseMidi - rootMidi) % 12 + 12) % 12
        var degreeIndex = 0
        for (i, st) in semitones.enumerated() { if st <= offsetInOctave { degreeIndex = i } }
        func midiForDegreeOffset(_ steps: Int) -> Int {
            let deg = degreeIndex + steps
            return baseMidi - offsetInOctave + semitones[deg % semitones.count] + (deg / semitones.count) * 12
        }
        return (ScaleHelper.midiNoteToFrequency(Float(midiForDegreeOffset(2))),
                ScaleHelper.midiNoteToFrequency(Float(midiForDegreeOffset(4))))
    }

    /// Real-time audio render callback. Runs on the audio thread — no allocations or blocking.
    private func renderAudio(frameCount: UInt32, audioBufferList: UnsafeMutablePointer<AudioBufferList>) -> OSStatus {
        os_unfair_lock_lock(&paramLock)
        let params = audioParams
        os_unfair_lock_unlock(&paramLock)

        let ablPointer = UnsafeMutableAudioBufferListPointer(audioBufferList)
        let channelCount = ablPointer.count
        guard channelCount > 0 else { return noErr }

        if params.fingerMode {
            return renderFingerMode(params: params, frameCount: frameCount, ablPointer: ablPointer, channelCount: channelCount)
        }

        let targetFreq = params.frequency
        let targetVolume = params.isMuted ? Float(0.0) : params.volume

        // Envelope rate coefficients (computed once per buffer, not per sample)
        let attackSamples = max(1.0, params.attackTimeMs * 0.001 * sampleRate)
        let releaseSamples = max(1.0, params.releaseTimeMs * 0.001 * sampleRate)
        let attackRate = 1.0 / attackSamples
        let releaseRate = 1.0 / releaseSamples

        // Filter coefficient: map cutoff 0..1 to alpha for one-pole LPF
        // cutoff 1.0 = wide open (alpha=1), cutoff 0.0 = very dark (alpha≈0.01)
        let filterAlpha = AudioConstants.filterMinAlpha + params.filterCutoff * (1.0 - AudioConstants.filterMinAlpha)

        for frame in 0..<Int(frameCount) {
            smoothedFrequency += (targetFreq - smoothedFrequency) * portamentoSpeed

            let vibratoMod = sinf(2.0 * .pi * vibratoPhase) * params.vibratoDepth * 15.0
            let freq = smoothedFrequency + vibratoMod
            let phaseInc = freq / sampleRate

            var sample: Float

            switch params.waveform {
            case .sine:
                sample = sinf(2.0 * .pi * phase)

            case .triangle:
                let t = phase - floorf(phase)
                sample = 4.0 * abs(t - 0.5) - 1.0

            case .sawtooth:
                sample = 2.0 * (phase - floorf(phase + 0.5))

            case .square:
                sample = phase < 0.5 ? 1.0 : -1.0

            case .fm:
                let modSig = sinf(2.0 * .pi * modPhase) * params.fmDepth
                sample = sinf(2.0 * .pi * phase + modSig)
                modPhase += freq * params.fmRatio / sampleRate
                if modPhase >= 1.0 { modPhase -= 1.0 }

            case .pad:
                let d = params.detune
                let amps = AudioConstants.padAmplitudes
                sample  = sinf(2.0 * .pi * padPhases[0]) * amps[0]
                sample += sinf(2.0 * .pi * padPhases[1]) * amps[1]
                sample += sinf(2.0 * .pi * padPhases[2]) * amps[2]
                sample += sinf(2.0 * .pi * padPhases[3]) * amps[3]
                sample += sinf(2.0 * .pi * padPhases[4]) * amps[4]
                padPhases[0] += freq / sampleRate
                padPhases[1] += freq * (1.0 + 0.005 * d) / sampleRate
                padPhases[2] += freq * (1.0 - 0.005 * d) / sampleRate
                padPhases[3] += freq * (1.0 + 0.010 * d) / sampleRate
                padPhases[4] += freq * (1.0 - 0.010 * d) / sampleRate
                for i in 0..<5 { if padPhases[i] >= 1.0 { padPhases[i] -= 1.0 } }
            }

            // One-pole low-pass filter
            filterState += filterAlpha * (sample - filterState)
            sample = filterState

            // Volume ramp (tracks hand height)
            smoothedVolume += (targetVolume - smoothedVolume) * AudioConstants.volumeSmoothingRate

            // Attack/release envelope
            let isActive = targetVolume > 0.001
            if isActive && !envelopeActive {
                envelopeActive = true
            } else if !isActive && envelopeActive && envelopeLevel <= 0.001 {
                envelopeActive = false
            }

            if envelopeActive {
                if isActive && envelopeLevel < 1.0 {
                    envelopeLevel = min(envelopeLevel + attackRate, 1.0)
                } else if !isActive {
                    envelopeLevel = max(envelopeLevel - releaseRate, 0.0)
                }
            } else {
                envelopeLevel = 0.0
            }

            sample *= smoothedVolume * envelopeLevel

            // Chord harmonization — two scale-aware sine voices
            if params.chordMode {
                chordSmoothedFreq2 += (params.chordFreq2 - chordSmoothedFreq2) * portamentoSpeed
                chordSmoothedFreq3 += (params.chordFreq3 - chordSmoothedFreq3) * portamentoSpeed
                let c2 = sinf(2.0 * .pi * chordPhase2) * smoothedVolume * envelopeLevel * 0.4
                let c3 = sinf(2.0 * .pi * chordPhase3) * smoothedVolume * envelopeLevel * 0.4
                chordPhase2 += chordSmoothedFreq2 / sampleRate
                if chordPhase2 >= 1.0 { chordPhase2 -= 1.0 }
                chordPhase3 += chordSmoothedFreq3 / sampleRate
                if chordPhase3 >= 1.0 { chordPhase3 -= 1.0 }
                sample = sample * 0.6 + c2 + c3
            }

            // Soft distortion (tanh waveshaping — hands apart drives amount)
            if params.distortion > 0.001 {
                let drive = 1.0 + params.distortion * 9.0  // 1x to 10x gain
                sample = tanhf(sample * drive) / tanhf(drive)
            }

            // Write same sample to all channels (stereo)
            for ch in 0..<channelCount {
                if let buffer = ablPointer[ch].mData?.assumingMemoryBound(to: Float.self) {
                    buffer[frame] = sample
                }
            }

            phase += phaseInc
            if phase >= 1.0 { phase -= 1.0 }

            vibratoPhase += params.vibratoRate / sampleRate
            if vibratoPhase >= 1.0 { vibratoPhase -= 1.0 }
        }

        return noErr
    }

    /// Processes a single finger voice oscillator. Audio-thread safe: all value types, no heap.
    @inline(__always)
    private func processVoice(
        phase: inout Float, envelope: inout Float,
        frequency: Float, isActive: Bool, isMuted: Bool,
        attackRate: Float, releaseRate: Float,
        vibratoMod: Float, sampleRate: Float
    ) -> Float {
        let active = isActive && !isMuted
        if active { envelope = min(envelope + attackRate, 1.0) }
        else { envelope = max(envelope - releaseRate, 0.0) }
        guard envelope > 0.0001 else { return 0.0 }
        let sample = sinf(2.0 * .pi * phase) * envelope
        phase += (frequency + vibratoMod) / sampleRate
        if phase >= 1.0 { phase -= 1.0 }
        return sample
    }

    /// Renders 5 independent finger oscillators with per-finger envelopes.
    private func renderFingerMode(params: AudioParams, frameCount: UInt32, ablPointer: UnsafeMutableAudioBufferListPointer, channelCount: Int) -> OSStatus {
        let attackSamples = max(1.0, params.attackTimeMs * 0.001 * sampleRate)
        let releaseSamples = max(1.0, params.releaseTimeMs * 0.001 * sampleRate)
        let attackRate = 1.0 / attackSamples
        let releaseRate = 1.0 / releaseSamples

        let filterAlpha = AudioConstants.filterMinAlpha + params.filterCutoff * (1.0 - AudioConstants.filterMinAlpha)

        var fPhases = (fingerPhases.0, fingerPhases.1, fingerPhases.2, fingerPhases.3, fingerPhases.4)
        var fEnvs = (fingerEnvelopes.0, fingerEnvelopes.1, fingerEnvelopes.2, fingerEnvelopes.3, fingerEnvelopes.4)

        let targetVolume = params.isMuted ? Float(0.0) : params.volume

        for frame in 0..<Int(frameCount) {
            smoothedVolume += (targetVolume - smoothedVolume) * AudioConstants.volumeSmoothingRate
            let vibratoMod = sinf(2.0 * .pi * vibratoPhase) * params.vibratoDepth * 15.0

            var mix: Float = 0.0
            mix += processVoice(phase: &fPhases.0, envelope: &fEnvs.0, frequency: params.fingerFrequencies.0, isActive: params.fingerActive.0, isMuted: params.isMuted, attackRate: attackRate, releaseRate: releaseRate, vibratoMod: vibratoMod, sampleRate: sampleRate)
            mix += processVoice(phase: &fPhases.1, envelope: &fEnvs.1, frequency: params.fingerFrequencies.1, isActive: params.fingerActive.1, isMuted: params.isMuted, attackRate: attackRate, releaseRate: releaseRate, vibratoMod: vibratoMod, sampleRate: sampleRate)
            mix += processVoice(phase: &fPhases.2, envelope: &fEnvs.2, frequency: params.fingerFrequencies.2, isActive: params.fingerActive.2, isMuted: params.isMuted, attackRate: attackRate, releaseRate: releaseRate, vibratoMod: vibratoMod, sampleRate: sampleRate)
            mix += processVoice(phase: &fPhases.3, envelope: &fEnvs.3, frequency: params.fingerFrequencies.3, isActive: params.fingerActive.3, isMuted: params.isMuted, attackRate: attackRate, releaseRate: releaseRate, vibratoMod: vibratoMod, sampleRate: sampleRate)
            mix += processVoice(phase: &fPhases.4, envelope: &fEnvs.4, frequency: params.fingerFrequencies.4, isActive: params.fingerActive.4, isMuted: params.isMuted, attackRate: attackRate, releaseRate: releaseRate, vibratoMod: vibratoMod, sampleRate: sampleRate)

            var sample = mix * 0.3

            filterState += filterAlpha * (sample - filterState)
            sample = filterState

            sample *= smoothedVolume

            for ch in 0..<channelCount {
                if let buffer = ablPointer[ch].mData?.assumingMemoryBound(to: Float.self) {
                    buffer[frame] = sample
                }
            }

            vibratoPhase += params.vibratoRate / sampleRate
            if vibratoPhase >= 1.0 { vibratoPhase -= 1.0 }
        }

        fingerPhases = fPhases
        fingerEnvelopes = fEnvs

        return noErr
    }
}
