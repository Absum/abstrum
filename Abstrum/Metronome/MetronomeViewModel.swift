//
//  MetronomeViewModel.swift
//

import Foundation
import Observation

@Observable
final class MetronomeViewModel {
    let tempoRange = 40...240

    var bpm: Int = 100 {
        didSet { engine.updateTempo(bpm: bpm) }
    }
    var beatsPerMeasure: Int = 4
    var isRunning = false
    var currentBeat = -1

    private let engine = MetronomeEngine()
    private var tapTimes: [Date] = []

    init() {
        engine.onBeat = { [weak self] beat in self?.currentBeat = beat }
        #if DEBUG
        if ProcessInfo.processInfo.environment["ABSTRUM_METRO"] == "start" {
            DispatchQueue.main.async { [weak self] in self?.toggle() }
        }
        #endif
    }

    func toggle() {
        isRunning ? stop() : start()
    }

    func adjust(by delta: Int) {
        bpm = min(tempoRange.upperBound, max(tempoRange.lowerBound, bpm + delta))
    }

    func setBeatsPerMeasure(_ count: Int) {
        beatsPerMeasure = count
        if isRunning { engine.start(bpm: bpm, beatsPerMeasure: count) }
    }

    /// Average the last few taps into a tempo.
    func tapTempo() {
        let now = Date()
        tapTimes.append(now)
        tapTimes = tapTimes.filter { now.timeIntervalSince($0) < 3 }
        guard tapTimes.count >= 2 else { return }

        let intervals = zip(tapTimes.dropFirst(), tapTimes).map { $0.timeIntervalSince($1) }
        let average = intervals.reduce(0, +) / Double(intervals.count)
        guard average > 0 else { return }
        bpm = min(tempoRange.upperBound, max(tempoRange.lowerBound, Int((60.0 / average).rounded())))
    }

    private func start() {
        currentBeat = -1
        engine.start(bpm: bpm, beatsPerMeasure: beatsPerMeasure)
        isRunning = true
    }

    private func stop() {
        engine.stop()
        isRunning = false
        currentBeat = -1
    }
}
