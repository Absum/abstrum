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

    private let engine = AVAudioEngine()
    private var pitch: PitchEngine?
    private var currentSampleRate: Double = 44_100
    private let bufferSize: AVAudioFrameCount = 4096

    var isRunning: Bool { engine.isRunning }

    func start() throws {
        let session = AVAudioSession.sharedInstance()
        // .measurement disables AGC / echo cancellation that would distort pitch.
        try session.setCategory(.record, mode: .measurement, options: [])
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

        engine.prepare()
        try engine.start()
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
