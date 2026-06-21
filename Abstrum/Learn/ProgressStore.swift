//
//  ProgressStore.swift
//  Offline-first progress, persisted as JSON in Application Support: completed
//  lessons, per-skill mastery, per-skill spaced-repetition review schedules,
//  plus the habit-loop stats — XP/level, a daily streak, and practice time.
//  The data set stays small (a few hundred lessons × a handful of fields), so
//  a single JSON snapshot is still right-sized; move to SQLite/SwiftData only
//  if per-run history or analytics need to be retained.
//

import Foundation
import Observation

@Observable
final class ProgressStore {
    static let shared = ProgressStore()

    private(set) var completedLessonIDs: Set<String> = []
    /// Per-lesson mastery 0…1, accumulated from run quality. A lesson counts as
    /// learned (and unlocks the next) only at `masteryThreshold`.
    private(set) var mastery: [String: Double] = [:]

    /// Mastery needed to consider a lesson learned; the EMA needs several clean
    /// runs to cross it, so progression reflects skill, not a single pass.
    static let masteryThreshold = 0.8
    private static let masteryAlpha = 0.4

    /// A slower-moving EMA of the same run scores. `mastery − baseline` is the
    /// trend: positive while a skill is improving, negative when it's slipping,
    /// ~0 once it's steady — drives the "up from X%" / weakness surfacing.
    private(set) var masteryBaseline: [String: Double] = [:]
    private static let baselineAlpha = 0.12

    func mastery(of lessonID: String) -> Double { mastery[lessonID] ?? 0 }
    func masteryBaseline(of lessonID: String) -> Double { masteryBaseline[lessonID] ?? mastery(of: lessonID) }
    /// Recent direction of a skill (positive = improving, negative = slipping).
    func trend(of lessonID: String) -> Double { mastery(of: lessonID) - masteryBaseline(of: lessonID) }

    // MARK: - Spaced repetition

    /// When each learned skill is next due for review. A clean review pushes the
    /// due-date out along `reviewIntervals`; a shaky one pulls it back in, so
    /// fragile skills resurface sooner. Drives the "what to practice today" list.
    private(set) var reviews: [String: ReviewState] = [:]

    /// Expanding review gaps in days (Leitner/SM-style). The last value repeats
    /// once a skill is well-retained, so long-held skills check back ~monthly.
    static let reviewIntervals = [1, 3, 7, 16, 35]

    struct ReviewState: Codable, Equatable {
        var stage: Int        // index into reviewIntervals
        var dueDate: Date
        var lastReviewed: Date
    }

    func reviewState(of lessonID: String) -> ReviewState? { reviews[lessonID] }

    /// Learned skills whose review is due on/before `date` (calendar day), most
    /// overdue first — the ordered "due for review" queue.
    func dueForReview(on date: Date = Date()) -> [String] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: date)
        return reviews
            .filter { cal.startOfDay(for: $0.value.dueDate) <= today }
            .sorted { $0.value.dueDate < $1.value.dueDate }
            .map { $0.key }
    }

    func isDueForReview(_ lessonID: String, on date: Date = Date()) -> Bool {
        guard let state = reviews[lessonID] else { return false }
        let cal = Calendar.current
        return cal.startOfDay(for: state.dueDate) <= cal.startOfDay(for: date)
    }

    /// Record a spaced review of an already-learned skill. A clean run advances
    /// one interval; a shaky run drops back one (never below the first gap).
    func recordReview(_ lessonID: String, clean: Bool, on date: Date = Date()) {
        let current = reviews[lessonID]?.stage ?? 0
        let next = clean ? current + 1 : current - 1
        scheduleReview(lessonID, stage: next, from: date)
        save()
    }

    /// (Re)schedule a skill's next review `reviewIntervals[stage]` days out.
    private func scheduleReview(_ lessonID: String, stage: Int, from date: Date) {
        let clamped = max(0, min(stage, Self.reviewIntervals.count - 1))
        let cal = Calendar.current
        let due = cal.date(byAdding: .day, value: Self.reviewIntervals[clamped],
                           to: cal.startOfDay(for: date)) ?? date
        reviews[lessonID] = ReviewState(stage: clamped, dueDate: due, lastReviewed: date)
    }

    // MARK: - Adaptive tempo

    /// Per-skill practice tempo as a factor of the lesson's target BPM. Starts
    /// below target and ramps up only as the learner plays cleanly (see
    /// `AdaptiveTempo`). Absent → the default start factor.
    private(set) var practiceTempo: [String: Double] = [:]

    func tempoFactor(of lessonID: String) -> Double {
        practiceTempo[lessonID] ?? AdaptiveTempo.startFactor
    }

    /// Fold a timed run's quality into the skill's practice tempo: clean runs
    /// speed it up toward target, shaky runs slow it back down.
    func recordTempoResult(_ lessonID: String, score: Double) {
        practiceTempo[lessonID] = AdaptiveTempo.next(factor: tempoFactor(of: lessonID), score: score)
        save()
    }

    // Habit-loop stats.
    private(set) var xp: Int = 0
    private(set) var practiceSeconds: Int = 0
    private(set) var currentStreak: Int = 0
    private(set) var bestStreak: Int = 0
    private(set) var lastActiveDay: String?        // "yyyy-MM-dd"
    private(set) var activeDays: Set<String> = []  // every day with activity

    /// XP needed per level (linear curve).
    static let xpPerLevel = 120

    var level: Int { xp / Self.xpPerLevel + 1 }
    var xpIntoLevel: Int { xp % Self.xpPerLevel }
    var practiceMinutes: Int { practiceSeconds / 60 }

    /// Whether the streak's most recent active day is today (vs. needs a session).
    func isActiveToday(_ now: Date = Date()) -> Bool { lastActiveDay == Self.dayKey(now) }

    /// Calendar days since the last practice, or nil if the user never played.
    func daysSinceActive(_ now: Date = Date()) -> Int? {
        guard let last = lastActiveDay, let date = Self.date(fromKey: last) else { return nil }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: date),
                                  to: cal.startOfDay(for: now)).day
    }

    private let fileURL: URL

    init(directory: URL? = nil, filename: String = "progress.json") {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(filename)
        load()
    }

    // MARK: - Lessons

    func isCompleted(_ lessonID: String) -> Bool {
        completedLessonIDs.contains(lessonID)
    }

    /// Mark a lesson learned outright (e.g. onboarding "I know this" skip-ahead).
    func markCompleted(_ lessonID: String, on date: Date = Date()) {
        let isNew = !completedLessonIDs.contains(lessonID)
        completedLessonIDs.insert(lessonID)
        mastery[lessonID] = 1.0
        masteryBaseline[lessonID] = 1.0          // fully known → no trend
        if isNew {
            xp += 25                     // reward only the first completion
            scheduleReview(lessonID, stage: 0, from: date)   // first review tomorrow
        }
        registerActivity(on: date)
        save()
    }

    /// Record one lesson run's quality (0…1). Mastery is an EMA toward the run
    /// score; a lesson is marked learned (unlocking the next) once it crosses
    /// the threshold — so it takes several clean runs, ideally across sessions.
    /// Running an already-learned lesson counts as a spaced review.
    func recordRun(_ lessonID: String, score: Double, on date: Date = Date()) {
        let s = max(0, min(1, score))
        let alreadyLearned = completedLessonIDs.contains(lessonID)
        let updated = (mastery[lessonID] ?? 0) * (1 - Self.masteryAlpha) + s * Self.masteryAlpha
        mastery[lessonID] = updated
        // Slow baseline trails the fast mastery so their gap reads as a trend.
        masteryBaseline[lessonID] = (masteryBaseline[lessonID] ?? 0) * (1 - Self.baselineAlpha) + s * Self.baselineAlpha
        if alreadyLearned {
            // A run of a learned skill is a review: clean runs space it out further.
            recordReview(lessonID, clean: s >= Self.masteryThreshold, on: date)
        } else if updated >= Self.masteryThreshold {
            completedLessonIDs.insert(lessonID)
            xp += 25
            scheduleReview(lessonID, stage: 0, from: date)   // first review tomorrow
        }
        registerActivity(on: date)
        save()
    }

    // MARK: - Stats

    /// Award XP for an activity (also counts toward today's streak).
    func awardXP(_ amount: Int, on date: Date = Date()) {
        guard amount > 0 else { return }
        xp += amount
        registerActivity(on: date)
        save()
    }

    /// Log practice time in seconds (also counts toward today's streak).
    func addPracticeTime(_ seconds: Int, on date: Date = Date()) {
        guard seconds > 0 else { return }
        practiceSeconds += seconds
        registerActivity(on: date)
        save()
    }

    /// Mark that the user practiced on `date`, updating the daily streak.
    func registerActivity(on date: Date = Date()) {
        let day = Self.dayKey(date)
        activeDays.insert(day)
        if lastActiveDay == day {        // already counted today
            save(); return
        }
        if let last = lastActiveDay, let lastDate = Self.date(fromKey: last) {
            let cal = Calendar.current
            let gap = cal.dateComponents([.day],
                                         from: cal.startOfDay(for: lastDate),
                                         to: cal.startOfDay(for: date)).day ?? 99
            currentStreak = gap == 1 ? currentStreak + 1 : 1
        } else {
            currentStreak = 1
        }
        bestStreak = max(bestStreak, currentStreak)
        lastActiveDay = day
        save()
    }

    /// Drop the streak to 0 if the last active day is neither today nor yesterday
    /// (call on launch so a missed day shows as broken without a new session).
    func refreshStreak(_ now: Date = Date()) {
        guard let last = lastActiveDay, let lastDate = Self.date(fromKey: last) else {
            if currentStreak != 0 { currentStreak = 0; save() }
            return
        }
        let cal = Calendar.current
        let gap = cal.dateComponents([.day],
                                     from: cal.startOfDay(for: lastDate),
                                     to: cal.startOfDay(for: now)).day ?? 99
        if gap > 1 && currentStreak != 0 { currentStreak = 0; save() }
    }

    func reset() {
        completedLessonIDs = []
        mastery = [:]
        masteryBaseline = [:]
        reviews = [:]
        practiceTempo = [:]
        xp = 0; practiceSeconds = 0; currentStreak = 0; bestStreak = 0
        lastActiveDay = nil; activeDays = []
        save()
    }

    // MARK: - Day keys

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    static func dayKey(_ date: Date) -> String { dayFormatter.string(from: date) }
    static func date(fromKey key: String) -> Date? { dayFormatter.date(from: key) }

    // MARK: - Persistence

    private struct Snapshot: Codable {
        var completedLessonIDs: [String]
        var mastery: [String: Double]?
        var masteryBaseline: [String: Double]?
        var reviews: [String: ReviewState]?
        var practiceTempo: [String: Double]?
        var xp: Int?
        var practiceSeconds: Int?
        var currentStreak: Int?
        var bestStreak: Int?
        var lastActiveDay: String?
        var activeDays: [String]?
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let s = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        completedLessonIDs = Set(s.completedLessonIDs)
        mastery = s.mastery ?? [:]
        // Migration: pre-mastery completions count as fully mastered.
        for id in completedLessonIDs where mastery[id] == nil { mastery[id] = 1.0 }
        masteryBaseline = s.masteryBaseline ?? [:]
        // Migration: seed baselines from current mastery so trends start at 0.
        for (id, m) in mastery where masteryBaseline[id] == nil { masteryBaseline[id] = m }
        reviews = s.reviews ?? [:]
        practiceTempo = s.practiceTempo ?? [:]
        xp = s.xp ?? 0
        practiceSeconds = s.practiceSeconds ?? 0
        currentStreak = s.currentStreak ?? 0
        bestStreak = s.bestStreak ?? 0
        lastActiveDay = s.lastActiveDay
        activeDays = Set(s.activeDays ?? [])
    }

    private func save() {
        let snapshot = Snapshot(completedLessonIDs: Array(completedLessonIDs),
                                mastery: mastery,
                                masteryBaseline: masteryBaseline,
                                reviews: reviews,
                                practiceTempo: practiceTempo,
                                xp: xp, practiceSeconds: practiceSeconds,
                                currentStreak: currentStreak, bestStreak: bestStreak,
                                lastActiveDay: lastActiveDay, activeDays: Array(activeDays))
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
