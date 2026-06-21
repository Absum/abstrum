//
//  StatsStoreTests.swift
//  Streak, XP/level, and practice-time logic in ProgressStore.
//

import XCTest

final class StatsStoreTests: XCTestCase {
    private func makeStore() -> ProgressStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("abstrum-stats-\(UUID().uuidString)")
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

    // MARK: - Spaced repetition

    func testMasterySchedulesFirstReviewTomorrow() {
        let s = makeStore()
        let base = Date()
        s.markCompleted("chord-em", on: base)
        XCTAssertNotNil(s.reviewState(of: "chord-em"))
        XCTAssertEqual(s.reviewState(of: "chord-em")?.stage, 0)
        XCTAssertFalse(s.isDueForReview("chord-em", on: base))      // not due the same day
        XCTAssertTrue(s.isDueForReview("chord-em", on: day(base, 1)))  // due the next day
    }

    func testCleanReviewExpandsTheInterval() {
        let s = makeStore()
        let base = Date()
        s.markCompleted("chord-c", on: base)               // stage 0 → next gap 1d
        s.recordReview("chord-c", clean: true, on: day(base, 1))   // stage 1 → next gap 3d
        XCTAssertEqual(s.reviewState(of: "chord-c")?.stage, 1)
        XCTAssertFalse(s.isDueForReview("chord-c", on: day(base, 3)))
        XCTAssertTrue(s.isDueForReview("chord-c", on: day(base, 4)))   // 1 + 3 days
    }

    func testShakyReviewPullsTheIntervalBack() {
        let s = makeStore()
        let base = Date()
        s.markCompleted("chord-g", on: base)
        s.recordReview("chord-g", clean: true, on: base)   // stage 1
        s.recordReview("chord-g", clean: true, on: base)   // stage 2
        XCTAssertEqual(s.reviewState(of: "chord-g")?.stage, 2)
        s.recordReview("chord-g", clean: false, on: base)  // shaky → back to stage 1
        XCTAssertEqual(s.reviewState(of: "chord-g")?.stage, 1)
    }

    func testReviewStageStaysWithinBounds() {
        let s = makeStore()
        let base = Date()
        s.markCompleted("chord-d", on: base)
        s.recordReview("chord-d", clean: false, on: base) // never below the first gap
        XCTAssertEqual(s.reviewState(of: "chord-d")?.stage, 0)
        for _ in 0..<10 { s.recordReview("chord-d", clean: true, on: base) }
        XCTAssertEqual(s.reviewState(of: "chord-d")?.stage, ProgressStore.reviewIntervals.count - 1)
    }

    func testDueForReviewOrdersMostOverdueFirst() {
        let s = makeStore()
        let base = Date()
        s.markCompleted("early", on: base)                 // due day 1
        s.markCompleted("late", on: base)
        s.recordReview("late", clean: true, on: base)      // due day 3
        XCTAssertEqual(s.dueForReview(on: day(base, 5)), ["early", "late"])
        XCTAssertEqual(s.dueForReview(on: base), [])       // nothing due on the day learned
    }

    func testRunningALearnedLessonCountsAsAReview() {
        let s = makeStore()
        while !s.isCompleted("chord-a") { s.recordRun("chord-a", score: 1.0) }
        XCTAssertEqual(s.reviewState(of: "chord-a")?.stage, 0)   // scheduled when first learned
        let before = s.reviewState(of: "chord-a")!.stage
        s.recordRun("chord-a", score: 1.0)                       // a clean run of a learned skill = a review
        XCTAssertEqual(s.reviewState(of: "chord-a")?.stage, before + 1)
    }

    func testReviewSchedulePersists() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("abstrum-stats-\(UUID().uuidString)")
        let base = Date()
        let a = ProgressStore(directory: dir, filename: "progress.json")
        a.markCompleted("chord-em", on: base)
        a.recordReview("chord-em", clean: true, on: base)        // stage 1
        let b = ProgressStore(directory: dir, filename: "progress.json")
        XCTAssertEqual(b.reviewState(of: "chord-em")?.stage, 1)
    }

    func testPersistenceRoundTrip() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("abstrum-stats-\(UUID().uuidString)")
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
