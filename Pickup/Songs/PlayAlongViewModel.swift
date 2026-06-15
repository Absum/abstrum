//
//  PlayAlongViewModel.swift
//  Tempo-driven play-along: an audible click advances the bars while the mic
//  scores which bars you played correctly.
//

import AVFoundation
import Observation
import SwiftUI

@Observable
final class PlayAlongViewModel {
    let song: Song
    var barIndex = 0
    var beatInBar = 0
    var isPlaying = false
    var finished = false
    var currentBarHit = false
    var hits = 0
    var permissionDenied = false
    var isPreviewing = false

    private let audio = AudioEngine()
    private let preview = TonePlayer()
    private var chordEngine: ChordEngine?
    private var beatTimer: Timer?
    private var previewTimer: Timer?
    private var previewBar = 0
    private let threshold = AudioSettings.shared.chordMatchThreshold
    private var holdFrames = 0
    private let holdRequired = 2

    init(song: Song) {
        self.song = song
        audio.detectsPitch = false
        audio.enableClickPlayback = true
        audio.onSamples = { [weak self] samples, sr in self?.process(samples, sr) }
        preview.keepAlive = true
    }

    var bars: [Chord] { song.bars }
    var current: Chord { bars[min(barIndex, bars.count - 1)] }
    var nextChord: Chord? { barIndex + 1 < bars.count ? bars[barIndex + 1] : nil }
    /// Fills to full on the last bar so it matches the "BAR x / N" counter;
    /// empty when idle.
    var progress: Double {
        guard !bars.isEmpty else { return 0 }
        if finished { return 1 }
        guard isPlaying || isPreviewing else { return 0 }
        return Double(barIndex + 1) / Double(bars.count)
    }
    var total: Int { bars.count }

    func toggle() { isPlaying ? stop() : start() }

    // MARK: - Preview (listen first; playback only, no mic)

    func togglePreview() { isPreviewing ? stopPreview() : startPreview() }

    private func startPreview() {
        guard !isPlaying, !bars.isEmpty else { return }
        finished = false
        isPreviewing = true
        previewBar = 0
        beatInBar = 0
        preview.warmUp()
        playPreviewBar()
    }

    private func playPreviewBar() {
        guard isPreviewing, previewBar < bars.count else { stopPreview(); return }
        barIndex = previewBar
        preview.playChord(bars[previewBar].frequencies)
        let barDuration = Double(song.beatsPerBar) * 60.0 / Double(song.bpm)
        previewTimer = Timer.scheduledTimer(withTimeInterval: barDuration, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.previewBar += 1
            self.playPreviewBar()
        }
    }

    private func stopPreview() {
        previewTimer?.invalidate(); previewTimer = nil
        preview.stop()
        isPreviewing = false
        barIndex = 0
        beatInBar = 0
    }

    func restart() {
        finished = false
        start()
    }

    private func start() {
        if isPreviewing { stopPreview() }
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else { self.permissionDenied = true; return }
                do { try self.audio.start() } catch { return }
                self.barIndex = 0; self.beatInBar = 0; self.hits = 0
                self.currentBarHit = false; self.holdFrames = 0; self.finished = false
                self.isPlaying = true
                self.startBeatTimer()
            }
        }
    }

    private func stop() {
        beatTimer?.invalidate(); beatTimer = nil
        audio.stop()
        isPlaying = false
    }

    private func startBeatTimer() {
        let interval = 60.0 / Double(song.bpm)
        beatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    private func tick() {
        audio.playClick(accent: beatInBar == 0)
        beatInBar += 1
        if beatInBar >= song.beatsPerBar {
            advanceBar()
        }
    }

    private func advanceBar() {
        if currentBarHit { hits += 1 }
        beatInBar = 0
        currentBarHit = false
        holdFrames = 0
        barIndex += 1
        if barIndex >= bars.count { finish() }
    }

    private func finish() {
        beatTimer?.invalidate(); beatTimer = nil
        audio.stop()
        isPlaying = false
        finished = true
        barIndex = max(0, bars.count - 1)
    }

    private func process(_ samples: [Float], _ sampleRate: Double) {
        if chordEngine == nil { chordEngine = ChordEngine(sampleRate: sampleRate) }
        let chroma = chordEngine?.chroma(samples)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isPlaying, !self.currentBarHit, let chroma else { return }
            let score = ChordMatcher.score(chroma: chroma, pitchClasses: self.current.pitchClasses)
            if score >= self.threshold {
                self.holdFrames += 1
                if self.holdFrames >= self.holdRequired { self.currentBarHit = true }
            } else {
                self.holdFrames = 0
            }
        }
    }
}
