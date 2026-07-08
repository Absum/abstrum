//
//  ChordEngine.swift
//  Swift wrapper around the C++ chroma (chord-feature) core.
//

import Foundation

final class ChordEngine {
    private var detector: OpaquePointer?

    init(sampleRate: Double) {
        detector = pk_chord_detector_create(sampleRate)
        if let detector { pk_chord_detector_set_gate(detector, AudioSettings.shared.inputGateRMS) }
    }

    deinit {
        if let detector { pk_chord_detector_destroy(detector) }
    }

    /// Forget buffered audio — call when the target chord changes so the old
    /// chord's tail doesn't blend into the new target's analysis window.
    func reset() {
        if let detector { pk_chord_detector_reset(detector) }
    }

    /// A normalized 12-bin chromagram, or nil when there isn't enough signal.
    func chroma(_ samples: [Float]) -> [Float]? {
        guard let detector else { return nil }
        // Re-push the gate so dev-panel changes apply live, like the other knobs.
        pk_chord_detector_set_gate(detector, AudioSettings.shared.inputGateRMS)
        var out = [Float](repeating: 0, count: 12)
        let ok = samples.withUnsafeBufferPointer { input in
            out.withUnsafeMutableBufferPointer { output in
                pk_chord_detector_chroma(detector, input.baseAddress, input.count, output.baseAddress)
            }
        }
        return ok == 1 ? out : nil
    }
}
