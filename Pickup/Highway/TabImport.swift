//
//  TabImport.swift
//  Parses a simple single-note tab into highway steps.
//  Token format: "string:fret" separated by spaces/commas/newlines, where
//  string 1 = high e (thinnest) … 6 = low E (thickest). e.g. "1:0 1:1 1:3 2:1"
//

import Foundation

enum TabImport {
    /// Parsed steps as internal (string 0 = low E … 5 = high e, fret).
    static func parse(_ text: String) -> [(string: Int, fret: Int)] {
        var steps: [(Int, Int)] = []
        let tokens = text.split(whereSeparator: { " \t\n\r,".contains($0) })
        for token in tokens {
            let parts = token.split(separator: ":")
            guard parts.count == 2,
                  let tabString = Int(parts[0]), let fret = Int(parts[1]),
                  (1...6).contains(tabString), (0...24).contains(fret) else { continue }
            steps.append((6 - tabString, fret))   // tab 1 = high e -> internal 5
        }
        return steps
    }
}
