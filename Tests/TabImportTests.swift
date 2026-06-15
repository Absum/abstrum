//
//  TabImportTests.swift
//  Parsing the single-note tab format (with rhythm).
//

import XCTest

final class TabImportTests: XCTestCase {
    func testParsesTokensAndMapsStrings() {
        // 1 = high e (internal 5), 6 = low E (internal 0). No letter = quarter (1 beat).
        let steps = TabImport.parse("1:0 1:3 6:2 2:1")
        XCTAssertEqual(steps.count, 4)
        XCTAssertEqual(steps[0].string, 5); XCTAssertEqual(steps[0].fret, 0); XCTAssertEqual(steps[0].beats, 1)
        XCTAssertEqual(steps[2].string, 0); XCTAssertEqual(steps[2].fret, 2)
        XCTAssertEqual(steps[3].string, 4); XCTAssertEqual(steps[3].fret, 1)
    }

    func testParsesDurationsAndRests() {
        let steps = TabImport.parse("1:0e 1:1h 2:3q. rq re")
        XCTAssertEqual(steps.count, 5)
        XCTAssertEqual(steps[0].beats, 0.5)    // eighth
        XCTAssertEqual(steps[1].beats, 2)      // half
        XCTAssertEqual(steps[2].beats, 1.5)    // dotted quarter
        XCTAssertEqual(steps[3].string, -1); XCTAssertEqual(steps[3].beats, 1)   // rest, quarter
        XCTAssertEqual(steps[4].string, -1); XCTAssertEqual(steps[4].beats, 0.5) // rest, eighth
    }

    func testIgnoresGarbageAndAcceptsNewlinesCommas() {
        let steps = TabImport.parse("1:0, x, 7:0, 1:99,\n2:2")
        XCTAssertEqual(steps.count, 2)
        XCTAssertEqual(steps[0].string, 5)
        XCTAssertEqual(steps[1].string, 4)
    }

    func testNoRealNotesWhenGarbage() {
        XCTAssertFalse(TabImport.parse("hello world").contains { $0.string >= 0 })
    }

    func testLetterRoundTrip() {
        XCTAssertEqual(TabImport.letter(forBeats: 0.5), "e")
        XCTAssertEqual(TabImport.letter(forBeats: 1.5), "q.")
        XCTAssertEqual(TabImport.letter(forBeats: 2), "h")
    }
}
