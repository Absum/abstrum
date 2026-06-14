//
//  SkillPathTests.swift
//  Lesson unlock rules + progress persistence.
//

import XCTest

final class SkillPathTests: XCTestCase {

    func testFirstLessonAlwaysUnlocked() {
        XCTAssertTrue(LessonLibrary.isUnlocked(LessonLibrary.openStrings, completed: []))
    }

    func testLessonLockedUntilPrerequisiteComplete() {
        let second = LessonLibrary.stringSwitching
        XCTAssertFalse(LessonLibrary.isUnlocked(second, completed: []))
        XCTAssertTrue(LessonLibrary.isUnlocked(second, completed: ["open-strings"]))
    }

    func testProgressPersistsAcrossInstances() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let filename = "progress.json"

        let store = ProgressStore(directory: dir, filename: filename)
        XCTAssertFalse(store.isCompleted("open-strings"))
        store.markCompleted("open-strings")

        let reloaded = ProgressStore(directory: dir, filename: filename)
        XCTAssertTrue(reloaded.isCompleted("open-strings"),
                      "Completion should survive a fresh store instance")
    }

    func testResetClearsProgress() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let store = ProgressStore(directory: dir, filename: "progress.json")
        store.markCompleted("open-strings")
        store.reset()
        XCTAssertTrue(store.completedLessonIDs.isEmpty)
    }
}
