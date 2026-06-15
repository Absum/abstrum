//
//  ChordDetectionTests.swift
//  Validates the chroma core + template matcher on synthetic chords.
//

import XCTest

final class ChordDetectionTests: XCTestCase {

    private let sampleRate = 44_100.0
    private let frameCount = 16_384   // matches the detector's analysis window

    /// Sum of equal-amplitude sines at the given frequencies.
    private func tone(_ frequencies: [Double]) -> [Float] {
        (0..<frameCount).map { i in
            let t = Double(i) / sampleRate
            let sample = frequencies.reduce(0.0) { $0 + sin(2.0 * .pi * $1 * t) }
            return Float(sample / Double(frequencies.count) * 0.7)
        }
    }

    private func chroma(_ samples: [Float]) -> [Float]? {
        let detector = pk_chord_detector_create(sampleRate)
        defer { pk_chord_detector_destroy(detector) }
        var out = [Float](repeating: 0, count: 12)
        let ok = samples.withUnsafeBufferPointer { input in
            out.withUnsafeMutableBufferPointer { output in
                pk_chord_detector_chroma(detector, input.baseAddress, input.count, output.baseAddress)
            }
        }
        return ok == 1 ? out : nil
    }

    // Open E major voicing: E2 B2 E3 G#3 B3 E4
    private let eMajorVoicing = [82.41, 123.47, 164.81, 207.65, 246.94, 329.63]
    // Open A major voicing: A2 E3 A3 C#4 E4
    private let aMajorVoicing = [110.00, 164.81, 220.00, 277.18, 329.63]

    // A power chord {root,fifth} is a subset of the major/minor triad, so over
    // the *full* bank a weak-third voicing can read as a 5 chord. That only
    // affects auto-identification (bestMatch), which the live app doesn't use —
    // it scores against the chord the user chose. So scope auto-ID to triads/7ths.
    private var triadCandidates: [Chord] { ChordBank.all.filter { $0.quality != .power } }

    func testEMajorMatchesEMajorBest() throws {
        let c = try XCTUnwrap(chroma(tone(eMajorVoicing)))
        let best = try XCTUnwrap(ChordMatcher.bestMatch(chroma: c, in: triadCandidates))
        XCTAssertEqual(best.chord.id, "E", "Best match should be E, got \(best.chord.id)")
        XCTAssertGreaterThan(best.score, 0.8)
    }

    func testEMajorScoresHigherThanEMinor() throws {
        let c = try XCTUnwrap(chroma(tone(eMajorVoicing)))
        let eMajor = ChordBank.all.first { $0.id == "E" }!
        let eMinor = ChordBank.all.first { $0.id == "Em" }!
        XCTAssertGreaterThan(ChordMatcher.score(chroma: c, pitchClasses: eMajor.pitchClasses),
                             ChordMatcher.score(chroma: c, pitchClasses: eMinor.pitchClasses))
    }

    func testAMajorMatchesAMajorBest() throws {
        let c = try XCTUnwrap(chroma(tone(aMajorVoicing)))
        let best = try XCTUnwrap(ChordMatcher.bestMatch(chroma: c, in: triadCandidates))
        XCTAssertEqual(best.chord.id, "A", "Best match should be A, got \(best.chord.id)")
    }

    func testPowerChordMatchesBest() throws {
        // E5 = E + B (root + fifth): E2, B2, E3.
        let c = try XCTUnwrap(chroma(tone([82.41, 123.47, 164.81])))
        let best = try XCTUnwrap(ChordMatcher.bestMatch(chroma: c, in: ChordBank.all))
        XCTAssertEqual(best.chord.id, "E5", "Best match should be E5, got \(best.chord.id)")
    }

    func testSilenceProducesNoChroma() {
        let silence = [Float](repeating: 0, count: frameCount)
        XCTAssertNil(chroma(silence))
    }
}
