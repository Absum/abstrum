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

    func testRepeatedPluckOfSameNoteIsIdentical() {
        // The "hear it" example must not drift between repeats — same pitch in,
        // bit-identical samples out.
        let a = ToneSynth.pluck(frequency: 196, sampleRate: 44_100, length: 2_000)
        let b = ToneSynth.pluck(frequency: 196, sampleRate: 44_100, length: 2_000)
        XCTAssertEqual(a, b)
    }

    func testDifferentPitchesProduceDifferentSamples() {
        let g = ToneSynth.pluck(frequency: 196, sampleRate: 44_100, length: 2_000)
        let a = ToneSynth.pluck(frequency: 220, sampleRate: 44_100, length: 2_000)
        XCTAssertNotEqual(g, a)
    }

    func testPluckFundamentalIsInTune() {
        // Autocorrelation peak should land near the true period for the pitch,
        // confirming the delay-length tuning isn't off.
        let freq = 330.0, sr = 44_100.0
        let s = ToneSynth.pluck(frequency: freq, sampleRate: sr, length: 8_000)
        let expected = sr / freq                       // ~133.6 samples
        let lo = Int(expected * 0.5), hi = Int(expected * 1.5)
        var bestLag = lo; var best = -Float.greatestFiniteMagnitude
        for lag in lo...hi {
            var sum: Float = 0
            for i in lag..<s.count { sum += s[i] * s[i - lag] }
            if sum > best { best = sum; bestLag = lag }
        }
        // Within ~3% of the ideal period (a few cents) — was consistently flat before.
        XCTAssertEqual(Double(bestLag), expected, accuracy: expected * 0.03)
    }

    func testChordFrequencies() {
        let e = ChordBank.all.first { $0.id == "E" }!
        let freqs = e.frequencies
        XCTAssertEqual(freqs.count, e.positions.count)
        XCTAssertEqual(freqs.first!, 82.41, accuracy: 0.5)   // low E open
    }
}
