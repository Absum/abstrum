//
//  MetronomeEngine.swift
//  Sample-accurate metronome: clicks are scheduled ahead at exact sample
//  positions in the player's timeline (a top-up timer only keeps the queue
//  filled), so audible timing doesn't inherit timer jitter. The UI beat pulse
//  fires from each click's data-played-back completion. Click buffers come
//  from the shared ClickSynth.
//

import AVFoundation

final class MetronomeEngine {
    /// Called on the main queue as each beat becomes audible, with the beat
    /// index within the bar.
    var onBeat: ((Int) -> Void)?

    private let engine = AVAudioEngine()
    private let player = AVAudioPlayerNode()
    private var accentClick: AVAudioPCMBuffer?
    private var normalClick: AVAudioPCMBuffer?

    private let queue = DispatchQueue(label: "fi.absum.abstrum.metronome", qos: .userInteractive)
    private var topUpTimer: DispatchSourceTimer?

    private(set) var isRunning = false
    private var beatsPerMeasure = 4

    // Scheduling state — touched only on `queue`.
    private let sampleRate = 44_100.0
    private let lookAheadSeconds = 0.8       // how far ahead clicks stay queued
    private var framesPerBeat = 0.0
    private var nextBeatFrame = 0.0          // player-timeline sample position
    private var beatIndex = 0
    private var epoch = 0                    // invalidates stale completions

    func start(bpm: Int, beatsPerMeasure: Int) {
        stop()
        self.beatsPerMeasure = max(1, beatsPerMeasure)

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [])
        try? session.setActive(true)

        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        accentClick = ClickSynth.makeClick(frequency: 1760, format: format, softAttack: false)
        normalClick = ClickSynth.makeClick(frequency: 1200, format: format, softAttack: false)

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
        queue.sync {
            beatIndex = 0
            rearm(bpm: bpm, startDelay: 0.06)
        }
        startTopUpTimer()
    }

    func updateTempo(bpm: Int) {
        guard isRunning else { return }
        queue.sync {
            epoch += 1                 // orphan completions from the old grid
            player.stop()              // clears everything scheduled
            player.play()
            rearm(bpm: bpm, startDelay: 0.05)   // keep beatIndex → bar phase survives
        }
    }

    func stop() {
        topUpTimer?.cancel()
        topUpTimer = nil
        queue.sync { epoch += 1 }
        if engine.isRunning {
            player.stop()
            engine.stop()
        }
        if isRunning { try? AVAudioSession.sharedInstance().setActive(false) }
        isRunning = false
    }

    // MARK: - Sample-accurate scheduling (on `queue`)

    /// Anchor the beat grid `startDelay` ahead of the player's current sample
    /// position and fill the look-ahead. Must run on `queue`.
    private func rearm(bpm: Int, startDelay: Double) {
        let clamped = min(300, max(20, bpm))
        framesPerBeat = 60.0 / Double(clamped) * sampleRate
        nextBeatFrame = (playerNowFrames() ?? 0) + startDelay * sampleRate
        topUp()
    }

    private func playerNowFrames() -> Double? {
        guard let nodeTime = player.lastRenderTime,
              let playerTime = player.playerTime(forNodeTime: nodeTime) else { return nil }
        return Double(playerTime.sampleTime)
    }

    /// Keep clicks scheduled out to the look-ahead horizon. Must run on `queue`.
    private func topUp() {
        guard isRunning, let now = playerNowFrames() else { return }
        let horizon = now + lookAheadSeconds * sampleRate
        let currentEpoch = epoch
        while nextBeatFrame < horizon {
            let beat = beatIndex % beatsPerMeasure
            guard let buffer = (beat == 0 ? accentClick : normalClick) else { return }
            let when = AVAudioTime(sampleTime: AVAudioFramePosition(nextBeatFrame.rounded()),
                                   atRate: sampleRate)
            player.scheduleBuffer(buffer, at: when, options: [],
                                  completionCallbackType: .dataPlayedBack) { [weak self] _ in
                guard let self else { return }
                self.queue.async {
                    guard self.epoch == currentEpoch else { return }   // stale grid
                    DispatchQueue.main.async { self.onBeat?(beat) }
                }
            }
            beatIndex += 1
            nextBeatFrame += framesPerBeat
        }
    }

    private func startTopUpTimer() {
        let t = DispatchSource.makeTimerSource(queue: queue)
        t.schedule(deadline: .now() + 0.2, repeating: 0.2, leeway: .milliseconds(20))
        t.setEventHandler { [weak self] in self?.topUp() }
        topUpTimer = t
        t.resume()
    }
}
