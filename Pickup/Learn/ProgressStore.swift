//
//  ProgressStore.swift
//  Offline-first lesson progress, persisted as JSON in Application Support.
//  Right-sized for the current data; migrate to SQLite/SwiftData when progress
//  grows to per-skill mastery, streaks, and spaced-repetition schedules.
//

import Foundation
import Observation

@Observable
final class ProgressStore {
    static let shared = ProgressStore()

    private(set) var completedLessonIDs: Set<String> = []

    private let fileURL: URL

    init(directory: URL? = nil, filename: String = "progress.json") {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(filename)
        load()
    }

    func isCompleted(_ lessonID: String) -> Bool {
        completedLessonIDs.contains(lessonID)
    }

    func markCompleted(_ lessonID: String) {
        guard !completedLessonIDs.contains(lessonID) else { return }
        completedLessonIDs.insert(lessonID)
        save()
    }

    func reset() {
        completedLessonIDs = []
        save()
    }

    // MARK: - Persistence

    private struct Snapshot: Codable { var completedLessonIDs: [String] }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return }
        completedLessonIDs = Set(snapshot.completedLessonIDs)
    }

    private func save() {
        let snapshot = Snapshot(completedLessonIDs: Array(completedLessonIDs))
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
