//
//  OnsetDetectorTests.swift
//  Exercises the C++ spectral-flux onset detector via its C ABI.
//

import XCTest

final class OnsetDetectorTests: XCTestCase {
    private let sr = 44_100.0

    /// Run a signal through the detector in engine-sized buffers; return the
    /// absolute onset frame indices it reports.
    private func detectOnsets(_ signal: [Float], sampleRate: Double) -> [Int64] {
        let det = pk_onset_detector_create(sampleRate)!
        defer { pk_onset_detector_destroy(det) }
        var onsets: [Int64] = []
        var out = [Int64](repeating: 0, count: 16)
        var i = 0
        while i < signal.count {
            let n = min(4096, signal.count - i)
            let slice = Array(signal[i..<(i + n)])
            let c = slice.withUnsafeBufferPointer { inp in
                out.withUnsafeMutableBufferPointer { o in
                    pk_onset_detector_process(det, inp.baseAddress, inp.count, o.baseAddress, Int32(o.count))
                }
            }
            for k in 0..<Int(c) { onsets.append(out[k]) }
            i += n
        }
        return onsets
    }

    private func silence(_ seconds: Double) -> [Float] {
        [Float](repeating: 0, count: Int(seconds * sr))
    }

    /// A sharply-plucked, decaying tone with an in-band fundamental.
    private func pluck(freq: Double, seconds: Double) -> [Float] {
        let n = Int(seconds * sr)
        return (0..<n).map { i in
            let t = Double(i) / sr
            return Float(sin(2 * .pi * freq * t) * exp(-t * 6.0))
        }
    }

    /// A soft-attack tone above the guitar band, like the metronome click.
    private func softTone(freq: Double, seconds: Double) -> [Float] {
        let n = Int(seconds * sr)
        return (0..<n).map { i in
            let t = Double(i) / sr
            let attack = min(1.0, t / 0.004)
            let env = 0.5 * (1 - cos(.pi * attack))
            return Float(sin(2 * .pi * freq * t) * exp(-t * 35.0) * env)
        }
    }

    func testDetectsGuitarPluck() {
        let lead = silence(0.3)
        let signal = lead + pluck(freq: 196, seconds: 0.6)   // G3
        let onsets = detectOnsets(signal, sampleRate: sr)

        XCTAssertFalse(onsets.isEmpty, "should detect the pluck")
        let start = Int64(lead.count)
        let first = onsets.min()!
        XCTAssertGreaterThan(first, start - 2048, "onset shouldn't precede the pluck")
        XCTAssertLessThan(first, start + 4096, "onset should land near the attack")
    }

    func testIgnoresSoftHighClick() {
        let signal = silence(0.3) + softTone(freq: 1500, seconds: 0.2) + silence(0.3)
        let onsets = detectOnsets(signal, sampleRate: sr)
        XCTAssertTrue(onsets.isEmpty, "a soft tone above the guitar band must not read as an onset")
    }

    func testSeparatesTwoPlucks() {
        let signal = silence(0.25) + pluck(freq: 110, seconds: 0.4)
                   + silence(0.05) + pluck(freq: 147, seconds: 0.4)
        let onsets = detectOnsets(signal, sampleRate: sr)
        XCTAssertGreaterThanOrEqual(onsets.count, 2, "two distinct plucks → at least two onsets")
    }

    func testFrameClockAdvances() {
        let det = pk_onset_detector_create(sr)!
        defer { pk_onset_detector_destroy(det) }
        let buf = [Float](repeating: 0, count: 1000)
        var out = [Int64](repeating: 0, count: 4)
        _ = buf.withUnsafeBufferPointer { inp in
            out.withUnsafeMutableBufferPointer { o in
                pk_onset_detector_process(det, inp.baseAddress, inp.count, o.baseAddress, 4)
            }
        }
        XCTAssertEqual(pk_onset_detector_frames(det), 1000)
    }
}
