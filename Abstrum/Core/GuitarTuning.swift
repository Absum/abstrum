//
//  GuitarTuning.swift
//  Standard-tuning open strings and nearest-string matching.
//

import Foundation

struct GuitarString: Identifiable, Equatable {
    let id: Int          // 0 = low E (6th string) … 5 = high e (1st string)
    let name: String     // "E", "A", "D", "G", "B", "E"
    let label: String    // scientific pitch, e.g. "E2"
    let frequency: Double
}

enum GuitarTuning {
    /// Standard tuning, low to high.
    static let standard: [GuitarString] = [
        GuitarString(id: 0, name: "E", label: "E2", frequency: 82.41),
        GuitarString(id: 1, name: "A", label: "A2", frequency: 110.00),
        GuitarString(id: 2, name: "D", label: "D3", frequency: 146.83),
        GuitarString(id: 3, name: "G", label: "G3", frequency: 196.00),
        GuitarString(id: 4, name: "B", label: "B3", frequency: 246.94),
        GuitarString(id: 5, name: "E", label: "E4", frequency: 329.63),
    ]

    /// Cents difference from a frequency to a target (negative = flat).
    static func cents(from frequency: Double, to target: GuitarString) -> Double {
        1200.0 * log2(frequency / target.frequency)
    }

    /// The string whose pitch is closest (in cents) to the given frequency.
    static func nearestString(toFrequency frequency: Double) -> (string: GuitarString, cents: Double) {
        let best = standard
            .map { (string: $0, cents: cents(from: frequency, to: $0)) }
            .min { abs($0.cents) < abs($1.cents) }!
        return best
    }
}
