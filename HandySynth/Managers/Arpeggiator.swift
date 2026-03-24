import Foundation

class Arpeggiator {
    var enabled: Bool = false
    var bpm: Double = 120.0
    var pattern: ArpPattern = .up
    var octaveRange: Int = 1

    // Scale context — set before calling process()
    var scale: Scale = .major
    var rootNote: RootNote = .C
    var baseOctave: Int = 3
    var scaleOctaveRange: Int = 3

    private var stepIndex: Int = 0
    private var lastStepTime: CFAbsoluteTime = 0
    private var direction: Int = 1 // 1 = up, -1 = down (for upDown)

    /// Returns an arpeggio frequency based on the current hand pitch position.
    /// Called every frame on the background queue.
    func process(inputPitch: Float) -> Float? {
        guard enabled else { return nil }

        let now = CFAbsoluteTimeGetCurrent()
        let stepInterval = 60.0 / bpm

        // Build valid MIDI notes for the scale
        let baseMidi = (baseOctave + 1) * 12 + rootNote.semitoneOffset
        let totalSemitones = scaleOctaveRange * 12
        var validNotes: [Int] = []
        for octave in 0...scaleOctaveRange {
            for semitone in scale.semitones {
                let note = baseMidi + octave * 12 + semitone
                if note <= baseMidi + totalSemitones {
                    validNotes.append(note)
                }
            }
        }
        guard !validNotes.isEmpty else { return nil }

        // Find the closest scale note to the input pitch
        let clampedPitch = min(max(inputPitch, 0.0), 1.0)
        let baseIndex = Int(roundf(clampedPitch * Float(validNotes.count - 1)))
        let clampedBase = min(max(baseIndex, 0), validNotes.count - 1)

        // Build the arp sequence: base note + extended octaves
        var arpNotes: [Int] = []
        for oct in 0..<octaveRange {
            let shifted = validNotes[clampedBase] + oct * 12
            arpNotes.append(shifted)
        }
        // Add notes above from the scale within the octave range
        for oct in 0..<octaveRange {
            for offset in 1..<min(validNotes.count - clampedBase, 8) {
                let note = validNotes[min(clampedBase + offset, validNotes.count - 1)] + oct * 12
                if !arpNotes.contains(note) {
                    arpNotes.append(note)
                }
            }
        }
        arpNotes.sort()
        guard !arpNotes.isEmpty else { return nil }

        // Advance step on BPM timer
        if now - lastStepTime >= stepInterval {
            lastStepTime = now
            advanceStep(noteCount: arpNotes.count)
        }

        let safeIndex = min(max(stepIndex, 0), arpNotes.count - 1)
        return ScaleHelper.midiNoteToFrequency(Float(arpNotes[safeIndex]))
    }

    private func advanceStep(noteCount: Int) {
        guard noteCount > 0 else { return }

        switch pattern {
        case .up:
            stepIndex = (stepIndex + 1) % noteCount
        case .down:
            stepIndex = stepIndex - 1
            if stepIndex < 0 { stepIndex = noteCount - 1 }
        case .upDown:
            stepIndex += direction
            if stepIndex >= noteCount {
                stepIndex = max(noteCount - 2, 0)
                direction = -1
            } else if stepIndex < 0 {
                stepIndex = min(1, noteCount - 1)
                direction = 1
            }
        case .random:
            stepIndex = Int.random(in: 0..<noteCount)
        }
    }

    func reset() {
        stepIndex = 0
        direction = 1
        lastStepTime = 0
    }
}
