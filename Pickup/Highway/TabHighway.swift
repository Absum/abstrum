//
//  TabHighway.swift
//  Falling-note tracks: single-note melodies on the 6 string lanes.
//

import Foundation

struct HighwayNote: Identifiable, Hashable {
    let id: Int
    let beat: Double     // start position in beats
    let string: Int      // 0 = low E … 5 = high e
    let fret: Int
    let frequency: Double
}

struct HighwayTrack: Identifiable, Hashable {
    let id: String
    let title: String
    let credit: String
    let bpm: Int
    let notes: [HighwayNote]
    var licensed: Bool = false   // copyrighted composition — not cleared to ship
}

enum HighwayLibrary {
    private static func note(_ id: Int, beat: Double, string: Int, fret: Int) -> HighwayNote {
        let freq = GuitarTuning.standard[string].frequency * pow(2.0, Double(fret) / 12.0)
        return HighwayNote(id: id, beat: beat, string: string, fret: fret, frequency: freq)
    }

    /// Build highway notes (one quarter-note per step) — used by song import.
    static func notes(from steps: [(string: Int, fret: Int)]) -> [HighwayNote] {
        steps.enumerated().map { i, step in
            note(i, beat: Double(i), string: min(5, max(0, step.string)), fret: max(0, step.fret))
        }
    }

    /// One quarter-note per step: (string, fret).
    private static func track(id: String, title: String, credit: String, bpm: Int,
                              steps: [(Int, Int)], repeats: Int = 1, licensed: Bool = false) -> HighwayTrack {
        let full = Array(repeating: steps, count: max(1, repeats)).flatMap { $0 }
        let notes = full.enumerated().map { i, step in
            note(i, beat: Double(i), string: step.0, fret: step.1)
        }
        return HighwayTrack(id: id, title: title, credit: credit, bpm: bpm, notes: notes, licensed: licensed)
    }

    private static let publicDomain: [HighwayTrack] = [
        track(id: "ladder", title: "Open String Ladder", credit: "Warm-up", bpm: 60,
              steps: [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0),
                      (4, 0), (3, 0), (2, 0), (1, 0), (0, 0)]),
        track(id: "ode-to-joy", title: "Ode to Joy", credit: "Beethoven", bpm: 80,
              steps: [(5, 0), (5, 0), (5, 1), (5, 3), (5, 3), (5, 1), (5, 0), (4, 3),
                      (4, 1), (4, 1), (4, 3), (5, 0), (5, 0), (4, 3), (4, 3)]),
        track(id: "twinkle", title: "Twinkle, Twinkle", credit: "Traditional", bpm: 90,
              steps: [(4, 1), (4, 1), (5, 3), (5, 3), (5, 5), (5, 5), (5, 3),
                      (5, 1), (5, 1), (5, 0), (5, 0), (4, 3), (4, 3), (4, 1)]),
        track(id: "mary-lamb", title: "Mary Had a Little Lamb", credit: "Traditional", bpm: 90,
              steps: [(5, 0), (4, 3), (4, 1), (4, 3), (5, 0), (5, 0), (5, 0),
                      (4, 3), (4, 3), (4, 3), (5, 0), (5, 3), (5, 3)]),
        track(id: "jingle", title: "Jingle Bells", credit: "Traditional", bpm: 100,
              steps: [(5, 0), (5, 0), (5, 0), (5, 0), (5, 0), (5, 0),
                      (5, 0), (5, 3), (4, 1), (4, 3), (5, 0)]),
        // Recognizable public-domain single-note themes.
        track(id: "fur-elise", title: "Für Elise", credit: "Beethoven", bpm: 100,
              steps: [(5, 0), (4, 4), (5, 0), (4, 4), (5, 0), (4, 0), (4, 3), (4, 1), (3, 2)], repeats: 2),
        track(id: "mountain-king", title: "In the Hall of the Mountain King", credit: "Grieg", bpm: 100,
              steps: [(2, 2), (2, 4), (3, 0), (3, 2), (4, 0), (3, 0), (4, 0), (5, 0),
                      (2, 1), (2, 4), (3, 0), (3, 2), (4, 0), (3, 0), (4, 0), (5, 0)]),
        track(id: "beethoven-5", title: "Symphony No. 5", credit: "Beethoven", bpm: 100,
              steps: [(3, 0), (3, 0), (3, 0), (2, 1), (2, 3), (2, 3), (2, 3), (2, 0)], repeats: 2),
        track(id: "star-spangled", title: "The Star-Spangled Banner", credit: "Traditional", bpm: 80,
              steps: [(3, 0), (2, 2), (1, 3), (2, 2), (3, 0), (4, 1), (5, 0), (4, 3), (4, 1)]),
    ]

    // Default tracks are public-domain only. Copyrighted songs are not bundled;
    // users add their own via the import system.
    static let all: [HighwayTrack] = publicDomain
}
