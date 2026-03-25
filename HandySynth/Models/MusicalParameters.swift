import Foundation

enum ArpPattern: String, CaseIterable, Identifiable {
    case up = "Up"
    case down = "Down"
    case upDown = "Up/Down"
    case random = "Random"

    var id: String { rawValue }
}

enum Waveform: String, CaseIterable, Identifiable {
    case sine = "Sine"
    case triangle = "Triangle"
    case sawtooth = "Sawtooth"
    case square = "Square"
    case pad = "Pad"
    case fm = "FM"

    var id: String { rawValue }
}

struct MusicalParameters {
    var pitch: Float = 0.5
    var volume: Float = 0.0
    var filterCutoff: Float = 1.0
    var vibratoDepth: Float = 0.0
    var vibratoRate: Float = 5.0
    var waveform: Waveform = .sine
    var isMuted: Bool = true
    var isSustaining: Bool = false
    var isQuantized: Bool = false
    var isPrecisionMode: Bool = false
    var reverbMix: Float = 0.2
    var delayMix: Float = 0.0
    var arpFrequency: Float? = nil

    // Finger-per-note polyphony (5 voices, one per finger)
    var fingerMode: Bool = false
    var fingerFrequencies: (Float, Float, Float, Float, Float) = (0, 0, 0, 0, 0)
    var fingerActive: (Bool, Bool, Bool, Bool, Bool) = (false, false, false, false, false)

    // Chord harmonization (left-hand spread)
    var chordMode: Bool = false

    // Pad detune depth (left-hand tilt), 0=unison 1=full spread
    var detune: Float = 0.0

    // Bimanual distance gesture — raw 0-1 value routed to target effect
    var bimanualActive: Bool = false
    var bimanualAmount: Float = 0.0

    // Distortion (soft clipping, 0=clean, 1=full drive)
    var distortion: Float = 0.0
}
