//
//  Chord.swift
//  Chord model, the open-chord bank, and chroma template matching.
//

import Foundation

struct Chord: Identifiable, Hashable {
    let id: String              // "E", "Am"
    let name: String            // display name
    let quality: String         // "Major" / "Minor"
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
    // string 0 = low E … 5 = high e
    static let all: [Chord] = [
        Chord(id: "E", name: "E", quality: "Major",
              positions: [.init(string: 0, fret: 0), .init(string: 1, fret: 2), .init(string: 2, fret: 2),
                          .init(string: 3, fret: 1), .init(string: 4, fret: 0), .init(string: 5, fret: 0)],
              mutedStrings: [], pitchClasses: [4, 8, 11]),       // E G# B
        Chord(id: "Em", name: "Em", quality: "Minor",
              positions: [.init(string: 0, fret: 0), .init(string: 1, fret: 2), .init(string: 2, fret: 2),
                          .init(string: 3, fret: 0), .init(string: 4, fret: 0), .init(string: 5, fret: 0)],
              mutedStrings: [], pitchClasses: [4, 7, 11]),       // E G B
        Chord(id: "A", name: "A", quality: "Major",
              positions: [.init(string: 1, fret: 0), .init(string: 2, fret: 2), .init(string: 3, fret: 2),
                          .init(string: 4, fret: 2), .init(string: 5, fret: 0)],
              mutedStrings: [0], pitchClasses: [9, 1, 4]),       // A C# E
        Chord(id: "Am", name: "Am", quality: "Minor",
              positions: [.init(string: 1, fret: 0), .init(string: 2, fret: 2), .init(string: 3, fret: 2),
                          .init(string: 4, fret: 1), .init(string: 5, fret: 0)],
              mutedStrings: [0], pitchClasses: [9, 0, 4]),       // A C E
        Chord(id: "D", name: "D", quality: "Major",
              positions: [.init(string: 2, fret: 0), .init(string: 3, fret: 2),
                          .init(string: 4, fret: 3), .init(string: 5, fret: 2)],
              mutedStrings: [0, 1], pitchClasses: [2, 6, 9]),    // D F# A
        Chord(id: "Dm", name: "Dm", quality: "Minor",
              positions: [.init(string: 2, fret: 0), .init(string: 3, fret: 2),
                          .init(string: 4, fret: 3), .init(string: 5, fret: 1)],
              mutedStrings: [0, 1], pitchClasses: [2, 5, 9]),    // D F A
        Chord(id: "G", name: "G", quality: "Major",
              positions: [.init(string: 0, fret: 3), .init(string: 1, fret: 2), .init(string: 2, fret: 0),
                          .init(string: 3, fret: 0), .init(string: 4, fret: 0), .init(string: 5, fret: 3)],
              mutedStrings: [], pitchClasses: [7, 11, 2]),       // G B D
        Chord(id: "C", name: "C", quality: "Major",
              positions: [.init(string: 1, fret: 3), .init(string: 2, fret: 2), .init(string: 3, fret: 0),
                          .init(string: 4, fret: 1), .init(string: 5, fret: 0)],
              mutedStrings: [0], pitchClasses: [0, 4, 7]),       // C E G
    ]
}
