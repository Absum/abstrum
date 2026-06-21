//
//  TunerViewModel.swift
//  Maps detected pitch onto the nearest guitar string (or a manually chosen
//  one), with log-space smoothing for a stable readout.
//

import AVFoundation
import Observation
import SwiftUI

@Observable
final class TunerViewModel {
    enum Direction { case flat, inTune, sharp }

    struct Reading {
        let string: GuitarString
        let cents: Double
        let frequency: Double

        var isInTune: Bool { abs(cents) <= 5 }
        var direction: Direction {
            if isInTune { return .inTune }
            return cents < 0 ? .flat : .sharp
        }
    }

    var reading: Reading?
    var isListening = false
    var permissionDenied = false
    /// Target string for manual mode; nil means auto-detect the nearest.
    var manualString: GuitarString?

    private let audio = AudioEngine()
    private var smoothedFrequency: Double = 0
    private var history: [Double] = []      // recent raw detections, for stabilizing
    private let historyLength = 8
    private var silenceFrames = 0

    init() {
        audio.onResult = { [weak self] in self?.handle($0) }
        loadDemoStateIfNeeded()
    }

    /// DEBUG-only: seed a fixed reading for design QA via the ABSTRUM_DEMO env var
    /// (format "stringIndex:cents", e.g. "5:0" or "0:-22"). No production effect.
    private func loadDemoStateIfNeeded() {
        #if DEBUG
        guard let demo = ProcessInfo.processInfo.environment["ABSTRUM_DEMO"] else { return }
        if demo == "listen" {
            // Auto-start the mic for end-to-end testing in the simulator.
            DispatchQueue.main.async { [weak self] in self?.toggle() }
            return
        }
        let parts = demo.split(separator: ":")
        guard parts.count == 2,
              let index = Int(parts[0]), GuitarTuning.standard.indices.contains(index),
              let cents = Double(parts[1]) else { return }
        let string = GuitarTuning.standard[index]
        let frequency = string.frequency * pow(2.0, cents / 1200.0)
        reading = Reading(string: string, cents: cents, frequency: frequency)
        isListening = true
        #endif
    }

    /// The string to highlight in the picker.
    var activeStringID: Int? { reading?.string.id ?? manualString?.id }

    func toggle() { isListening ? stop() : start() }

    /// Tap a string to lock onto it; tap again (same string) to return to auto.
    func selectString(_ string: GuitarString) {
        manualString = (manualString?.id == string.id) ? nil : string
    }

    private func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else { self.permissionDenied = true; return }
                do {
                    try self.audio.start()
                    self.isListening = true
                } catch {
                    print("Abstrum: audio start failed — \(error)")
                }
            }
        }
    }

    private func stop() {
        audio.stop()
        isListening = false
        reading = nil
        smoothedFrequency = 0
        history.removeAll()
    }

    private func handle(_ result: AudioEngine.Result?) {
        guard let result else {
            silenceFrames += 1
            if silenceFrames > 6 {
                reading = nil
                smoothedFrequency = 0
                history.removeAll()
            }
            return
        }
        silenceFrames = 0

        // Keep a short window of recent detections.
        history.append(result.frequency)
        if history.count > historyLength { history.removeFirst() }
        guard history.count >= 4 else { return }

        // Reject octave jumps / spurious frames: keep only detections that agree
        // with the window's median (within 50 cents). Need a majority to update.
        let median = history.sorted()[history.count / 2]
        let agreeing = history.filter { abs(1200.0 * log2($0 / median)) < 50.0 }
        guard agreeing.count >= max(3, history.count / 2) else { return }  // unstable: hold

        // Stable estimate = log-mean of the agreeing frames, then gently smoothed.
        let logMean = agreeing.reduce(0.0) { $0 + log2($1) } / Double(agreeing.count)
        let stable = pow(2.0, logMean)
        smoothedFrequency = smoothedFrequency == 0
            ? stable
            : exp(log(smoothedFrequency) * 0.5 + log(stable) * 0.5)

        let target = manualString ?? GuitarTuning.nearestString(toFrequency: smoothedFrequency).string
        reading = Reading(string: target,
                          cents: GuitarTuning.cents(from: smoothedFrequency, to: target),
                          frequency: smoothedFrequency)
    }
}
