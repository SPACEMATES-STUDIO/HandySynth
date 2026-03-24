import SwiftUI

@main
struct HandySynthApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var cameraManager = CameraManager()
    @StateObject private var handTracker = HandTrackingManager()
    @StateObject private var gestureInterpreter = GestureInterpreter()
    @StateObject private var audioEngine = AudioEngine()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(settings)
                .environmentObject(cameraManager)
                .environmentObject(handTracker)
                .environmentObject(gestureInterpreter)
                .environmentObject(audioEngine)
        }
        .defaultSize(width: 1000, height: 700)
    }
}
