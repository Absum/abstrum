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
}

enum HighwayLibrary {
    private static func note(_ id: Int, beat: Double, string: Int, fret: Int) -> HighwayNote {
        let freq = GuitarTuning.standard[string].frequency * pow(2.0, Double(fret) / 12.0)
        return HighwayNote(id: id, beat: beat, string: string, fret: fret, frequency: freq)
    }

    /// One quarter-note per step: (string, fret).
    private static func track(id: String, title: String, credit: String, bpm: Int,
                              steps: [(Int, Int)]) -> HighwayTrack {
        let notes = steps.enumerated().map { i, step in
            note(i, beat: Double(i), string: step.0, fret: step.1)
        }
        return HighwayTrack(id: id, title: title, credit: credit, bpm: bpm, notes: notes)
    }

    static let all: [HighwayTrack] = [
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
    ]
}
