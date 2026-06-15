//
//  ImportStore.swift
//  Persisted user-imported highway songs (Codable JSON in Application Support).
//

import Foundation
import Observation

struct ImportedSong: Codable, Identifiable, Hashable {
    let id: String
    var title: String
    var bpm: Int
    var steps: [[Int]]   // [internalString, fret] per beat

    var track: HighwayTrack {
        HighwayTrack(id: id, title: title, credit: "Imported", bpm: bpm,
                     notes: HighwayLibrary.notes(from: steps.map { (string: $0[0], fret: $0[1]) }),
                     licensed: false)
    }
}

@Observable
final class ImportStore {
    static let shared = ImportStore()

    private(set) var songs: [ImportedSong] = []
    private let fileURL: URL

    init(directory: URL? = nil, filename: String = "imported-songs.json") {
        let dir = directory ?? FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        fileURL = dir.appendingPathComponent(filename)
        load()
    }

    var tracks: [HighwayTrack] { songs.map { $0.track } }

    func add(title: String, bpm: Int, steps: [(string: Int, fret: Int)]) {
        guard !steps.isEmpty else { return }
        let song = ImportedSong(id: "import-\(UUID().uuidString)",
                                title: title.isEmpty ? "My Song" : title,
                                bpm: max(30, min(240, bpm)),
                                steps: steps.map { [$0.string, $0.fret] })
        songs.append(song)
        save()
    }

    func delete(_ id: String) {
        songs.removeAll { $0.id == id }
        save()
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? JSONDecoder().decode([ImportedSong].self, from: data) else { return }
        songs = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(songs) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
