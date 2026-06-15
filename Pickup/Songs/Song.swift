//
//  Song.swift
//  Play-along song charts (public-domain / original) — one chord per bar.
//

import Foundation

struct Song: Identifiable, Hashable {
    let id: String
    let title: String
    let credit: String       // "Traditional", "Pachelbel", "Original"…
    let bpm: Int
    let beatsPerBar: Int
    let barChordIDs: [String] // one chord id per bar

    /// Resolved chords, one per bar (skips any unknown id — guarded by tests).
    var bars: [Chord] {
        barChordIDs.compactMap { id in ChordBank.all.first { $0.id == id } }
    }
}

enum SongLibrary {
    static let all: [Song] = [
        Song(id: "blues-a", title: "12-Bar Blues in A", credit: "Traditional",
             bpm: 100, beatsPerBar: 4,
             barChordIDs: ["A", "A", "A", "A", "D", "D", "A", "A", "E", "D", "A", "E"]),
        Song(id: "rising-sun", title: "House of the Rising Sun", credit: "Traditional",
             bpm: 90, beatsPerBar: 4,
             barChordIDs: ["Am", "C", "D", "F", "Am", "C", "E", "E"]),
        Song(id: "canon-d", title: "Canon in D", credit: "Pachelbel",
             bpm: 80, beatsPerBar: 4,
             barChordIDs: ["D", "A", "Bm", "F#m", "G", "D", "G", "A"]),
        Song(id: "folk-g", title: "Simple Folk Song", credit: "Original",
             bpm: 96, beatsPerBar: 4,
             barChordIDs: ["G", "G", "C", "G", "Em", "C", "D", "G"]),
        Song(id: "auld-lang-syne", title: "Auld Lang Syne", credit: "Traditional",
             bpm: 90, beatsPerBar: 4,
             barChordIDs: ["G", "C", "G", "D", "G", "C", "D", "G"]),
        Song(id: "amazing-grace", title: "Amazing Grace", credit: "Traditional",
             bpm: 80, beatsPerBar: 3,
             barChordIDs: ["G", "G", "C", "G", "G", "D", "G", "G"]),
        Song(id: "scarborough", title: "Scarborough Fair", credit: "Traditional",
             bpm: 96, beatsPerBar: 3,
             barChordIDs: ["Am", "G", "Am", "Am", "C", "G", "Am", "Am"]),
        Song(id: "greensleeves", title: "Greensleeves", credit: "Traditional",
             bpm: 90, beatsPerBar: 3,
             barChordIDs: ["Am", "G", "C", "Am", "Am", "E", "Am", "E"]),
        Song(id: "drunken-sailor", title: "Drunken Sailor", credit: "Traditional",
             bpm: 110, beatsPerBar: 4,
             barChordIDs: ["Dm", "Dm", "C", "C", "Dm", "Dm", "C", "Dm"]),
        Song(id: "ode-to-joy", title: "Ode to Joy", credit: "Beethoven",
             bpm: 100, beatsPerBar: 4,
             barChordIDs: ["C", "C", "G", "C", "C", "G", "C", "C"]),
        Song(id: "saints", title: "When the Saints Go Marching In", credit: "Traditional",
             bpm: 100, beatsPerBar: 4,
             barChordIDs: ["G", "G", "C", "G", "G", "D", "G", "G"]),
        Song(id: "wild-rover", title: "The Wild Rover", credit: "Traditional",
             bpm: 120, beatsPerBar: 3,
             barChordIDs: ["G", "C", "G", "G", "C", "D", "G", "G"]),
        Song(id: "blues-e", title: "12-Bar Blues in E", credit: "Traditional",
             bpm: 96, beatsPerBar: 4,
             barChordIDs: ["E7", "E7", "E7", "E7", "A7", "A7", "E7", "E7", "B7", "A7", "E7", "B7"]),
    ]
}
