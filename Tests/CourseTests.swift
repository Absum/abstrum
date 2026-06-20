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
        XCTAssertEqual(CourseLibrary.firstChords.lessons.count, 8)   // Em Am, song, E A D G C
        XCTAssertEqual(CourseLibrary.chordChanges.lessons.count, 3)
        XCTAssertEqual(CourseLibrary.strumming.lessons.count, 3)
    }

    func testTier3BarreContent() {
        XCTAssertFalse(CourseLibrary.barreRhythm.comingSoon)
        XCTAssertEqual(CourseLibrary.barreRhythm.lessons.count, 6)        // easy-F added first
        XCTAssertEqual(CourseLibrary.barreRhythm.lessons.first?.id, "cheater-f")
        XCTAssertNotNil(LessonLibrary.chordF.steps.first?.chord?.barre)   // full F is a barre shape
        XCTAssertEqual(LessonLibrary.chordF.prerequisite, "cheater-f")
    }

    func testTier4ScaleContent() {
        XCTAssertFalse(CourseLibrary.leadBasics.comingSoon)
        XCTAssertEqual(CourseLibrary.leadBasics.lessons.count, 3)
        let scale = LessonLibrary.minorPentatonic
        XCTAssertEqual(scale.steps.first?.note, "A")
        XCTAssertTrue(scale.steps.allSatisfy { $0.chord == nil && $0.strum == nil })  // pure note steps
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
        // Easiest chords come first.
        XCTAssertEqual(CourseLibrary.firstChords.lessons.first?.id, "chord-em")
        XCTAssertEqual(CourseLibrary.firstChords.lessons.last?.id, "chord-c")
        // A 2-chord song lands after the first two chords and gates the rest.
        XCTAssertTrue(CourseLibrary.firstChords.lessons.contains { $0.id == "song-em-am" })
        XCTAssertEqual(LessonLibrary.chordE.prerequisite, "song-em-am")
    }

    func testMultiplePrerequisites() {
        // The Four-Chord Song is a DAG node: needs its chords mastered, not just the spine.
        let song = LessonLibrary.firstSong
        XCTAssertFalse(song.prerequisites.isEmpty)
        let missingD = Set(["strum-keep", "chord-c", "chord-g"])
        XCTAssertFalse(LessonLibrary.isUnlocked(song, completed: missingD))
        XCTAssertTrue(LessonLibrary.isUnlocked(song, completed: missingD.union(["chord-d"])))
    }

    func testChordsUnlockRightAfterOpenStrings() {
        // Chords no longer depend on the single-note fretting lessons.
        XCTAssertFalse(CourseLibrary.isUnlocked(CourseLibrary.firstChords, completed: []))
        XCTAssertTrue(CourseLibrary.isUnlocked(CourseLibrary.firstChords, completed: ["low-to-high"]))
    }

    func testFirstCourseUnlocked() {
        XCTAssertTrue(CourseLibrary.isUnlocked(CourseLibrary.firstContact, completed: []))
    }

    func testSingleNotesAreLeadPrep() {
        // Single-note fretting is now Tier 4 lead-prep, gated by the end of Tier 3.
        XCTAssertEqual(CourseLibrary.firstNotes.tier, 4)
        XCTAssertFalse(CourseLibrary.isUnlocked(CourseLibrary.firstNotes, completed: ["low-to-high"]))
        XCTAssertTrue(CourseLibrary.isUnlocked(CourseLibrary.firstNotes, completed: ["faster-strum"]))
        // …and they precede the first scale.
        XCTAssertEqual(LessonLibrary.minorPentatonic.prerequisite, "a-string-notes")
    }

    func testFrettedNoteFrequencyAndName() {
        // Low E string, 1st fret ≈ F2 (87.31 Hz).
        let step = LessonLibrary.lowENotes.steps[1]
        XCTAssertEqual(step.frequency, 87.31, accuracy: 0.5)
        XCTAssertEqual(step.note, "F")
        XCTAssertEqual(step.position, FretPosition(string: 0, fret: 1))
    }
}
