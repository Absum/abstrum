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
    private var holdFrames = 0
    private let holdRequired = 4   // ~0.3–0.4s of the right note before it counts

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
        player.playNote(currentStep.frequency)
    }

    func restart() {
        completedSteps.removeAll()
        currentIndex = 0
        isComplete = false
        feedback = .waiting
        detectedLabel = nil
        holdFrames = 0
    }

    private func handle(_ result: AudioEngine.Result?) {
        guard !isComplete else { return }
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
