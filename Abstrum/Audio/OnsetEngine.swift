//
//  OnsetEngine.swift
//  Swift wrapper around the C++ spectral-flux onset detector.
//

import Foundation

final class OnsetEngine {
    private var detector: OpaquePointer?
    private let sampleRate: Double

    init(sampleRate: Double) {
        self.sampleRate = sampleRate > 0 ? sampleRate : 44_100
        detector = pk_onset_detector_create(self.sampleRate)
        if let detector { pk_onset_detector_set_gate(detector, AudioSettings.shared.inputGateRMS) }
    }

    deinit {
        if let detector { pk_onset_detector_destroy(detector) }
    }

    /// Feed a buffer of mono samples; returns the time (seconds since this engine
    /// was created) of any note onsets detected within it.
    func process(_ samples: [Float]) -> [Double] {
        guard let detector, !samples.isEmpty else { return [] }
        // Re-push the gate so dev-panel changes apply live, like the other knobs.
        pk_onset_detector_set_gate(detector, AudioSettings.shared.inputGateRMS)
        var frames = [Int64](repeating: 0, count: 16)
        let n = samples.withUnsafeBufferPointer { input in
            frames.withUnsafeMutableBufferPointer { output in
                pk_onset_detector_process(detector, input.baseAddress, input.count,
                                          output.baseAddress, Int32(output.count))
            }
        }
        guard n > 0 else { return [] }
        return (0..<Int(n)).map { Double(frames[$0]) / sampleRate }
    }
}
