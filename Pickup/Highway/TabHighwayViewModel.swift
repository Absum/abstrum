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
    /// User-facing reason the last Start attempt failed (nil = no error).
    var lastError: String?
    /// Playback speed multiplier (scales tempo: lower = slower / easier).
    var speed: Double = 1.0
    /// Most recent hit time per string lane, for the strike-line flash.
    var flashes: [Int: Double] = [:]
    /// Listen mode: the app plays the melody (synth) instead of scoring the mic.
    var isPreviewing = false
    /// Practice/wait mode: hold each note at the strike line until it's played.
    var waitMode = false

    private let audio = AudioEngine()
    private let preview = TonePlayer()
    private var playedIDs: Set<Int> = []
    private var lastTick: Date?
    private var lastClickBeat = Int.min
    private var clock: Timer?
    private let hitWindow = 0.30      // seconds around a note's strike time
    private let centsTolerance = 60.0

    init(track: HighwayTrack) {
        self.track = track
        audio.onResult = { [weak self] in self?.handle($0) }
        audio.enableClickPlayback = true   // metronome click + count-in during play
        preview.keepAlive = true
    }

    var notes: [HighwayNote] { track.notes }
    var total: Int { notes.count }
    var hits: Int { hitIDs.count }

    func seconds(of note: HighwayNote) -> Double {
        note.beat * 60.0 / Double(track.bpm) / max(0.25, speed)
    }
    private var endTime: Double { (notes.map { seconds(of: $0) }.max() ?? 0) + 1.6 }

    func toggle() { isPlaying ? stop() : start() }

    // MARK: - Listen (the app plays the melody; no mic)

    func togglePreview() { isPreviewing ? stopPreview() : startPreview() }

    private func startPreview() {
        guard !isPlaying else { return }
        hitIDs = []; flashes = [:]; playedIDs = []; finished = false
        currentTime = -2.0
        lastTick = nil
        preview.warmUp()       // spin up the engine during the lead-in
        isPreviewing = true
        startClock()
    }

    private func stopPreview() {
        clock?.invalidate(); clock = nil
        preview.stop()
        isPreviewing = false
        currentTime = 0; hitIDs = []; flashes = [:]; playedIDs = []
    }

    private func start() {
        lastError = nil
        if isPreviewing { stopPreview() }
        // Make sure the Listen engine isn't holding the playback session — on a
        // real device the mic's .record session won't activate over a live one.
        preview.stop()
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else {
                    self.permissionDenied = true
                    self.lastError = "Microphone access is off — enable it in Settings › Pickup."
                    return
                }
                // Release any active (e.g. leftover Listen) session before switching
                // categories, otherwise activating .record can fail on device.
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                do { try self.audio.start() }
                catch {
                    self.lastError = "Couldn't start the mic: \(error.localizedDescription)"
                    print("Pickup.highway: audio start failed — \(error)")
                    return
                }
                self.hitIDs = []
                self.flashes = [:]
                self.finished = false
                self.currentTime = -2.0          // lead-in before the first note
                self.lastTick = nil
                self.lastClickBeat = .min
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
            self?.tick()
        }
    }

    private var nextUnhitTime: Double? {
        notes.filter { !hitIDs.contains($0.id) }.map { seconds(of: $0) }.min()
    }

    private func tick() {
        let now = Date()
        guard let last = lastTick else { lastTick = now; return }
        let dt = now.timeIntervalSince(last)
        lastTick = now

        if isPreviewing {
            currentTime += dt
            for note in notes where !playedIDs.contains(note.id) && seconds(of: note) <= currentTime {
                preview.playNote(note.frequency)
                playedIDs.insert(note.id)
                hitIDs.insert(note.id)
                flashes[note.string] = currentTime
            }
            if currentTime > endTime { stopPreview() }
            return
        }

        // Play mode: in wait mode, never advance past a not-yet-played note.
        if waitMode, let nextT = nextUnhitTime {
            currentTime = min(currentTime + dt, nextT)
        } else {
            currentTime += dt
        }

        // Metronome: click on each beat boundary (accent the downbeat). Negative
        // time covers the count-in before the first note arrives.
        let beatInterval = 60.0 / Double(track.bpm) / max(0.25, speed)
        let beat = Int(floor(currentTime / beatInterval))
        if beat > lastClickBeat {
            lastClickBeat = beat
            audio.playClick(accent: ((beat % 4) + 4) % 4 == 0)
        }

        if currentTime > endTime { finish() }
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
