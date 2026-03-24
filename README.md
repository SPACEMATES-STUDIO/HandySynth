# HandySynth

A macOS app that turns your hands into a musical instrument — track hand gestures via the front camera and play real-time synthesized audio.

![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![Vision](https://img.shields.io/badge/Vision-Hand%20Tracking-green)
![AVAudioEngine](https://img.shields.io/badge/AVAudioEngine-Synthesis-red)

## Features

- **Real-time hand tracking** — Vision framework detects 21 landmarks per hand at 30fps
- **Four waveforms** — Sine, Triangle, Sawtooth, Pad (5-voice detuned unison)
- **Five musical scales** — Major, Minor, Pentatonic, Chromatic, Blues with configurable root note
- **Expressive gestures** — pitch, volume, mute, sustain, precision mode, vibrato, filter cutoff
- **Finger-per-note mode** — piano-style polyphony, curl each finger to play its scale degree
- **Arpeggiator** — scale-aware pattern cycling (up/down/upDown/random) with configurable BPM
- **Attack/release envelope** — smooth note transitions with adjustable timing
- **Metal terrain visualizer** — FFT-driven scrolling mountain ridges in a toggleable split view
- **Effects** — Reverb and delay with adjustable mix
- **Low latency** — ~50-60ms end-to-end (camera to audio output)
- **Zero external dependencies** — pure SwiftUI + AVFoundation + Vision + Metal

## Requirements

| Requirement | Version |
|---|---|
| macOS | 14.0+ (Sonoma) |
| Xcode | 15+ |
| Hardware | Mac with front-facing camera |
| Permission | Camera access |

## Setup

```bash
git clone <repo-url>
cd HandySynth
open HandySynth.xcodeproj
```

Build and Run (Cmd+R). Grant camera permission when prompted.

## How It Works

```
Front Camera (AVCaptureSession, 30fps)
    -> HandTrackingManager (VNDetectHumanHandPoseRequest, 2 hands)
        -> GestureInterpreter (smoothing + debouncing + gesture detection)
            -> AudioEngine (AVAudioSourceNode -> Reverb -> Delay -> Output)
                -> FFTAnalyzer -> Metal Terrain Visualizer
```

The camera captures video frames on a background queue. Each frame is processed by the Vision framework to detect up to two hand poses (left and right). The gesture interpreter converts raw landmarks into musical parameters using exponential smoothing and frame-based debouncing. The audio engine synthesizes sound in real-time using an `AVAudioSourceNode` render callback with portamento, vibrato, and a one-pole low-pass filter.

## Gesture Reference

### Standard Mode

| Gesture | Hand | Effect |
|---|---|---|
| Hand height (up/down) | Left | Pitch — bottom is low, top is high |
| Hand height (up/down) | Right | Volume |
| Fist | Either | Mute |
| Pinch (thumb + index) | Either | Sustain current note (toggleable in settings) |
| Point (index finger) | Left | Precision pitch mode (narrow range around current note) |
| Peace sign | Right | Toggle quantized/chromatic mode |
| Finger spread | Right | Filter cutoff (closed = dark, open = bright) |
| Hand shake | Left | Vibrato (depth and rate from motion) |

### Finger-Per-Note Mode

Piano-style polyphony — curl a finger down to play its note, lift to stop. Each finger maps to a scale degree. Right hand still controls volume and effects, or can be omitted (defaults to 80% volume).

| Finger | Scale Degree |
|---|---|
| Thumb | 1st (root) |
| Index | 2nd |
| Middle | 3rd |
| Ring | 4th |
| Little | 5th |
| Hand height | Octave select |

## Project Structure

```
HandySynth/
├── App/
│   └── HandySynthApp.swift             — Entry point, dependency injection
├── Managers/
│   ├── CameraManager.swift              — Camera capture session
│   ├── HandTrackingManager.swift        — Vision hand pose detection
│   ├── GestureInterpreter.swift         — Gesture recognition + parameter mapping
│   ├── AudioEngine.swift                — Real-time audio synthesis + effects
│   ├── Arpeggiator.swift                — Scale-aware arpeggiator engine
│   └── FFTAnalyzer.swift                — Accelerate FFT for visualizer
├── Models/
│   ├── AppSettings.swift                — Centralized app settings
│   ├── MusicalParameters.swift          — Audio parameter struct
│   ├── HandLandmarks.swift              — Hand joint data model
│   ├── GestureState.swift               — Gesture detection logic
│   └── ScaleDefinitions.swift           — Musical scale definitions
├── Views/
│   ├── ContentView.swift                — Main view with camera + overlays
│   ├── CameraPreviewView.swift          — Live camera feed
│   ├── PitchOverlayView.swift           — Pitch scale indicator
│   ├── VolumeOverlayView.swift          — Volume meter
│   ├── HandDebugOverlayView.swift       — Hand skeleton overlay
│   ├── MetalVisualizerView.swift        — Metal terrain visualizer wrapper
│   └── SettingsView.swift               — Settings panel
├── Metal/
│   ├── ShaderTypes.h                    — Shared C structs for Metal uniforms
│   ├── Shaders.metal                    — Terrain vertex/fragment shaders
│   └── VisualizerRenderer.swift         — MTKViewDelegate terrain renderer
├── Utilities/
│   └── SmoothingFilter.swift            — Signal smoothing filter
└── Resources/
    ├── Info.plist
    └── Assets.xcassets/
```

## Settings

All settings persist across launches. Configurable via the gear icon:

- **Waveform** — Sine, Triangle, Sawtooth, Pad
- **Scale** — Major, Minor, Pentatonic, Chromatic, Blues
- **Root note** — C through B
- **Base octave** — 1–5
- **Octave range** — 1–4
- **Quantized mode** — Snap to scale notes
- **Portamento** — Pitch glide speed
- **Envelope** — Attack (0–500ms) and release (0–2000ms)
- **Arpeggiator** — Enable/disable, BPM, pattern, octave range
- **Reverb mix** — 0–100%
- **Delay mix** — 0–100%
- **Visualizer** — Toggle split view, terrain height/spacing, primary/secondary colors
- **Finger-per-note** — Piano-style polyphonic mode
- **Sustain enabled** — Allow pinch gesture to hold notes
- **Show hand skeleton** — Debug overlay toggle

## Privacy

All camera processing happens locally on-device using Apple's Vision framework. No video, audio, or gesture data is stored, recorded, or transmitted.
