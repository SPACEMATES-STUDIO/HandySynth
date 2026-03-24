import Foundation

enum Scale: String, CaseIterable, Identifiable {
    case major = "Major"
    case minor = "Minor"
    case pentatonic = "Pentatonic"
    case chromatic = "Chromatic"
    case blues = "Blues"

    var id: String { rawValue }

    var semitones: [Int] {
        switch self {
        case .major: return [0, 2, 4, 5, 7, 9, 11]
        case .minor: return [0, 2, 3, 5, 7, 8, 10]
        case .pentatonic: return [0, 2, 4, 7, 9]
        case .chromatic: return Array(0...11)
        case .blues: return [0, 3, 5, 6, 7, 10]
        }
    }
}

enum RootNote: String, CaseIterable, Identifiable {
    case C, Db = "Db", D, Eb = "Eb", E, F, Gb = "Gb", G, Ab = "Ab", A, Bb = "Bb", B

    var id: String { rawValue }

    var semitoneOffset: Int {
        switch self {
        case .C: return 0
        case .Db: return 1
        case .D: return 2
        case .Eb: return 3
        case .E: return 4
        case .F: return 5
        case .Gb: return 6
        case .G: return 7
        case .Ab: return 8
        case .A: return 9
        case .Bb: return 10
        case .B: return 11
        }
    }
}

struct ScaleHelper {
    static func midiNoteToFrequency(_ note: Float) -> Float {
        440.0 * powf(2.0, (note - 69.0) / 12.0)
    }

    static func frequencyToMidiNote(_ freq: Float) -> Float {
        69.0 + 12.0 * log2f(freq / 440.0)
    }

    static func positionToFrequency(
        position: Float,
        baseOctave: Int,
        octaveRange: Int,
        scale: Scale,
        rootNote: RootNote,
        quantize: Bool
    ) -> Float {
        let baseMidi = Float((baseOctave + 1) * 12 + rootNote.semitoneOffset)
        let totalSemitones = Float(octaveRange * 12)
        let clampedPos = min(max(position, 0.0), 1.0)

        if !quantize {
            let midiNote = baseMidi + clampedPos * totalSemitones
            return midiNoteToFrequency(midiNote)
        }

        // Build all valid MIDI notes in range
        var validNotes: [Float] = []
        let semitones = scale.semitones
        for octave in 0...octaveRange {
            for semitone in semitones {
                let note = baseMidi + Float(octave * 12 + semitone)
                if note <= baseMidi + totalSemitones {
                    validNotes.append(note)
                }
            }
        }

        guard !validNotes.isEmpty else {
            return midiNoteToFrequency(baseMidi)
        }

        let index = clampedPos * Float(validNotes.count - 1)
        let noteIndex = min(max(Int(roundf(index)), 0), validNotes.count - 1)
        return midiNoteToFrequency(validNotes[noteIndex])
    }

    static func noteName(for frequency: Float) -> String {
        let noteNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
        let midiNote = Int(roundf(frequencyToMidiNote(frequency)))
        let name = noteNames[((midiNote % 12) + 12) % 12]
        let octave = midiNote / 12 - 1
        return "\(name)\(octave)"
    }

    static func noteNamesInRange(baseOctave: Int, octaveRange: Int, rootNote: RootNote, scale: Scale) -> [(String, Float)] {
        let noteNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
        let baseMidi = (baseOctave + 1) * 12 + rootNote.semitoneOffset
        let totalSemitones = octaveRange * 12
        var result: [(String, Float)] = []

        for octave in 0...octaveRange {
            for semitone in scale.semitones {
                let note = baseMidi + octave * 12 + semitone
                if note <= baseMidi + totalSemitones {
                    let name = noteNames[((note % 12) + 12) % 12]
                    let oct = note / 12 - 1
                    let position = Float(note - baseMidi) / Float(totalSemitones)
                    result.append(("\(name)\(oct)", position))
                }
            }
        }
        return result
    }
}
