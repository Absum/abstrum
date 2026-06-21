//
//  Scaffold.swift
//  Scaffolding & feedback fading (Vygotsky ZPD): the more a skill is mastered,
//  the fewer supports it shows — full diagram → no finger numbers → recall it
//  from memory — and the feedback thins from continuous to flag-errors-only.
//  Keyed off the lesson's mastery so supports fade exactly as competence grows.
//

import Foundation

enum ScaffoldLevel {
    /// First acquisition: full chord/note diagram with finger numbers, hints,
    /// and continuous per-attempt feedback.
    case full
    /// Gaining competence: keep the shape but drop the finger numbers.
    case reduced
    /// Mastered: hide the prompt (retrieve it from memory) and only flag errors.
    case fromMemory

    /// Whether the chord/note diagram is shown by default at this level.
    var showsDiagram: Bool { self != .fromMemory }
    /// Whether finger numbers are drawn on the diagram.
    var showsFingerNumbers: Bool { self == .full }
    /// Whether feedback is continuous (vs. only flagging errors).
    var showsContinuousFeedback: Bool { self == .full || self == .reduced }
}

enum Scaffold {
    /// Mastery at/above which finger numbers drop away…
    static let reducedThreshold = 0.45
    /// …and at/above which the prompt is hidden for from-memory retrieval.
    /// Matches the mastery bar, so a skill goes "from memory" exactly when learned.
    static let fromMemoryThreshold = ProgressStore.masteryThreshold

    static func level(forMastery mastery: Double) -> ScaffoldLevel {
        if mastery >= fromMemoryThreshold { return .fromMemory }
        if mastery >= reducedThreshold { return .reduced }
        return .full
    }
}
