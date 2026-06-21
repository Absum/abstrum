//
//  NoteMath.swift
//  Frequency <-> note-name conversion (equal temperament, A4 = 440 Hz).
//

import Foundation

enum NoteMath {
    static let noteNames = ["C", "C♯", "D", "D♯", "E", "F",
                            "F♯", "G", "G♯", "A", "A♯", "B"]

    static let concertA = 440.0

    struct Reading {
        let name: String      // e.g. "E"
        let octave: Int       // scientific pitch notation octave
        let cents: Double     // -50...+50, deviation from the nearest note
        let frequency: Double

        var displayName: String { "\(name)\(octave)" }
        var isInTune: Bool { abs(cents) < 5 }
    }

    /// Map a frequency in Hz to the nearest note plus cents deviation.
    static func reading(forFrequency frequency: Double) -> Reading? {
        guard frequency > 0 else { return nil }
        let midi = 69.0 + 12.0 * log2(frequency / concertA)
        let nearest = midi.rounded()
        let cents = (midi - nearest) * 100.0
        let index = (Int(nearest) % 12 + 12) % 12
        let octave = Int(nearest) / 12 - 1
        return Reading(name: noteNames[index],
                       octave: octave,
                       cents: cents,
                       frequency: frequency)
    }
}
