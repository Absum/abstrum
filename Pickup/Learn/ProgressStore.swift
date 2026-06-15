//
//  ProgressStore.swift
//  Offline-first progress, persisted as JSON in Application Support: completed
//  lessons plus the habit-loop stats — XP/level, a daily streak, and practice
//  time. Right-sized for the current data; migrate to SQLite/SwiftData if this
//  grows to per-skill mastery and spaced-repetition schedules.
//

import Foundation
import Observation

@Observable
final class ProgressStore {
    static let shared = ProgressStore()

    private(set) var completedLessonIDs: Set<String> = []

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

    func markCompleted(_ lessonID: String) {
        let isNew = !completedLessonIDs.contains(lessonID)
        completedLessonIDs.insert(lessonID)
        if isNew { xp += 25 }          // reward only the first completion
        registerActivity()
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
        xp = s.xp ?? 0
        practiceSeconds = s.practiceSeconds ?? 0
        currentStreak = s.currentStreak ?? 0
        bestStreak = s.bestStreak ?? 0
        lastActiveDay = s.lastActiveDay
        activeDays = Set(s.activeDays ?? [])
    }

    private func save() {
        let snapshot = Snapshot(completedLessonIDs: Array(completedLessonIDs),
                                xp: xp, practiceSeconds: practiceSeconds,
                                currentStreak: currentStreak, bestStreak: bestStreak,
                                lastActiveDay: lastActiveDay, activeDays: Array(activeDays))
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
