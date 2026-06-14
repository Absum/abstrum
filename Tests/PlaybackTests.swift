//
//  PlaybackTests.swift
//  Tone synthesis + chord pitch derivation for "hear it" examples.
//

import XCTest

final class PlaybackTests: XCTestCase {

    func testPluckProducesFiniteNonSilentSamples() {
        let samples = ToneSynth.pluck(frequency: 110, sampleRate: 44_100, length: 4_410)
        XCTAssertEqual(samples.count, 4_410)
        XCTAssertTrue(samples.allSatisfy { $0.isFinite })
        XCTAssertTrue(samples.contains { abs($0) > 0.01 }, "Pluck should produce audible signal")
    }

    func testStrumIsNormalizedAndFinite() {
        let samples = ToneSynth.strum(frequencies: [82.41, 110, 146.83],
                                      sampleRate: 44_100, duration: 0.5, strumDelay: 0.02)
        XCTAssertEqual(samples.count, Int(44_100 * 0.5))
        XCTAssertTrue(samples.allSatisfy { $0.isFinite })
        XCTAssertLessThanOrEqual(samples.map { abs($0) }.max() ?? 0, 1.0)
    }

    func testChordFrequencies() {
        let e = ChordBank.all.first { $0.id == "E" }!
        let freqs = e.frequencies
        XCTAssertEqual(freqs.count, e.positions.count)
        XCTAssertEqual(freqs.first!, 82.41, accuracy: 0.5)   // low E open
    }
}
