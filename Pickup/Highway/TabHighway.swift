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
    var duration: Double = 1   // length in beats
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
    private static func note(_ id: Int, beat: Double, string: Int, fret: Int, duration: Double) -> HighwayNote {
        let freq = GuitarTuning.standard[string].frequency * pow(2.0, Double(fret) / 12.0)
        return HighwayNote(id: id, beat: beat, string: string, fret: fret, frequency: freq, duration: duration)
    }

    /// Build highway notes from rhythmic steps (string < 0 = rest), accumulating
    /// the start beat from each step's duration. Used by song import.
    static func notes(fromRhythm steps: [(string: Int, fret: Int, beats: Double)]) -> [HighwayNote] {
        var result: [HighwayNote] = []
        var beat = 0.0
        var id = 0
        for step in steps {
            let beats = max(0.0625, step.beats)
            if step.string >= 0 {
                result.append(note(id, beat: beat,
                                   string: min(5, max(0, step.string)), fret: max(0, step.fret),
                                   duration: beats))
                id += 1
            }
            beat += beats
        }
        return result
    }

    /// One quarter-note per step: (string, fret).
    private static func track(id: String, title: String, credit: String, bpm: Int,
                              steps: [(Int, Int)], repeats: Int = 1, licensed: Bool = false) -> HighwayTrack {
        let full = Array(repeating: steps, count: max(1, repeats)).flatMap { $0 }
        let rhythm = full.map { (string: $0.0, fret: $0.1, beats: 1.0) }
        return HighwayTrack(id: id, title: title, credit: credit, bpm: bpm,
                            notes: notes(fromRhythm: rhythm), licensed: licensed)
    }

    /// Rhythmic track: each step is (string, fret, beats). string < 0 = rest.
    private static func track(id: String, title: String, credit: String, bpm: Int,
                              rhythm steps: [(Int, Int, Double)], repeats: Int = 1,
                              licensed: Bool = false) -> HighwayTrack {
        let full = Array(repeating: steps, count: max(1, repeats)).flatMap { $0 }
        let mapped = full.map { (string: $0.0, fret: $0.1, beats: $0.2) }
        return HighwayTrack(id: id, title: title, credit: credit, bpm: bpm,
                            notes: notes(fromRhythm: mapped), licensed: licensed)
    }

    private static let publicDomain: [HighwayTrack] = [
        // Warm-up stays even quarter-notes by design.
        track(id: "ladder", title: "Open String Ladder", credit: "Warm-up", bpm: 60,
              steps: [(0, 0), (1, 0), (2, 0), (3, 0), (4, 0), (5, 0),
                      (4, 0), (3, 0), (2, 0), (1, 0), (0, 0)]),
        // Quarters through the phrases, with the closing "E. D D" dotted figure.
        track(id: "ode-to-joy", title: "Ode to Joy", credit: "Beethoven", bpm: 80,
              rhythm: [(5, 0, 1), (5, 0, 1), (5, 1, 1), (5, 3, 1), (5, 3, 1), (5, 1, 1), (5, 0, 1), (4, 3, 1),
                       (4, 1, 1), (4, 1, 1), (4, 3, 1), (5, 0, 1), (5, 0, 1.5), (4, 3, 0.5), (4, 3, 2)]),
        // Quarters with a half-note on "star" and the final note.
        track(id: "twinkle", title: "Twinkle, Twinkle", credit: "Traditional", bpm: 90,
              rhythm: [(4, 1, 1), (4, 1, 1), (5, 3, 1), (5, 3, 1), (5, 5, 1), (5, 5, 1), (5, 3, 2),
                       (5, 1, 1), (5, 1, 1), (5, 0, 1), (5, 0, 1), (4, 3, 1), (4, 3, 1), (4, 1, 2)]),
        track(id: "mary-lamb", title: "Mary Had a Little Lamb", credit: "Traditional", bpm: 90,
              rhythm: [(5, 0, 1), (4, 3, 1), (4, 1, 1), (4, 3, 1), (5, 0, 1), (5, 0, 1), (5, 0, 2),
                       (4, 3, 1), (4, 3, 1), (4, 3, 2), (5, 0, 1), (5, 3, 1), (5, 3, 2)]),
        // "Jingle bells" = two quarters + a half, twice; then the run home.
        track(id: "jingle", title: "Jingle Bells", credit: "Traditional", bpm: 100,
              rhythm: [(5, 0, 1), (5, 0, 1), (5, 0, 2), (5, 0, 1), (5, 0, 1), (5, 0, 2),
                       (5, 0, 1), (5, 3, 1), (4, 1, 1.5), (4, 3, 0.5), (5, 0, 2)]),
        // Recognizable public-domain single-note themes.
        // Für Elise opens on a run of even eighth notes.
        track(id: "fur-elise", title: "Für Elise", credit: "Beethoven", bpm: 100,
              rhythm: [(5, 0, 0.5), (4, 4, 0.5), (5, 0, 0.5), (4, 4, 0.5), (5, 0, 0.5),
                       (4, 0, 0.5), (4, 3, 0.5), (4, 1, 0.5), (3, 2, 1)], repeats: 2),
        // Grieg's creeping march: staccato eighths rising to a held step.
        track(id: "mountain-king", title: "In the Hall of the Mountain King", credit: "Grieg", bpm: 110,
              rhythm: [(2, 2, 0.5), (2, 4, 0.5), (3, 0, 0.5), (3, 2, 0.5), (4, 0, 0.5), (3, 0, 0.5), (4, 0, 0.5), (5, 0, 1),
                       (2, 1, 0.5), (2, 4, 0.5), (3, 0, 0.5), (3, 2, 0.5), (4, 0, 0.5), (3, 0, 0.5), (4, 0, 0.5), (5, 0, 1)]),
        // The famous "short-short-short-long" motif.
        track(id: "beethoven-5", title: "Symphony No. 5", credit: "Beethoven", bpm: 108,
              rhythm: [(3, 0, 0.5), (3, 0, 0.5), (3, 0, 0.5), (2, 1, 2),
                       (2, 3, 0.5), (2, 3, 0.5), (2, 3, 0.5), (2, 0, 2)], repeats: 2),
        track(id: "star-spangled", title: "The Star-Spangled Banner", credit: "Traditional", bpm: 80,
              rhythm: [(3, 0, 1.5), (2, 2, 0.5), (1, 3, 1), (2, 2, 1), (3, 0, 1), (4, 1, 1),
                       (5, 0, 2), (4, 3, 1), (4, 1, 1)]),
        // Rossini's gallop — two sixteenths + an eighth, the rhythm showcase.
        track(id: "william-tell", title: "William Tell Overture", credit: "Rossini", bpm: 132,
              rhythm: [(5, 0, 0.25), (5, 0, 0.25), (5, 0, 0.5), (5, 0, 0.25), (5, 0, 0.25), (5, 0, 0.5),
                       (5, 0, 0.25), (5, 0, 0.25), (5, 0, 0.5), (5, 0, 1),
                       (5, 0, 0.5), (5, 3, 0.5), (5, 5, 0.5), (5, 3, 0.5), (5, 0, 2)], repeats: 2),
    ]

    // Default tracks are public-domain only. Copyrighted songs are not bundled;
    // users add their own via the import system.
    static let all: [HighwayTrack] = publicDomain
}
