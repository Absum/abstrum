//
//  ToneSynth.swift
//  Plucked-string synthesis (Karplus–Strong) for "hear it" examples.
//  Pure sample generation — no audio framework — so it's easy to test.
//

import Foundation

enum ToneSynth {
    /// Karplus–Strong plucked-string samples for one note.
    static func pluck(frequency: Double, sampleRate: Double, length: Int, decay: Float = 0.996) -> [Float] {
        guard frequency > 0, length > 0, sampleRate > 0 else { return [] }
        let n = max(2, Int((sampleRate / frequency).rounded()))
        var ring = (0..<n).map { _ in Float.random(in: -1...1) }
        var out = [Float](repeating: 0, count: length)
        var index = 0
        for i in 0..<length {
            out[i] = ring[index]
            let next = (index + 1) % n
            ring[index] = decay * 0.5 * (ring[index] + ring[next])
            index = next
        }
        return out
    }

    /// Mix several plucked notes with an optional strum stagger; returns
    /// normalized mono samples with a short fade-out.
    static func strum(frequencies: [Double],
                      sampleRate: Double,
                      duration: Double = 1.8,
                      strumDelay: Double = 0.0) -> [Float] {
        let total = max(1, Int(sampleRate * duration))
        var mix = [Float](repeating: 0, count: total)
        for (i, frequency) in frequencies.enumerated() {
            let onset = min(total - 1, Int(Double(i) * strumDelay * sampleRate))
            let note = pluck(frequency: frequency, sampleRate: sampleRate, length: total - onset)
            for j in 0..<note.count { mix[onset + j] += note[j] }
        }

        var peak: Float = 0
        for value in mix { peak = max(peak, abs(value)) }
        let scale = peak > 0 ? 0.85 / peak : 1
        let fade = min(total / 20, 1500)
        for i in 0..<total {
            var sample = mix[i] * scale
            if fade > 0, i > total - fade { sample *= Float(total - i) / Float(fade) }
            mix[i] = sample
        }
        return mix
    }
}
