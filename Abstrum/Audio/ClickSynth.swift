//
//  ClickSynth.swift
//  The one metronome-click synthesizer, shared by the standalone metronome
//  engine and the in-lesson click playback (they previously kept two copies).
//

import AVFoundation

enum ClickSynth {
    /// A short enveloped sine "tick".
    ///
    /// `softAttack` adds a ~4 ms raised-cosine ramp: used when the click plays
    /// over the open mic, so the band-limited onset detector doesn't read the
    /// click's broadband edge as a pluck. The standalone metronome (mic off)
    /// keeps the hard edge for crispness.
    static func makeClick(frequency: Double, format: AVAudioFormat,
                          softAttack: Bool) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * 0.05)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            var envelope = exp(-t * 35.0)
            if softAttack {
                let attack = min(1.0, t / 0.004)
                envelope *= 0.5 * (1.0 - cos(.pi * attack))
            }
            samples[i] = Float(sin(2.0 * .pi * frequency * t) * envelope * 0.5)
        }
        return buffer
    }
}
