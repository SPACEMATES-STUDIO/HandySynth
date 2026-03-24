import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Settings")
                    .font(.title2.bold())

                GroupBox("Sound") {
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

                        if settings.selectedWaveform == .pad {
                            Text("Pad detune controlled by left-hand tilt")
                                .font(.caption)
                                .foregroundColor(.secondary)
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
                        }
                    }
                }

                GroupBox("Play Mode") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Finger Per Note", isOn: $settings.fingerPerNoteMode)
                        Text("Each finger plays a scale degree. Hand height selects octave.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                GroupBox("Envelope") {
                    VStack(alignment: .leading, spacing: 10) {
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

                GroupBox("Arpeggiator") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Enabled", isOn: $settings.arpEnabled)

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
                }

                GroupBox("Effects") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Reverb")
                            Slider(value: $settings.reverbMix, in: 0...1)
                            Text("\(Int(settings.reverbMix * 100))%")
                                .frame(width: 40, alignment: .trailing)
                                .font(.caption.monospacedDigit())
                        }
                        Text("Reverb is gesture-controlled when both hands are visible (this value used as fallback).")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        HStack {
                            Text("Delay")
                            Slider(value: $settings.delayMix, in: 0...1)
                            Text("\(Int(settings.delayMix * 100))%")
                                .frame(width: 40, alignment: .trailing)
                                .font(.caption.monospacedDigit())
                        }
                    }
                }

                GroupBox("Visualizer") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Show Visualizer", isOn: $settings.showVisualizer)

                        HStack {
                            Text("Terrain Height")
                            Slider(value: $settings.vizTerrainHeight, in: 200...2000)
                        }

                        HStack {
                            Text("Spacing")
                            Slider(value: $settings.vizTerrainSpacing, in: 5...60)
                        }

                        Text("Primary Color")
                            .font(.caption.bold())
                        colorSliders(
                            r: $settings.vizColorPrimaryR,
                            g: $settings.vizColorPrimaryG,
                            b: $settings.vizColorPrimaryB
                        )

                        Text("Secondary Color")
                            .font(.caption.bold())
                        colorSliders(
                            r: $settings.vizColorSecondaryR,
                            g: $settings.vizColorSecondaryG,
                            b: $settings.vizColorSecondaryB
                        )
                    }
                }

                GroupBox("Gestures") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("Sustain (Pinch)", isOn: $settings.sustainEnabled)

                        VStack(alignment: .leading, spacing: 6) {
                            if settings.fingerPerNoteMode {
                                gestureRow("Thumb", "Root (1st)")
                                gestureRow("Index", "2nd degree")
                                gestureRow("Middle", "3rd degree")
                                gestureRow("Ring", "4th degree")
                                gestureRow("Little", "5th degree")
                                gestureRow("Hand Height", "Octave select")
                            } else {
                                gestureRow("Left Hand Height", "Pitch")
                                gestureRow("Left Spread", "Chord (3rd + 5th)")
                                gestureRow("Left Tilt", "Pad detune depth")
                                gestureRow("Point", "Precision pitch")
                                gestureRow("Pinch", settings.sustainEnabled ? "Sustain note" : "Disabled")
                            }
                            gestureRow("Right Hand Height", "Volume")
                            gestureRow("Right Spread", "Filter cutoff")
                            gestureRow("Both Hands Apart", "Reverb amount")
                            gestureRow("Fist", "Mute")
                            gestureRow("Peace", "Toggle quantized")
                            gestureRow("Hand Shake", "Vibrato")
                        }
                        .font(.caption)
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
        .frame(width: 320, height: 960)
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

    private func gestureRow(_ gesture: String, _ action: String) -> some View {
        HStack {
            Text(gesture)
                .fontWeight(.medium)
                .frame(width: 120, alignment: .leading)
            Text(action)
                .foregroundColor(.secondary)
        }
    }
}
