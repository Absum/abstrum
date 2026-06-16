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

/// A timed strum exercise: strum `chord` once per beat at `bpm` for `beats` beats.
struct StrumPattern: Hashable {
    let bpm: Int
    let beats: Int
}

struct LessonStep: Identifiable, Hashable {
    let id: Int
    let note: String          // "E" (or chord name for a chord step)
    let octaveLabel: String   // "E2"
    let frequency: Double     // target Hz (0 for chord steps)
    let hint: String          // "6th string — low E"
    let position: FretPosition?
    /// When set, this step is scored by chord (chroma) detection, not pitch.
    var chord: Chord? = nil
    /// When set, this is a timed strum step (metronome + onset timing), not a hold.
    var strum: StrumPattern? = nil
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
    /// A future tier on the map with no lessons authored yet (shown locked).
    var comingSoon: Bool = false
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

    // MARK: - Tier 1 — open chords (scored by chord detection)

    static let chordA = Lesson(
        id: "chord-a", title: "The A Chord", subtitle: "Three fingers, top five strings",
        tier: 1, prerequisite: "a-string-notes", steps: chordSteps(["A", "A", "A"]))

    static let chordE = Lesson(
        id: "chord-e", title: "The E Chord", subtitle: "A full, ringing chord",
        tier: 1, prerequisite: "chord-a", steps: chordSteps(["E", "E", "E"]))

    static let chordD = Lesson(
        id: "chord-d", title: "The D Chord", subtitle: "A bright triangle shape",
        tier: 1, prerequisite: "chord-e", steps: chordSteps(["D", "D", "D"]))

    static let chordG = Lesson(
        id: "chord-g", title: "The G Chord", subtitle: "Reach across all six strings",
        tier: 1, prerequisite: "chord-d", steps: chordSteps(["G", "G", "G"]))

    static let chordC = Lesson(
        id: "chord-c", title: "The C Chord", subtitle: "A classic open chord",
        tier: 1, prerequisite: "chord-g", steps: chordSteps(["C", "C", "C"]))

    // MARK: - Tier 2 — chord transitions (alternating chord steps)

    static let changeEA = Lesson(
        id: "change-ea", title: "E ↔ A", subtitle: "Switch cleanly between E and A",
        tier: 2, prerequisite: "chord-c", steps: chordSteps(["E", "A", "E", "A"]))

    static let changeAD = Lesson(
        id: "change-ad", title: "A ↔ D", subtitle: "The A–D change",
        tier: 2, prerequisite: "change-ea", steps: chordSteps(["A", "D", "A", "D"]))

    static let changeGC = Lesson(
        id: "change-gc", title: "G ↔ C", subtitle: "The classic G–C change",
        tier: 2, prerequisite: "change-ad", steps: chordSteps(["G", "C", "G", "C"]))

    // MARK: - Tier 2 — strumming in time (metronome + onset timing)

    static let strumDown = Lesson(
        id: "strum-down", title: "Downstrokes", subtitle: "One strum per beat, in time",
        tier: 2, prerequisite: "change-gc", steps: strumSteps([("E", 70, 8)]))

    static let strumKeep = Lesson(
        id: "strum-keep", title: "Keep the Beat", subtitle: "Hold the tempo on A",
        tier: 2, prerequisite: "strum-down", steps: strumSteps([("A", 80, 8)]))

    static let firstSong = Lesson(
        id: "first-song", title: "Your First Song", subtitle: "Em–C–G–D, a bar each",
        tier: 2, prerequisite: "strum-keep",
        steps: strumSteps([("Em", 80, 4), ("C", 80, 4), ("G", 80, 4), ("D", 80, 4)]))

    // MARK: - Tier 3 — barre chords & rhythm

    static let chordF = Lesson(
        id: "chord-f", title: "The F Chord", subtitle: "Your first barre — index across all six",
        tier: 3, prerequisite: "first-song", steps: chordSteps(["F", "F", "F"]))

    static let chordBm = Lesson(
        id: "chord-bm", title: "The B Minor Chord", subtitle: "An A-shape barre",
        tier: 3, prerequisite: "chord-f", steps: chordSteps(["Bm", "Bm", "Bm"]))

    static let changeFC = Lesson(
        id: "change-fc", title: "F ↔ C", subtitle: "Barre to open and back",
        tier: 3, prerequisite: "chord-bm", steps: chordSteps(["F", "C", "F", "C"]))

    static let palmMute = Lesson(
        id: "palm-mute", title: "Palm Muting", subtitle: "Rest your palm on the strings, strum in time",
        tier: 3, prerequisite: "change-fc", steps: strumSteps([("E", 80, 8)]))

    static let fasterStrum = Lesson(
        id: "faster-strum", title: "Faster Strumming", subtitle: "Pick up the pace, keep it even",
        tier: 3, prerequisite: "palm-mute", steps: strumSteps([("A", 100, 8)]))

    static let all: [Lesson] = [openStrings, stringSwitching, lowToHigh, lowENotes, aStringNotes,
                                chordA, chordE, chordD, chordG, chordC,
                                changeEA, changeAD, changeGC,
                                strumDown, strumKeep, firstSong,
                                chordF, chordBm, changeFC, palmMute, fasterStrum]

    // MARK: - Step builders

    private static func chord(_ id: String) -> Chord? { ChordBank.all.first { $0.id == id } }

    /// One "strum this chord" step per id (skips any unknown id).
    private static func chordSteps(_ ids: [String]) -> [LessonStep] {
        ids.compactMap(chord).enumerated().map { index, chord in
            LessonStep(id: index, note: chord.name, octaveLabel: "", frequency: 0,
                       hint: "Strum the \(chord.name) chord", position: nil, chord: chord)
        }
    }

    /// Timed strum steps: (chord id, bpm, beats).
    private static func strumSteps(_ specs: [(String, Int, Int)]) -> [LessonStep] {
        specs.enumerated().compactMap { index, spec in
            guard let chord = chord(spec.0) else { return nil }
            return LessonStep(id: index, note: chord.name, octaveLabel: "", frequency: 0,
                              hint: "Strum \(chord.name) on every beat", position: nil,
                              chord: chord, strum: StrumPattern(bpm: spec.1, beats: spec.2))
        }
    }

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

    static let firstChords = Course(
        id: "first-chords", title: "First Chords",
        subtitle: "Tier 1 · A E D G C", tier: 1,
        lessons: [LessonLibrary.chordA, LessonLibrary.chordE, LessonLibrary.chordD,
                  LessonLibrary.chordG, LessonLibrary.chordC])

    static let chordChanges = Course(
        id: "chord-changes", title: "Chord Changes",
        subtitle: "Tier 2 · Switch cleanly", tier: 2,
        lessons: [LessonLibrary.changeEA, LessonLibrary.changeAD, LessonLibrary.changeGC])

    static let strumming = Course(
        id: "strumming", title: "Strumming & Songs",
        subtitle: "Tier 2 · Play in time", tier: 2,
        lessons: [LessonLibrary.strumDown, LessonLibrary.strumKeep, LessonLibrary.firstSong])

    // MARK: - Tiers 3–5 — on the map, content not authored yet

    static let barreRhythm = Course(
        id: "barre-rhythm", title: "Barre & Rhythm",
        subtitle: "Tier 3 · Barre chords, palm muting", tier: 3,
        lessons: [LessonLibrary.chordF, LessonLibrary.chordBm, LessonLibrary.changeFC,
                  LessonLibrary.palmMute, LessonLibrary.fasterStrum])

    static let leadBasics = Course(
        id: "lead-basics", title: "Lead Basics",
        subtitle: "Tier 4 · Pentatonics, riffs, bends", tier: 4,
        lessons: [], comingSoon: true)

    static let intermediate = Course(
        id: "intermediate", title: "Intermediate",
        subtitle: "Tier 5 · Improv, theory, ear training", tier: 5,
        lessons: [], comingSoon: true)

    /// The full skill-graph map, tier 0 → 5 (3–5 are locked placeholders).
    static let all: [Course] = [firstContact, firstNotes, firstChords, chordChanges, strumming,
                                barreRhythm, leadBasics, intermediate]

    static func isUnlocked(_ course: Course, completed: Set<String>) -> Bool {
        guard !course.comingSoon else { return false }
        guard let first = course.lessons.first else { return true }
        return LessonLibrary.isUnlocked(first, completed: completed)
    }

    static func completedCount(_ course: Course, completed: Set<String>) -> Int {
        course.lessons.filter { completed.contains($0.id) }.count
    }
}
