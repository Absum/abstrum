//
//  Lesson.swift
//  Lesson model + pitch-matching, and the starter lesson content.
//

import Foundation

struct LessonStep: Identifiable, Equatable {
    let id: Int
    let note: String         // "E"
    let octaveLabel: String  // "E2"
    let frequency: Double    // target Hz
    let hint: String         // "6th string — low E"
}

struct Lesson: Identifiable, Equatable {
    let id: String
    let title: String
    let subtitle: String
    let steps: [LessonStep]
}

/// How close the played pitch is to the step's target.
enum LessonMatch { case correct, close, off }

enum LessonLibrary {
    /// Classify a detected frequency against a target.
    /// `correctCents` is generous enough to feel responsive but still requires
    /// the right note; `close` covers up to ~a semitone for "you're nearly there".
    static func evaluate(frequency: Double,
                         target: Double,
                         correctCents: Double = 40,
                         closeCents: Double = 120) -> LessonMatch {
        guard frequency > 0, target > 0 else { return .off }
        let off = abs(1200.0 * log2(frequency / target))
        if off <= correctCents { return .correct }
        if off <= closeCents { return .close }
        return .off
    }

    static let openStrings = Lesson(
        id: "open-strings",
        title: "Open Strings",
        subtitle: "Tier 0 · Play each string cleanly",
        steps: GuitarTuning.standard.enumerated().map { index, string in
            LessonStep(id: index,
                       note: string.name,
                       octaveLabel: string.label,
                       frequency: string.frequency,
                       hint: stringHints[index])
        })

    static let all: [Lesson] = [openStrings]

    private static let stringHints = [
        "6th string — low E", "5th string — A", "4th string — D",
        "3rd string — G", "2nd string — B", "1st string — high E",
    ]
}
