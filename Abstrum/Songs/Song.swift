//
//  Song.swift
//  Play-along song charts — one chord per bar. Repertoire is public-domain or
//  original only (owner decision: nothing licensed); users add their own songs
//  via the tab-highway import.
//

import Foundation

enum SongDifficulty: Int, CaseIterable, Comparable {
    case beginner, easy, intermediate

    var label: String {
        switch self {
        case .beginner:     return "Beginner"
        case .easy:         return "Easy"
        case .intermediate: return "Intermediate"
        }
    }

    static func < (lhs: SongDifficulty, rhs: SongDifficulty) -> Bool { lhs.rawValue < rhs.rawValue }
}

struct Song: Identifiable, Hashable {
    let id: String
    let title: String
    let credit: String       // "Traditional", "Pachelbel", "Original"…
    let bpm: Int
    let beatsPerBar: Int
    let difficulty: SongDifficulty
    let barChordIDs: [String] // one chord id per bar

    /// Resolved chords, one per bar (skips any unknown id — guarded by tests).
    var bars: [Chord] {
        barChordIDs.compactMap { id in ChordBank.all.first { $0.id == id } }
    }
}

enum SongLibrary {
    /// Graded: beginner = the open-chord family at an easy pace; easy = minor
    /// colour / brisker tempo; intermediate = barre chords or 7th voicings.
    static let all: [Song] = [
        // MARK: Beginner — open chords, steady tempos
        Song(id: "folk-g", title: "Simple Folk Song", credit: "Original",
             bpm: 96, beatsPerBar: 4, difficulty: .beginner,
             barChordIDs: ["G", "G", "C", "G", "Em", "C", "D", "G"]),
        Song(id: "auld-lang-syne", title: "Auld Lang Syne", credit: "Traditional",
             bpm: 90, beatsPerBar: 4, difficulty: .beginner,
             barChordIDs: ["G", "C", "G", "D", "G", "C", "D", "G"]),
        Song(id: "amazing-grace", title: "Amazing Grace", credit: "Traditional",
             bpm: 80, beatsPerBar: 3, difficulty: .beginner,
             barChordIDs: ["G", "G", "C", "G", "G", "D", "G", "G"]),
        Song(id: "ode-to-joy", title: "Ode to Joy", credit: "Beethoven",
             bpm: 100, beatsPerBar: 4, difficulty: .beginner,
             barChordIDs: ["C", "C", "G", "C", "C", "G", "C", "C"]),
        Song(id: "saints", title: "When the Saints Go Marching In", credit: "Traditional",
             bpm: 100, beatsPerBar: 4, difficulty: .beginner,
             barChordIDs: ["G", "G", "C", "G", "G", "D", "G", "G"]),
        Song(id: "oh-susanna", title: "Oh! Susanna", credit: "Foster",
             bpm: 110, beatsPerBar: 4, difficulty: .beginner,
             barChordIDs: ["G", "G", "G", "D", "G", "G", "D", "G"]),
        Song(id: "happy-birthday", title: "Happy Birthday", credit: "Traditional",
             bpm: 90, beatsPerBar: 3, difficulty: .beginner,
             barChordIDs: ["G", "D", "D", "G", "G", "C", "G", "G"]),
        Song(id: "kumbaya", title: "Kumbaya", credit: "Traditional",
             bpm: 84, beatsPerBar: 3, difficulty: .beginner,
             barChordIDs: ["G", "C", "G", "G", "C", "G", "D", "G"]),
        Song(id: "twinkle", title: "Twinkle, Twinkle", credit: "Traditional",
             bpm: 88, beatsPerBar: 4, difficulty: .beginner,
             barChordIDs: ["G", "C", "G", "D", "G", "C", "D", "G"]),

        // MARK: Easy — minor colour, brisker tempos
        Song(id: "blues-a", title: "12-Bar Blues in A", credit: "Traditional",
             bpm: 100, beatsPerBar: 4, difficulty: .easy,
             barChordIDs: ["A", "A", "A", "A", "D", "D", "A", "A", "E", "D", "A", "E"]),
        Song(id: "scarborough", title: "Scarborough Fair", credit: "Traditional",
             bpm: 96, beatsPerBar: 3, difficulty: .easy,
             barChordIDs: ["Am", "G", "Am", "Am", "C", "G", "Am", "Am"]),
        Song(id: "greensleeves", title: "Greensleeves", credit: "Traditional",
             bpm: 90, beatsPerBar: 3, difficulty: .easy,
             barChordIDs: ["Am", "G", "C", "Am", "Am", "E", "Am", "E"]),
        Song(id: "drunken-sailor", title: "Drunken Sailor", credit: "Traditional",
             bpm: 110, beatsPerBar: 4, difficulty: .easy,
             barChordIDs: ["Dm", "Dm", "C", "C", "Dm", "Dm", "C", "Dm"]),
        Song(id: "wild-rover", title: "The Wild Rover", credit: "Traditional",
             bpm: 120, beatsPerBar: 3, difficulty: .easy,
             barChordIDs: ["G", "C", "G", "G", "C", "D", "G", "G"]),
        Song(id: "minuet-g", title: "Minuet in G", credit: "Petzold",
             bpm: 104, beatsPerBar: 3, difficulty: .easy,
             barChordIDs: ["G", "C", "G", "D", "Em", "C", "D", "G"]),

        // MARK: Intermediate — barre chords or 7th voicings
        Song(id: "rising-sun", title: "House of the Rising Sun", credit: "Traditional",
             bpm: 90, beatsPerBar: 4, difficulty: .intermediate,
             barChordIDs: ["Am", "C", "D", "F", "Am", "C", "E", "E"]),
        Song(id: "canon-d", title: "Canon in D", credit: "Pachelbel",
             bpm: 80, beatsPerBar: 4, difficulty: .intermediate,
             barChordIDs: ["D", "A", "Bm", "F#m", "G", "D", "G", "A"]),
        Song(id: "blues-e", title: "12-Bar Blues in E", credit: "Traditional",
             bpm: 96, beatsPerBar: 4, difficulty: .intermediate,
             barChordIDs: ["E7", "E7", "E7", "E7", "A7", "A7", "E7", "E7", "B7", "A7", "E7", "B7"]),
        Song(id: "danny-boy", title: "Danny Boy", credit: "Traditional",
             bpm: 76, beatsPerBar: 4, difficulty: .intermediate,
             barChordIDs: ["C", "C7", "F", "C", "F", "C", "G", "C"]),
        Song(id: "streets-laredo", title: "Streets of Laredo", credit: "Traditional",
             bpm: 100, beatsPerBar: 3, difficulty: .intermediate,
             barChordIDs: ["C", "G", "C", "G", "C", "F", "G", "C"]),
    ]

    /// Songs of one difficulty, in library order.
    static func songs(_ difficulty: SongDifficulty) -> [Song] {
        all.filter { $0.difficulty == difficulty }
    }
}
