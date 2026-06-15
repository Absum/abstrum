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

    private let audio = AudioEngine()
    private let player = TonePlayer()
    private let store: ProgressStore
    private var chordEngine: ChordEngine?
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

    func stopListening() { audio.stop() }

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
        completedSteps.removeAll()
        currentIndex = 0
        isComplete = false
        feedback = .waiting
        detectedLabel = nil
        holdFrames = 0
    }

    /// Score a chord step from the chroma (runs the FFT off the main thread).
    private func handleChroma(_ samples: [Float], sampleRate: Double) {
        guard !isComplete, let chord = currentStep.chord else { return }
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
        if currentIndex + 1 < lesson.steps.count {
            currentIndex += 1
        } else {
            isComplete = true
            store.markCompleted(lesson.id)
            audio.stop()
        }
    }
}
