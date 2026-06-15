//
//  Chord.swift
//  Chord model, qualities, the chord bank (curated open voicings + generated
//  movable barre shapes for every root), and chroma template matching.
//

import Foundation

enum ChordQuality: String, CaseIterable, Hashable {
    case major, minor, power, dom7, min7, maj7, sus2, sus4

    var label: String {
        switch self {
        case .major: return "Major"
        case .minor: return "Minor"
        case .power: return "5"
        case .dom7:  return "7"
        case .min7:  return "m7"
        case .maj7:  return "maj7"
        case .sus2:  return "sus2"
        case .sus4:  return "sus4"
        }
    }

    var suffix: String {
        switch self {
        case .major: return ""
        case .minor: return "m"
        case .power: return "5"
        case .dom7:  return "7"
        case .min7:  return "m7"
        case .maj7:  return "maj7"
        case .sus2:  return "sus2"
        case .sus4:  return "sus4"
        }
    }

    /// Semitone intervals above the root (for the detection template).
    var intervals: [Int] {
        switch self {
        case .major: return [0, 4, 7]
        case .minor: return [0, 3, 7]
        case .power: return [0, 7]
        case .dom7:  return [0, 4, 7, 10]
        case .min7:  return [0, 3, 7, 10]
        case .maj7:  return [0, 4, 7, 11]
        case .sus2:  return [0, 2, 7]
        case .sus4:  return [0, 5, 7]
        }
    }
}

/// A barre: one finger pressing several strings at the same fret.
struct Barre: Hashable {
    let fret: Int
    let fromString: Int
    let toString: Int
}

struct Chord: Identifiable, Hashable {
    let id: String
    let name: String
    let root: String
    let quality: ChordQuality
    let positions: [FretPosition]   // sounded strings (open or fretted)
    let mutedStrings: [Int]
    let pitchClasses: Set<Int>      // detection template (0 = C … 11 = B)
    let barre: Barre?
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
    static let rootNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    private static func pc(of root: String) -> Int { rootNames.firstIndex(of: root) ?? 0 }

    private static func p(_ string: Int, _ fret: Int) -> FretPosition { FretPosition(string: string, fret: fret) }

    private static func make(_ root: String, _ quality: ChordQuality,
                             _ positions: [FretPosition], muted: [Int] = []) -> Chord {
        let classes = Set(quality.intervals.map { (pc(of: root) + $0) % 12 })
        return Chord(id: root + quality.suffix, name: root + quality.suffix, root: root,
                     quality: quality, positions: positions, mutedStrings: muted,
                     pitchClasses: classes, barre: nil)
    }

    // MARK: - Curated open voicings (kept for their nicer open shapes)

    private static let curatedOpen: [Chord] = [
        make("E", .major, [p(0, 0), p(1, 2), p(2, 2), p(3, 1), p(4, 0), p(5, 0)]),
        make("A", .major, [p(1, 0), p(2, 2), p(3, 2), p(4, 2), p(5, 0)], muted: [0]),
        make("D", .major, [p(2, 0), p(3, 2), p(4, 3), p(5, 2)], muted: [0, 1]),
        make("G", .major, [p(0, 3), p(1, 2), p(2, 0), p(3, 0), p(4, 0), p(5, 3)]),
        make("C", .major, [p(1, 3), p(2, 2), p(3, 0), p(4, 1), p(5, 0)], muted: [0]),
        make("E", .minor, [p(0, 0), p(1, 2), p(2, 2), p(3, 0), p(4, 0), p(5, 0)]),
        make("A", .minor, [p(1, 0), p(2, 2), p(3, 2), p(4, 1), p(5, 0)], muted: [0]),
        make("D", .minor, [p(2, 0), p(3, 2), p(4, 3), p(5, 1)], muted: [0, 1]),
        make("E", .dom7, [p(0, 0), p(1, 2), p(2, 0), p(3, 1), p(4, 0), p(5, 0)]),
        make("A", .dom7, [p(1, 0), p(2, 2), p(3, 0), p(4, 2), p(5, 0)], muted: [0]),
        make("D", .dom7, [p(2, 0), p(3, 2), p(4, 1), p(5, 2)], muted: [0, 1]),
        make("G", .dom7, [p(0, 3), p(1, 2), p(2, 0), p(3, 0), p(4, 0), p(5, 1)]),
        make("C", .dom7, [p(1, 3), p(2, 2), p(3, 3), p(4, 1), p(5, 0)], muted: [0]),
        make("B", .dom7, [p(1, 2), p(2, 1), p(3, 2), p(4, 0), p(5, 2)], muted: [0]),
        make("E", .min7, [p(0, 0), p(1, 2), p(2, 2), p(3, 0), p(4, 3), p(5, 0)]),
        make("A", .min7, [p(1, 0), p(2, 2), p(3, 0), p(4, 1), p(5, 0)], muted: [0]),
        make("D", .min7, [p(2, 0), p(3, 2), p(4, 1), p(5, 1)], muted: [0, 1]),
        make("C", .maj7, [p(1, 3), p(2, 2), p(3, 0), p(4, 0), p(5, 0)], muted: [0]),
        make("A", .maj7, [p(1, 0), p(2, 2), p(3, 1), p(4, 2), p(5, 0)], muted: [0]),
        make("D", .maj7, [p(2, 0), p(3, 2), p(4, 2), p(5, 2)], muted: [0, 1]),
        make("F", .maj7, [p(2, 3), p(3, 2), p(4, 1), p(5, 0)], muted: [0, 1]),
        make("G", .maj7, [p(0, 3), p(1, 2), p(2, 0), p(3, 0), p(4, 0), p(5, 2)]),
        make("E", .maj7, [p(0, 0), p(1, 2), p(2, 1), p(3, 1), p(4, 0), p(5, 0)]),
        make("A", .sus2, [p(1, 0), p(2, 2), p(3, 2), p(4, 0), p(5, 0)], muted: [0]),
        make("D", .sus2, [p(2, 0), p(3, 2), p(4, 3), p(5, 0)], muted: [0, 1]),
        make("A", .sus4, [p(1, 0), p(2, 2), p(3, 2), p(4, 3), p(5, 0)], muted: [0]),
        make("D", .sus4, [p(2, 0), p(3, 2), p(4, 3), p(5, 3)], muted: [0, 1]),
        make("E", .sus4, [p(0, 0), p(1, 2), p(2, 2), p(3, 2), p(4, 0), p(5, 0)]),
    ]

    // MARK: - Movable shapes (offsets from the base fret; -1 = muted, 0 = barre)

    private struct Shape {
        let offsets: [Int]
        let rootString: Int
        let rootOpenPC: Int   // open pitch class of the root string (E=4, A=9, D=2)
        let isBarre: Bool
    }

    private static let shapes: [ChordQuality: [Shape]] = [
        .major: [Shape(offsets: [0, 2, 2, 1, 0, 0], rootString: 0, rootOpenPC: 4, isBarre: true),
                 Shape(offsets: [-1, 0, 2, 2, 2, 0], rootString: 1, rootOpenPC: 9, isBarre: true)],
        .minor: [Shape(offsets: [0, 2, 2, 0, 0, 0], rootString: 0, rootOpenPC: 4, isBarre: true),
                 Shape(offsets: [-1, 0, 2, 2, 1, 0], rootString: 1, rootOpenPC: 9, isBarre: true)],
        .dom7:  [Shape(offsets: [0, 2, 0, 1, 0, 0], rootString: 0, rootOpenPC: 4, isBarre: true),
                 Shape(offsets: [-1, 0, 2, 0, 2, 0], rootString: 1, rootOpenPC: 9, isBarre: true)],
        .min7:  [Shape(offsets: [0, 2, 0, 0, 0, 0], rootString: 0, rootOpenPC: 4, isBarre: true),
                 Shape(offsets: [-1, 0, 2, 0, 1, 0], rootString: 1, rootOpenPC: 9, isBarre: true)],
        .maj7:  [Shape(offsets: [0, 2, 1, 1, 0, 0], rootString: 0, rootOpenPC: 4, isBarre: true),
                 Shape(offsets: [-1, 0, 2, 1, 2, 0], rootString: 1, rootOpenPC: 9, isBarre: true)],
        .sus4:  [Shape(offsets: [0, 2, 2, 2, 0, 0], rootString: 0, rootOpenPC: 4, isBarre: true),
                 Shape(offsets: [-1, 0, 2, 2, 3, 0], rootString: 1, rootOpenPC: 9, isBarre: true)],
        .sus2:  [Shape(offsets: [-1, 0, 2, 2, 0, 0], rootString: 1, rootOpenPC: 9, isBarre: true)],
        .power: [Shape(offsets: [0, 2, 2, -1, -1, -1], rootString: 0, rootOpenPC: 4, isBarre: false),
                 Shape(offsets: [-1, 0, 2, 2, -1, -1], rootString: 1, rootOpenPC: 9, isBarre: false),
                 Shape(offsets: [-1, -1, 0, 2, 3, -1], rootString: 2, rootOpenPC: 2, isBarre: false)],
    ]

    private static func generate(rootPC: Int, quality: ChordQuality) -> Chord? {
        guard let candidates = shapes[quality] else { return nil }
        var chosen: (base: Int, shape: Shape)?
        for shape in candidates {
            let base = ((rootPC - shape.rootOpenPC) % 12 + 12) % 12
            if shape.isBarre && base == 0 { continue }   // base 0 = open = curated
            if chosen == nil || base < chosen!.base { chosen = (base, shape) }
        }
        guard let pick = chosen else { return nil }
        let base = pick.base
        var positions: [FretPosition] = []
        var muted: [Int] = []
        for s in 0..<6 {
            let o = pick.shape.offsets[s]
            if o < 0 { muted.append(s) } else { positions.append(p(s, base + o)) }
        }
        let root = rootNames[rootPC]
        let classes = Set(quality.intervals.map { (rootPC + $0) % 12 })
        let barre = (pick.shape.isBarre && base > 0)
            ? Barre(fret: base, fromString: pick.shape.rootString, toString: 5) : nil
        return Chord(id: root + quality.suffix, name: root + quality.suffix, root: root,
                     quality: quality, positions: positions, mutedStrings: muted,
                     pitchClasses: classes, barre: barre)
    }

    static let all: [Chord] = {
        var result = curatedOpen
        var seen = Set(result.map { $0.id })
        // Generate every root for every quality that isn't already curated.
        for quality in ChordQuality.allCases {
            for rootPC in 0..<12 {
                let id = rootNames[rootPC] + quality.suffix
                if seen.contains(id) { continue }
                if let chord = generate(rootPC: rootPC, quality: quality) {
                    result.append(chord)
                    seen.insert(id)
                }
            }
        }
        let order = ChordQuality.allCases
        return result.sorted {
            let qa = order.firstIndex(of: $0.quality)!, qb = order.firstIndex(of: $1.quality)!
            return qa != qb ? qa < qb : pc(of: $0.root) < pc(of: $1.root)
        }
    }()

    static func chords(quality: ChordQuality?) -> [Chord] {
        guard let quality else { return all }
        return all.filter { $0.quality == quality }
    }
}
