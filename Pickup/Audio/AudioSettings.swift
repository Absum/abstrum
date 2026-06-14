//
//  AudioSettings.swift
//  One global source of truth for mic sensitivity, shared by every listening
//  surface (tuner, lessons, chords) — not configured per section.
//

import Foundation

enum AudioSettings {
    /// Mic input gate: RMS below this is treated as silence. Lower = more
    /// sensitive. Applied to both the pitch and chord DSP cores.
    static var inputGateRMS: Float = 0.0025

    /// Acceptance threshold for chord matching (chroma cosine similarity).
    /// Lower = easier to register a real (imperfect) strum.
    static var chordMatchThreshold: Double = 0.70
}
