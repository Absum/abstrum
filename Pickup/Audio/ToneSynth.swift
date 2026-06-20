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
        // The 2-tap averaging loop filter adds ~half a sample of delay, so size
        // the delay line for (period − 0.5) to keep the note in tune rather than
        // consistently flat.
        let n = max(2, Int((sampleRate / frequency - 0.5).rounded()))

        // Deterministic excitation seeded by the pitch: every "hear it" of the
        // same note produces an identical burst, so the pitch/timbre doesn't
        // wobble between repeats (a random burst made short delay lines — high
        // notes — sound like they drifted each play).
        var state = UInt64(bitPattern: Int64((frequency * 1000).rounded())) ^ 0x9E3779B97F4A7C15
        func noise() -> Float {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Float(Int32(truncatingIfNeeded: state >> 32)) / Float(Int32.max)   // ≈ [-1, 1]
        }
        var ring = (0..<n).map { _ in noise() }
        // Low-pass the excitation burst so the attack isn't a harsh broadband click.
        let raw = ring
        for i in 0..<n { ring[i] = 0.5 * (raw[i] + raw[(i + 1) % n]) }
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
        let scale = peak > 0 ? 0.7 / peak : 1          // headroom — don't drive speakers to full scale
        let fadeOut = min(total / 20, 1500)
        let attack = min(total, Int(sampleRate * 0.006))   // ~6 ms fade-in kills the onset click
        for i in 0..<total {
            var sample = mix[i] * scale
            if attack > 0, i < attack { sample *= Float(i) / Float(attack) }
            if fadeOut > 0, i > total - fadeOut { sample *= Float(total - i) / Float(fadeOut) }
            mix[i] = sample
        }
        return mix
    }
}
