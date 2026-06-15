//
//  TabHighwayViewModel.swift
//  Drives the falling-note highway: a clock advances time while the pitch
//  engine scores notes as they cross the strike line.
//

import AVFoundation
import Observation
import SwiftUI

@Observable
final class TabHighwayViewModel {
    let track: HighwayTrack
    var currentTime: Double = 0
    var isPlaying = false
    var finished = false
    var hitIDs: Set<Int> = []
    var permissionDenied = false
    /// Playback speed multiplier (scales tempo: lower = slower / easier).
    var speed: Double = 1.0
    /// Most recent hit time per string lane, for the strike-line flash.
    var flashes: [Int: Double] = [:]

    private let audio = AudioEngine()
    private var startDate: Date?
    private var clock: Timer?
    private let hitWindow = 0.30      // seconds around a note's strike time
    private let centsTolerance = 60.0

    init(track: HighwayTrack) {
        self.track = track
        audio.onResult = { [weak self] in self?.handle($0) }
    }

    var notes: [HighwayNote] { track.notes }
    var total: Int { notes.count }
    var hits: Int { hitIDs.count }

    func seconds(of note: HighwayNote) -> Double {
        note.beat * 60.0 / Double(track.bpm) / max(0.25, speed)
    }
    private var endTime: Double { (notes.map { seconds(of: $0) }.max() ?? 0) + 1.6 }

    func toggle() { isPlaying ? stop() : start() }

    private func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else { self.permissionDenied = true; return }
                do { try self.audio.start() } catch { return }
                self.hitIDs = []
                self.flashes = [:]
                self.finished = false
                self.currentTime = -2.0          // 2-beat lead-in before the first note
                self.startDate = Date().addingTimeInterval(2.0)
                self.isPlaying = true
                self.startClock()
            }
        }
    }

    private func stop() {
        clock?.invalidate(); clock = nil
        audio.stop()
        isPlaying = false
    }

    func restart() { stop(); start() }

    private func startClock() {
        clock = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            guard let self, let startDate = self.startDate else { return }
            self.currentTime = Date().timeIntervalSince(startDate)
            if self.currentTime > self.endTime { self.finish() }
        }
    }

    private func finish() {
        clock?.invalidate(); clock = nil
        audio.stop()
        isPlaying = false
        finished = true
    }

    private func handle(_ result: AudioEngine.Result?) {
        guard isPlaying, let frequency = result?.frequency, frequency > 0 else { return }
        for n in notes where !hitIDs.contains(n.id) {
            let dt = abs(seconds(of: n) - currentTime)
            guard dt < hitWindow else { continue }
            let cents = abs(1200.0 * log2(frequency / n.frequency))
            if cents < centsTolerance {
                hitIDs.insert(n.id)
                flashes[n.string] = currentTime
                break
            }
        }
    }
}
