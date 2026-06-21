//
//  InterleavedDrill.swift
//  Interleaved practice (block → interleave once competent): once a chord has
//  passed the first mastery gate via blocked lessons, it joins a shuffled pool.
//  This builds an ephemeral "Mixed Chords" lesson that interleaves those known
//  chords — a desirable difficulty that improves retention and transfer over
//  re-drilling one chord at a time.
//

import Foundation

enum InterleavedDrill {
    /// Need at least this many distinct learned chords to make a mix worthwhile.
    static let minPool = 2
    /// Default number of chord changes in a generated drill.
    static let defaultLength = 8

    /// The interleavable pool: distinct chords from the learner's *single-chord*
    /// lessons that they've passed the first gate on (completed). Songs and
    /// change drills are excluded — their chords already appear via the chord
    /// lessons. Returned in curriculum order (stable).
    static func pool(completed: Set<String>, lessons: [Lesson] = LessonLibrary.all) -> [Chord] {
        var seen = Set<String>()
        var result: [Chord] = []
        for lesson in lessons where completed.contains(lesson.id) {
            let chords = lesson.steps.compactMap { $0.strum == nil ? $0.chord : nil }
            let ids = Set(chords.map(\.id))
            guard ids.count == 1, let chord = chords.first, !seen.contains(chord.id) else { continue }
            seen.insert(chord.id)
            result.append(chord)
        }
        return result
    }

    /// A shuffled, evenly-spread sequence of `length` chord ids from `poolIDs`,
    /// avoiding immediate repeats. Cycles the full pool (shuffled each pass) so
    /// every chord recurs before any repeats — even coverage, not clumping.
    static func sequence(poolIDs: [String], length: Int,
                         using rng: inout some RandomNumberGenerator) -> [String] {
        guard !poolIDs.isEmpty else { return [] }
        var out: [String] = []
        while out.count < length {
            var cycle = poolIDs.shuffled(using: &rng)
            // Don't let a cycle boundary create an immediate repeat.
            if let last = out.last, cycle.first == last, cycle.count > 1 {
                cycle.swapAt(0, 1)
            }
            for id in cycle where out.count < length { out.append(id) }
        }
        return out
    }

    /// Build the ephemeral mixed-chords lesson, or nil if the pool is too small.
    static func lesson(completed: Set<String>,
                       lessons: [Lesson] = LessonLibrary.all,
                       length: Int = defaultLength,
                       using rng: inout some RandomNumberGenerator) -> Lesson? {
        let chords = pool(completed: completed, lessons: lessons)
        guard chords.count >= minPool else { return nil }
        let byID = Dictionary(uniqueKeysWithValues: chords.map { ($0.id, $0) })
        let ids = sequence(poolIDs: chords.map(\.id), length: length, using: &rng)
        let steps = ids.enumerated().map { index, id -> LessonStep in
            let chord = byID[id]!
            return LessonStep(id: index, note: chord.name, octaveLabel: "", frequency: 0,
                              hint: "Strum the \(chord.name) chord", position: nil, chord: chord)
        }
        return Lesson(id: "interleaved-mix", title: "Mixed Chords",
                      subtitle: "Shuffle of the chords you know", tier: 2,
                      prerequisite: nil, steps: steps, tracksProgress: false)
    }

    /// Convenience using the system RNG (real shuffle each time).
    static func lesson(completed: Set<String>,
                       lessons: [Lesson] = LessonLibrary.all,
                       length: Int = defaultLength) -> Lesson? {
        var rng = SystemRandomNumberGenerator()
        return lesson(completed: completed, lessons: lessons, length: length, using: &rng)
    }
}

/// A tiny deterministic RNG (SplitMix64) — lets the drill be unit-tested with a
/// fixed seed while production uses the system generator.
struct SeededGenerator: RandomNumberGenerator {
    private var state: UInt64
    init(seed: UInt64) { state = seed }
    mutating func next() -> UInt64 {
        state = state &+ 0x9E3779B97F4A7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58476D1CE4E5B9
        z = (z ^ (z >> 27)) &* 0x94D049BB133111EB
        return z ^ (z >> 31)
    }
}
