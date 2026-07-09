//
//  EarTraining.swift
//  The listen-and-answer paradigm: hear a synthesized prompt, tap the answer.
//  No mic. Question generation is pure (deterministic under a seeded RNG) so
//  drills are fully testable; prompts are synthesized — nothing sampled.
//

import Foundation

/// Attached to a Lesson (with empty steps) to make it a listen-and-answer
/// drill instead of a mic-scored exercise.
struct EarDrillSpec: Hashable {
    enum Kind: Hashable {
        /// Identify melodic intervals from a pool of semitone sizes.
        case intervals([Int])
        /// Identify chord quality by ear from a pool.
        case chordQualities([ChordQuality])
        /// Hear a rhythm, pick which notated pattern it was (indices into
        /// `EarTraining.rhythmPatterns`).
        case rhythms([Int])
        /// Curated theory questions (set id into `EarTraining.theorySets`).
        case theory(String)
    }

    let kind: Kind
    let questionCount: Int
}

enum EarTraining {

    struct Question {
        let prompt: Prompt
        let text: String            // the on-screen question
        let choices: [String]
        let answerIndex: Int
    }

    enum Prompt {
        case notes([Double], gap: Double)   // sequential frequencies
        case chord([Double])                // simultaneous (strummed)
        case rhythm([Double], bpm: Int)     // tick offsets in beats
        case silent                          // text-only (theory)
    }

    // MARK: - Intervals

    static func intervalName(_ semitones: Int) -> String {
        switch semitones {
        case 2:  return "Major 2nd"
        case 3:  return "Minor 3rd"
        case 4:  return "Major 3rd"
        case 5:  return "Perfect 4th"
        case 7:  return "Perfect 5th"
        case 9:  return "Major 6th"
        case 12: return "Octave"
        default: return "\(semitones) semitones"
        }
    }

    /// Comfortable guitar-register roots for prompts.
    private static let promptRoots: [Double] = [110.0, 130.81, 146.83, 164.81, 196.0, 220.0]

    static func intervalQuestions(pool: [Int], count: Int,
                                  using rng: inout some RandomNumberGenerator) -> [Question] {
        let choices = pool.map(intervalName)
        return (0..<count).map { _ in
            let semitones = pool.randomElement(using: &rng)!
            let root = promptRoots.randomElement(using: &rng)!
            let top = root * pow(2.0, Double(semitones) / 12.0)
            return Question(prompt: .notes([root, top], gap: 0.75),
                            text: "How far apart are the two notes?",
                            choices: choices,
                            answerIndex: pool.firstIndex(of: semitones)!)
        }
    }

    // MARK: - Chord quality

    /// Synthesize a root-position voicing of a quality on a random root.
    static func chordQualityQuestions(pool: [ChordQuality], count: Int,
                                      using rng: inout some RandomNumberGenerator) -> [Question] {
        let choices = pool.map { $0.label }
        return (0..<count).map { _ in
            let quality = pool.randomElement(using: &rng)!
            let root = promptRoots.randomElement(using: &rng)!
            let frequencies = quality.intervals.map { root * pow(2.0, Double($0) / 12.0) }
            return Question(prompt: .chord(frequencies),
                            text: "What kind of chord is that?",
                            choices: choices,
                            answerIndex: pool.firstIndex(of: quality)!)
        }
    }

    // MARK: - Rhythm dictation

    /// Patterns as beat offsets over one 4/4 bar, with their notation-ish label.
    static let rhythmPatterns: [(offsets: [Double], display: String)] = [
        ([0, 1, 2, 3],            "1 · 2 · 3 · 4"),
        ([0, 1, 1.5, 2, 3],       "1 · 2 & 3 · 4"),
        ([0, 0.5, 1, 2, 3],       "1 & 2 · 3 · 4"),
        ([0, 1, 2, 2.5, 3, 3.5],  "1 · 2 · 3 & 4 &"),
        ([0, 1.5, 2, 3],          "1 · & 3 · 4"),
        ([0, 0.5, 1.5, 2.5, 3],   "1 & (2)& (3)& 4"),
    ]

    static func rhythmQuestions(patternIndices: [Int], count: Int, bpm: Int,
                                using rng: inout some RandomNumberGenerator) -> [Question] {
        let valid = patternIndices.filter { rhythmPatterns.indices.contains($0) }
        let choices = valid.map { rhythmPatterns[$0].display }
        return (0..<count).map { _ in
            let pick = valid.randomElement(using: &rng)!
            return Question(prompt: .rhythm(rhythmPatterns[pick].offsets, bpm: bpm),
                            text: "Which rhythm did you hear?",
                            choices: choices,
                            answerIndex: valid.firstIndex(of: pick)!)
        }
    }

    // MARK: - Theory (curated question sets)

    static let theorySets: [String: [Question]] = [
        "number-system-g": [
            Question(prompt: .silent, text: "In the key of G, which chord is the IV?",
                     choices: ["C", "D", "Em", "Am"], answerIndex: 0),
            Question(prompt: .silent, text: "In the key of G, which chord is the V?",
                     choices: ["C", "D", "Em", "Am"], answerIndex: 1),
            Question(prompt: .silent, text: "What is the relative minor of G?",
                     choices: ["Am", "Bm", "Em", "Dm"], answerIndex: 2),
            Question(prompt: .silent, text: "A I–IV–V in G uses…",
                     choices: ["G, C, D", "G, D, Em", "G, Am, C", "G, B, D"], answerIndex: 0),
            Question(prompt: .silent, text: "In the key of C, which chord is the IV?",
                     choices: ["F", "G", "Am", "Dm"], answerIndex: 0),
            Question(prompt: .silent, text: "In the key of C, which chord is the V?",
                     choices: ["F", "G", "Am", "Em"], answerIndex: 1),
        ],
        "chord-families": [
            Question(prompt: .silent, text: "Which chords all belong to the key of G?",
                     choices: ["G, C, D, Em", "G, A, B, C", "G, Cm, D, E", "G, C#, D, F"], answerIndex: 0),
            Question(prompt: .silent, text: "Which chords all belong to the key of C?",
                     choices: ["C, F, G, Am", "C, D, E, F", "C, Fm, G, A", "C, Eb, G, B"], answerIndex: 0),
            Question(prompt: .silent, text: "The ii chord in a major key is always…",
                     choices: ["minor", "major", "diminished", "a 7th"], answerIndex: 0),
            Question(prompt: .silent, text: "Em and G share a key. Em is its…",
                     choices: ["relative minor", "dominant", "subdominant", "parallel minor"], answerIndex: 0),
            Question(prompt: .silent, text: "The three major chords of any major key are…",
                     choices: ["I, IV, V", "I, ii, V", "I, III, VII", "IV, V, vi"], answerIndex: 0),
        ],
    ]

    // MARK: - Drill assembly

    /// Build the question list for a lesson's drill spec.
    static func questions(for spec: EarDrillSpec,
                          using rng: inout some RandomNumberGenerator) -> [Question] {
        switch spec.kind {
        case .intervals(let pool):
            return intervalQuestions(pool: pool, count: spec.questionCount, using: &rng)
        case .chordQualities(let pool):
            return chordQualityQuestions(pool: pool, count: spec.questionCount, using: &rng)
        case .rhythms(let indices):
            return rhythmQuestions(patternIndices: indices, count: spec.questionCount,
                                   bpm: 80, using: &rng)
        case .theory(let setID):
            let set = theorySets[setID] ?? []
            // Curated sets play in order, capped to the requested count.
            return Array(set.prefix(spec.questionCount))
        }
    }
}
