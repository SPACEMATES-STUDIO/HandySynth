import Foundation
import Combine

class GestureInterpreter: ObservableObject {
    // Audio path — updated every frame, NOT @Published
    private(set) var parameters = MusicalParameters()

    // Display path — throttled @Published for UI
    @Published var displayPitch: Float = 0.5
    @Published var displayVolume: Float = 0.0
    @Published var displayMuted: Bool = true
    @Published var displayWaveform: Waveform = .sine
    @Published var displaySustaining: Bool = false
    @Published var displayQuantized: Bool = false
    @Published var displayNoteName: String = ""

    // Set by pipeline wiring — read on background queue
    var sustainEnabled: Bool = true
    var waveformOverride: Waveform = .sine
    var fingerPerNoteEnabled: Bool = false
    let arpeggiator = Arpeggiator()

    // Smoothing filters for continuous parameters
    private let pitchFilter = SmoothingFilter(factor: 0.6)
    private let volumeFilter = SmoothingFilter(factor: 0.5)
    private let filterCutoffFilter = SmoothingFilter(factor: 0.6)

    // Debouncing for discrete gestures
    private let leftDebouncer = GestureDebouncer(requiredFrames: 4)
    private let rightDebouncer = GestureDebouncer(requiredFrames: 4)

    // Vibrato detection
    private var wristYHistory: [Float] = []
    private let vibratoHistorySize = 12

    // Precision mode anchor
    private var precisionAnchor: Float = 0.5
    private var precisionRange: Float = 0.15

    // Quantized mode toggle state
    private var lastPeaceGestureTime: Date = .distantPast

    // Throttle for UI updates
    private var lastDisplayUpdate: CFAbsoluteTime = 0
    private let displayUpdateInterval: CFAbsoluteTime = 1.0 / 15.0

    /// Converts hand landmarks into musical parameters. Called every frame on background queue.
    /// Set `sustainEnabled` and `waveformOverride` before calling.
    func update(leftHand: HandLandmarks?, rightHand: HandLandmarks?) {
        var params = parameters
        processLeftHand(leftHand, params: &params)
        processRightHand(rightHand, params: &params)
        params.waveform = waveformOverride
        params.arpFrequency = arpeggiator.process(inputPitch: params.pitch)
        parameters = params
        throttledDisplayUpdate(params)
    }

    // MARK: - Left Hand (Pitch)

    private func processLeftHand(_ hand: HandLandmarks?, params: inout MusicalParameters) {
        guard let left = hand else {
            params.isMuted = true
            wristYHistory.removeAll()
            params.vibratoDepth = 0
            return
        }

        if fingerPerNoteEnabled {
            processFingerPerNote(left, params: &params)
            return
        }

        let rawGesture = GestureDetector.detectGesture(hand: left)
        let gesture = leftDebouncer.update(rawGesture)

        switch gesture {
        case .fist:
            params.isMuted = true
        case .pinch:
            if sustainEnabled {
                params.isSustaining = true
            }
            params.isMuted = false
            if !sustainEnabled {
                let rawPitch = Float(left.wrist.y)
                params.pitch = pitchFilter.smooth(rawPitch)
            }
        case .point:
            params.isPrecisionMode = true
            params.isSustaining = false
            params.isMuted = false
            let rawPitch = Float(left.wrist.y)
            let precisionPitch = precisionAnchor + (rawPitch - 0.5) * precisionRange
            params.pitch = pitchFilter.smooth(min(max(precisionPitch, 0.0), 1.0))
        default:
            params.isMuted = false
            params.isSustaining = false
            params.isPrecisionMode = false
            precisionAnchor = pitchFilter.current
            let rawPitch = Float(left.wrist.y)
            params.pitch = pitchFilter.smooth(rawPitch)
        }

        detectVibrato(wristY: Float(left.wrist.y), params: &params)
    }

    // MARK: - Finger Per Note

    private func processFingerPerNote(_ hand: HandLandmarks, params: inout MusicalParameters) {
        let fingers = FingerState.from(hand)

        // Hand height selects octave
        let handY = min(max(Float(hand.wrist.y), 0.0), 1.0)
        let octaveOffset = Int(handY * Float(arpeggiator.scaleOctaveRange))
        let clampedOctaveOffset = min(octaveOffset, arpeggiator.scaleOctaveRange - 1)

        let semitones = arpeggiator.scale.semitones
        let baseMidi = (arpeggiator.baseOctave + 1) * 12 + arpeggiator.rootNote.semitoneOffset + clampedOctaveOffset * 12

        // Each finger = independent voice mapped to a scale degree
        let fingerStates = [fingers.thumbExtended, fingers.indexExtended,
                            fingers.middleExtended, fingers.ringExtended, fingers.littleExtended]

        var freqs: (Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0)
        var active: (Bool, Bool, Bool, Bool, Bool) = (false, false, false, false, false)

        for i in 0..<5 {
            let semitone = semitones[min(i, semitones.count - 1)]
            let freq = ScaleHelper.midiNoteToFrequency(Float(baseMidi + semitone))
            let isOn = !fingerStates[i]  // finger curled (down) = note on, like a piano

            switch i {
            case 0: freqs.0 = freq; active.0 = isOn
            case 1: freqs.1 = freq; active.1 = isOn
            case 2: freqs.2 = freq; active.2 = isOn
            case 3: freqs.3 = freq; active.3 = isOn
            case 4: freqs.4 = freq; active.4 = isOn
            default: break
            }
        }

        params.fingerMode = true
        params.fingerFrequencies = freqs
        params.fingerActive = active
        params.isMuted = fingers.extendedCount == 5  // all fingers up = silence

        detectVibrato(wristY: Float(hand.wrist.y), params: &params)
    }

    // MARK: - Right Hand (Expression)

    private func processRightHand(_ hand: HandLandmarks?, params: inout MusicalParameters) {
        guard let right = hand else {
            // In finger mode, default to full volume when right hand absent
            params.volume = volumeFilter.smooth(params.fingerMode ? 0.8 : 0.0)
            return
        }

        let rawGesture = GestureDetector.detectGesture(hand: right)
        let gesture = rightDebouncer.update(rawGesture)

        let rawVolume = Float(right.wrist.y)
        params.volume = volumeFilter.smooth(min(max(rawVolume, 0.0), 1.0))

        let spread = GestureDetector.fingerSpread(hand: right)
        params.filterCutoff = filterCutoffFilter.smooth(spread)

        switch gesture {
        case .fist:
            if !params.fingerMode { params.isMuted = true }
        case .pinch:
            if sustainEnabled {
                params.isSustaining = true
            }
        case .peace:
            if Date().timeIntervalSince(lastPeaceGestureTime) > 1.0 {
                params.isQuantized.toggle()
                lastPeaceGestureTime = Date()
            }
        default:
            break
        }
    }

    // MARK: - Vibrato Detection

    private func detectVibrato(wristY: Float, params: inout MusicalParameters) {
        wristYHistory.append(wristY)
        if wristYHistory.count > vibratoHistorySize {
            wristYHistory.removeFirst()
        }

        guard wristYHistory.count >= 6 else {
            params.vibratoDepth = 0
            params.vibratoRate = 5.0
            return
        }

        var deltas: [Float] = []
        for i in 1..<wristYHistory.count {
            deltas.append(wristYHistory[i] - wristYHistory[i - 1])
        }

        var signChanges = 0
        for i in 1..<deltas.count {
            if deltas[i] * deltas[i - 1] < 0 {
                signChanges += 1
            }
        }

        let amplitude = (wristYHistory.max() ?? 0) - (wristYHistory.min() ?? 0)

        if signChanges >= 3 && amplitude > 0.02 {
            params.vibratoDepth = min(amplitude * 5.0, 1.0)
            let estimatedHz = Float(signChanges) / Float(wristYHistory.count) * 30.0
            params.vibratoRate = min(max(estimatedHz, 3.0), 12.0)
        } else {
            params.vibratoDepth = 0
            params.vibratoRate = 5.0
        }
    }

    // MARK: - Display Updates

    private func throttledDisplayUpdate(_ params: MusicalParameters) {
        let now = CFAbsoluteTimeGetCurrent()
        guard now - lastDisplayUpdate >= displayUpdateInterval else { return }
        lastDisplayUpdate = now
        let p = params
        DispatchQueue.main.async { [weak self] in
            self?.displayPitch = p.pitch
            self?.displayVolume = p.volume
            self?.displayMuted = p.isMuted
            self?.displayWaveform = p.waveform
            self?.displaySustaining = p.isSustaining
            self?.displayQuantized = p.isQuantized
        }
    }
}
