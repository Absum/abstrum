//
//  ChordVoicingTests.swift
//  Audit: every chord's fingering actually voices its chord tones.
//

import XCTest

final class ChordVoicingTests: XCTestCase {
    // Open-string pitch classes: E2 A2 D3 G3 B3 E4.
    private let openPC = [4, 9, 2, 7, 11, 4]
    private let rootNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    /// Every fingered/open note must be a chord tone (no foreign notes), and the
    /// root must be present. (Voicings may omit the 5th, e.g. open C7 — allowed.)
    func testEveryVoicingUsesOnlyChordTones() {
        for chord in ChordBank.all {
            var played = Set<Int>()
            for pos in chord.positions {
                played.insert((openPC[pos.string] + pos.fret) % 12)
            }
            XCTAssertTrue(played.isSubset(of: chord.pitchClasses),
                          "\(chord.id): foreign notes \(played.subtracting(chord.pitchClasses).sorted())")
            let rootPC = rootNames.firstIndex(of: chord.root)!
            XCTAssertTrue(played.contains(rootPC), "\(chord.id): root not voiced")
        }
    }

    func testAllRootsCoveredPerQuality() {
        for quality in ChordQuality.allCases {
            let roots = Set(ChordBank.chords(quality: quality).map { $0.root })
            XCTAssertEqual(roots.count, 12, "\(quality.label) should cover all 12 roots, got \(roots.count)")
        }
    }
}
