//
//  DailySessionTests.swift
//  The structured daily-session generator: arc ordering, phase selection,
//  review interleaving/caps, and song classification.
//

import XCTest

final class DailySessionTests: XCTestCase {

    // A learner who's finished Tier 0 + all of the open chords (through C).
    private let throughOpenChords: Set<String> = [
        "open-strings", "string-switching", "low-to-high",
        "chord-em", "chord-am", "song-em-am",
        "chord-e", "chord-a", "chord-d", "chord-g", "chord-c",
    ]

    func testFreshLearnerGetsASingleStartingStep() {
        let plan = DailySession.plan(completed: [], due: [])
        XCTAssertEqual(plan.count, 1)
        XCTAssertEqual(plan.first?.phase, .newSkill)
        XCTAssertEqual(plan.first?.lesson.id, "open-strings")
    }

    func testSessionFollowsTheArcInOrder() {
        let plan = DailySession.plan(completed: throughOpenChords, due: ["chord-em", "chord-am"])
        let phaseOrder = plan.map { $0.phase.order }
        XCTAssertEqual(phaseOrder, phaseOrder.sorted(), "items must run warm-up → … → cool-down")
        XCTAssertEqual(plan.first?.phase, .warmUp)
        // The arc covers the full pedagogical sequence here.
        XCTAssertEqual(Set(plan.map { $0.phase }),
                       [.warmUp, .review, .newSkill, .song, .coolDown])
    }

    func testReviewBlockMirrorsTheDueQueue() {
        let plan = DailySession.plan(completed: throughOpenChords, due: ["chord-am", "chord-em"])
        let reviews = plan.filter { $0.phase == .review }.map { $0.lesson.id }
        XCTAssertEqual(reviews, ["chord-am", "chord-em"])   // order preserved
    }

    func testReviewsAreCappedAndWarmupIsNotDue() {
        let due = ["chord-em", "chord-am", "chord-d", "chord-g", "chord-c"]
        let plan = DailySession.plan(completed: throughOpenChords, due: due, maxReviews: 3)
        XCTAssertEqual(plan.filter { $0.phase == .review }.count, 3)
        let warmup = plan.first { $0.phase == .warmUp }
        XCTAssertNotNil(warmup)
        XCTAssertFalse(due.contains(warmup!.lesson.id), "warm-up shouldn't be a due-for-review skill")
    }

    func testNoDueSkillsMeansNoReviewBlock() {
        let plan = DailySession.plan(completed: throughOpenChords, due: [])
        XCTAssertFalse(plan.contains { $0.phase == .review })
        XCTAssertTrue(plan.contains { $0.phase == .newSkill })
    }

    func testNewSkillIsTheFrontierLesson() {
        // Through chord-c, the next unlocked-but-unlearned lesson is Dm (the
        // last Tier-1 chord, which gates the Tier-2 changes).
        let plan = DailySession.plan(completed: throughOpenChords, due: [])
        XCTAssertEqual(plan.first { $0.phase == .newSkill }?.lesson.id, "chord-dm")
    }

    func testNoDuplicateLessonsAcrossPhases() {
        let plan = DailySession.plan(completed: throughOpenChords, due: ["chord-em", "song-em-am"])
        let ids = plan.map { $0.lesson.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testStaleDueIDsDoNotEatReviewSlots() {
        // SRS entries can reference lessons removed in a resequencing; they must
        // neither appear nor consume the review cap.
        let plan = DailySession.plan(completed: throughOpenChords,
                                     due: ["ghost-1", "ghost-2", "ghost-3", "chord-em"],
                                     maxReviews: 3)
        let reviews = plan.filter { $0.phase == .review }.map { $0.lesson.id }
        XCTAssertEqual(reviews, ["chord-em"])   // survives despite three stale ids ahead of it
    }

    func testLessonIDLookupCoversTheWholeLibrary() {
        XCTAssertEqual(LessonLibrary.byID.count, LessonLibrary.all.count)   // ids are unique
        XCTAssertNil(LessonLibrary.byID["ghost"])
    }

    func testSongClassification() {
        XCTAssertTrue(DailySession.isSong(LessonLibrary.firstSong))    // strummed Em-C-G-D
        XCTAssertTrue(DailySession.isSong(LessonLibrary.spiralGCD))    // strummed G-C-D
        XCTAssertTrue(DailySession.isSong(LessonLibrary.songEmAm))     // chord-only first song
        XCTAssertFalse(DailySession.isSong(LessonLibrary.changeEA))    // a two-chord change drill
        XCTAssertFalse(DailySession.isSong(LessonLibrary.strumKeep))   // single-chord strum drill
        XCTAssertFalse(DailySession.isSong(LessonLibrary.chordEm))     // single chord
    }
}
