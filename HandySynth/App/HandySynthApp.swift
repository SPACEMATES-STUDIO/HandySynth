import SwiftUI

@main
struct HandySynthApp: App {
    @StateObject private var settings: AppSettings
    @StateObject private var cameraManager: CameraManager
    @StateObject private var handTracker: HandTrackingManager
    @StateObject private var gestureInterpreter: GestureInterpreter
    @StateObject private var audioEngine: AudioEngine
    @StateObject private var coordinator: PipelineCoordinator

    init() {
        let s = AppSettings()
        let cm = CameraManager()
        let ht = HandTrackingManager()
        let gi = GestureInterpreter()
        let ae = AudioEngine()
        _settings = StateObject(wrappedValue: s)
        _cameraManager = StateObject(wrappedValue: cm)
        _handTracker = StateObject(wrappedValue: ht)
        _gestureInterpreter = StateObject(wrappedValue: gi)
        _audioEngine = StateObject(wrappedValue: ae)
        _coordinator = StateObject(wrappedValue: PipelineCoordinator(
            settings: s, cameraManager: cm, handTracker: ht,
            gestureInterpreter: gi, audioEngine: ae
        ))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(cameraManager)
                .environmentObject(handTracker)
                .environmentObject(gestureInterpreter)
                .environmentObject(audioEngine)
                .environmentObject(coordinator)
        }
        .defaultSize(width: 1000, height: 700)
    }
}
