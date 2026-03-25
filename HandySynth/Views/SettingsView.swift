import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2.bold())

                GroupBox("Synth") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Waveform")
                            Spacer()
                            Picker("", selection: $settings.selectedWaveformRaw) {
                                ForEach(Waveform.allCases) { waveform in
                                    Text(waveform.rawValue).tag(waveform.rawValue)
                                }
                            }
                            .frame(width: 140)
                        }

                        if settings.selectedWaveform == .fm {
                            HStack {
                                Text("FM Ratio")
                                Slider(value: $settings.fmRatio, in: 0.5...8.0)
                                Text(String(format: "%.1f", settings.fmRatio))
                                    .frame(width: 36, alignment: .trailing)
                                    .font(.caption.monospacedDigit())
                            }
                            HStack {
                                Text("FM Depth")
                                Slider(value: $settings.fmDepth, in: 0...5.0)
                                Text(String(format: "%.1f", settings.fmDepth))
                                    .frame(width: 36, alignment: .trailing)
                                    .font(.caption.monospacedDigit())
                            }
                        }

                        Toggle("Finger Per Note", isOn: $settings.fingerPerNoteMode)

                        HStack {
                            Text("Attack")
                            Slider(value: $settings.attackTimeMs, in: 0...500)
                            Text("\(Int(settings.attackTimeMs))ms")
                                .frame(width: 50, alignment: .trailing)
                                .font(.caption.monospacedDigit())
                        }
                        HStack {
                            Text("Release")
                            Slider(value: $settings.releaseTimeMs, in: 0...2000)
                            Text("\(Int(settings.releaseTimeMs))ms")
                                .frame(width: 50, alignment: .trailing)
                                .font(.caption.monospacedDigit())
                        }
                    }
                }

                GroupBox("Pitch") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Quantized Mode", isOn: $settings.isQuantized)

                        HStack {
                            Text("Scale")
                            Spacer()
                            Picker("", selection: $settings.selectedScaleRaw) {
                                ForEach(Scale.allCases) { scale in
                                    Text(scale.rawValue).tag(scale.rawValue)
                                }
                            }
                            .frame(width: 140)
                        }

                        HStack {
                            Text("Root Note")
                            Spacer()
                            Picker("", selection: $settings.rootNoteRaw) {
                                ForEach(RootNote.allCases) { note in
                                    Text(note.rawValue).tag(note.rawValue)
                                }
                            }
                            .frame(width: 80)
                        }

                        HStack {
                            Text("Base Octave: \(settings.baseOctave)")
                            Spacer()
                            Stepper("", value: $settings.baseOctave, in: 1...5)
                        }

                        HStack {
                            Text("Octave Range: \(settings.octaveRange)")
                            Spacer()
                            Stepper("", value: $settings.octaveRange, in: 1...4)
                        }

                        HStack {
                            Text("Portamento")
                            Slider(value: $settings.portamentoSpeed, in: 0.001...0.05)
                            Text("\(Int((settings.portamentoSpeed - 0.001) / 0.049 * 100))%")
                                .frame(width: 36, alignment: .trailing)
                                .font(.caption.monospacedDigit())
                        }
                    }
                }

                GroupBox("Arpeggiator") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enabled", isOn: $settings.arpEnabled)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("BPM")
                                Slider(value: $settings.arpBPM, in: 60...300)
                                Text("\(Int(settings.arpBPM))")
                                    .frame(width: 36, alignment: .trailing)
                                    .font(.caption.monospacedDigit())
                            }
                            HStack {
                                Text("Pattern")
                                Spacer()
                                Picker("", selection: $settings.arpPatternRaw) {
                                    ForEach(ArpPattern.allCases) { pattern in
                                        Text(pattern.rawValue).tag(pattern.rawValue)
                                    }
                                }
                                .frame(width: 120)
                            }
                            HStack {
                                Text("Octaves: \(settings.arpOctaveRange)")
                                Spacer()
                                Stepper("", value: $settings.arpOctaveRange, in: 1...3)
                            }
                        }
                        .opacity(settings.arpEnabled ? 1 : 0.35)
                    }
                }

                GroupBox("Effects") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Hands Apart →")
                            Spacer()
                            Picker("", selection: $settings.bimanualTargetRaw) {
                                ForEach(BimanualTarget.allCases) { target in
                                    Text(target.rawValue).tag(target.rawValue)
                                }
                            }
                            .frame(width: 140)
                        }

                        HStack {
                            Text("Reverb")
                            Slider(value: $settings.reverbMix, in: 0...1)
                            Text("\(Int(settings.reverbMix * 100))%")
                                .frame(width: 40, alignment: .trailing)
                                .font(.caption.monospacedDigit())
                        }
                        HStack {
                            Text("Delay")
                            Slider(value: $settings.delayMix, in: 0...1)
                            Text("\(Int(settings.delayMix * 100))%")
                                .frame(width: 40, alignment: .trailing)
                                .font(.caption.monospacedDigit())
                        }
                        Text("Reverb and Delay sliders are fallbacks when both-hands gesture is active.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                GroupBox("Visualizer") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Show Visualizer", isOn: $settings.showVisualizer)

                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Terrain Height")
                                Slider(value: $settings.vizTerrainHeight, in: 200...2000)
                            }
                            HStack {
                                Text("Spacing")
                                Slider(value: $settings.vizTerrainSpacing, in: 5...60)
                            }
                            Text("Primary Color").font(.caption.bold())
                            colorSliders(
                                r: $settings.vizColorPrimaryR,
                                g: $settings.vizColorPrimaryG,
                                b: $settings.vizColorPrimaryB
                            )
                            Text("Secondary Color").font(.caption.bold())
                            colorSliders(
                                r: $settings.vizColorSecondaryR,
                                g: $settings.vizColorSecondaryG,
                                b: $settings.vizColorSecondaryB
                            )
                        }
                        .opacity(settings.showVisualizer ? 1 : 0.35)
                    }
                }

                GroupBox("Gesture Cheat Sheet") {
                    VStack(alignment: .leading, spacing: 12) {

                        if settings.fingerPerNoteMode {
                            cheatSheetSection("LEFT HAND — Finger Per Note", color: .cyan)
                            gestureRow("👍 Thumb curled", "Root note (1st degree)")
                            gestureRow("☝️ Index curled", "2nd degree")
                            gestureRow("🖕 Middle curled", "3rd degree")
                            gestureRow("💍 Ring curled", "4th degree")
                            gestureRow("🤙 Pinky curled", "5th degree")
                            gestureRow("↕ Hand height", "Select octave")
                            gestureRow("✊ All fingers up", "Silence")
                        } else {
                            cheatSheetSection("LEFT HAND — Pitch & Expression", color: .cyan)
                            gestureRow("↕ Hand height", "Controls pitch — low = low note, high = high note")
                            gestureToggleRow("✋ Spread fingers", "Chord — adds 3rd & 5th above current note", isOn: $settings.chordGestureEnabled)
                            gestureToggleRow("↗ Tilt knuckles", "Pad detune — wider tilt = thicker sound (Pad only)", isOn: $settings.detuneGestureEnabled)
                            gestureToggleRow("✊ Curl fingers", "Overdrive — 4 fingers open = clean, curl = grit", isOn: $settings.distortionGestureEnabled)
                            gestureRow("☝️ Point", "Precision mode — slow, fine pitch control")
                            gestureToggleRow("🤏 Pinch", "Hold note (sustain)", isOn: $settings.sustainEnabled)
                            gestureToggleRow("〰 Shake wrist", "Vibrato — speed & depth from motion", isOn: $settings.vibratoEnabled)
                        }

                        cheatSheetSection("RIGHT HAND — Volume & Effects", color: .orange)
                        gestureRow("↕ Hand height", "Controls volume")
                        gestureToggleRow("✋ Spread fingers", "Filter brightness — closed = dark, open = bright", isOn: $settings.filterGestureEnabled)
                        gestureRow("✌️ Peace sign", "Toggle snap-to-scale (quantized mode)")
                        gestureRow("✊ Fist", "Mute")

                        cheatSheetSection("BOTH HANDS", color: .purple)
                        gestureToggleBadgedRow("↔ Move apart", bimanualCheatSheetDescription,
                                               badge: bimanualCheatSheetBadge, badgeColor: bimanualCheatSheetColor,
                                               isOn: $settings.bimanualGestureEnabled)
                    }
                }

                GroupBox("Display") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Show Hand Skeleton", isOn: $settings.showHandSkeleton)
                        Toggle("Body Wireframe", isOn: $settings.showBodyWireframe)
                        Toggle("Hide Camera Feed", isOn: $settings.hideCameraFeed)
                            .disabled(!settings.showBodyWireframe)
                        if settings.hideCameraFeed && !settings.showBodyWireframe {
                            Text("Enable Body Wireframe to hide camera")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 340, height: 980)
    }

    private func colorSliders(r: Binding<Double>, g: Binding<Double>, b: Binding<Double>) -> some View {
        VStack(spacing: 4) {
            HStack {
                Text("R").font(.caption).frame(width: 14)
                Slider(value: r, in: 0...1)
            }
            HStack {
                Text("G").font(.caption).frame(width: 14)
                Slider(value: g, in: 0...1)
            }
            HStack {
                Text("B").font(.caption).frame(width: 14)
                Slider(value: b, in: 0...1)
            }
        }
    }

    private var bimanualCheatSheetDescription: String {
        switch settings.bimanualTarget {
        case .reverb: return "Controls reverb — farther apart = more reverb"
        case .delay: return "Controls delay mix — farther apart = more echo"
        }
    }

    private var bimanualCheatSheetBadge: String {
        switch settings.bimanualTarget {
        case .reverb: return "REVERB~"
        case .delay: return "DELAY~"
        }
    }

    private var bimanualCheatSheetColor: Color {
        switch settings.bimanualTarget {
        case .reverb: return .blue
        case .delay: return .teal
        }
    }

    private func cheatSheetSection(_ title: String, color: Color) -> some View {
        Text(title)
            .font(.system(size: 10, weight: .bold, design: .monospaced))
            .foregroundColor(color)
            .padding(.top, 4)
    }

    private func gestureRow(_ gesture: String, _ action: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(gesture)
                .fontWeight(.semibold)
                .frame(width: 130, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
            Text(action)
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .font(.caption)
    }

    private func gestureToggleRow(_ gesture: String, _ action: String, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(gesture).fontWeight(.semibold)
                Text(action).foregroundColor(.secondary)
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().scaleEffect(0.75)
        }
        .font(.caption)
        .opacity(isOn.wrappedValue ? 1.0 : 0.4)
    }

    private func gestureToggleBadgedRow(_ gesture: String, _ action: String, badge: String, badgeColor: Color, isOn: Binding<Bool>) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(gesture).fontWeight(.semibold)
                HStack(spacing: 4) {
                    Text(action).foregroundColor(.secondary)
                    Text(badge)
                        .fontWeight(.bold)
                        .foregroundColor(badgeColor)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(badgeColor.opacity(0.15))
                        .cornerRadius(3)
                }
            }
            Spacer()
            Toggle("", isOn: isOn).labelsHidden().scaleEffect(0.75)
        }
        .font(.caption)
        .opacity(isOn.wrappedValue ? 1.0 : 0.4)
    }

}
