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
    /// Quality (0…1) of the just-finished run, for the completion screen.
    var lastRunScore: Double = 0

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
    private var stepMisses = 0          // times the current step's hold was dropped
    private var runQualitySum = 0.0     // accumulated per-step quality this run
    private var runStepCount = 0
    // Chord threshold/hold, note tolerance and timing window read live from
    // AudioSettings so the dev tuning panel applies without restarting.

    init(lesson: Lesson, store: ProgressStore = .shared) {
        self.lesson = lesson
        self.store = store
        var startIndex = 0
        #if DEBUG
        if let raw = ProcessInfo.processInfo.environment["ABSTRUM_LESSON_STEP"],
           let i = Int(raw), lesson.steps.indices.contains(i) {
            startIndex = i
        }
        #endif
        currentIndex = startIndex
        audio.onResult = { [weak self] in self?.handle($0) }
        audio.onSamples = { [weak self] samples, rate in self?.handleChroma(samples, sampleRate: rate) }
        audio.onOnset = { [weak self] _ in self?.registerStrum() }
        // Full-duplex for every lesson (not just strum steps): "hear it"
        // examples then play over the open mic — detection is paused for the
        // duration instead of tearing the capture engine down and back up.
        audio.enableClickPlayback = true
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

    /// Adaptive practice tempo for the current strum step: the lesson's target
    /// BPM scaled by the skill's accuracy-earned factor (accuracy before speed).
    var currentBpm: Int {
        guard let pattern = currentStep.strum else { return 0 }
        return AdaptiveTempo.bpm(target: pattern.bpm, factor: store.tempoFactor(of: lesson.id))
    }
    /// The "graduation" tempo this exercise is ramping toward.
    var targetBpm: Int { currentStep.strum?.bpm ?? 0 }
    /// Whether the skill has reached its target tempo.
    var isAtTargetTempo: Bool { AdaptiveTempo.isAtTarget(store.tempoFactor(of: lesson.id)) }

    /// Accumulated mastery of this lesson (0…1) and whether it's crossed the bar.
    var mastery: Double { store.mastery(of: lesson.id) }
    var isMastered: Bool { mastery >= ProgressStore.masteryThreshold }

    /// How much hand-holding to show: fades as the lesson is mastered.
    var scaffold: ScaffoldLevel { Scaffold.level(forMastery: mastery) }

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
        audio.suspended = false
        player.stop()
        audio.stop()
    }

    // MARK: - Strum steps (timed metronome exercise)

    /// Start the metronome + count-in for the current strum step.
    func beginStrum() {
        guard currentStep.strum != nil, !strumRunning else { return }
        hitBeats = []; strumHits = 0; strumFinished = false
        let beatInterval = 60.0 / Double(currentBpm)
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

        let beatInterval = 60.0 / Double(currentBpm)
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
        let beatInterval = 60.0 / Double(currentBpm)
        let nearest = Int((strumTime / beatInterval).rounded())
        guard nearest >= 0, nearest < pattern.beats, !hitBeats.contains(nearest) else { return }
        if abs(strumTime - Double(nearest) * beatInterval) <= AudioSettings.shared.timingWindow {
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

    /// Play the target once for audiation (sound-before-symbol), without opening
    /// the mic — used by the pre-play "hear it first" primer.
    func audiate() {
        player.onFinished = nil
        if let chord = currentStep.chord {
            player.playChord(chord.frequencies)
        } else {
            player.playNote(currentStep.frequency)
        }
    }

    /// Play the target note as an example. If the mic is capturing, detection
    /// pauses (so the example isn't scored) and resumes the instant it ends —
    /// the capture engine and audio session stay up throughout.
    func playExample() {
        if audio.isRunning {
            audio.suspended = true
            holdFrames = 0
            feedback = .waiting
            player.onFinished = { [weak self] in self?.resumeDetection() }
        } else {
            player.onFinished = { [weak self] in self?.startListening() }
        }
        if let chord = currentStep.chord {
            player.playChord(chord.frequencies)
        } else {
            player.playNote(currentStep.frequency)
        }
    }

    private func resumeDetection() {
        chordEngine?.reset()   // drop pre-example audio from the analysis window
        audio.suspended = false
    }

    func restart() {
        clock?.invalidate(); clock = nil
        completedSteps.removeAll()
        currentIndex = 0
        isComplete = false
        feedback = .waiting
        detectedLabel = nil
        holdFrames = 0; stepMisses = 0; runQualitySum = 0; runStepCount = 0
        strumRunning = false; strumFinished = false; strumHits = 0; strumBeat = 0; hitBeats = []
        chordEngine?.reset()   // back to the first target — start from clean audio
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
            let threshold = AudioSettings.shared.chordMatchThreshold
            if value >= threshold {
                self.feedback = .correct
                self.holdFrames += 1
                if self.holdFrames >= AudioSettings.shared.chordHoldFrames { self.completeStep() }
            } else if value >= threshold - 0.12 {
                if self.holdFrames > 0 { self.stepMisses += 1 }
                self.feedback = .close; self.holdFrames = 0
            } else {
                if self.holdFrames > 0 { self.stepMisses += 1 }
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

        switch LessonLibrary.evaluate(frequency: result.frequency, target: currentStep.frequency,
                                      correctCents: AudioSettings.shared.noteToleranceCents) {
        case .correct:
            feedback = .correct
            holdFrames += 1
            if holdFrames >= holdRequired { completeStep() }
        case .close:
            if holdFrames > 0 { stepMisses += 1 }   // had it, lost it
            feedback = .close; holdFrames = 0
        case .off:
            if holdFrames > 0 { stepMisses += 1 }
            feedback = .waiting; holdFrames = 0
        }
    }

    private func completeStep() {
        // Score this step's quality before clearing per-step state.
        let quality: Double
        if let pattern = currentStep.strum {
            quality = min(1, Double(strumHits) / Double(max(1, pattern.beats)))   // beats hit in time
        } else {
            quality = stepMisses == 0 ? 1.0 : 1.0 / Double(1 + stepMisses)        // steady-hold cleanliness
        }
        runQualitySum += quality
        runStepCount += 1

        completedSteps.insert(currentStep.id)
        holdFrames = 0; stepMisses = 0
        feedback = .waiting
        detectedLabel = nil
        strumFinished = false; strumBeat = 0; strumHits = 0; hitBeats = []
        if currentIndex + 1 < lesson.steps.count {
            currentIndex += 1
            chordEngine?.reset()   // new target: don't blend the old chord's tail
        } else {
            isComplete = true
            lastRunScore = runStepCount > 0 ? runQualitySum / Double(runStepCount) : 1
            if lesson.tracksProgress {
                store.recordRun(lesson.id, score: lastRunScore)   // mastery EMA; unlocks at threshold
                if lesson.steps.contains(where: { $0.strum != nil }) {
                    // Accuracy before speed: a clean timed run earns a faster tempo next time.
                    store.recordTempoResult(lesson.id, score: lastRunScore)
                }
            }
            audio.stop()
        }
    }
}
