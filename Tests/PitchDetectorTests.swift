//
//  PitchDetectorTests.swift
//  Phase 0 pitch-accuracy harness.
//
//  Exercises the portable C++ YIN core against synthetic signals at known
//  frequencies, so we can validate detection accuracy repeatably without a
//  guitar in hand. On-device validation against real recordings comes later;
//  this is the automated floor that must always hold.
//

import XCTest

final class PitchDetectorTests: XCTestCase {

    private let sampleRate = 48_000.0
    private let frameCount = 4096

    // Standard guitar open strings (equal temperament, A4 = 440 Hz).
    private let openStrings: [(name: String, freq: Double)] = [
        ("E2", 82.41), ("A2", 110.00), ("D3", 146.83),
        ("G3", 196.00), ("B3", 246.94), ("E4", 329.63),
    ]

    // MARK: - Signal synthesis

    /// A pure sine wave at `freq`.
    private func sine(_ freq: Double, amplitude: Double = 0.6) -> [Float] {
        (0..<frameCount).map { i in
            Float(amplitude * sin(2.0 * .pi * freq * Double(i) / sampleRate))
        }
    }

    /// A plucked-string-ish tone: fundamental plus decaying harmonics.
    private func pluck(_ freq: Double) -> [Float] {
        let harmonics: [(mult: Double, amp: Double)] =
            [(1, 1.0), (2, 0.5), (3, 0.3), (4, 0.15)]
        return (0..<frameCount).map { i in
            let t = Double(i) / sampleRate
            var sample = 0.0
            for h in harmonics {
                sample += h.amp * sin(2.0 * .pi * freq * h.mult * t)
            }
            return Float(sample * 0.25) // keep clear of clipping
        }
    }

    private func cents(detected: Double, target: Double) -> Double {
        1200.0 * log2(detected / target)
    }

    private func detect(_ samples: [Float]) -> (freq: Float, clarity: Float)? {
        let detector = pk_pitch_detector_create(sampleRate)
        defer { pk_pitch_detector_destroy(detector) }
        var clarity: Float = 0
        let freq = samples.withUnsafeBufferPointer {
            pk_pitch_detector_process(detector, $0.baseAddress, $0.count, &clarity)
        }
        return freq > 0 ? (freq, clarity) : nil
    }

    // MARK: - Accuracy

    func testPureSineDetectsConcertA() throws {
        let result = try XCTUnwrap(detect(sine(440)), "A4 sine should be detected")
        XCTAssertEqual(Double(result.freq), 440, accuracy: 2.0)
        XCTAssertGreaterThan(result.clarity, 0.8)
    }

    func testOpenStringsWithinFiveCents() throws {
        for string in openStrings {
            let result = try XCTUnwrap(detect(sine(string.freq)),
                                       "\(string.name) should be detected")
            let off = cents(detected: Double(result.freq), target: string.freq)
            XCTAssertLessThan(abs(off), 5.0,
                "\(string.name): detected \(result.freq) Hz, \(off) cents off")
        }
    }

    func testQuietSignalStillDetected() throws {
        // Quiet input (e.g. simulator mic, soft playing) must still register —
        // regression guard for the RMS silence gate being set too high.
        let quiet = sine(146.83, amplitude: 0.012) // RMS ~0.0085
        let result = try XCTUnwrap(detect(quiet), "Quiet D3 should still be detected")
        let off = cents(detected: Double(result.freq), target: 146.83)
        XCTAssertLessThan(abs(off), 5.0, "Quiet D3: detected \(result.freq) Hz, \(off) cents off")
    }

    func testHarmonicRichTonesTrackFundamental() throws {
        for string in openStrings {
            let result = try XCTUnwrap(detect(pluck(string.freq)),
                                       "\(string.name) pluck should be detected")
            let off = cents(detected: Double(result.freq), target: string.freq)
            // Harmonic content makes octave errors the classic failure mode —
            // assert we locked the fundamental, not the 2nd harmonic.
            XCTAssertLessThan(abs(off), 15.0,
                "\(string.name) pluck: detected \(result.freq) Hz, \(off) cents off")
        }
    }

    // MARK: - Rejection

    func testSilenceReportsNoPitch() {
        let silence = [Float](repeating: 0, count: frameCount)
        XCTAssertNil(detect(silence), "Silence should not yield a pitch")
    }

    func testAboveRangeToneIsRejectedNotAliased() {
        // A periodic tone above the plausible guitar range (kMaxFreq = 2000 Hz)
        // must report NO pitch — not lock onto its 2x period and misreport an
        // octave down. Locks the deliberate low-tau search + range-check design.
        XCTAssertNil(detect(sine(2500)), "2.5 kHz tone must not alias to 1250 Hz")
    }

    func testLowAmplitudeNoiseReportsNoPitch() {
        // White-ish noise below the RMS gate.
        var seed: UInt64 = 0x1234_5678
        let noise: [Float] = (0..<frameCount).map { _ in
            seed = seed &* 6364136223846793005 &+ 1442695040888963407
            let unit = Double(seed >> 33) / Double(UInt32.max) * 2 - 1
            return Float(unit * 0.002) // well under the 0.01 gate
        }
        XCTAssertNil(detect(noise), "Near-silent noise should not yield a pitch")
    }

    // MARK: - Latency budget

    func testProcessingIsWellWithinRealTime() throws {
        let samples = pluck(146.83)
        let detector = pk_pitch_detector_create(sampleRate)
        defer { pk_pitch_detector_destroy(detector) }

        // A frame of audio lasts frameCount/sampleRate seconds; processing must
        // be a small fraction of that to keep end-to-end latency low.
        let frameDuration = Double(frameCount) / sampleRate
        let iterations = 50
        let start = Date()
        for _ in 0..<iterations {
            var clarity: Float = 0
            _ = samples.withUnsafeBufferPointer {
                pk_pitch_detector_process(detector, $0.baseAddress, $0.count, &clarity)
            }
        }
        let perCall = Date().timeIntervalSince(start) / Double(iterations)
        // Comfortable margin: stay under a quarter of the frame's wall-clock.
        XCTAssertLessThan(perCall, frameDuration * 0.25,
            "process() took \(perCall * 1000) ms per \(frameDuration * 1000) ms frame")
    }
}
