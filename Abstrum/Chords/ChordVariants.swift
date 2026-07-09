//
//  ChordVariants.swift
//  Alternate voicings for everyday chords, with when-to-use guidance. Lessons
//  teach exactly one canonical voicing (cognitive load: one shape at a time);
//  variants surface in the Chords reference tab and after mastery — never
//  during first acquisition.
//

import Foundation

struct ChordVariant: Identifiable {
    let chord: Chord
    let label: String       // short picker label, e.g. "4-finger"
    let whenToUse: String
    var id: String { chord.id }
}

enum ChordVariants {
    /// All the ways to play a chord: the canonical bank voicing first, then
    /// the alternates. Empty when a chord has no registered variants (most).
    static func variants(for chordID: String) -> [ChordVariant] {
        guard let entry = registry[chordID],
              let canonical = ChordBank.all.first(where: { $0.id == chordID }) else { return [] }
        return [ChordVariant(chord: canonical, label: entry.canonicalLabel,
                             whenToUse: entry.canonicalNote)] + entry.alternates
    }

    /// Whether a chord has more than one registered way to play it.
    static func hasAlternates(_ chordID: String) -> Bool { registry[chordID] != nil }

    // MARK: - Registry

    private struct Entry {
        let canonicalLabel: String
        let canonicalNote: String
        let alternates: [ChordVariant]
    }

    private static let registry: [String: Entry] = [
        "G": Entry(
            canonicalLabel: "3-finger",
            canonicalNote: "The easiest first G — this is the one the lessons teach.",
            alternates: [ChordVariant(
                chord: make("G-4finger", name: "G", root: "G", quality: .major,
                            positions: [pos(0, 3, 2), pos(1, 2, 1), pos(2, 0), pos(3, 0),
                                        pos(4, 3, 3), pos(5, 3, 4)]),
                label: "4-finger",
                whenToUse: "Ring and pinky stay planted through G→C and G→D — quicker changes and a fuller top end.")]),
        "A": Entry(
            canonicalLabel: "3-finger",
            canonicalNote: "Three fingers stacked on fret 2 — the standard A.",
            alternates: [ChordVariant(
                chord: make("A-mini-barre", name: "A", root: "A", quality: .major,
                            positions: [pos(1, 0), pos(2, 2, 1), pos(3, 2, 1), pos(4, 2, 1), pos(5, 0)],
                            muted: [0], barre: Barre(fret: 2, fromString: 2, toString: 4)),
                label: "mini-barre",
                whenToUse: "One finger frets all three notes — quick changes, and a first taste of barring before the F.")]),
        "C": Entry(
            canonicalLabel: "standard",
            canonicalNote: "The classic open C.",
            alternates: [ChordVariant(
                chord: make("C-pinky-g", name: "C", root: "C", quality: .major,
                            positions: [pos(1, 3, 3), pos(2, 2, 2), pos(3, 0), pos(4, 1, 1), pos(5, 3, 4)],
                            muted: [0]),
                label: "pinky G",
                whenToUse: "The pinky rings a G on top — the C→G change barely has to move.")]),
    ]

    // MARK: - Builders

    private static func pos(_ string: Int, _ fret: Int, _ finger: Int = 0) -> FretPosition {
        FretPosition(string: string, fret: fret, finger: finger)
    }

    private static func make(_ id: String, name: String, root: String, quality: ChordQuality,
                             positions: [FretPosition], muted: [Int] = [],
                             barre: Barre? = nil) -> Chord {
        let rootPC = ChordBank.rootNames.firstIndex(of: root) ?? 0
        let classes = Set(quality.intervals.map { (rootPC + $0) % 12 })
        return Chord(id: id, name: name, root: root, quality: quality, positions: positions,
                     mutedStrings: muted, pitchClasses: classes, barre: barre)
    }
}
