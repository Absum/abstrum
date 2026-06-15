//
//  LessonViewModel.swift
//  Drives a lesson: listens, matches the played note to the current target,
//  gives per-note feedback, and advances when a note is held correctly.
//

import AVFoundation
import Observation
import SwiftUI

@Observable
final class LessonViewModel {
    enum Feedback { case waiting, close, correct }

    let lesson: Lesson
    var currentIndex: Int
    var completedSteps: Set<Int> = []
    var isComplete = false
    var feedback: Feedback = .waiting
    var detectedLabel: String?
    var permissionDenied = false

    // Strum-step state (timed metronome exercise).
    var strumBeat = 0          // current beat (negative during count-in)
    var strumHits = 0
    var strumRunning = false
    var strumFinished = false

    private let audio = AudioEngine()
    private let player = TonePlayer()
    private let store: ProgressStore
    private var chordEngine: ChordEngine?
    private var clock: Timer?
    private var lastTick: Date?
    private var strumTime = 0.0
    private var hitBeats: Set<Int> = []
    private let countInBeats = 4
    private var holdFrames = 0
    private let holdRequired = 4        // ~0.3–0.4s of the right note before it counts
    private let chordHoldRequired = 3   // strums register a touch faster
    private let chordThreshold = AudioSettings.shared.chordMatchThreshold

    init(lesson: Lesson, store: ProgressStore = .shared) {
        self.lesson = lesson
        self.store = store
        var startIndex = 0
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["PICKUP_LESSON_STEP"],
           let i = Int(raw), lesson.steps.indices.contains(i) {
            startIndex = i
        }
        #endif
        currentIndex = startIndex
        audio.onResult = { [weak self] in self?.handle($0) }
        audio.onSamples = { [weak self] samples, rate in self?.handleChroma(samples, sampleRate: rate) }
        audio.onOnset = { [weak self] _ in self?.registerStrum() }
        if lesson.steps.contains(where: { $0.strum != nil }) { audio.enableClickPlayback = true }
    }

    /// Which beats the player has landed (for the beat indicator).
    var strumHitBeats: Set<Int> { hitBeats }

    /// Pass threshold for a strum step: land ~60% of the beats.
    var strumTarget: Int {
        guard let pattern = currentStep.strum else { return 0 }
        return max(1, Int((Double(pattern.beats) * 0.6).rounded()))
    }

    var currentStep: LessonStep { lesson.steps[min(currentIndex, lesson.steps.count - 1)] }
    var progress: Double { Double(completedSteps.count) / Double(lesson.steps.count) }

    func startListening() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else { self.permissionDenied = true; return }
                try? self.audio.start()
            }
        }
    }

    func stopListening() {
        clock?.invalidate(); clock = nil
        strumRunning = false
        audio.stop()
    }

    // MARK: - Strum steps (timed metronome exercise)

    /// Start the metronome + count-in for the current strum step.
    func beginStrum() {
        guard let pattern = currentStep.strum, !strumRunning else { return }
        hitBeats = []; strumHits = 0; strumFinished = false
        let beatInterval = 60.0 / Double(pattern.bpm)
        strumTime = -Double(countInBeats) * beatInterval   // count-in before beat 0
        strumBeat = Int(floor(strumTime / beatInterval))
        lastTick = nil
        strumRunning = true
        clock?.invalidate()
        clock = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            self?.strumTick()
        }
    }

    func retryStrum() { strumFinished = false; beginStrum() }

    private func strumTick() {
        guard let pattern = currentStep.strum else { return }
        let now = Date()
        guard let last = lastTick else { lastTick = now; return }
        strumTime += now.timeIntervalSince(last); lastTick = now

        let beatInterval = 60.0 / Double(pattern.bpm)
        let beat = Int(floor(strumTime / beatInterval))
        if beat != strumBeat {
            strumBeat = beat
            if beat >= -countInBeats && beat < pattern.beats {
                audio.playClick(accent: ((beat % 4) + 4) % 4 == 0)
            }
        }
        if strumTime > Double(pattern.beats) * beatInterval + 0.4 { finishStrum() }
    }

    /// A detected onset: credit the nearest beat if it's close enough.
    private func registerStrum() {
        guard strumRunning, let pattern = currentStep.strum, strumTime >= -0.15 else { return }
        let beatInterval = 60.0 / Double(pattern.bpm)
        let nearest = Int((strumTime / beatInterval).rounded())
        guard nearest >= 0, nearest < pattern.beats, !hitBeats.contains(nearest) else { return }
        if abs(strumTime - Double(nearest) * beatInterval) <= 0.25 {
            hitBeats.insert(nearest)
            strumHits += 1
        }
    }

    private func finishStrum() {
        clock?.invalidate(); clock = nil
        strumRunning = false
        strumFinished = true
        if strumHits >= strumTarget {
            feedback = .correct
            completeStep()
        }
    }

    /// Play the target note as an example; pause the mic during playback.
    func playExample() {
        audio.stop()
        player.onFinished = { [weak self] in self?.startListening() }
        if let chord = currentStep.chord {
            player.playChord(chord.frequencies)
        } else {
            player.playNote(currentStep.frequency)
        }
    }

    func restart() {
        clock?.invalidate(); clock = nil
        completedSteps.removeAll()
        currentIndex = 0
        isComplete = false
        feedback = .waiting
        detectedLabel = nil
        holdFrames = 0
        strumRunning = false; strumFinished = false; strumHits = 0; strumBeat = 0; hitBeats = []
    }

    /// Score a chord step from the chroma (runs the FFT off the main thread).
    private func handleChroma(_ samples: [Float], sampleRate: Double) {
        guard !isComplete, currentStep.strum == nil, let chord = currentStep.chord else { return }
        if chordEngine == nil { chordEngine = ChordEngine(sampleRate: sampleRate) }
        let value = chordEngine?.chroma(samples)
            .map { ChordMatcher.score(chroma: $0, pitchClasses: chord.pitchClasses) } ?? 0
        DispatchQueue.main.async { [weak self] in
            guard let self, !self.isComplete, self.currentStep.chord != nil else { return }
            self.detectedLabel = "\(Int(value * 100))% match"
            if value >= self.chordThreshold {
                self.feedback = .correct
                self.holdFrames += 1
                if self.holdFrames >= self.chordHoldRequired { self.completeStep() }
            } else if value >= self.chordThreshold - 0.12 {
                self.feedback = .close; self.holdFrames = 0
            } else {
                self.feedback = .waiting; self.holdFrames = 0
            }
        }
    }

    private func handle(_ result: AudioEngine.Result?) {
        guard !isComplete, currentStep.chord == nil else { return }   // chord steps use chroma
        guard let result, let reading = NoteMath.reading(forFrequency: result.frequency) else {
            detectedLabel = nil; feedback = .waiting; holdFrames = 0; return
        }
        detectedLabel = reading.displayName

        switch LessonLibrary.evaluate(frequency: result.frequency, target: currentStep.frequency) {
        case .correct:
            feedback = .correct
            holdFrames += 1
            if holdFrames >= holdRequired { completeStep() }
        case .close:
            feedback = .close; holdFrames = 0
        case .off:
            feedback = .waiting; holdFrames = 0
        }
    }

    private func completeStep() {
        completedSteps.insert(currentStep.id)
        holdFrames = 0
        feedback = .waiting
        detectedLabel = nil
        strumFinished = false; strumBeat = 0; strumHits = 0; hitBeats = []
        if currentIndex + 1 < lesson.steps.count {
            currentIndex += 1
        } else {
            isComplete = true
            store.markCompleted(lesson.id)
            audio.stop()
        }
    }
}
