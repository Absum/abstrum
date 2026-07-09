//
//  ChordVariantTests.swift
//  Alternate voicings: registry integrity and detection compatibility.
//

import XCTest

final class ChordVariantTests: XCTestCase {

    func testVariantChordsHaveAlternates() {
        for id in ["G", "A", "C"] {
            XCTAssertTrue(ChordVariants.hasAlternates(id), "\(id) should have variants")
            XCTAssertGreaterThan(ChordVariants.variants(for: id).count, 1)
        }
        XCTAssertFalse(ChordVariants.hasAlternates("Em"))
        XCTAssertTrue(ChordVariants.variants(for: "Em").isEmpty)
    }

    func testCanonicalVoicingComesFirstAndIsTheBankChord() throws {
        let g = try XCTUnwrap(ChordVariants.variants(for: "G").first)
        let bankG = try XCTUnwrap(ChordBank.all.first { $0.id == "G" })
        XCTAssertEqual(g.chord.positions, bankG.positions)
        XCTAssertEqual(g.chord.id, "G")
    }

    func testVariantsAreDetectionCompatible() throws {
        // Every alternate voicing must share the canonical chord's pitch-class
        // template — the detector can't tell voicings apart, by design.
        for id in ["G", "A", "C"] {
            let variants = ChordVariants.variants(for: id)
            let canonical = try XCTUnwrap(variants.first)
            for variant in variants.dropFirst() {
                XCTAssertEqual(variant.chord.pitchClasses, canonical.chord.pitchClasses,
                               "\(variant.chord.id) must match \(id)'s template")
                XCTAssertNotEqual(variant.chord.positions, canonical.chord.positions,
                                  "\(variant.chord.id) should actually differ in fingering")
                XCTAssertEqual(variant.chord.name, canonical.chord.name,
                               "variants display the same chord name")
                XCTAssertFalse(variant.whenToUse.isEmpty)
            }
        }
    }

    func testVariantIDsDoNotCollideWithTheBank() {
        let bankIDs = Set(ChordBank.all.map { $0.id })
        for id in ["G", "A", "C"] {
            for variant in ChordVariants.variants(for: id).dropFirst() {
                XCTAssertFalse(bankIDs.contains(variant.chord.id),
                               "\(variant.chord.id) collides with a bank chord id")
            }
        }
    }

    func testVariantPositionsAreValidFretboardPositions() {
        for id in ["G", "A", "C"] {
            for variant in ChordVariants.variants(for: id) {
                for p in variant.chord.positions {
                    XCTAssertTrue((0...5).contains(p.string), "\(variant.chord.id): bad string")
                    XCTAssertTrue((0...12).contains(p.fret), "\(variant.chord.id): bad fret")
                }
                // No sounded string may also be muted.
                let sounded = Set(variant.chord.positions.map { $0.string })
                XCTAssertTrue(sounded.isDisjoint(with: variant.chord.mutedStrings),
                              "\(variant.chord.id): string both sounded and muted")
            }
        }
    }
}
