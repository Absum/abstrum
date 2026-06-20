//
//  StatsStoreTests.swift
//  Streak, XP/level, and practice-time logic in ProgressStore.
//

import XCTest

final class StatsStoreTests: XCTestCase {
    private func makeStore() -> ProgressStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pickup-stats-\(UUID().uuidString)")
        return ProgressStore(directory: dir, filename: "progress.json")
    }

    private func day(_ base: Date, _ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: base)!
    }

    func testConsecutiveDaysBuildStreak() {
        let s = makeStore()
        let base = Date()
        s.registerActivity(on: day(base, 0)); XCTAssertEqual(s.currentStreak, 1)
        s.registerActivity(on: day(base, 1)); XCTAssertEqual(s.currentStreak, 2)
        s.registerActivity(on: day(base, 2)); XCTAssertEqual(s.currentStreak, 3)
        XCTAssertEqual(s.bestStreak, 3)
    }

    func testSameDayDoesNotDoubleCount() {
        let s = makeStore()
        let base = Date()
        s.registerActivity(on: day(base, 0))
        s.registerActivity(on: day(base, 0))
        XCTAssertEqual(s.currentStreak, 1)
    }

    func testGapResetsStreakButKeepsBest() {
        let s = makeStore()
        let base = Date()
        s.registerActivity(on: day(base, 0))
        s.registerActivity(on: day(base, 1))   // streak 2
        s.registerActivity(on: day(base, 3))   // missed day 2 → reset
        XCTAssertEqual(s.currentStreak, 1)
        XCTAssertEqual(s.bestStreak, 2)
    }

    func testRefreshBreaksStreakAfterMissedDay() {
        let s = makeStore()
        let base = Date()
        s.registerActivity(on: day(base, 0))    // streak 1
        s.refreshStreak(day(base, 2))           // two days later, nothing logged
        XCTAssertEqual(s.currentStreak, 0)
    }

    func testRefreshKeepsStreakNextDay() {
        let s = makeStore()
        let base = Date()
        s.registerActivity(on: day(base, 0))
        s.refreshStreak(day(base, 1))           // yesterday active → still alive
        XCTAssertEqual(s.currentStreak, 1)
    }

    func testXPAccumulatesAndLevels() {
        let s = makeStore()
        s.awardXP(ProgressStore.xpPerLevel)     // exactly one level
        XCTAssertEqual(s.level, 2)
        XCTAssertEqual(s.xpIntoLevel, 0)
        s.awardXP(30)
        XCTAssertEqual(s.level, 2)
        XCTAssertEqual(s.xpIntoLevel, 30)
    }

    func testLessonCompletionAwardsXPOnce() {
        let s = makeStore()
        s.markCompleted("lesson-a"); XCTAssertEqual(s.xp, 25)
        s.markCompleted("lesson-a"); XCTAssertEqual(s.xp, 25)   // no double
    }

    func testPracticeMinutes() {
        let s = makeStore()
        s.addPracticeTime(90)
        XCTAssertEqual(s.practiceMinutes, 1)
        XCTAssertEqual(s.practiceSeconds, 90)
    }

    func testMasteryRequiresSeveralCleanRuns() {
        let s = makeStore()
        // One perfect run shouldn't instantly "master" it.
        s.recordRun("chord-a", score: 1.0)
        XCTAssertFalse(s.isCompleted("chord-a"))
        XCTAssertLessThan(s.mastery(of: "chord-a"), ProgressStore.masteryThreshold)
        // Repeated clean runs cross the threshold and unlock it.
        for _ in 0..<5 { s.recordRun("chord-a", score: 1.0) }
        XCTAssertGreaterThanOrEqual(s.mastery(of: "chord-a"), ProgressStore.masteryThreshold)
        XCTAssertTrue(s.isCompleted("chord-a"))
    }

    func testSloppyRunsNeverMaster() {
        let s = makeStore()
        for _ in 0..<20 { s.recordRun("chord-e", score: 0.5) }   // EMA converges to 0.5
        XCTAssertFalse(s.isCompleted("chord-e"))
        XCTAssertLessThan(s.mastery(of: "chord-e"), ProgressStore.masteryThreshold)
    }

    func testMarkCompletedSetsFullMastery() {
        let s = makeStore()
        s.markCompleted("chord-d")
        XCTAssertEqual(s.mastery(of: "chord-d"), 1.0)
        XCTAssertTrue(s.isCompleted("chord-d"))
    }

    func testPersistenceRoundTrip() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pickup-stats-\(UUID().uuidString)")
        let a = ProgressStore(directory: dir, filename: "progress.json")
        a.awardXP(50)
        a.markCompleted("x")          // +25
        a.addPracticeTime(120)
        let b = ProgressStore(directory: dir, filename: "progress.json")
        XCTAssertEqual(b.xp, 75)
        XCTAssertEqual(b.practiceSeconds, 120)
        XCTAssertEqual(b.completedLessonIDs, ["x"])
        XCTAssertEqual(b.currentStreak, 1)
    }
}
