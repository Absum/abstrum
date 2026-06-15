//
//  Lesson.swift
//  Lesson + course model, pitch-matching, content, and unlock rules.
//

import Foundation

/// Where a note is played: which string (0 = low E … 5 = high e) and fret (0 = open).
/// `finger` is the fretting hand finger (1 = index … 4 = pinky; 0 = unspecified/open).
struct FretPosition: Hashable {
    let string: Int
    let fret: Int
    var finger: Int = 0
}

struct LessonStep: Identifiable, Hashable {
    let id: Int
    let note: String          // "E"
    let octaveLabel: String   // "E2"
    let frequency: Double     // target Hz
    let hint: String          // "6th string — low E"
    let position: FretPosition?
}

struct Lesson: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let tier: Int
    let prerequisite: String?  // lesson id that must be completed first
    let steps: [LessonStep]
}

struct Course: Identifiable, Hashable {
    let id: String
    let title: String
    let subtitle: String
    let tier: Int
    let lessons: [Lesson]
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

    // MARK: - Lessons (a single prerequisite chain spanning the courses)

    static let openStrings = Lesson(
        id: "open-strings", title: "Open Strings",
        subtitle: "Play each string cleanly", tier: 0, prerequisite: nil,
        steps: openStringSteps([0, 1, 2, 3, 4, 5]))

    static let stringSwitching = Lesson(
        id: "string-switching", title: "String Switching",
        subtitle: "Jump between strings", tier: 0, prerequisite: "open-strings",
        steps: openStringSteps([0, 1, 0, 1, 2, 1, 0]))

    static let lowToHigh = Lesson(
        id: "low-to-high", title: "Low to High",
        subtitle: "Run up and back down", tier: 0, prerequisite: "string-switching",
        steps: openStringSteps([0, 1, 2, 3, 4, 5, 4, 3, 2, 1, 0]))

    static let lowENotes = Lesson(
        id: "low-e-notes", title: "Low E Notes",
        subtitle: "Open, 1st & 3rd fret", tier: 1, prerequisite: "low-to-high",
        steps: frettedSteps(string: 0, frets: [0, 1, 3]))

    static let aStringNotes = Lesson(
        id: "a-string-notes", title: "A String Notes",
        subtitle: "Open, 2nd & 3rd fret", tier: 1, prerequisite: "low-e-notes",
        steps: frettedSteps(string: 1, frets: [0, 2, 3]))

    static let all: [Lesson] = [openStrings, stringSwitching, lowToHigh, lowENotes, aStringNotes]

    // MARK: - Step builders

    private static let stringHints = [
        "6th string — low E", "5th string — A", "4th string — D",
        "3rd string — G", "2nd string — B", "1st string — high E",
    ]
    private static let stringNames = ["low E", "A", "D", "G", "B", "high E"]

    private static func openStringSteps(_ indices: [Int]) -> [LessonStep] {
        indices.enumerated().map { position, stringIndex in
            let string = GuitarTuning.standard[stringIndex]
            return LessonStep(id: position, note: string.name, octaveLabel: string.label,
                              frequency: string.frequency, hint: stringHints[stringIndex],
                              position: FretPosition(string: stringIndex, fret: 0))
        }
    }

    private static func frettedSteps(string stringIndex: Int, frets: [Int]) -> [LessonStep] {
        let open = GuitarTuning.standard[stringIndex]
        return frets.enumerated().map { position, fret in
            let frequency = open.frequency * pow(2.0, Double(fret) / 12.0)
            let reading = NoteMath.reading(forFrequency: frequency)
            let hint = fret == 0
                ? "\(stringNames[stringIndex]) string — open"
                : "\(ordinal(fret)) fret · \(stringNames[stringIndex]) string"
            return LessonStep(id: position,
                              note: reading?.name ?? "?",
                              octaveLabel: reading?.displayName ?? "",
                              frequency: frequency, hint: hint,
                              position: FretPosition(string: stringIndex, fret: fret))
        }
    }

    private static func ordinal(_ n: Int) -> String {
        switch n {
        case 1: return "1st"
        case 2: return "2nd"
        case 3: return "3rd"
        default: return "\(n)th"
        }
    }
}

enum CourseLibrary {
    static let firstContact = Course(
        id: "first-contact", title: "First Contact",
        subtitle: "Tier 0 · Meet the strings", tier: 0,
        lessons: [LessonLibrary.openStrings, LessonLibrary.stringSwitching, LessonLibrary.lowToHigh])

    static let firstNotes = Course(
        id: "first-notes", title: "First Notes",
        subtitle: "Tier 1 · Fret your first notes", tier: 1,
        lessons: [LessonLibrary.lowENotes, LessonLibrary.aStringNotes])

    static let all: [Course] = [firstContact, firstNotes]

    static func isUnlocked(_ course: Course, completed: Set<String>) -> Bool {
        guard let first = course.lessons.first else { return true }
        return LessonLibrary.isUnlocked(first, completed: completed)
    }

    static func completedCount(_ course: Course, completed: Set<String>) -> Int {
        course.lessons.filter { completed.contains($0.id) }.count
    }
}
