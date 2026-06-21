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
    var steps: [[Int]]   // [internalString, fret, durationSixteenths]; string -1 = rest

    var track: HighwayTrack {
        let rhythm = steps.map { s -> (string: Int, fret: Int, beats: Double) in
            let sixteenths = s.count > 2 ? s[2] : 4          // default quarter (back-compat)
            return (string: s[0], fret: s[1], beats: Double(sixteenths) / 4.0)
        }
        return HighwayTrack(id: id, title: title, credit: "Imported", bpm: bpm,
                            notes: HighwayLibrary.notes(fromRhythm: rhythm), licensed: false)
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

    private func encode(_ steps: [(string: Int, fret: Int, beats: Double)]) -> [[Int]] {
        steps.map { [$0.string, $0.fret, Int(($0.beats * 4).rounded())] }
    }

    func add(title: String, bpm: Int, steps: [(string: Int, fret: Int, beats: Double)]) {
        guard steps.contains(where: { $0.string >= 0 }) else { return }
        let song = ImportedSong(id: "import-\(UUID().uuidString)",
                                title: title.isEmpty ? "My Song" : title,
                                bpm: max(30, min(240, bpm)),
                                steps: encode(steps))
        songs.append(song)
        save()
    }

    func update(id: String, title: String, bpm: Int, steps: [(string: Int, fret: Int, beats: Double)]) {
        guard steps.contains(where: { $0.string >= 0 }),
              let idx = songs.firstIndex(where: { $0.id == id }) else { return }
        songs[idx] = ImportedSong(id: id,
                                  title: title.isEmpty ? "My Song" : title,
                                  bpm: max(30, min(240, bpm)),
                                  steps: encode(steps))
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
