# HandySynth

Native macOS SwiftUI app that turns hand gestures into a real-time musical instrument using the front camera.

- **Stack**: SwiftUI, AVFoundation, Vision, AVAudioEngine, Metal
- **Target**: macOS 14.0+ (Sonoma)
- **Bundle ID**: `com.anthony.HandySynth`
- **Dependencies**: None (pure Apple frameworks)

## Build & Run

1. Open `HandySynth.xcodeproj` in Xcode
2. Build and Run (Cmd+R)
3. Grant camera permission when prompted

No secrets, keys, or additional setup required.

## Architecture

### Real-Time Pipeline

```
Front Camera (AVCaptureSession, 30fps)
  -> HandTrackingManager (VNDetectHumanHandPoseRequest, 2 hands, background queue)
    -> GestureInterpreter (gesture detection + smoothing, background queue)
      -> AudioEngine (AVAudioSourceNode render callback, real-time audio thread)
        -> FFTAnalyzer -> Metal Terrain Visualizer
```

### Two Data Paths

- **Audio path**: Runs every frame (~30fps) on the camera's background queue. `GestureInterpreter.parameters` is a plain struct (NOT @Published) read/written on this queue. `AudioEngine.audioParams` is protected by `os_unfair_lock`.
- **Display path**: Throttled to ~15fps. `GestureInterpreter.display*` properties are `@Published` and dispatched to main queue. UI never drives audio.

### Threading

| Queue | Components |
|---|---|
| Camera queue (`.userInteractive`) | CameraManager, HandTrackingManager, GestureInterpreter.update(), AudioEngine.updateParameters() |
| Real-time audio thread | AudioEngine.renderAudio() — no locks, no allocations |
| Metal render thread | VisualizerRenderer.draw() — reads FFT bands via NSLock |
| Main thread | All SwiftUI views, @Published updates |

## File Structure

```
HandySynth/
├── App/
│   └── HandySynthApp.swift              — @main entry, manager + settings injection
├── Managers/
│   ├── CameraManager.swift              — AVCaptureSession, frame delivery via closure
│   ├── HandTrackingManager.swift        — Vision hand pose, left/right classification
│   ├── GestureInterpreter.swift         — Landmarks -> musical parameters + gestures
│   ├── AudioEngine.swift                — Synthesis, effects chain, thread-safe params
│   ├── Arpeggiator.swift                — Scale-aware arpeggiator engine
│   └── FFTAnalyzer.swift                — Accelerate FFT for visualizer
├── Models/
│   ├── AppSettings.swift                — Centralized @AppStorage settings
│   ├── MusicalParameters.swift          — Audio state struct + Waveform enum
│   ├── HandLandmarks.swift              — 21 joint points + bone connections
│   ├── GestureState.swift               — Gesture detection, enums, debouncer
│   └── ScaleDefinitions.swift           — Scales, notes, frequency mapping
├── Views/
│   ├── ContentView.swift                — Main compositor, pipeline wiring
│   ├── CameraPreviewView.swift          — NSViewRepresentable for camera feed
│   ├── PitchOverlayView.swift           — Canvas-based pitch ruler (top)
│   ├── VolumeOverlayView.swift          — Canvas-based volume meter (right)
│   ├── HandDebugOverlayView.swift       — Canvas-based hand skeleton overlay
│   ├── MetalVisualizerView.swift        — NSViewRepresentable for MTKView
│   └── SettingsView.swift               — Settings popover
├── Metal/
│   ├── ShaderTypes.h                    — Shared C structs for Metal uniforms
│   ├── Shaders.metal                    — Terrain vertex/fragment shaders
│   └── VisualizerRenderer.swift         — MTKViewDelegate terrain renderer
├── Utilities/
│   └── SmoothingFilter.swift            — Exponential moving average filter
└── Resources/
    ├── Info.plist                        — Camera usage description
    └── Assets.xcassets/
```

## Key Conventions

- **Settings**: Centralized in `AppSettings` (`ObservableObject` with `@AppStorage`). Never read `UserDefaults.standard` directly from business logic.
- **Background queue rule**: `GestureInterpreter.update()` runs on a background queue. It must NOT touch `@Published` properties directly — use `DispatchQueue.main.async` for display updates.
- **Vision coordinates**: Origin bottom-left, x/y normalized 0–1.
- **Camera mirroring**: Camera and skeleton views are individually flipped via `.scaleEffect(x: -1, y: 1)` for selfie view. UI elements are not mirrored.
- **Audio thread safety**: `os_unfair_lock` protects `AudioEngine.audioParams`. No allocations or locks in `renderAudio()` beyond the param copy.

## Testing

Manual testing procedure:
1. Launch app, verify camera feed displays
2. Raise both hands — skeleton overlay should track joints
3. Move left hand up/down — pitch changes
4. Move right hand up/down — volume changes
5. Make fist — audio mutes
6. Pinch (if enabled in settings) — note sustains
7. Point with left hand — precision pitch mode
8. Peace sign with right hand — toggles quantized mode
9. Spread fingers on right hand — filter opens
10. Shake left hand — vibrato
11. Enable arpeggiator — hear scale patterns cycling
12. Toggle visualizer — terrain appears in right half responding to audio
13. Open settings, change scale/waveform/effects — verify changes apply
