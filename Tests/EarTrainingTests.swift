//
//  EarTrainingTests.swift
//  Listen-and-answer question generation: correctness of prompts vs answers.
//

import XCTest

final class EarTrainingTests: XCTestCase {

    func testIntervalQuestionsEncodeTheAnswer() {
        var rng = SeededGenerator(seed: 7)
        let pool = [12, 7, 4]
        let questions = EarTraining.intervalQuestions(pool: pool, count: 20, using: &rng)
        XCTAssertEqual(questions.count, 20)
        for question in questions {
            XCTAssertEqual(question.choices, ["Octave", "Perfect 5th", "Major 3rd"])
            guard case .notes(let freqs, _) = question.prompt else {
                return XCTFail("interval prompt must be sequential notes")
            }
            XCTAssertEqual(freqs.count, 2)
            // The played interval must match the labelled answer.
            let semitones = 12.0 * log2(freqs[1] / freqs[0])
            XCTAssertEqual(semitones, Double(pool[question.answerIndex]), accuracy: 0.01)
        }
    }

    func testChordQualityQuestionsEncodeTheAnswer() {
        var rng = SeededGenerator(seed: 21)
        let pool: [ChordQuality] = [.major, .minor]
        let questions = EarTraining.chordQualityQuestions(pool: pool, count: 20, using: &rng)
        for question in questions {
            guard case .chord(let freqs) = question.prompt else {
                return XCTFail("quality prompt must be a chord")
            }
            // Reconstruct the third from the frequencies: major = 4, minor = 3.
            let third = 12.0 * log2(freqs[1] / freqs[0])
            let expected = pool[question.answerIndex] == .major ? 4.0 : 3.0
            XCTAssertEqual(third, expected, accuracy: 0.01)
        }
    }

    func testRhythmQuestionsUseRealPatterns() {
        var rng = SeededGenerator(seed: 3)
        let questions = EarTraining.rhythmQuestions(patternIndices: [0, 1, 3], count: 12,
                                                    bpm: 80, using: &rng)
        for question in questions {
            guard case .rhythm(let offsets, let bpm) = question.prompt else {
                return XCTFail("rhythm prompt expected")
            }
            XCTAssertEqual(bpm, 80)
            // The played offsets must be the pattern named by the answer.
            let display = question.choices[question.answerIndex]
            let match = EarTraining.rhythmPatterns.first { $0.display == display }
            XCTAssertEqual(offsets, match?.offsets)
        }
    }

    func testTheorySetsAnswerKeysAreSane() {
        for (id, set) in EarTraining.theorySets {
            XCTAssertFalse(set.isEmpty, "\(id) is empty")
            for question in set {
                XCTAssertTrue(question.choices.indices.contains(question.answerIndex),
                              "\(id): answer index out of range")
                XCTAssertEqual(Set(question.choices).count, question.choices.count,
                               "\(id): duplicate choices")
            }
        }
    }

    func testEarLessonsCarrySpecsAndNoSteps() {
        for lesson in LessonLibrary.all where lesson.ear != nil {
            XCTAssertTrue(lesson.steps.isEmpty, "\(lesson.id): ear drills have no mic steps")
            var rng = SeededGenerator(seed: 1)
            let questions = EarTraining.questions(for: lesson.ear!, using: &rng)
            XCTAssertEqual(questions.count, lesson.ear!.questionCount, "\(lesson.id)")
        }
        // The interval drills exist and chain.
        XCTAssertNotNil(LessonLibrary.earIntervals1.ear)
        XCTAssertEqual(LessonLibrary.earIntervals2.prerequisite, "ear-intervals-1")
    }

    func testRhythmSynthPlacesTicksAtOffsets() {
        let sr = 44_100.0
        let samples = ToneSynth.rhythm(beatOffsets: [0, 1, 1.5], bpm: 60, sampleRate: sr)
        XCTAssertFalse(samples.isEmpty)
        XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 1.0 })
        // Energy exists right after each tick offset (1 beat = 1s at 60 bpm)…
        for offset in [0.0, 1.0, 1.5] {
            let start = Int(offset * sr)
            let window = Array(samples[start..<min(samples.count, start + 2000)])
            XCTAssertTrue(window.contains { abs($0) > 0.05 }, "no tick at beat \(offset)")
        }
        // …and silence in the gap between beat 0's decay and beat 1.
        let gap = Array(samples[Int(0.5 * sr)..<Int(0.9 * sr)])
        XCTAssertTrue(gap.allSatisfy { abs($0) < 0.05 }, "gap between ticks should be quiet")
    }
}
