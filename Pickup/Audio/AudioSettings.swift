//
//  AudioSettings.swift
//  One global, persisted source of truth for mic sensitivity, shared by every
//  listening surface (tuner, lessons, chords) — not configured per section.
//

import Foundation
import Observation

@Observable
final class AudioSettings {
    static let shared = AudioSettings()

    static let defaultGate: Float = 0.0025
    static let defaultThreshold: Double = 0.70

    /// Mic input gate: RMS below this is treated as silence. Lower = more sensitive.
    var inputGateRMS: Float {
        didSet { UserDefaults.standard.set(Double(inputGateRMS), forKey: Key.gate) }
    }

    /// Acceptance threshold for chord matching (chroma cosine similarity).
    var chordMatchThreshold: Double {
        didSet { UserDefaults.standard.set(chordMatchThreshold, forKey: Key.threshold) }
    }

    private enum Key {
        static let gate = "audio.inputGateRMS"
        static let threshold = "audio.chordMatchThreshold"
    }

    private init() {
        let defaults = UserDefaults.standard
        inputGateRMS = (defaults.object(forKey: Key.gate) as? Double).map(Float.init) ?? Self.defaultGate
        chordMatchThreshold = (defaults.object(forKey: Key.threshold) as? Double) ?? Self.defaultThreshold
    }

    func resetToDefaults() {
        inputGateRMS = Self.defaultGate
        chordMatchThreshold = Self.defaultThreshold
    }
}
