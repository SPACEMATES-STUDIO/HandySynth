import SwiftUI

struct ContentView: View {
    @EnvironmentObject var settings: AppSettings
    @EnvironmentObject var cameraManager: CameraManager
    @EnvironmentObject var handTracker: HandTrackingManager
    @EnvironmentObject var gestureInterpreter: GestureInterpreter
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var coordinator: PipelineCoordinator

    @State private var showSettings = false

    var body: some View {
        HStack(spacing: 0) {
            cameraPanel

            if settings.showVisualizer {
                MetalVisualizerView(renderer: $coordinator.visualizerRenderer, fftAnalyzer: coordinator.fftAnalyzer)
                    .onAppear { coordinator.wireVisualizer() }
                    .onDisappear { coordinator.unwireVisualizer() }
            }
        }
        .ignoresSafeArea()
        .task {
            await coordinator.start()
        }
        .onChange(of: settings.showVisualizer) { _, newValue in
            if newValue {
                coordinator.wireVisualizer()
            } else {
                coordinator.unwireVisualizer()
            }
        }
    }

    // MARK: - Camera Panel

    private var cameraPanel: some View {
        ZStack {
            Color.black

            if !settings.hideCameraFeed || !settings.showBodyWireframe {
                CameraPreviewView(session: cameraManager.session)
                    .scaleEffect(x: -1, y: 1)
            }

            if settings.showBodyWireframe {
                BodyWireframeOverlayView(
                    body_: handTracker.bodyLandmarks,
                    leftHand: handTracker.leftHand,
                    rightHand: handTracker.rightHand
                )
                .scaleEffect(x: -1, y: 1)
            }

            HandDebugOverlayView(
                leftHand: settings.showHandSkeleton && !settings.showBodyWireframe ? handTracker.leftHand : nil,
                rightHand: settings.showHandSkeleton && !settings.showBodyWireframe ? handTracker.rightHand : nil
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

            Text("FINGER")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.purple)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.purple.opacity(0.2))
                .cornerRadius(4)
                .opacity(settings.fingerPerNoteMode ? 1 : 0)

            Text("CHORD")
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(.mint)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.mint.opacity(0.2))
                .cornerRadius(4)
                .opacity(gestureInterpreter.displayChordMode ? 1 : 0)

            Text(bimanualBadgeLabel)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(bimanualBadgeColor)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(bimanualBadgeColor.opacity(0.2))
                .cornerRadius(4)
                .opacity(gestureInterpreter.displayBimanualReverb ? 1 : 0)
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

    private var bimanualBadgeLabel: String {
        switch settings.bimanualTarget {
        case .reverb: return "REVERB~"
        case .delay: return "DELAY~"
        }
    }

    private var bimanualBadgeColor: Color {
        switch settings.bimanualTarget {
        case .reverb: return .blue
        case .delay: return .teal
        }
    }

    private var waveformIcon: String {
        switch gestureInterpreter.displayWaveform {
        case .sine: return "waveform.path"
        case .triangle: return "triangle"
        case .sawtooth: return "waveform"
        case .square: return "square.on.square"
        case .fm: return "antenna.radiowaves.left.and.right"
        case .pad: return "waveform.badge.plus"
        }
    }

}
