//
//  TonePlayer.swift
//  Plays synthesized note/chord examples through the speaker.
//

import AVFoundation

final class TonePlayer {
    /// Called on the main queue when playback finishes (engine already stopped).
    var onFinished: (() -> Void)?

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

    func stop() {
        player.stop()
        if engine.isRunning { engine.stop() }
    }

    private func play(_ frequencies: [Double], strumDelay: Double) {
        guard !frequencies.isEmpty else { return }
        let samples = ToneSynth.strum(frequencies: frequencies, sampleRate: sampleRate, strumDelay: strumDelay)
        guard let buffer = makeBuffer(samples) else { return }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)
        if !engine.isRunning { try? engine.start() }

        player.stop()
        player.scheduleBuffer(buffer, at: nil, options: [.interrupts]) { [weak self] in
            DispatchQueue.main.async {
                self?.stop()
                self?.onFinished?()
            }
        }
        player.play()
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
