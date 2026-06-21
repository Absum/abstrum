//
//  AudioSettings.swift
//  One global, persisted source of truth for the detection "feel" — shared by
//  every listening surface (tuner, lessons, chords, highway, play-along), not
//  configured per section. The extra knobs beyond sensitivity/strictness are
//  surfaced only in the DEBUG developer tuning panel.
//

import Foundation
import Observation

@Observable
final class AudioSettings {
    static let shared = AudioSettings()

    static let defaultGate: Float = 0.0025
    static let defaultThreshold: Double = 0.70
    static let defaultChordHoldFrames = 3
    static let defaultNoteToleranceCents: Double = 60
    static let defaultTimingWindowMs: Double = 250

    /// Mic input gate: RMS below this is treated as silence. Lower = more sensitive.
    /// Shared by all three detectors (pitch, chord, onset).
    var inputGateRMS: Float {
        didSet { UserDefaults.standard.set(Double(inputGateRMS), forKey: Key.gate) }
    }

    /// Acceptance threshold for chord matching (chroma cosine similarity).
    var chordMatchThreshold: Double {
        didSet { UserDefaults.standard.set(chordMatchThreshold, forKey: Key.threshold) }
    }

    /// How many consecutive frames a chord must match before it registers.
    var chordHoldFrames: Int {
        didSet { UserDefaults.standard.set(chordHoldFrames, forKey: Key.chordHold) }
    }

    /// How close (in cents) a played note must be to count as correct.
    var noteToleranceCents: Double {
        didSet { UserDefaults.standard.set(noteToleranceCents, forKey: Key.noteCents) }
    }

    /// How far (ms) a strum/onset can land from the beat and still count.
    var timingWindowMs: Double {
        didSet { UserDefaults.standard.set(timingWindowMs, forKey: Key.timingWindow) }
    }

    /// Timing window in seconds (for the clocks).
    var timingWindow: Double { timingWindowMs / 1000.0 }

    private enum Key {
        static let gate = "audio.inputGateRMS"
        static let threshold = "audio.chordMatchThreshold"
        static let chordHold = "audio.chordHoldFrames"
        static let noteCents = "audio.noteToleranceCents"
        static let timingWindow = "audio.timingWindowMs"
    }

    private init() {
        let defaults = UserDefaults.standard
        inputGateRMS = (defaults.object(forKey: Key.gate) as? Double).map(Float.init) ?? Self.defaultGate
        chordMatchThreshold = (defaults.object(forKey: Key.threshold) as? Double) ?? Self.defaultThreshold
        chordHoldFrames = (defaults.object(forKey: Key.chordHold) as? Int) ?? Self.defaultChordHoldFrames
        noteToleranceCents = (defaults.object(forKey: Key.noteCents) as? Double) ?? Self.defaultNoteToleranceCents
        timingWindowMs = (defaults.object(forKey: Key.timingWindow) as? Double) ?? Self.defaultTimingWindowMs
    }

    func resetToDefaults() {
        inputGateRMS = Self.defaultGate
        chordMatchThreshold = Self.defaultThreshold
        chordHoldFrames = Self.defaultChordHoldFrames
        noteToleranceCents = Self.defaultNoteToleranceCents
        timingWindowMs = Self.defaultTimingWindowMs
    }
}
