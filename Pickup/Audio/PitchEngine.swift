//
//  PitchEngine.swift
//  Thin Swift wrapper around the portable C++ pitch-detection core.
//

import Foundation

final class PitchEngine {
    struct Estimate {
        let frequency: Float
        let clarity: Float
    }

    private var detector: OpaquePointer?

    init(sampleRate: Double) {
        detector = pk_pitch_detector_create(sampleRate)
        if let detector { pk_pitch_detector_set_gate(detector, AudioSettings.inputGateRMS) }
    }

    deinit {
        if let detector { pk_pitch_detector_destroy(detector) }
    }

    /// Returns an estimate, or nil when the core reports no confident pitch.
    func process(_ samples: [Float]) -> Estimate? {
        guard let detector else { return nil }
        var clarity: Float = 0
        let frequency = samples.withUnsafeBufferPointer { buffer in
            pk_pitch_detector_process(detector, buffer.baseAddress, buffer.count, &clarity)
        }
        guard frequency > 0 else { return nil }
        return Estimate(frequency: frequency, clarity: clarity)
    }
}
