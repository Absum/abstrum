//
//  CourseTests.swift
//  Course structure, unlock chain across courses, and fretted-note content.
//

import XCTest

final class CourseTests: XCTestCase {

    func testCoursesExist() {
        XCTAssertEqual(CourseLibrary.all.count, 8)   // 5 playable + 3 coming-soon (tiers 3–5)
        XCTAssertEqual(CourseLibrary.firstContact.lessons.count, 3)
        XCTAssertEqual(CourseLibrary.firstNotes.lessons.count, 2)
        XCTAssertEqual(CourseLibrary.firstChords.lessons.count, 5)
        XCTAssertEqual(CourseLibrary.chordChanges.lessons.count, 3)
        XCTAssertEqual(CourseLibrary.strumming.lessons.count, 3)
    }

    func testTier3BarreContent() {
        XCTAssertFalse(CourseLibrary.barreRhythm.comingSoon)
        XCTAssertEqual(CourseLibrary.barreRhythm.lessons.count, 5)
        XCTAssertNotNil(LessonLibrary.chordF.steps.first?.chord?.barre)   // F is a barre shape
    }

    func testFullSixTierMap() {
        // Tiers 0 through 5 are all represented on the map.
        let tiers = Set(CourseLibrary.all.map { $0.tier })
        XCTAssertEqual(tiers, [0, 1, 2, 3, 4, 5])
        // Tiers 3–5 are coming-soon placeholders: locked, no lessons.
        for course in CourseLibrary.all where course.comingSoon {
            XCTAssertTrue(course.lessons.isEmpty)
            XCTAssertFalse(CourseLibrary.isUnlocked(course, completed: ["low-to-high"]))
        }
    }

    func testStrumLessonsAreTimed() {
        let song = LessonLibrary.firstSong
        XCTAssertEqual(song.steps.count, 4)
        XCTAssertTrue(song.steps.allSatisfy { $0.strum != nil })
        XCTAssertEqual(song.steps.compactMap { $0.chord?.id }, ["Em", "C", "G", "D"])
    }

    func testChordLessonsTargetChords() {
        for lesson in CourseLibrary.firstChords.lessons {
            XCTAssertFalse(lesson.steps.isEmpty)
            XCTAssertTrue(lesson.steps.allSatisfy { $0.chord != nil })
        }
        XCTAssertEqual(LessonLibrary.chordA.steps.first?.chord?.id, "A")
        XCTAssertEqual(LessonLibrary.changeEA.steps.compactMap { $0.chord?.id }, ["E", "A", "E", "A"])
    }

    func testChordCourseUnlockChain() {
        XCTAssertFalse(CourseLibrary.isUnlocked(CourseLibrary.firstChords, completed: []))
        XCTAssertTrue(CourseLibrary.isUnlocked(CourseLibrary.firstChords, completed: ["a-string-notes"]))
    }

    func testFirstCourseUnlocked() {
        XCTAssertTrue(CourseLibrary.isUnlocked(CourseLibrary.firstContact, completed: []))
    }

    func testSecondCourseLockedUntilFirstContactFinished() {
        XCTAssertFalse(CourseLibrary.isUnlocked(CourseLibrary.firstNotes, completed: []))
        // first-notes' first lesson requires "low-to-high" (last of first-contact).
        XCTAssertTrue(CourseLibrary.isUnlocked(CourseLibrary.firstNotes, completed: ["low-to-high"]))
    }

    func testFrettedNoteFrequencyAndName() {
        // Low E string, 1st fret ≈ F2 (87.31 Hz).
        let step = LessonLibrary.lowENotes.steps[1]
        XCTAssertEqual(step.frequency, 87.31, accuracy: 0.5)
        XCTAssertEqual(step.note, "F")
        XCTAssertEqual(step.position, FretPosition(string: 0, fret: 1))
    }
}
