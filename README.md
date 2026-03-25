# HandySynth

A macOS app that turns your hands into a musical instrument — track hand gestures via the front camera and play real-time synthesized audio.

![macOS 14.0+](https://img.shields.io/badge/macOS-14.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-5-orange)
![Vision](https://img.shields.io/badge/Vision-Hand%20Tracking-green)
![AVAudioEngine](https://img.shields.io/badge/AVAudioEngine-Synthesis-red)

## Features

- **Real-time hand tracking** — Vision framework detects 21 landmarks per hand at 30fps
- **Six waveforms** — Sine, Triangle, Sawtooth, Square, Pad (5-voice detuned unison), FM synthesis
- **Five musical scales** — Major, Minor, Pentatonic, Chromatic, Blues with configurable root note
- **Expressive gestures** — pitch, volume, mute, sustain, precision mode, vibrato, filter cutoff
- **Overdrive** — curl left-hand fingers to add cubic soft-clip distortion
- **Chord harmonization** — spread left-hand fingers to add scale-aware 3rd and 5th voices
- **Bimanual effect control** — move hands apart/together to sweep Reverb or Delay in real time
- **Pad detune** — tilt left hand to control detuning depth of the Pad waveform
- **Finger-per-note mode** — piano-style polyphony, curl each finger to play its scale degree
- **Arpeggiator** — scale-aware pattern cycling (up/down/upDown/random) with configurable BPM
- **Attack/release envelope** — smooth note transitions with adjustable timing
- **Body wireframe overlay** — 3D rigged model driven by Vision body pose tracking
- **Metal terrain visualizer** — FFT-driven scrolling mountain ridges in a toggleable split view
- **Effects** — Reverb and delay with adjustable mix
- **Per-gesture toggles** — enable/disable individual gestures in settings to avoid conflicts
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

**Left hand — pitch & expression**

| Gesture | Effect | Toggleable |
|---|---|---|
| Hand height (up/down) | Pitch — bottom is low, top is high | |
| Finger spread | Chord mode — adds 3rd and 5th scale degrees | ✓ |
| Finger curl (4→1 extended) | Overdrive — 4 open = clean, curl down = grit | ✓ |
| Hand tilt | Pad detune depth (tilt knuckles up for wider spread) | ✓ |
| Point (index finger) | Precision pitch mode (narrow range around current note) | |
| Pinch (thumb + index) | Sustain current note | ✓ |
| Hand shake | Vibrato (depth and rate from motion) | ✓ |
| Fist | Mute | |

**Right hand — volume & effects**

| Gesture | Effect | Toggleable |
|---|---|---|
| Hand height (up/down) | Volume | |
| Finger spread | Filter cutoff (closed = dark, open = bright) | ✓ |
| Peace sign | Toggle quantized/chromatic mode | |
| Fist | Mute | |

**Both hands**

| Gesture | Effect | Toggleable |
|---|---|---|
| Hands apart | Sweeps Reverb or Delay (configurable in settings) | ✓ |

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
│   └── HandySynthApp.swift              — Entry point, dependency injection
├── Managers/
│   ├── CameraManager.swift              — Camera capture session
│   ├── HandTrackingManager.swift        — Vision hand + body pose detection
│   ├── PipelineCoordinator.swift        — Wires camera → gesture → audio pipeline
│   ├── GestureInterpreter.swift         — Gesture recognition + parameter mapping
│   ├── AudioEngine.swift                — Real-time audio synthesis + effects
│   ├── Arpeggiator.swift                — Scale-aware arpeggiator engine
│   └── FFTAnalyzer.swift                — Accelerate FFT for visualizer
├── Models/
│   ├── AppSettings.swift                — Centralized app settings
│   ├── MusicalParameters.swift          — Audio parameter struct
│   ├── HandLandmarks.swift              — Hand joint data model
│   ├── BodyLandmarks.swift              — Body pose joint data model
│   ├── GestureState.swift               — Gesture detection logic
│   └── ScaleDefinitions.swift           — Musical scale definitions
├── Views/
│   ├── ContentView.swift                — Main view with camera + overlays
│   ├── CameraPreviewView.swift          — Live camera feed
│   ├── BodyWireframeOverlayView.swift   — 3D rigged model driven by body pose
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
    ├── human_rigged.dae                 — Rigged 3D model for body wireframe
    └── Assets.xcassets/
```

## Settings

All settings persist across launches. Configurable via the gear icon (⚙).

**Synth**
- **Waveform** — Sine, Triangle, Sawtooth, Square, Pad, FM
- **FM Ratio / Depth** — modulator frequency ratio and intensity (visible when FM selected)
- **Finger Per Note** — switch to piano-style polyphonic mode
- **Attack / Release** — envelope timing (0–500ms / 0–2000ms)

**Pitch**
- **Scale** — Major, Minor, Pentatonic, Chromatic, Blues
- **Root note** — C through B
- **Base octave / Octave range** — playing range
- **Quantized mode** — snap pitch to scale notes
- **Portamento** — pitch glide amount (0–100%)

**Arpeggiator**
- Enable/disable, BPM (60–300), pattern (Up/Down/Up-Down/Random), octave range

**Effects**
- **Hands Apart →** — choose what the bimanual gesture controls: Reverb or Delay
- **Reverb mix / Delay mix** — fallback levels when gesture is inactive

**Visualizer**
- Toggle split view, terrain height/spacing, primary/secondary colors

**Gesture Cheat Sheet**
- Per-gesture enable toggles for: chord mode, pad detune, overdrive, sustain, vibrato, filter cutoff, bimanual effect

**Display**
- Show hand skeleton overlay
- Body wireframe mode (3D rigged model driven by body pose)
- Hide camera feed (when body wireframe is active)

## Privacy

All camera processing happens locally on-device using Apple's Vision framework. No video, audio, or gesture data is stored, recorded, or transmitted.
