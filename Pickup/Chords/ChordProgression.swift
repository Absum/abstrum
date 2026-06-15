//
//  ChordProgression.swift
//  Preset chord progressions for change practice.
//

import Foundation

struct ChordProgression: Identifiable, Hashable {
    let id: String
    let name: String
    let subtitle: String
    let chordIDs: [String]

    var chords: [Chord] {
        chordIDs.compactMap { id in ChordBank.all.first { $0.id == id } }
    }
}

enum ChordProgressions {
    static let all: [ChordProgression] = [
        ChordProgression(id: "g-c", name: "G – C",
                         subtitle: "Two-chord warm-up", chordIDs: ["G", "C"]),
        ChordProgression(id: "g-c-d", name: "G – C – D",
                         subtitle: "I–IV–V · three-chord classic", chordIDs: ["G", "C", "D"]),
        ChordProgression(id: "em-c-g-d", name: "Em – C – G – D",
                         subtitle: "The four-chord pop loop", chordIDs: ["Em", "C", "G", "D"]),
        ChordProgression(id: "am-f-c-g", name: "Am – F – C – G",
                         subtitle: "Four-chord loop in C", chordIDs: ["Am", "F", "C", "G"]),
        ChordProgression(id: "e-a", name: "E – A",
                         subtitle: "I–IV · easy first changes", chordIDs: ["E", "A"]),
        ChordProgression(id: "am-dm-e", name: "Am – Dm – E",
                         subtitle: "i–iv–V · minor cadence", chordIDs: ["Am", "Dm", "E"]),
    ]
}
