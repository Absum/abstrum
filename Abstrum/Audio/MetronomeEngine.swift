//
//  MetronomeEngine.swift
//  Click playback via AVAudioEngine + a player node, driven by a high-priority
//  timer. Accent on the downbeat. Click buffers are synthesized once.
//

import AVFoundation

final class MetronomeEngine {
    /// Called on the main queue at each beat with the beat index within the bar.
    var onBeat: ((Int) -> Void)?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var accentClick: AVAudioPCMBuffer?
    private var normalClick: AVAudioPCMBuffer?

    private let queue = DispatchQueue(label: "fi.absum.abstrum.metronome", qos: .userInteractive)
    private var timer: DispatchSourceTimer?

    private(set) var isRunning = false
    private var beatsPerMeasure = 4
    private var currentBeat = 0

    func start(bpm: Int, beatsPerMeasure: Int) {
        stop()
        self.beatsPerMeasure = max(1, beatsPerMeasure)
        currentBeat = 0

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)!
        accentClick = Self.makeClick(frequency: 1760, format: format)
        normalClick = Self.makeClick(frequency: 1200, format: format)

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: format)
        do {
            try engine.start()
        } catch {
            print("Abstrum: metronome engine failed — \(error)")
            return
        }
        player.play()

        isRunning = true
        scheduleTimer(bpm: bpm, immediate: true)
    }

    func updateTempo(bpm: Int) {
        guard isRunning else { return }
        scheduleTimer(bpm: bpm, immediate: false)
    }

    func stop() {
        timer?.cancel()
        timer = nil
        if engine.isRunning {
            player.stop()
            engine.stop()
        }
        if isRunning { try? AVAudioSession.sharedInstance().setActive(false) }
        isRunning = false
    }

    private func scheduleTimer(bpm: Int, immediate: Bool) {
        timer?.cancel()
        let interval = 60.0 / Double(min(300, max(20, bpm)))
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: immediate ? .now() : .now() + interval,
                   repeating: interval, leeway: .milliseconds(1))
        t.setEventHandler { [weak self] in self?.tick() }
        timer = t
        t.resume()
    }

    private func tick() {
        let beat = currentBeat
        if let buffer = (beat == 0 ? accentClick : normalClick) {
            player.scheduleBuffer(buffer, at: nil, options: [], completionHandler: nil)
        }
        currentBeat = (beat + 1) % beatsPerMeasure
        DispatchQueue.main.async { [weak self] in self?.onBeat?(beat) }
    }

    /// A short enveloped sine "tick".
    private static func makeClick(frequency: Double, format: AVAudioFormat) -> AVAudioPCMBuffer {
        let sampleRate = format.sampleRate
        let duration = 0.05
        let frames = AVAudioFrameCount(sampleRate * duration)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames)!
        buffer.frameLength = frames
        let samples = buffer.floatChannelData![0]
        for i in 0..<Int(frames) {
            let t = Double(i) / sampleRate
            let envelope = exp(-t * 35.0)
            samples[i] = Float(sin(2.0 * .pi * frequency * t) * envelope * 0.5)
        }
        return buffer
    }
}
