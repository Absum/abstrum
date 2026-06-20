//
//  AdaptiveTempoTests.swift
//  Accuracy-before-speed tempo policy + per-skill persistence in ProgressStore.
//

import XCTest

final class AdaptiveTempoTests: XCTestCase {

    private func makeStore() -> ProgressStore {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pickup-tempo-\(UUID().uuidString)")
        return ProgressStore(directory: dir, filename: "progress.json")
    }

    // MARK: - Policy

    func testStartsBelowTarget() {
        XCTAssertLessThan(AdaptiveTempo.startFactor, AdaptiveTempo.maxFactor)
        // A 100 BPM exercise begins notably slower.
        XCTAssertLessThan(AdaptiveTempo.bpm(target: 100, factor: AdaptiveTempo.startFactor), 100)
    }

    func testCleanRunsSpeedUpTowardTargetAndCap() {
        var f = AdaptiveTempo.startFactor
        for _ in 0..<10 { f = AdaptiveTempo.next(factor: f, score: 1.0) }
        XCTAssertEqual(f, AdaptiveTempo.maxFactor, accuracy: 1e-9)   // never overshoots target
        XCTAssertTrue(AdaptiveTempo.isAtTarget(f))
    }

    func testShakyRunsSlowDownToFloor() {
        var f = AdaptiveTempo.startFactor
        for _ in 0..<10 { f = AdaptiveTempo.next(factor: f, score: 0.0) }
        XCTAssertEqual(f, AdaptiveTempo.minFactor, accuracy: 1e-9)   // never below the floor
    }

    func testMiddlingRunHoldsTempo() {
        let f = AdaptiveTempo.next(factor: 0.7, score: 0.75)   // between shaky and clean
        XCTAssertEqual(f, 0.7, accuracy: 1e-9)
    }

    func testBpmNeverDropsBelowFloor() {
        // Even a very slow factor on a slow exercise stays playable.
        XCTAssertGreaterThanOrEqual(AdaptiveTempo.bpm(target: 70, factor: 0.5), AdaptiveTempo.minBPM)
    }

    // MARK: - Persistence in ProgressStore

    func testDefaultTempoFactorIsTheStartFactor() {
        let s = makeStore()
        XCTAssertEqual(s.tempoFactor(of: "first-song"), AdaptiveTempo.startFactor, accuracy: 1e-9)
    }

    func testCleanResultRaisesAndPersistsTempo() {
        let dir = FileManager.default.temporaryDirectory
            .appendingPathComponent("pickup-tempo-\(UUID().uuidString)")
        let a = ProgressStore(directory: dir, filename: "progress.json")
        a.recordTempoResult("first-song", score: 1.0)
        let raised = a.tempoFactor(of: "first-song")
        XCTAssertGreaterThan(raised, AdaptiveTempo.startFactor)
        let b = ProgressStore(directory: dir, filename: "progress.json")
        XCTAssertEqual(b.tempoFactor(of: "first-song"), raised, accuracy: 1e-9)
    }

    func testResetClearsTempo() {
        let s = makeStore()
        s.recordTempoResult("first-song", score: 1.0)
        s.reset()
        XCTAssertEqual(s.tempoFactor(of: "first-song"), AdaptiveTempo.startFactor, accuracy: 1e-9)
    }
}
