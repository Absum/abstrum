//
//  TabImport.swift
//  Parses a simple single-note tab into highway steps.
//  Token format: "string:fret" separated by spaces/commas/newlines, where
//  string 1 = high e (thinnest) … 6 = low E (thickest). e.g. "1:0 1:1 1:3 2:1"
//

import Foundation

enum TabImport {
    /// Parsed steps as internal (string 0 = low E … 5 = high e; string -1 = rest)
    /// with a duration in beats. A note token is "string:fret" + optional value
    /// letter (w/h/q/e/s, dotted with '.'); a rest is "r" + optional value letter.
    static func parse(_ text: String) -> [(string: Int, fret: Int, beats: Double)] {
        var steps: [(Int, Int, Double)] = []
        let tokens = text.split(whereSeparator: { " \t\n\r,".contains($0) })
        for raw in tokens {
            let token = raw.lowercased()
            if token.first == "r" {                      // rest
                steps.append((-1, 0, value(of: token.dropFirst())))
                continue
            }
            let parts = token.split(separator: ":")
            guard parts.count == 2, let tabString = Int(parts[0]), (1...6).contains(tabString) else { continue }
            let fretDigits = parts[1].prefix { $0.isNumber }
            guard let fret = Int(fretDigits), (0...24).contains(fret) else { continue }
            let valuePart = parts[1].drop { $0.isNumber }
            steps.append((6 - tabString, fret, value(of: valuePart)))   // tab 1 = high e -> internal 5
        }
        return steps
    }

    /// Value letter -> beats (default quarter). 'w'hole=4, 'h'alf=2, 'q'uarter=1,
    /// 'e'ighth=0.5, 's'ixteenth=0.25; a trailing '.' dots it (×1.5).
    static func value(of s: Substring) -> Double {
        guard let first = s.first else { return 1 }
        let base: Double
        switch first {
        case "w": base = 4
        case "h": base = 2
        case "q": base = 1
        case "e": base = 0.5
        case "s": base = 0.25
        default: return 1
        }
        return s.contains(".") ? base * 1.5 : base
    }

    /// Beats -> value letter (for rebuilding token text when editing).
    static func letter(forBeats b: Double) -> String {
        let table: [(Double, String)] = [(4, "w"), (3, "h."), (2, "h"), (1.5, "q."),
                                          (1, "q"), (0.75, "e."), (0.5, "e"), (0.375, "s."), (0.25, "s")]
        for (val, l) in table where abs(b - val) < 0.01 { return l }
        return "q"
    }
}
