//
//  TabImportTests.swift
//  Parsing the simple single-note tab format.
//

import XCTest

final class TabImportTests: XCTestCase {
    func testParsesTokensAndMapsStrings() {
        // 1 = high e (internal 5), 6 = low E (internal 0).
        let steps = TabImport.parse("1:0 1:3 6:2 2:1")
        XCTAssertEqual(steps.count, 4)
        XCTAssertEqual(steps[0].string, 5); XCTAssertEqual(steps[0].fret, 0)
        XCTAssertEqual(steps[1].string, 5); XCTAssertEqual(steps[1].fret, 3)
        XCTAssertEqual(steps[2].string, 0); XCTAssertEqual(steps[2].fret, 2)
        XCTAssertEqual(steps[3].string, 4); XCTAssertEqual(steps[3].fret, 1)
    }

    func testIgnoresGarbageAndAcceptsNewlinesCommas() {
        let steps = TabImport.parse("1:0, x, 7:0, 1:99,\n2:2")
        // "7:0" (string out of range) and "1:99" (fret out of range) and "x" dropped.
        XCTAssertEqual(steps.count, 2)
        XCTAssertEqual(steps[0].string, 5)
        XCTAssertEqual(steps[1].string, 4)
    }

    func testEmptyForNoValidTokens() {
        XCTAssertTrue(TabImport.parse("hello world").isEmpty)
    }
}
