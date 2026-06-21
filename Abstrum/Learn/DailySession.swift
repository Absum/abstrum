//
//  DailySession.swift
//  Builds today's guided practice from the learner's state, following the
//  evidence-based arc: warm-up → spaced interleaved review → focused new-skill
//  block → song integration → cool-down. Replaces free browsing with a short
//  (~10–15 min) deliberate-practice session. Pure and testable; the UI just
//  plays the items it returns in order.
//

import Foundation

/// The stages of a structured practice session, in the order they're played.
enum SessionPhase: String, CaseIterable {
    case warmUp, review, newSkill, song, coolDown

    /// Ascending arc position — used to keep generated sessions in order.
    var order: Int { Self.allCases.firstIndex(of: self)! }

    var label: String {
        switch self {
        case .warmUp:   return "Warm-up"
        case .review:   return "Review"
        case .newSkill: return "New skill"
        case .song:     return "Song"
        case .coolDown: return "Cool-down"
        }
    }

    var blurb: String {
        switch self {
        case .warmUp:   return "Loosen up with something you know"
        case .review:   return "Shore up a skill that's going shaky"
        case .newSkill: return "Take the next step — slow and clean"
        case .song:     return "Put it together and play"
        case .coolDown: return "End on a win"
        }
    }
}

/// One step of a generated session: a lesson to play in a given phase.
struct SessionItem: Identifiable, Hashable {
    let lesson: Lesson
    let phase: SessionPhase
    var id: String { "\(phase.rawValue):\(lesson.id)" }
}

enum DailySession {
    /// A "song" lesson is musical integration rather than a drill: a progression
    /// of two or more distinct chords (a strummed song, or the chord-only first
    /// song), as opposed to a single-chord technique drill or a two-chord change.
    static func isSong(_ lesson: Lesson) -> Bool {
        if lesson.id == "song-em-am" { return true }
        let strummedChords = lesson.steps.compactMap { $0.strum != nil ? $0.chord?.id : nil }
        return Set(strummedChords).count >= 2
    }

    /// Build today's session from progress + the due-for-review queue.
    /// `due` is expected most-overdue-first (as ProgressStore.dueForReview returns).
    static func plan(lessons: [Lesson] = LessonLibrary.all,
                     completed: Set<String>,
                     due: [String],
                     maxReviews: Int = 3) -> [SessionItem] {
        var items: [SessionItem] = []
        var used: Set<String> = []

        func lesson(_ id: String) -> Lesson? { lessons.first { $0.id == id } }
        func add(_ lesson: Lesson, _ phase: SessionPhase) {
            guard !used.contains(lesson.id) else { return }
            used.insert(lesson.id)
            items.append(SessionItem(lesson: lesson, phase: phase))
        }

        // The frontier: the next unlocked lesson not yet learned.
        let nextNew = lessons.first {
            LessonLibrary.isUnlocked($0, completed: completed) && !completed.contains($0.id)
        }

        // Fresh learner — no point in an arc, just point at the first step.
        guard !completed.isEmpty else {
            if let nextNew { add(nextNew, .newSkill) }
            return items
        }

        let learned = lessons.filter { completed.contains($0.id) }

        // 1. Warm-up: an easy, already-learned lesson — ideally not one that's
        //    also due for review (so it doesn't double as the review block).
        let easiestLearned = learned.sorted { $0.tier < $1.tier }
        if let warm = easiestLearned.first(where: { !due.contains($0.id) }) ?? easiestLearned.first {
            add(warm, .warmUp)
        }

        // 2. Review: the due queue, interleaved, capped to keep the session short.
        for id in due.prefix(maxReviews) { if let l = lesson(id) { add(l, .review) } }

        // 3. New skill: the frontier lesson, practised slow.
        if let nextNew { add(nextNew, .newSkill) }

        // 4. Song integration: the most advanced playable song, preferring a
        //    learned one for a confident musical finish.
        let playableSongs = lessons.filter {
            isSong($0) && LessonLibrary.isUnlocked($0, completed: completed)
        }
        if let song = playableSongs.filter({ completed.contains($0.id) }).max(by: { $0.tier < $1.tier })
                    ?? playableSongs.max(by: { $0.tier < $1.tier }) {
            add(song, .song)
        }

        // 5. Cool-down: a learned song to end on, else any easy learned lesson.
        if let cool = learned.first(where: { isSong($0) && !used.contains($0.id) })
                    ?? learned.first(where: { !used.contains($0.id) }) {
            add(cool, .coolDown)
        }

        return items
    }

    /// Convenience: build today's session straight off the shared progress store.
    static func today(_ store: ProgressStore = .shared, on date: Date = Date()) -> [SessionItem] {
        plan(completed: store.completedLessonIDs, due: store.dueForReview(on: date))
    }
}
