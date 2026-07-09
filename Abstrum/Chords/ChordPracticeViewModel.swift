//
//  ChordPracticeViewModel.swift
//  Listens for a strummed chord and verifies it via chroma template matching.
//

import AVFoundation
import Observation
import SwiftUI

@Observable
final class ChordPracticeViewModel {
    private(set) var chord: Chord
    var score: Double = 0        // live match 0…1
    var matched = false
    var listening = false
    var permissionDenied = false

    var isPlayingExample = false

    private let audio = AudioEngine()
    private let player = TonePlayer()
    private var chordEngine: ChordEngine?
    private var holdFrames = 0
    // Threshold + hold read live from AudioSettings so the dev tuning panel applies.

    init(chord: Chord) {
        self.chord = chord
        audio.detectsPitch = false
        audio.onSamples = { [weak self] samples, sampleRate in
            self?.process(samples, sampleRate: sampleRate)
        }
    }

    func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else { self.permissionDenied = true; return }
                do { try self.audio.start(); self.listening = true }
                catch { print("Abstrum: chord audio start failed — \(error)") }
            }
        }
    }

    func stop() {
        audio.stop()
        listening = false
    }

    func reset() {
        matched = false
        holdFrames = 0
        score = 0
    }

    /// Switch to another voicing of the same chord (variant picker). Match
    /// state resets; detection templates are identical across variants.
    func select(_ variant: Chord) {
        chord = variant
        chordEngine?.reset()
        reset()
    }

    /// Play the chord as an example; pause the mic so it isn't self-detected.
    func playExample() {
        guard !isPlayingExample else { return }
        isPlayingExample = true
        audio.stop()
        player.onFinished = { [weak self] in
            guard let self else { return }
            self.isPlayingExample = false
            if self.listening { try? self.resumeListening() }
        }
        player.playChord(chord.frequencies)
    }

    private func resumeListening() throws {
        // listening flag is already true; just restart capture.
        let engine = audio
        try engine.start()
    }

    // Runs on the audio thread; computes chroma off the main thread, then
    // publishes the result on main.
    private func process(_ samples: [Float], sampleRate: Double) {
        if chordEngine == nil { chordEngine = ChordEngine(sampleRate: sampleRate) }
        let value: Double
        if let chroma = chordEngine?.chroma(samples) {
            value = ChordMatcher.score(chroma: chroma, pitchClasses: chord.pitchClasses)
        } else {
            value = 0
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.score = value
            if value >= AudioSettings.shared.chordMatchThreshold {
                self.holdFrames += 1
                if self.holdFrames >= AudioSettings.shared.chordHoldFrames {
                    if !self.matched { ProgressStore.shared.awardXP(10) }
                    self.matched = true
                }
            } else {
                self.holdFrames = 0
            }
        }
    }
}
