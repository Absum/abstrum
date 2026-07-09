//
//  ToneSynth.swift
//  Plucked-string synthesis (extended Karplus–Strong) for "hear it" examples:
//  pitch-seeded excitation, pick-position comb, and a small resonant "body".
//  All sound is original and generated in code — no audio assets, by decision.
//  Pure sample generation — no audio framework — so it's easy to test.
//

import Foundation

enum ToneSynth {
    /// Where along the string the "pick" strikes (fraction of string length).
    /// The comb this creates in the excitation is what makes an attack read
    /// as *picked* rather than plucked-rubber-band.
    private static let pickPosition = 0.13

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
        // Pick-position comb (Jaffe–Smith): striking the string at
        // `pickPosition` suppresses the harmonics with a node there.
        let pickOffset = max(1, Int((Double(n) * pickPosition).rounded()))
        if pickOffset < n {
            let combed = ring
            for i in 0..<n { ring[i] = combed[i] - combed[(i + pickOffset) % n] }
        }
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
    /// normalized mono samples with a short fade-out, coloured by the body.
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

        // A resonant "body" before normalization: the string alone sounds like
        // a wire; these resonances are the wood.
        applyBody(&mix, sampleRate: sampleRate)

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

    /// A rhythm prompt: short damped ticks at the given beat offsets.
    static func rhythm(beatOffsets: [Double], bpm: Int, sampleRate: Double) -> [Float] {
        guard !beatOffsets.isEmpty, bpm > 0, sampleRate > 0 else { return [] }
        let beat = 60.0 / Double(max(1, bpm))
        let total = max(1, Int(sampleRate * ((beatOffsets.max() ?? 0) * beat + 0.6)))
        var mix = [Float](repeating: 0, count: total)
        for offset in beatOffsets {
            let start = min(total - 1, Int(offset * beat * sampleRate))
            let length = min(total - start, Int(sampleRate * 0.14))
            let tick = pluck(frequency: 440, sampleRate: sampleRate, length: length, decay: 0.90)
            for j in 0..<tick.count { mix[start + j] += tick[j] }
        }
        var peak: Float = 0
        for value in mix { peak = max(peak, abs(value)) }
        let scale = peak > 0 ? 0.7 / peak : 1
        for i in 0..<total { mix[i] *= scale }
        return mix
    }

    // MARK: - Body resonance (pure code — no impulse-response asset)

    /// Two peaking filters approximating an acoustic guitar's main air and
    /// top-plate resonances. Applied in place, before normalization.
    private static func applyBody(_ samples: inout [Float], sampleRate: Double) {
        peakingFilter(&samples, sampleRate: sampleRate, frequency: 110, q: 1.1, gainDB: 5.0)
        peakingFilter(&samples, sampleRate: sampleRate, frequency: 225, q: 1.4, gainDB: 3.5)
    }

    /// RBJ-cookbook peaking EQ biquad, direct form I, in place.
    private static func peakingFilter(_ samples: inout [Float], sampleRate: Double,
                                      frequency: Double, q: Double, gainDB: Double) {
        let a = pow(10.0, gainDB / 40.0)
        let w0 = 2.0 * Double.pi * frequency / sampleRate
        let alpha = sin(w0) / (2.0 * q)
        let cosw0 = cos(w0)
        let a0 = 1.0 + alpha / a
        let b0 = Float((1.0 + alpha * a) / a0)
        let b1 = Float(-2.0 * cosw0 / a0)
        let b2 = Float((1.0 - alpha * a) / a0)
        let a1 = Float(-2.0 * cosw0 / a0)
        let a2 = Float((1.0 - alpha / a) / a0)
        var x1: Float = 0, x2: Float = 0, y1: Float = 0, y2: Float = 0
        for i in 0..<samples.count {
            let x = samples[i]
            let y = b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2 = x1; x1 = x
            y2 = y1; y1 = y
            samples[i] = y
        }
    }
}
