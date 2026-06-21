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
    let prerequisite: String?       // the spine edge (id that must be mastered first)
    /// Extra prerequisites — all must be mastered too. Lets the path be a graph
    /// (e.g. a song that needs several specific chords), not a single chain.
    var prerequisites: [String] = []
    let steps: [LessonStep]
    /// Whether finishing this lesson records mastery/SRS/tempo. False for
    /// ephemeral, generated drills (e.g. the interleaved mix) so they don't
    /// pollute progress with a synthetic lesson id.
    var tracksProgress = true
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

    /// A lesson is unlocked when its spine prerequisite AND all extra
    /// prerequisites have been mastered (a DAG, not just a chain).
    static func isUnlocked(_ lesson: Lesson, completed: Set<String>) -> Bool {
        if let prerequisite = lesson.prerequisite, !completed.contains(prerequisite) { return false }
        return lesson.prerequisites.allSatisfy { completed.contains($0) }
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

    // Single-note fretting now lives in the lead track (Tier 4) as scale prep —
    // chords/songs come first; single notes matter once you start playing lead.
    static let lowENotes = Lesson(
        id: "low-e-notes", title: "Low E Notes",
        subtitle: "Open, 1st & 3rd fret", tier: 4, prerequisite: "faster-strum",
        steps: frettedSteps(string: 0, frets: [0, 1, 3]))

    static let aStringNotes = Lesson(
        id: "a-string-notes", title: "A String Notes",
        subtitle: "Open, 2nd & 3rd fret", tier: 4, prerequisite: "low-e-notes",
        steps: frettedSteps(string: 1, frets: [0, 2, 3]))

    // MARK: - Tier 1 — open chords, easiest first (scored by chord detection)
    // Em → Am → E → A → D → G → C. Chords unlock right after open strings; the
    // single-note fretting lessons are a parallel branch (relocated to lead next).

    static let chordEm = Lesson(
        id: "chord-em", title: "The E Minor Chord", subtitle: "Two fingers — your easiest chord",
        tier: 1, prerequisite: "low-to-high", steps: chordSteps(["Em", "Em", "Em"]))

    static let chordAm = Lesson(
        id: "chord-am", title: "The A Minor Chord", subtitle: "Same shape, moved over a string",
        tier: 1, prerequisite: "chord-em", steps: chordSteps(["Am", "Am", "Am"]))

    /// Session-1 payoff: play a real two-chord progression with the first two chords
    /// you learned — the early win that carries a beginner through sore fingertips.
    static let songEmAm = Lesson(
        id: "song-em-am", title: "Your First Song", subtitle: "Em & Am — your first progression",
        tier: 1, prerequisite: "chord-am", steps: chordSteps(["Em", "Am", "Em", "Am", "Em", "Am"]))

    static let chordE = Lesson(
        id: "chord-e", title: "The E Chord", subtitle: "A full, ringing chord",
        tier: 1, prerequisite: "song-em-am", steps: chordSteps(["E", "E", "E"]))

    static let chordA = Lesson(
        id: "chord-a", title: "The A Chord", subtitle: "Three fingers, top five strings",
        tier: 1, prerequisite: "chord-e", steps: chordSteps(["A", "A", "A"]))

    static let chordD = Lesson(
        id: "chord-d", title: "The D Chord", subtitle: "A bright triangle shape",
        tier: 1, prerequisite: "chord-a", steps: chordSteps(["D", "D", "D"]))

    static let chordG = Lesson(
        id: "chord-g", title: "The G Chord", subtitle: "Reach across all six strings",
        tier: 1, prerequisite: "chord-d", steps: chordSteps(["G", "G", "G"]))

    static let chordC = Lesson(
        id: "chord-c", title: "The C Chord", subtitle: "A classic open chord, trickiest of the set",
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
        id: "first-song", title: "Four-Chord Song", subtitle: "Em–C–G–D strummed in time",
        tier: 2, prerequisite: "strum-keep",
        prerequisites: ["chord-c", "chord-g", "chord-d"],   // needs the actual chords
        steps: strumSteps([("Em", 80, 4), ("C", 80, 4), ("G", 80, 4), ("D", 80, 4)]))

    // Spiral revisit: the open chords come back faster (Bruner — revisit deeper).
    static let spiralGCD = Lesson(
        id: "spiral-gcd", title: "G–C–D at Speed", subtitle: "Your open chords, faster",
        tier: 2, prerequisite: "first-song", prerequisites: ["chord-g", "chord-c", "chord-d"],
        steps: strumSteps([("G", 100, 4), ("C", 100, 4), ("D", 100, 4), ("G", 100, 4)]))

    // MARK: - Tier 3 — barre chords, power chords & rhythm

    static let cheaterF = Lesson(
        id: "cheater-f", title: "The Easy F", subtitle: "A 4-string F — no full barre yet",
        tier: 3, prerequisite: "first-song", steps: chordSteps([easyFChord, easyFChord, easyFChord]))

    static let chordF = Lesson(
        id: "chord-f", title: "The Full F Barre", subtitle: "Index across all six strings",
        tier: 3, prerequisite: "cheater-f", steps: chordSteps(["F", "F", "F"]))

    static let chordBm = Lesson(
        id: "chord-bm", title: "The B Minor Chord", subtitle: "An A-shape barre",
        tier: 3, prerequisite: "chord-f", steps: chordSteps(["Bm", "Bm", "Bm"]))

    // CAGED in action: the movable E-shape (F#m) and A-shape (B) barres up the neck.
    static let moreBarre = Lesson(
        id: "more-barre", title: "Barre Shapes Move", subtitle: "One shape, slid up the neck — B & F♯m",
        tier: 3, prerequisite: "chord-bm", steps: chordSteps(["B", "F#m", "B", "F#m"]))

    static let changeFC = Lesson(
        id: "change-fc", title: "F ↔ C", subtitle: "Barre to open and back",
        tier: 3, prerequisite: "more-barre", steps: chordSteps(["F", "C", "F", "C"]))

    // Power chords — root + fifth, two fingers, the backbone of rock.
    static let powerChords = Lesson(
        id: "power-chords", title: "Power Chords", subtitle: "Two notes, all attitude — E5 & A5",
        tier: 3, prerequisite: "change-fc", steps: chordSteps(["E5", "A5", "E5", "A5"]))

    // Same power-chord shape slid around for a riff.
    static let powerRiff = Lesson(
        id: "power-riff", title: "Power-Chord Riff", subtitle: "Slide the shape — E5 · G5 · A5",
        tier: 3, prerequisite: "power-chords",
        steps: strumSteps([("E5", 90, 4), ("G5", 90, 4), ("A5", 90, 4), ("E5", 90, 4)]))

    static let palmMute = Lesson(
        id: "palm-mute", title: "Palm Muting", subtitle: "Rest your palm on the strings, strum in time",
        tier: 3, prerequisite: "power-riff", steps: strumSteps([("E", 80, 8)]))

    static let fasterStrum = Lesson(
        id: "faster-strum", title: "Faster Strumming", subtitle: "Pick up the pace, keep it even",
        tier: 3, prerequisite: "palm-mute", steps: strumSteps([("A", 100, 8)]))

    // 16th-note feel — fast, even strumming to build a loose, steady wrist.
    static let sixteenths = Lesson(
        id: "sixteenths", title: "16th-Note Strumming", subtitle: "Fast and even — keep the wrist loose",
        tier: 3, prerequisite: "faster-strum", steps: strumSteps([("E", 110, 16)]))

    // Spiral revisit + tier-3 capstone: open chords return alongside the F barre.
    static let spiralBarreMix = Lesson(
        id: "spiral-barre-mix", title: "Open & Barre", subtitle: "Mix the F barre with open chords",
        tier: 3, prerequisite: "sixteenths", prerequisites: ["chord-f", "chord-c", "chord-g"],
        steps: strumSteps([("F", 90, 4), ("C", 90, 4), ("G", 90, 4), ("C", 90, 4)]))

    // MARK: - Tier 4 — lead basics (single-note scales & riffs)

    static let minorPentatonic = Lesson(
        id: "pentatonic-am", title: "A Minor Pentatonic", subtitle: "Your first scale — one octave",
        tier: 4, prerequisite: "a-string-notes",
        steps: noteSteps([(1, 0), (1, 3), (2, 0), (2, 2), (3, 0), (3, 2)]))

    static let pentatonicRun = Lesson(
        id: "pentatonic-run", title: "Pentatonic Run", subtitle: "Up and back down",
        tier: 4, prerequisite: "pentatonic-am",
        steps: noteSteps([(1, 0), (1, 3), (2, 0), (2, 2), (3, 0), (3, 2),
                          (3, 0), (2, 2), (2, 0), (1, 3), (1, 0)]))

    static let firstLick = Lesson(
        id: "first-lick", title: "First Lick", subtitle: "A simple pentatonic lead line",
        tier: 4, prerequisite: "pentatonic-run",
        steps: noteSteps([(3, 0), (3, 2), (3, 0), (2, 2), (2, 0), (1, 3), (1, 0)]))

    // The movable A-minor-pentatonic Box 1 at the 5th fret — the shape that slides.
    static let pentatonicBox1 = Lesson(
        id: "pentatonic-box1", title: "Pentatonic Box 1", subtitle: "The movable shape — A minor, 5th fret",
        tier: 4, prerequisite: "first-lick",
        steps: noteSteps([(0, 5), (0, 8), (1, 5), (1, 7), (2, 5), (2, 7),
                          (3, 5), (3, 7), (4, 5), (4, 8), (5, 5), (5, 8)]))

    static let box1Lick = Lesson(
        id: "box1-lick", title: "Box-1 Lick", subtitle: "A lead line inside the box",
        tier: 4, prerequisite: "pentatonic-box1",
        steps: noteSteps([(4, 8), (4, 5), (3, 7), (3, 5), (2, 7), (2, 5), (1, 7), (1, 5)]))

    // One-octave G major — the major scale behind most melodies.
    static let majorScaleG = Lesson(
        id: "major-scale-g", title: "The Major Scale", subtitle: "G major, one octave",
        tier: 4, prerequisite: "box1-lick",
        steps: noteSteps([(0, 3), (1, 0), (1, 2), (1, 3), (2, 0), (2, 2), (2, 4), (3, 0)]))

    // Chromatic 1-2-3-4 spider walk — finger independence and hand sync.
    static let fingerIndependence = Lesson(
        id: "finger-independence", title: "Finger Independence", subtitle: "The 1-2-3-4 spider walk",
        tier: 4, prerequisite: "major-scale-g",
        steps: noteSteps([(0, 1), (0, 2), (0, 3), (0, 4), (1, 1), (1, 2), (1, 3), (1, 4),
                          (2, 1), (2, 2), (2, 3), (2, 4)]))

    static let all: [Lesson] = [openStrings, stringSwitching, lowToHigh, lowENotes, aStringNotes,
                                chordEm, chordAm, songEmAm, chordE, chordA, chordD, chordG, chordC,
                                changeEA, changeAD, changeGC,
                                strumDown, strumKeep, firstSong, spiralGCD,
                                cheaterF, chordF, chordBm, moreBarre, changeFC, powerChords, powerRiff,
                                palmMute, fasterStrum, sixteenths, spiralBarreMix,
                                minorPentatonic, pentatonicRun, firstLick,
                                pentatonicBox1, box1Lick, majorScaleG, fingerIndependence]

    // MARK: - Step builders

    private static func chord(_ id: String) -> Chord? { ChordBank.all.first { $0.id == id } }

    /// One "strum this chord" step per id (skips any unknown id).
    private static func chordSteps(_ ids: [String]) -> [LessonStep] {
        chordSteps(ids.compactMap(chord))
    }

    /// Chord steps from explicit voicings (for shapes not in the bank, e.g. the easy F).
    private static func chordSteps(_ chords: [Chord]) -> [LessonStep] {
        chords.enumerated().map { index, chord in
            LessonStep(id: index, note: chord.name, octaveLabel: "", frequency: 0,
                       hint: "Strum the \(chord.name) chord", position: nil, chord: chord)
        }
    }

    /// The 4-string "easy F" — no full barre. Mute low E & A; index barres the
    /// top two strings at fret 1, middle on G(2), ring on D(3). F major (F A C).
    static let easyFChord = Chord(
        id: "F-easy", name: "F", root: "F", quality: .major,
        positions: [FretPosition(string: 2, fret: 3, finger: 3),
                    FretPosition(string: 3, fret: 2, finger: 2),
                    FretPosition(string: 4, fret: 1, finger: 1),
                    FretPosition(string: 5, fret: 1, finger: 1)],
        mutedStrings: [0, 1],
        pitchClasses: [5, 9, 0],
        barre: Barre(fret: 1, fromString: 4, toString: 5))

    /// Single-note steps across strings: (string, fret) → pitch target.
    private static func noteSteps(_ positions: [(Int, Int)]) -> [LessonStep] {
        positions.enumerated().map { index, pos in
            let open = GuitarTuning.standard[pos.0]
            let frequency = open.frequency * pow(2.0, Double(pos.1) / 12.0)
            let reading = NoteMath.reading(forFrequency: frequency)
            let hint = pos.1 == 0
                ? "\(stringNames[pos.0]) string — open"
                : "\(ordinal(pos.1)) fret · \(stringNames[pos.0]) string"
            return LessonStep(id: index, note: reading?.name ?? "?",
                              octaveLabel: reading?.displayName ?? "", frequency: frequency,
                              hint: hint, position: FretPosition(string: pos.0, fret: pos.1))
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
        id: "first-notes", title: "Single Notes",
        subtitle: "Tier 4 · Lead prep — fret single notes", tier: 4,
        lessons: [LessonLibrary.lowENotes, LessonLibrary.aStringNotes])

    static let firstChords = Course(
        id: "first-chords", title: "First Chords",
        subtitle: "Tier 1 · Em Am E A D G C", tier: 1,
        lessons: [LessonLibrary.chordEm, LessonLibrary.chordAm, LessonLibrary.songEmAm,
                  LessonLibrary.chordE, LessonLibrary.chordA, LessonLibrary.chordD,
                  LessonLibrary.chordG, LessonLibrary.chordC])

    static let chordChanges = Course(
        id: "chord-changes", title: "Chord Changes",
        subtitle: "Tier 2 · Switch cleanly", tier: 2,
        lessons: [LessonLibrary.changeEA, LessonLibrary.changeAD, LessonLibrary.changeGC])

    static let strumming = Course(
        id: "strumming", title: "Strumming & Songs",
        subtitle: "Tier 2 · Play in time", tier: 2,
        lessons: [LessonLibrary.strumDown, LessonLibrary.strumKeep, LessonLibrary.firstSong,
                  LessonLibrary.spiralGCD])

    // MARK: - Tiers 3–5 — on the map, content not authored yet

    static let barreRhythm = Course(
        id: "barre-rhythm", title: "Barre & Rhythm",
        subtitle: "Tier 3 · Barre chords, palm muting", tier: 3,
        lessons: [LessonLibrary.cheaterF, LessonLibrary.chordF, LessonLibrary.chordBm,
                  LessonLibrary.moreBarre, LessonLibrary.changeFC, LessonLibrary.powerChords,
                  LessonLibrary.powerRiff, LessonLibrary.palmMute, LessonLibrary.fasterStrum,
                  LessonLibrary.sixteenths, LessonLibrary.spiralBarreMix])

    static let leadBasics = Course(
        id: "lead-basics", title: "Lead Basics",
        subtitle: "Tier 4 · Pentatonic scales & riffs", tier: 4,
        lessons: [LessonLibrary.minorPentatonic, LessonLibrary.pentatonicRun, LessonLibrary.firstLick,
                  LessonLibrary.pentatonicBox1, LessonLibrary.box1Lick, LessonLibrary.majorScaleG,
                  LessonLibrary.fingerIndependence])

    static let intermediate = Course(
        id: "intermediate", title: "Intermediate",
        subtitle: "Tier 5 · Improv, theory, ear training", tier: 5,
        lessons: [], comingSoon: true)

    /// The full skill-graph map, tier 0 → 5 (3–5 are locked placeholders).
    // Chords-first: First Chords sits right after First Contact; First Notes
    // (single-note fretting) is now a parallel side-track ahead of lead work.
    static let all: [Course] = [firstContact, firstChords, chordChanges, strumming,
                                barreRhythm, firstNotes, leadBasics, intermediate]

    static func isUnlocked(_ course: Course, completed: Set<String>) -> Bool {
        guard !course.comingSoon else { return false }
        guard let first = course.lessons.first else { return true }
        return LessonLibrary.isUnlocked(first, completed: completed)
    }

    static func completedCount(_ course: Course, completed: Set<String>) -> Int {
        course.lessons.filter { completed.contains($0.id) }.count
    }
}
