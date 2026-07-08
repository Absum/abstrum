//
//  ChordChangeViewModel.swift
//  Detection-driven chord-change drill: play the current chord cleanly to count
//  a change and advance to the next chord in the progression (loops).
//

import AVFoundation
import Observation
import SwiftUI

@Observable
final class ChordChangeViewModel {
    let progression: ChordProgression
    var index = 0
    var changes = 0
    var seconds = 0
    var justMatched = false
    var isRunning = false
    var pulse = false
    var permissionDenied = false

    let bpm = 70

    private let audio = AudioEngine()
    private var chordEngine: ChordEngine?
    private var holdFrames = 0
    private let holdRequired = 3
    private let threshold = AudioSettings.shared.chordMatchThreshold
    private var beatTimer: Timer?
    private var secondTimer: Timer?
    private var beat = 0

    init(progression: ChordProgression) {
        self.progression = progression
        audio.detectsPitch = false
        audio.enableClickPlayback = true
        audio.onSamples = { [weak self] samples, sr in self?.process(samples, sr) }
    }

    var chords: [Chord] { progression.chords }
    /// nil when the progression has no resolvable chords (bad data).
    var current: Chord? { chords.isEmpty ? nil : chords[index % chords.count] }
    var nextChord: Chord? { chords.isEmpty ? nil : chords[(index + 1) % chords.count] }

    func toggle() { isRunning ? stop() : start() }

    private func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else { self.permissionDenied = true; return }
                guard !self.chords.isEmpty else { return }   // bad progression data
                do { try self.audio.start() } catch { return }
                self.isRunning = true
                self.startTimers()
            }
        }
    }

    private func stop() {
        audio.stop()
        isRunning = false
        beatTimer?.invalidate(); beatTimer = nil
        secondTimer?.invalidate(); secondTimer = nil
    }

    func resetCounters() {
        index = 0; changes = 0; seconds = 0; holdFrames = 0
    }

    private func startTimers() {
        beat = 0
        let interval = 60.0 / Double(bpm)
        beatTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self else { return }
            self.audio.playClick(accent: self.beat % 4 == 0)
            self.pulse.toggle()
            self.beat += 1
        }
        secondTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.seconds += 1
        }
    }

    private func process(_ samples: [Float], _ sampleRate: Double) {
        if chordEngine == nil { chordEngine = ChordEngine(sampleRate: sampleRate) }
        let chroma = chordEngine?.chroma(samples)
        DispatchQueue.main.async { [weak self] in
            guard let self, self.isRunning, let current = self.current else { return }
            guard let chroma else { self.holdFrames = 0; return }
            let score = ChordMatcher.score(chroma: chroma, pitchClasses: current.pitchClasses)
            if score >= self.threshold {
                self.holdFrames += 1
                if self.holdFrames >= self.holdRequired { self.advance() }
            } else {
                self.holdFrames = 0
            }
        }
    }

    private func advance() {
        changes += 1
        index += 1
        holdFrames = 0
        justMatched = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) { [weak self] in
            self?.justMatched = false
        }
    }
}
