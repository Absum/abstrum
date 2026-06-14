//
//  Lesson.swift
//  Lesson model + pitch-matching, the skill-path content, and unlock rules.
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
    let tier: Int
    let prerequisite: String?   // lesson id that must be completed first
    let steps: [LessonStep]
}

/// How close the played pitch is to the step's target.
enum LessonMatch { case correct, close, off }

enum LessonLibrary {
    /// Classify a detected frequency against a target.
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

    /// A lesson is unlocked if it has no prerequisite or the prerequisite is done.
    static func isUnlocked(_ lesson: Lesson, completed: Set<String>) -> Bool {
        guard let prerequisite = lesson.prerequisite else { return true }
        return completed.contains(prerequisite)
    }

    // MARK: - Content (the skill path)

    static let openStrings = Lesson(
        id: "open-strings",
        title: "Open Strings",
        subtitle: "Tier 0 · Play each string cleanly",
        tier: 0, prerequisite: nil,
        steps: steps(fromStringIndices: [0, 1, 2, 3, 4, 5]))

    static let stringSwitching = Lesson(
        id: "string-switching",
        title: "String Switching",
        subtitle: "Tier 0 · Jump between strings",
        tier: 0, prerequisite: "open-strings",
        steps: steps(fromStringIndices: [0, 1, 0, 1, 2, 1, 0]))

    static let lowToHigh = Lesson(
        id: "low-to-high",
        title: "Low to High",
        subtitle: "Tier 1 · Run up and back down",
        tier: 1, prerequisite: "string-switching",
        steps: steps(fromStringIndices: [0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0]))

    static let all: [Lesson] = [openStrings, stringSwitching, lowToHigh]

    // MARK: - Helpers

    private static let stringHints = [
        "6th string — low E", "5th string — A", "4th string — D",
        "3rd string — G", "2nd string — B", "1st string — high E",
    ]

    private static func steps(fromStringIndices indices: [Int]) -> [LessonStep] {
        indices.enumerated().map { position, stringIndex in
            let string = GuitarTuning.standard[stringIndex]
            return LessonStep(id: position,
                              note: string.name,
                              octaveLabel: string.label,
                              frequency: string.frequency,
                              hint: stringHints[stringIndex])
        }
    }
}
