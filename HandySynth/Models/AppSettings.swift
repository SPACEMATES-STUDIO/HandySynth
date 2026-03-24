import SwiftUI

class AppSettings: ObservableObject {
    @AppStorage("selectedScale") var selectedScaleRaw = Scale.major.rawValue
    @AppStorage("rootNote") var rootNoteRaw = RootNote.C.rawValue
    @AppStorage("baseOctave") var baseOctave = 3
    @AppStorage("octaveRange") var octaveRange = 3
    @AppStorage("isQuantized") var isQuantized = false
    @AppStorage("showHandSkeleton") var showHandSkeleton = true
    @AppStorage("reverbMix") var reverbMix = 0.2
    @AppStorage("delayMix") var delayMix = 0.0
    @AppStorage("portamentoSpeed") var portamentoSpeed = 0.005
    @AppStorage("selectedWaveform") var selectedWaveformRaw = Waveform.sine.rawValue
    @AppStorage("sustainEnabled") var sustainEnabled = true
    @AppStorage("fingerPerNoteMode") var fingerPerNoteMode = false

    // Envelope
    @AppStorage("attackTimeMs") var attackTimeMs = 10.0
    @AppStorage("releaseTimeMs") var releaseTimeMs = 100.0

    // Arpeggiator
    @AppStorage("arpEnabled") var arpEnabled = false
    @AppStorage("arpBPM") var arpBPM = 120.0
    @AppStorage("arpPattern") var arpPatternRaw = ArpPattern.up.rawValue
    @AppStorage("arpOctaveRange") var arpOctaveRange = 1

    // Visualizer
    @AppStorage("showVisualizer") var showVisualizer = false
    @AppStorage("vizTerrainHeight") var vizTerrainHeight = 770.0
    @AppStorage("vizTerrainSpacing") var vizTerrainSpacing = 20.0
    @AppStorage("vizColorPrimaryR") var vizColorPrimaryR = 0.0
    @AppStorage("vizColorPrimaryG") var vizColorPrimaryG = 1.0
    @AppStorage("vizColorPrimaryB") var vizColorPrimaryB = 0.6
    @AppStorage("vizColorSecondaryR") var vizColorSecondaryR = 0.0
    @AppStorage("vizColorSecondaryG") var vizColorSecondaryG = 0.3
    @AppStorage("vizColorSecondaryB") var vizColorSecondaryB = 0.8

    var selectedScale: Scale {
        get { Scale(rawValue: selectedScaleRaw) ?? .major }
        set { selectedScaleRaw = newValue.rawValue }
    }

    var rootNote: RootNote {
        get { RootNote(rawValue: rootNoteRaw) ?? .C }
        set { rootNoteRaw = newValue.rawValue }
    }

    var selectedWaveform: Waveform {
        get { Waveform(rawValue: selectedWaveformRaw) ?? .sine }
        set { selectedWaveformRaw = newValue.rawValue }
    }

    var reverbMixFloat: Float {
        get { Float(reverbMix) }
        set { reverbMix = Double(newValue) }
    }

    var delayMixFloat: Float {
        get { Float(delayMix) }
        set { delayMix = Double(newValue) }
    }

    var portamentoSpeedFloat: Float {
        get { Float(portamentoSpeed) }
        set { portamentoSpeed = Double(newValue) }
    }

    var arpPattern: ArpPattern {
        get { ArpPattern(rawValue: arpPatternRaw) ?? .up }
        set { arpPatternRaw = newValue.rawValue }
    }
}
