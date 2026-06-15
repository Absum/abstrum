//
//  Chord.swift
//  Chord model, qualities, the open-chord bank, and chroma template matching.
//

import Foundation

enum ChordQuality: String, CaseIterable, Hashable {
    case major, minor, power, dom7, min7, maj7, sus2, sus4

    var label: String {
        switch self {
        case .major: return "Major"
        case .minor: return "Minor"
        case .power: return "5"
        case .dom7:  return "7"
        case .min7:  return "m7"
        case .maj7:  return "maj7"
        case .sus2:  return "sus2"
        case .sus4:  return "sus4"
        }
    }

    /// Appended to the root for the chord name (E + "m" = "Em").
    var suffix: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .power: return "5"
        case .dom7:  return "7"
        case .min7:  return "m7"
        case .maj7:  return "maj7"
        case .sus2:  return "sus2"
        case .sus4:  return "sus4"
        }
    }

    /// Semitone intervals above the root.
    var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .power: return [0, 7]
        case .dom7:  return [0, 4, 7, 10]
        case .min7:  return [0, 3, 7, 10]
        case .maj7:  return [0, 4, 7, 11]
        case .sus2:  return [0, 2, 7]
        case .sus4:  return [0, 5, 7]
        }
    }
}

struct Chord: Identifiable, Hashable {
    let id: String
    let name: String
    let root: String
    let quality: ChordQuality
    let positions: [FretPosition]   // sounded strings (open or fretted)
    let mutedStrings: [Int]
    let pitchClasses: Set<Int>      // detection template (0 = C … 11 = B)
}

extension Chord {
    /// The actual sounding pitches (Hz) of the chord's strings, low to high.
    var frequencies: [Double] {
        let ordered = positions.sorted { $0.string < $1.string }
        var result: [Double] = []
        for p in ordered {
            let openHz = GuitarTuning.standard[p.string].frequency
            result.append(openHz * pow(2.0, Double(p.fret) / 12.0))
        }
        return result
    }
}

enum ChordMatcher {
    /// Cosine similarity between a 12-bin chroma vector and a chord's
    /// pitch-class template (1 at chord tones). 0…1; higher = better match.
    static func score(chroma: [Float], pitchClasses: Set<Int>) -> Double {
        guard chroma.count == 12, !pitchClasses.isEmpty else { return 0 }
        var dot = 0.0
        var energy = 0.0
        for i in 0..<12 {
            let c = Double(chroma[i])
            energy += c * c
            if pitchClasses.contains(i) { dot += c }
        }
        let denom = energy.squareRoot() * Double(pitchClasses.count).squareRoot()
        return denom > 0 ? dot / denom : 0
    }

    /// The best-scoring chord from `candidates` for a chroma vector.
    static func bestMatch(chroma: [Float], in candidates: [Chord]) -> (chord: Chord, score: Double)? {
        var best: (chord: Chord, score: Double)?
        for chord in candidates {
            let s = score(chroma: chroma, pitchClasses: chord.pitchClasses)
            if best == nil || s > best!.score { best = (chord, s) }
        }
        return best
    }
}

enum ChordBank {
    private static let rootPitchClass: [String: Int] = [
        "C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5,
        "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11,
    ]

    private static func p(_ string: Int, _ fret: Int) -> FretPosition {
        FretPosition(string: string, fret: fret)
    }

    private static func make(_ root: String, _ quality: ChordQuality,
                             _ positions: [FretPosition], muted: [Int] = []) -> Chord {
        let rootPC = rootPitchClass[root] ?? 0
        let classes = Set(quality.intervals.map { (rootPC + $0) % 12 })
        let name = root + quality.suffix
        return Chord(id: name, name: name, root: root, quality: quality,
                     positions: positions, mutedStrings: muted, pitchClasses: classes)
    }

    // string 0 = low E … 5 = high e. Verified common open voicings.
    // Split per quality so the type-checker doesn't choke on one huge literal.
    private static let majors: [Chord] = [
        make("E", .major, [p(0, 0), p(1, 2), p(2, 2), p(3, 1), p(4, 0), p(5, 0)]),
        make("A", .major, [p(1, 0), p(2, 2), p(3, 2), p(4, 2), p(5, 0)], muted: [0]),
        make("D", .major, [p(2, 0), p(3, 2), p(4, 3), p(5, 2)], muted: [0, 1]),
        make("G", .major, [p(0, 3), p(1, 2), p(2, 0), p(3, 0), p(4, 0), p(5, 3)]),
        make("C", .major, [p(1, 3), p(2, 2), p(3, 0), p(4, 1), p(5, 0)], muted: [0]),
    ]
    private static let minors: [Chord] = [
        make("E", .minor, [p(0, 0), p(1, 2), p(2, 2), p(3, 0), p(4, 0), p(5, 0)]),
        make("A", .minor, [p(1, 0), p(2, 2), p(3, 2), p(4, 1), p(5, 0)], muted: [0]),
        make("D", .minor, [p(2, 0), p(3, 2), p(4, 3), p(5, 1)], muted: [0, 1]),
    ]
    private static let dom7s: [Chord] = [
        make("E", .dom7, [p(0, 0), p(1, 2), p(2, 0), p(3, 1), p(4, 0), p(5, 0)]),
        make("A", .dom7, [p(1, 0), p(2, 2), p(3, 0), p(4, 2), p(5, 0)], muted: [0]),
        make("D", .dom7, [p(2, 0), p(3, 2), p(4, 1), p(5, 2)], muted: [0, 1]),
        make("G", .dom7, [p(0, 3), p(1, 2), p(2, 0), p(3, 0), p(4, 0), p(5, 1)]),
        make("C", .dom7, [p(1, 3), p(2, 2), p(3, 3), p(4, 1), p(5, 0)], muted: [0]),
        make("B", .dom7, [p(1, 2), p(2, 1), p(3, 2), p(4, 0), p(5, 2)], muted: [0]),
    ]
    private static let min7s: [Chord] = [
        make("E", .min7, [p(0, 0), p(1, 2), p(2, 2), p(3, 0), p(4, 3), p(5, 0)]),
        make("A", .min7, [p(1, 0), p(2, 2), p(3, 0), p(4, 1), p(5, 0)], muted: [0]),
        make("D", .min7, [p(2, 0), p(3, 2), p(4, 1), p(5, 1)], muted: [0, 1]),
    ]
    private static let maj7s: [Chord] = [
        make("C", .maj7, [p(1, 3), p(2, 2), p(3, 0), p(4, 0), p(5, 0)], muted: [0]),
        make("A", .maj7, [p(1, 0), p(2, 2), p(3, 1), p(4, 2), p(5, 0)], muted: [0]),
        make("D", .maj7, [p(2, 0), p(3, 2), p(4, 2), p(5, 2)], muted: [0, 1]),
        make("F", .maj7, [p(2, 3), p(3, 2), p(4, 1), p(5, 0)], muted: [0, 1]),
        make("G", .maj7, [p(0, 3), p(1, 2), p(2, 0), p(3, 0), p(4, 0), p(5, 2)]),
        make("E", .maj7, [p(0, 0), p(1, 2), p(2, 1), p(3, 1), p(4, 0), p(5, 0)]),
    ]
    private static let sus2s: [Chord] = [
        make("A", .sus2, [p(1, 0), p(2, 2), p(3, 2), p(4, 0), p(5, 0)], muted: [0]),
        make("D", .sus2, [p(2, 0), p(3, 2), p(4, 3), p(5, 0)], muted: [0, 1]),
    ]
    private static let sus4s: [Chord] = [
        make("A", .sus4, [p(1, 0), p(2, 2), p(3, 2), p(4, 3), p(5, 0)], muted: [0]),
        make("D", .sus4, [p(2, 0), p(3, 2), p(4, 3), p(5, 3)], muted: [0, 1]),
        make("E", .sus4, [p(0, 0), p(1, 2), p(2, 2), p(3, 2), p(4, 0), p(5, 0)]),
    ]
    private static let powers: [Chord] = [
        make("E", .power, [p(0, 0), p(1, 2), p(2, 2)], muted: [3, 4, 5]),
        make("A", .power, [p(1, 0), p(2, 2), p(3, 2)], muted: [0, 4, 5]),
        make("D", .power, [p(2, 0), p(3, 2), p(4, 3)], muted: [0, 1, 5]),
        make("F", .power, [p(0, 1), p(1, 3), p(2, 3)], muted: [3, 4, 5]),
    ]

    static let all: [Chord] = majors + minors + powers + dom7s + min7s + maj7s + sus2s + sus4s

    /// Chords filtered by quality (nil = all).
    static func chords(quality: ChordQuality?) -> [Chord] {
        guard let quality else { return all }
        return all.filter { $0.quality == quality }
    }
}
