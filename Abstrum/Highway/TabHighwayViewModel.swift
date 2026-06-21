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
    /// Loop the track for drilling — replays instead of showing results.
    var loop = false

    /// Signed timing error per hit note (seconds; <0 = early, >0 = late), after
    /// compensating for analysis latency. Drives the timing accuracy score.
    var timingErrors: [Int: Double] = [:]
    /// Recent note onsets (attack times in the visual clock), from the DSP
    /// onset detector — used to time each hit precisely.
    private var recentOnsets: [Double] = []
    /// Most recent hit's timing feedback, for the on-strike flash label.
    var lastTiming: (string: Int, grade: TimingGrade, ms: Int, time: Double)?

    enum TimingGrade { case perfect, early, late }

    /// Pitch detection lags the actual pluck by roughly one analysis window;
    /// subtract it so an on-the-beat pluck scores ~0. Rough — calibratable.
    private let timingLatency = 0.085

    private let audio = AudioEngine()
    private let preview = TonePlayer()
    private var playedIDs: Set<Int> = []
    private var lastTick: Date?
    private var lastClickBeat = Int.min
    private var clock: Timer?
    private let hitWindow = 0.30      // seconds around a note's strike time
    // Note tolerance + onset window read live from AudioSettings (dev tuning).

    init(track: HighwayTrack) {
        self.track = track
        audio.onResult = { [weak self] in self?.handle($0) }
        audio.onOnset = { [weak self] in self?.handleOnset($0) }   // attack timing
        audio.enableClickPlayback = true   // metronome click + count-in during play
        preview.keepAlive = true
    }

    var notes: [HighwayNote] { track.notes }
    var total: Int { notes.count }
    var hits: Int { hitIDs.count }

    /// Mean absolute timing error in milliseconds across graded hits.
    var avgTimingMs: Int {
        guard !timingErrors.isEmpty else { return 0 }
        let mean = timingErrors.values.map { abs($0) }.reduce(0, +) / Double(timingErrors.count)
        return Int((mean * 1000).rounded())
    }

    /// Timing accuracy 0–100: tight to the beat = 100, ±200 ms = 0.
    var timingAccuracy: Int {
        guard !timingErrors.isEmpty else { return 0 }
        let mean = timingErrors.values.map { abs($0) }.reduce(0, +) / Double(timingErrors.count)
        return Int((max(0, min(1, 1 - mean / 0.2)) * 100).rounded())
    }

    /// On average, were hits early or late? (nil when dead-on or no data.)
    var timingBias: TimingGrade? {
        guard !timingErrors.isEmpty else { return nil }
        let mean = timingErrors.values.reduce(0, +) / Double(timingErrors.count)
        if abs(mean) <= 0.02 { return .perfect }
        return mean < 0 ? .early : .late
    }

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
                    self.lastError = "Microphone access is off — enable it in Settings › Abstrum."
                    return
                }
                // Release any active (e.g. leftover Listen) session before switching
                // categories, otherwise activating .record can fail on device.
                try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
                do { try self.audio.start() }
                catch {
                    self.lastError = "Couldn't start the mic: \(error.localizedDescription)"
                    print("Abstrum.highway: audio start failed — \(error)")
                    return
                }
                self.hitIDs = []
                self.flashes = [:]
                self.timingErrors = [:]
                self.lastTiming = nil
                self.recentOnsets = []
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
        if loop {
            // Replay for drilling — keep the clock + audio running, just reset.
            currentTime = -2.0
            hitIDs = []; flashes = [:]; timingErrors = [:]; recentOnsets = []
            lastClickBeat = .min
            return
        }
        clock?.invalidate(); clock = nil
        audio.stop()
        isPlaying = false
        finished = true
        ProgressStore.shared.awardXP(5 + hits * 2)
        ProgressStore.shared.addPracticeTime(Int(max(0, currentTime)))
    }

    /// A DSP-detected attack, in seconds since audio start; converted to the
    /// visual clock (which begins at -2 during the lead-in) and kept briefly.
    private func handleOnset(_ secondsSinceStart: Double) {
        guard isPlaying else { return }
        recentOnsets.append(secondsSinceStart - 2.0)
        recentOnsets.removeAll { $0 < currentTime - 1.0 }
    }

    private func handle(_ result: AudioEngine.Result?) {
        guard isPlaying, let frequency = result?.frequency, frequency > 0 else { return }
        for n in notes where !hitIDs.contains(n.id) {
            let dt = abs(seconds(of: n) - currentTime)
            guard dt < hitWindow else { continue }
            let cents = abs(1200.0 * log2(frequency / n.frequency))
            if cents < AudioSettings.shared.noteToleranceCents {
                hitIDs.insert(n.id)
                flashes[n.string] = currentTime
                // Grade timing (not meaningful while waitMode holds the note).
                if !waitMode {
                    let beat = seconds(of: n)
                    // Prefer the real attack onset nearest this note's beat;
                    // fall back to the pitch-match time if none is close.
                    let offset: Double
                    if let o = recentOnsets.min(by: { abs($0 - beat) < abs($1 - beat) }),
                       abs(o - beat) <= AudioSettings.shared.timingWindow {
                        offset = o - beat
                    } else {
                        offset = (currentTime - beat) - timingLatency
                    }
                    timingErrors[n.id] = offset
                    let grade: TimingGrade = abs(offset) <= 0.05 ? .perfect : (offset < 0 ? .early : .late)
                    lastTiming = (n.string, grade, Int((offset * 1000).rounded()), currentTime)
                }
                break
            }
        }
    }
}
