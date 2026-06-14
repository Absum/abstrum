//
//  LessonMatcherTests.swift
//  The note-matching that lesson feedback depends on.
//

import XCTest

final class LessonMatcherTests: XCTestCase {

    private func shifted(_ base: Double, cents: Double) -> Double {
        base * pow(2.0, cents / 1200.0)
    }

    func testExactPitchIsCorrect() {
        XCTAssertEqual(LessonLibrary.evaluate(frequency: 110.0, target: 110.0), .correct)
    }

    func testWithinToleranceIsCorrect() {
        XCTAssertEqual(LessonLibrary.evaluate(frequency: shifted(110, cents: 30), target: 110.0), .correct)
        XCTAssertEqual(LessonLibrary.evaluate(frequency: shifted(110, cents: -30), target: 110.0), .correct)
    }

    func testSemitoneOffIsClose() {
        XCTAssertEqual(LessonLibrary.evaluate(frequency: shifted(110, cents: 100), target: 110.0), .close)
    }

    func testWrongNoteIsOff() {
        // D3 played against an A2 target.
        XCTAssertEqual(LessonLibrary.evaluate(frequency: 146.83, target: 110.0), .off)
    }

    func testInvalidInputIsOff() {
        XCTAssertEqual(LessonLibrary.evaluate(frequency: 0, target: 110.0), .off)
    }
}
