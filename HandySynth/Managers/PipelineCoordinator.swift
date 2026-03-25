import SwiftUI
import Combine

class PipelineCoordinator: ObservableObject {
    @Published var visualizerRenderer: VisualizerRenderer?
    @Published var fftAnalyzer: FFTAnalyzer?
    @Published var pipelineReady: Bool = false

    private let settings: AppSettings
    private let cameraManager: CameraManager
    private let handTracker: HandTrackingManager
    private let gestureInterpreter: GestureInterpreter
    private let audioEngine: AudioEngine
    private var settingsCancellable: AnyCancellable?

    init(settings: AppSettings,
         cameraManager: CameraManager,
         handTracker: HandTrackingManager,
         gestureInterpreter: GestureInterpreter,
         audioEngine: AudioEngine) {
        self.settings = settings
        self.cameraManager = cameraManager
        self.handTracker = handTracker
        self.gestureInterpreter = gestureInterpreter
        self.audioEngine = audioEngine

        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.applySettings() }
        }
    }

    func start() async {
        applySettings()
        audioEngine.start()
        try? await Task.sleep(nanoseconds: 300_000_000)
        wirePipeline()
        cameraManager.startSession()
        pipelineReady = true
    }

    // MARK: - Pipeline

    private func wirePipeline() {
        let handTracker = handTracker

        cameraManager.frameHandler = { [weak handTracker] buffer in
            handTracker?.processFrame(buffer)
        }

        handTracker.onHandsDetected = { [weak self] left, right in
            guard let self = self else { return }
            let interpreter = self.gestureInterpreter
            let engine = self.audioEngine
            let settings = self.settings

            // Push settings every frame to ensure they're always current
            self.handTracker.bodyTrackingEnabled = settings.showBodyWireframe
            interpreter.sustainEnabled = settings.sustainEnabled
            interpreter.waveformOverride = settings.selectedWaveform
            interpreter.fingerPerNoteEnabled = settings.fingerPerNoteMode

            let arp = interpreter.arpeggiator
            arp.enabled = settings.arpEnabled
            arp.bpm = settings.arpBPM
            arp.pattern = settings.arpPattern
            arp.octaveRange = settings.arpOctaveRange
            arp.scale = settings.selectedScale
            arp.rootNote = settings.rootNote
            arp.baseOctave = settings.baseOctave
            arp.scaleOctaveRange = settings.octaveRange

            engine.scale = settings.selectedScale
            engine.rootNote = settings.rootNote
            engine.baseOctave = settings.baseOctave
            engine.octaveRange = settings.octaveRange
            engine.portamentoSpeed = settings.portamentoSpeedFloat
            engine.attackTimeMs = Float(settings.attackTimeMs)
            engine.releaseTimeMs = Float(settings.releaseTimeMs)

            engine.fmRatio = settings.fmRatioFloat
            engine.fmDepth = settings.fmDepthFloat

            interpreter.update(leftHand: left, rightHand: right)
            var params = interpreter.parameters
            if settings.isQuantized { params.isQuantized = true }

            if params.bimanualActive {
                switch settings.bimanualTarget {
                case .reverb:
                    params.reverbMix = params.bimanualAmount
                    params.delayMix = settings.delayMixFloat
                case .delay:
                    params.reverbMix = settings.reverbMixFloat
                    params.delayMix = params.bimanualAmount
                }
            } else {
                params.reverbMix = settings.reverbMixFloat
                params.delayMix = settings.delayMixFloat
            }

            engine.updateParameters(params)
        }
    }

    // MARK: - Visualizer

    func wireVisualizer() {
        let analyzer = FFTAnalyzer(fftSize: 1024, bandCount: 32, sampleRate: 44100)
        fftAnalyzer = analyzer

        audioEngine.audioTapHandler = { samples in
            analyzer.analyze(samples: samples)
        }

        updateVisualizerColors()
    }

    func unwireVisualizer() {
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
        // Body tracking
        handTracker.bodyTrackingEnabled = settings.showBodyWireframe

        // AudioEngine
        audioEngine.scale = settings.selectedScale
        audioEngine.rootNote = settings.rootNote
        audioEngine.baseOctave = settings.baseOctave
        audioEngine.octaveRange = settings.octaveRange
        audioEngine.portamentoSpeed = settings.portamentoSpeedFloat
        audioEngine.attackTimeMs = Float(settings.attackTimeMs)
        audioEngine.releaseTimeMs = Float(settings.releaseTimeMs)
        audioEngine.fmRatio = settings.fmRatioFloat
        audioEngine.fmDepth = settings.fmDepthFloat

        // GestureInterpreter
        gestureInterpreter.sustainEnabled = settings.sustainEnabled
        gestureInterpreter.waveformOverride = settings.selectedWaveform
        gestureInterpreter.fingerPerNoteEnabled = settings.fingerPerNoteMode

        // Arpeggiator
        let arp = gestureInterpreter.arpeggiator
        arp.enabled = settings.arpEnabled
        arp.bpm = settings.arpBPM
        arp.pattern = settings.arpPattern
        arp.octaveRange = settings.arpOctaveRange
        arp.scale = settings.selectedScale
        arp.rootNote = settings.rootNote
        arp.baseOctave = settings.baseOctave
        arp.scaleOctaveRange = settings.octaveRange

        // Visualizer
        updateVisualizerColors()
    }
}
