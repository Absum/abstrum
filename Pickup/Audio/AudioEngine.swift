//
//  AudioEngine.swift
//  Low-latency mic capture via AVAudioEngine, feeding the pitch core.
//
//  The latency-critical path (capture + DSP) stays native; only the throttled
//  result is handed to the UI on the main queue.
//

import AVFoundation

final class AudioEngine {
    struct Result {
        let frequency: Double
        let clarity: Double
    }

    /// Called on the main queue. nil means "no confident pitch right now".
    var onResult: ((Result?) -> Void)?
    /// Raw mono samples + sample rate, on the audio thread (for chord chroma).
    var onSamples: (([Float], Double) -> Void)?
    /// Skip monophonic pitch detection (e.g. when only chroma is needed).
    var detectsPitch = true
    /// Run full-duplex (.playAndRecord) so a metronome click can play while the
    /// mic is capturing — used by chord-change practice.
    var enableClickPlayback = false

    private let engine = AVAudioEngine()
    private var pitch: PitchEngine?
    private var currentSampleRate: Double = 44_100
    private let bufferSize: AVAudioFrameCount = 4096

    private let clickPlayer = AVAudioPlayerNode()
    private var clickAttached = false
    private var accentClick: AVAudioPCMBuffer?
    private var normalClick: AVAudioPCMBuffer?

    var isRunning: Bool { engine.isRunning }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        if enableClickPlayback {
            // .measurement keeps AGC/echo-cancellation off so pitch detection stays
            // accurate while a click plays; chroma-only callers can use .default.
            let mode: AVAudioSession.Mode = detectsPitch ? .measurement : .default
            try session.setCategory(.playAndRecord, mode: mode, options: [.defaultToSpeaker])
        } else {
            // .measurement disables AGC / echo cancellation that would distort pitch.
            try session.setCategory(.record, mode: .measurement, options: [])
        }
        try session.setPreferredIOBufferDuration(0.01)
        try session.setActive(true)

        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)
        currentSampleRate = format.sampleRate
        pitch = PitchEngine(sampleRate: format.sampleRate)

        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: bufferSize, format: format) { [weak self] buffer, _ in
            self?.process(buffer)
        }

        if enableClickPlayback {
            let clickFormat = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
            if !clickAttached { engine.attach(clickPlayer); clickAttached = true }
            engine.connect(clickPlayer, to: engine.mainMixerNode, format: clickFormat)
            accentClick = Self.makeClick(frequency: 1760, format: clickFormat)
            normalClick = Self.makeClick(frequency: 1200, format: clickFormat)
        }

        engine.prepare()
        try engine.start()
        if enableClickPlayback { clickPlayer.play() }
    }

    /// Play a metronome click (only when enableClickPlayback was set before start).
    func playClick(accent: Bool) {
        guard enableClickPlayback, engine.isRunning else { return }
        if let buffer = accent ? accentClick : normalClick {
            clickPlayer.scheduleBuffer(buffer, at: nil, options: [.interrupts], completionHandler: nil)
        }
    }

    private static func makeClick(frequency: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let frames = AVAudioFrameCount(sampleRate * 0.05)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            samples[i] = Float(sin(2.0 * .pi * frequency * t) * exp(-t * 35.0) * 0.5)
        }
        return buffer
    }

    func stop() {
        guard engine.isRunning else { return }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        try? AVAudioSession.sharedInstance().setActive(false)
    }

    private func process(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return }

        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: count))

        onSamples?(samples, currentSampleRate)
        guard detectsPitch else { return }

        let estimate = pitch?.process(samples)
        let result = estimate.map { Result(frequency: Double($0.frequency),
                                           clarity: Double($0.clarity)) }

        DispatchQueue.main.async { [weak self] in
            self?.onResult?(result)
        }
    }
}
