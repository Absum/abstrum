//
//  AdaptiveTempo.swift
//  Accuracy-before-speed tempo control (Fitts' law / deliberate practice):
//  start a timed exercise below its target tempo and only speed up once the
//  learner plays it cleanly, dropping back when they get sloppy. A skill's
//  tempo is stored as a *factor* of its target BPM so a multi-step exercise
//  scales uniformly, and so the same policy works for any target tempo.
//

import Foundation

enum AdaptiveTempo {
    /// Where a fresh skill begins — a comfortable fraction of target tempo.
    static let startFactor = 0.7
    /// Never practise slower than this fraction (too slow loses the groove)…
    static let minFactor = 0.5
    /// …and "graduation" is target tempo.
    static let maxFactor = 1.0
    /// How much one rep moves the tempo.
    static let stepFactor = 0.1
    /// A run at/above this quality earns a speed-up…
    static let cleanScore = 0.9
    /// …and below this it drops the tempo back.
    static let shakyScore = 0.6
    /// Floor on the resulting BPM so the metronome stays musically usable.
    static let minBPM = 50

    /// The next tempo factor given the current one and a run's quality (0…1):
    /// clean → faster, shaky → slower, in-between → hold. Clamped to [min, max].
    static func next(factor: Double, score: Double) -> Double {
        var f = factor
        if score >= cleanScore { f += stepFactor }
        else if score < shakyScore { f -= stepFactor }
        return min(maxFactor, max(minFactor, f))
    }

    /// Resolve a target BPM and factor into the BPM to actually play at,
    /// never below `minBPM`.
    static func bpm(target: Int, factor: Double) -> Int {
        max(minBPM, Int((Double(target) * factor).rounded()))
    }

    /// Whether a factor has reached target tempo (graduated).
    static func isAtTarget(_ factor: Double) -> Bool { factor >= maxFactor }
}
