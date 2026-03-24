import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var handTracker: HandTrackingManager
    @EnvironmentObject var gestureInterpreter: GestureInterpreter
    @EnvironmentObject var audioEngine: AudioEngine

    @State private var showSettings = false
    @State private var pipelineReady = false
    @State private var visualizerRenderer: VisualizerRenderer?
    @State private var fftAnalyzer: FFTAnalyzer?

    var body: some View {
        HStack(spacing: 0) {
            cameraPanel

            if settings.showVisualizer {
                MetalVisualizerView(renderer: $visualizerRenderer, fftAnalyzer: fftAnalyzer)
                    .onAppear { wireVisualizer() }
                    .onDisappear { unwireVisualizer() }
            }
        }
        .ignoresSafeArea()
        .task {
            applySettings()
            audioEngine.start()
            try? await Task.sleep(nanoseconds: 300_000_000)
            wirePipeline()
            cameraManager.startSession()
            pipelineReady = true
        }
        .onReceive(settings.objectWillChange) { _ in
            applySettings()
        }
        .onChange(of: settings.showVisualizer) { _, newValue in
            if newValue {
                wireVisualizer()
            } else {
                unwireVisualizer()
            }
        }
    }

    // MARK: - Camera Panel

    private var cameraPanel: some View {
        ZStack {
            Color.black

            CameraPreviewView(session: cameraManager.session)
                .scaleEffect(x: -1, y: 1)

            HandDebugOverlayView(
                leftHand: settings.showHandSkeleton ? handTracker.leftHand : nil,
                rightHand: settings.showHandSkeleton ? handTracker.rightHand : nil
            )
            .scaleEffect(x: -1, y: 1)

            VStack(spacing: 0) {
                PitchOverlayView(
                    currentPitch: gestureInterpreter.displayPitch,
                    currentNoteName: audioEngine.currentNoteName,
                    isQuantized: gestureInterpreter.displayQuantized || settings.isQuantized,
                    scale: settings.selectedScale,
                    rootNote: settings.rootNote,
                    baseOctave: settings.baseOctave,
                    octaveRange: settings.octaveRange
                )
                .padding(.top, 8)
                Spacer()
            }

            HStack(spacing: 0) {
                Spacer()
                VolumeOverlayView(
                    volume: gestureInterpreter.displayVolume,
                    isMuted: gestureInterpreter.displayMuted
                )
            }

            VStack(spacing: 0) {
                Spacer()
                HStack {
                    statusBar
                    Spacer()
                    settingsButton
                }
                .padding(12)
            }

            if let error = cameraManager.cameraError {
                Text(error)
                    .foregroundColor(.white)
                    .padding()
                    .background(.red.opacity(0.8))
                    .cornerRadius(8)
            }
        }
    }

    // MARK: - Status Bar

    private var statusBar: some View {
        HStack(spacing: 6) {
            Image(systemName: waveformIcon)
                .foregroundColor(.cyan)
            Text(gestureInterpreter.displayWaveform.rawValue)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(.white.opacity(0.8))

            Text("SUSTAIN")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.yellow)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.yellow.opacity(0.2))
                .cornerRadius(4)
                .opacity(gestureInterpreter.displaySustaining ? 1 : 0)

            Text("QUANTIZED")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.green)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.green.opacity(0.2))
                .cornerRadius(4)
                .opacity((gestureInterpreter.displayQuantized || settings.isQuantized) ? 1 : 0)

            Text("ARP")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.orange)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.orange.opacity(0.2))
                .cornerRadius(4)
                .opacity(settings.arpEnabled ? 1 : 0)
        }
        .padding(8)
        .background(.black.opacity(0.4))
        .cornerRadius(8)
    }

    private var settingsButton: some View {
        Button {
            showSettings.toggle()
        } label: {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 18))
                .foregroundColor(.white.opacity(0.8))
                .padding(10)
                .background(.black.opacity(0.4))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showSettings) {
            SettingsView(settings: settings)
        }
    }

    private var waveformIcon: String {
        switch gestureInterpreter.displayWaveform {
        case .sine: return "waveform.path"
        case .triangle: return "triangle"
        case .sawtooth: return "waveform"
        case .pad: return "waveform.badge.plus"
        }
    }

    // MARK: - Pipeline

    private func wirePipeline() {
        let interpreter = gestureInterpreter
        let engine = audioEngine
        let settings = settings

        cameraManager.frameHandler = { [weak handTracker] buffer in
            handTracker?.processFrame(buffer)
        }

        handTracker.onHandsDetected = { [weak interpreter, weak engine, weak settings] left, right in
            guard let interpreter = interpreter, let engine = engine, let settings = settings else { return }
            interpreter.sustainEnabled = settings.sustainEnabled
            interpreter.waveformOverride = settings.selectedWaveform

            // Push arpeggiator settings
            let arp = interpreter.arpeggiator
            arp.enabled = settings.arpEnabled
            arp.bpm = settings.arpBPM
            arp.pattern = settings.arpPattern
            arp.octaveRange = settings.arpOctaveRange
            arp.scale = settings.selectedScale
            arp.rootNote = settings.rootNote
            arp.baseOctave = settings.baseOctave
            arp.scaleOctaveRange = settings.octaveRange

            interpreter.update(leftHand: left, rightHand: right)
            var params = interpreter.parameters
            if settings.isQuantized { params.isQuantized = true }
            params.reverbMix = settings.reverbMixFloat
            params.delayMix = settings.delayMixFloat
            engine.updateParameters(params)
        }
    }

    // MARK: - Visualizer Wiring

    private func wireVisualizer() {
        let analyzer = FFTAnalyzer(fftSize: 1024, bandCount: 32, sampleRate: 44100)
        fftAnalyzer = analyzer

        audioEngine.audioTapHandler = { samples in
            analyzer.analyze(samples: samples)
        }

        updateVisualizerColors()
    }

    private func unwireVisualizer() {
        audioEngine.audioTapHandler = nil
        fftAnalyzer = nil
    }

    private func updateVisualizerColors() {
        guard let renderer = visualizerRenderer else { return }
        renderer.colorPrimary = SIMD4<Float>(
            Float(settings.vizColorPrimaryR),
            Float(settings.vizColorPrimaryG),
            Float(settings.vizColorPrimaryB),
            1.0
        )
        renderer.colorSecondary = SIMD4<Float>(
            Float(settings.vizColorSecondaryR),
            Float(settings.vizColorSecondaryG),
            Float(settings.vizColorSecondaryB),
            1.0
        )
        renderer.spectrumHeight = Float(settings.vizTerrainHeight)
        renderer.spacing = Float(settings.vizTerrainSpacing)
    }

    // MARK: - Settings

    private func applySettings() {
        audioEngine.scale = settings.selectedScale
        audioEngine.rootNote = settings.rootNote
        audioEngine.baseOctave = settings.baseOctave
        audioEngine.octaveRange = settings.octaveRange
        audioEngine.portamentoSpeed = settings.portamentoSpeedFloat
        audioEngine.attackTimeMs = Float(settings.attackTimeMs)
        audioEngine.releaseTimeMs = Float(settings.releaseTimeMs)
        updateVisualizerColors()
    }
}
