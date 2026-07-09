//
//  CourseTests.swift
//  Course structure, unlock chain across courses, and fretted-note content.
//

import XCTest

final class CourseTests: XCTestCase {

    func testCoursesExist() {
        XCTAssertEqual(CourseLibrary.all.count, 9)   // all playable — incl. the Ear Training track
        XCTAssertEqual(CourseLibrary.firstContact.lessons.count, 3)
        XCTAssertEqual(CourseLibrary.firstNotes.lessons.count, 2)
        XCTAssertEqual(CourseLibrary.firstChords.lessons.count, 9)   // Em Am, song, E A D G C Dm
        XCTAssertEqual(CourseLibrary.chordChanges.lessons.count, 4)  // + Am↔Dm side branch
        XCTAssertEqual(CourseLibrary.strumming.lessons.count, 10)  // + patterns, dynamics, chuck, songs
    }

    func testStrumPatternLibrary() {
        // Pattern lessons carry eighth-note strokes; simple lessons don't.
        XCTAssertNil(LessonLibrary.strumDown.steps.first?.strum?.strokes)
        let downUp = LessonLibrary.patternDownUp.steps.first?.strum
        XCTAssertEqual(downUp?.strokes?.count, 8)          // 2 slots per beat
        XCTAssertEqual(downUp?.beats, 4)
        // Old Faithful: D · D-U · U-D-U = 6 hits out of 8 slots.
        let faithful = LessonLibrary.patternOldFaithful.steps.first?.strum
        XCTAssertEqual(faithful?.strokes,
                       [.down, .rest, .down, .up, .rest, .up, .down, .up])
        XCTAssertEqual(faithful?.expectedHits.count, 6)
        // Expected offsets land on the eighth grid (beats: 0, 1, 1.5, 2.5, 3, 3.5).
        XCTAssertEqual(faithful?.expectedHits.map { $0.beatOffset },
                       [0, 1.0, 1.5, 2.5, 3.0, 3.5])
        // Simple mode: one expected hit per beat, ids are beat indices.
        let simple = StrumPattern(bpm: 80, beats: 4)
        XCTAssertEqual(simple.expectedHits.map { $0.beatOffset }, [0, 1, 2, 3])
        XCTAssertEqual(simple.expectedHits.map { $0.id }, [0, 1, 2, 3])
        // The new songs resolve all their chords, incl. Dm in the minor loop.
        XCTAssertEqual(LessonLibrary.songFifties.steps.compactMap { $0.chord?.id },
                       ["G", "Em", "C", "D"])
        XCTAssertEqual(LessonLibrary.songMinorLoop.steps.compactMap { $0.chord?.id },
                       ["Am", "Dm", "G", "C"])
    }

    func testTier3BarreContent() {
        XCTAssertFalse(CourseLibrary.barreRhythm.comingSoon)
        XCTAssertEqual(CourseLibrary.barreRhythm.lessons.count, 11)       // + movable barre, power chords, riff, 16ths
        XCTAssertEqual(CourseLibrary.barreRhythm.lessons.first?.id, "cheater-f")
        XCTAssertNotNil(LessonLibrary.chordF.steps.first?.chord?.barre)   // full F is a barre shape
        XCTAssertEqual(LessonLibrary.chordF.prerequisite, "cheater-f")
        // Movable barres up the neck are still barre shapes.
        XCTAssertNotNil(LessonLibrary.moreBarre.steps.first?.chord?.barre)
        // Power chords are root + fifth — two pitch classes.
        XCTAssertEqual(LessonLibrary.powerChords.steps.first?.chord?.id, "E5")
        XCTAssertEqual(LessonLibrary.powerChords.steps.first?.chord?.pitchClasses.count, 2)
        // The spiral mix is the tier-3 capstone, gated by the 16th-note lesson.
        XCTAssertEqual(LessonLibrary.spiralBarreMix.prerequisite, "sixteenths")
        XCTAssertEqual(CourseLibrary.barreRhythm.lessons.last?.id, "spiral-barre-mix")
    }

    func testTier3PrerequisiteChainIsConnected() {
        // Every tier-3 lesson's spine prereq resolves to a real earlier lesson.
        let ids = Set(LessonLibrary.all.map { $0.id })
        for lesson in CourseLibrary.barreRhythm.lessons {
            if let prereq = lesson.prerequisite { XCTAssertTrue(ids.contains(prereq), "\(lesson.id) → \(prereq)") }
        }
        // Power-chord lessons resolve every chord (no dropped steps).
        XCTAssertEqual(LessonLibrary.powerRiff.steps.compactMap { $0.chord?.id }, ["E5", "G5", "A5", "E5"])
    }

    func testTier4ScaleContent() {
        XCTAssertFalse(CourseLibrary.leadBasics.comingSoon)
        XCTAssertEqual(CourseLibrary.leadBasics.lessons.count, 7)   // + box 1, lick, major scale, finger drill
        let scale = LessonLibrary.minorPentatonic
        XCTAssertEqual(scale.steps.first?.note, "A")
        // Every lead lesson is pure single-note content.
        for lesson in CourseLibrary.leadBasics.lessons {
            XCTAssertTrue(lesson.steps.allSatisfy { $0.chord == nil && $0.strum == nil }, lesson.id)
        }
        // Box 1 is the movable shape — entirely up at the 5th fret and above.
        XCTAssertTrue(LessonLibrary.pentatonicBox1.steps.allSatisfy { ($0.position?.fret ?? 0) >= 5 })
        // The major scale spells G major, one octave (G … F♯ … G).
        let major = LessonLibrary.majorScaleG.steps.map { $0.note }
        XCTAssertEqual(major.first, "G")
        XCTAssertEqual(major.last, "G")
        XCTAssertTrue(major.contains("F♯") || major.contains("F#"))
    }

    func testFullSixTierMap() {
        // Tiers 0 through 5 are all represented — and all real now: no
        // coming-soon placeholders, every course has lessons.
        let tiers = Set(CourseLibrary.all.map { $0.tier })
        XCTAssertEqual(tiers, [0, 1, 2, 3, 4, 5])
        for course in CourseLibrary.all {
            XCTAssertFalse(course.comingSoon, "\(course.id) is still a placeholder")
            XCTAssertFalse(course.lessons.isEmpty, "\(course.id) has no lessons")
        }
    }

    func testTier5IntermediateContent() {
        XCTAssertFalse(CourseLibrary.intermediate.comingSoon)
        XCTAssertEqual(CourseLibrary.intermediate.lessons.count, 4)
        // Gated on the end of Tier 4 lead.
        XCTAssertEqual(LessonLibrary.fingerstyleThumb.prerequisite, "first-lick")
        // Fingerstyle intro is pure single-note content.
        XCTAssertTrue(LessonLibrary.fingerstyleThumb.steps.allSatisfy { $0.chord == nil && $0.strum == nil })
        XCTAssertTrue(LessonLibrary.fingerstyleArp.steps.allSatisfy { $0.chord == nil && $0.strum == nil })
        // Full songs resolve every chord, including the F barre and the 7ths.
        XCTAssertEqual(LessonLibrary.fullWaterWide.steps.count, 8)
        XCTAssertTrue(LessonLibrary.fullWaterWide.prerequisites.contains("chord-f"))
        XCTAssertEqual(LessonLibrary.fullSlowBlues.steps.count, 12)
        XCTAssertEqual(Set(LessonLibrary.fullSlowBlues.steps.compactMap { $0.chord?.id }),
                       ["E7", "A7", "B7"])
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
        // Easiest chords come first; Dm completes the open-chord family last.
        XCTAssertEqual(CourseLibrary.firstChords.lessons.first?.id, "chord-em")
        XCTAssertEqual(CourseLibrary.firstChords.lessons.last?.id, "chord-dm")
        // A 2-chord song lands after the first two chords and gates the rest.
        XCTAssertTrue(CourseLibrary.firstChords.lessons.contains { $0.id == "song-em-am" })
        XCTAssertEqual(LessonLibrary.chordE.prerequisite, "song-em-am")
    }

    func testDmCompletesTheOpenChordFamily() {
        // Dm sits at the end of Tier 1 on the mastery spine: it follows C and
        // gates the Tier-2 changes.
        XCTAssertEqual(LessonLibrary.chordDm.prerequisite, "chord-c")
        XCTAssertEqual(LessonLibrary.changeEA.prerequisite, "chord-dm")
        XCTAssertEqual(LessonLibrary.chordDm.steps.first?.chord?.id, "Dm")
        // The minor-family change drill alternates Am and Dm as a side branch.
        XCTAssertEqual(LessonLibrary.changeAmDm.steps.compactMap { $0.chord?.id },
                       ["Am", "Dm", "Am", "Dm"])
        XCTAssertEqual(LessonLibrary.changeAmDm.prerequisite, "change-gc")
    }

    func testSpiralRevisitsReuseEarlierChords() {
        // Spiral nodes pull earlier chords back at a harder tempo / mixed with barre.
        XCTAssertTrue(CourseLibrary.strumming.lessons.contains { $0.id == "spiral-gcd" })
        XCTAssertEqual(Set(LessonLibrary.spiralGCD.prerequisites), ["chord-g", "chord-c", "chord-d"])
        XCTAssertTrue(LessonLibrary.spiralBarreMix.prerequisites.contains("chord-f"))   // open + barre
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
