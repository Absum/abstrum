//
//  TonePlayer.swift
//  Plays synthesized note/chord examples through the speaker.
//

import AVFoundation

final class TonePlayer {
    /// Called on the main queue when playback finishes (engine already stopped).
    var onFinished: (() -> Void)?
    /// Keep the engine running between strums (for a sequence like a song preview).
    var keepAlive = false

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private let sampleRate = 44_100.0

    init() {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
    }

    func playNote(_ frequency: Double) { play([frequency], strumDelay: 0) }
    func playChord(_ frequencies: [Double]) { play(frequencies, strumDelay: 0.028) }

    /// Start the audio session + engine ahead of time so the first note doesn't
    /// glitch while the engine spins up. Call during a lead-in.
    func warmUp() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
        if !engine.isRunning { try? engine.start() }
        if !player.isPlaying { player.play() }
    }

    func stop() {
        player.stop()
        if engine.isRunning { engine.stop() }
    }

    private func play(_ frequencies: [Double], strumDelay: Double) {
        guard !frequencies.isEmpty else { return }
        let samples = ToneSynth.strum(frequencies: frequencies, sampleRate: sampleRate, strumDelay: strumDelay)
        guard let buffer = makeBuffer(samples) else { return }

        // Cold start only — once running we just schedule buffers, so a sequence
        // (song preview) doesn't churn the session or reset the player per note.
        if !engine.isRunning {
            let session = AVAudioSession.sharedInstance()
            try? session.setCategory(.playback, mode: .default, options: [])
            try? session.setActive(true)
            try? engine.start()
        }

        // Only a one-shot (non-keepAlive) stops the engine when its note finishes.
        let completion: AVAudioNodeCompletionHandler? = keepAlive ? nil : { [weak self] in
            DispatchQueue.main.async {
                self?.stop()
                self?.onFinished?()
            }
        }
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: completion)
        if !player.isPlaying { player.play() }
    }

    private func makeBuffer(_ samples: [Float]) -> AVAudioPCMBuffer? {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format,
                                            frameCapacity: AVAudioFrameCount(samples.count)) else { return nil }
        buffer.frameLength = AVAudioFrameCount(samples.count)
        let channel = buffer.floatChannelData![0]
        for i in 0..<samples.count { channel[i] = samples[i] }
        return buffer
    }
}
