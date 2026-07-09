//
//  SongTests.swift
//  Every song's chart resolves to real chords.
//

import XCTest

final class SongTests: XCTestCase {
    func testSongBarsResolve() {
        for song in SongLibrary.all {
            XCTAssertEqual(song.bars.count, song.barChordIDs.count,
                           "\(song.title): a bar chord id did not resolve to a bank chord")
            XCTAssertFalse(song.bars.isEmpty)
        }
    }

    func testSongIDsAreUnique() {
        let ids = SongLibrary.all.map { $0.id }
        XCTAssertEqual(ids.count, Set(ids).count)
    }

    func testEveryDifficultyIsRepresented() {
        for difficulty in SongDifficulty.allCases {
            XCTAssertFalse(SongLibrary.songs(difficulty).isEmpty, "\(difficulty.label) is empty")
        }
    }

    func testDifficultyGradingIsHonest() {
        // Barre chords (F, Bm, F#m, B) and 7th voicings only appear at
        // intermediate; beginner songs stay inside the open-chord family.
        let barreOr7th: Set<String> = ["F", "Bm", "F#m", "B", "E7", "A7", "B7", "C7", "D7", "G7"]
        let openFamily: Set<String> = ["Em", "Am", "E", "A", "D", "G", "C", "Dm"]
        for song in SongLibrary.all {
            let chords = Set(song.barChordIDs)
            switch song.difficulty {
            case .beginner:
                XCTAssertTrue(chords.isSubset(of: openFamily),
                              "\(song.title) (beginner) uses \(chords.subtracting(openFamily))")
            case .easy:
                XCTAssertTrue(chords.isDisjoint(with: barreOr7th),
                              "\(song.title) (easy) uses barre/7th chords")
            case .intermediate:
                XCTAssertFalse(chords.isDisjoint(with: barreOr7th),
                               "\(song.title) shouldn't be intermediate without a barre/7th")
            }
        }
    }
}
