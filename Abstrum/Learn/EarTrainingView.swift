//
//  EarTrainingView.swift
//  Plays a listen-and-answer ear drill: hear the synthesized prompt, tap the
//  answer, immediate feedback. No mic. Scores feed recordRun like any lesson,
//  so ear skills earn mastery, spaced reviews, and daily-session slots.
//

import Observation
import SwiftUI

@Observable
final class EarTrainingViewModel {
    let lesson: Lesson
    private(set) var questions: [EarTraining.Question] = []
    var index = 0
    var selected: Int?
    var correct = 0
    var isComplete = false
    var lastRunScore = 0.0

    private let player = TonePlayer()
    private let store: ProgressStore

    init(lesson: Lesson, store: ProgressStore = .shared) {
        self.lesson = lesson
        self.store = store
        var rng = SystemRandomNumberGenerator()
        if let spec = lesson.ear {
            questions = EarTraining.questions(for: spec, using: &rng)
        }
    }

    var current: EarTraining.Question? {
        questions.indices.contains(index) ? questions[index] : nil
    }
    var hasPrompt: Bool {
        if case .silent = current?.prompt { return false }
        return current != nil
    }

    var mastery: Double { store.mastery(of: lesson.id) }
    var isMastered: Bool { mastery >= ProgressStore.masteryThreshold }

    func playPrompt() {
        switch current?.prompt {
        case .notes(let frequencies, let gap): player.playSequence(frequencies, gap: gap)
        case .chord(let frequencies):          player.playChord(frequencies)
        case .rhythm(let offsets, let bpm):    player.playRhythm(beatOffsets: offsets, bpm: bpm)
        case .silent, .none:                   break
        }
    }

    func choose(_ choice: Int) {
        guard selected == nil, let question = current else { return }
        selected = choice
        if choice == question.answerIndex { correct += 1 }
    }

    func next() {
        guard selected != nil else { return }
        if index + 1 < questions.count {
            index += 1
            selected = nil
            playPrompt()
        } else {
            isComplete = true
            lastRunScore = questions.isEmpty ? 0 : Double(correct) / Double(questions.count)
            if lesson.tracksProgress {
                store.recordRun(lesson.id, score: lastRunScore)
            }
        }
    }

    func restart() {
        var rng = SystemRandomNumberGenerator()
        if let spec = lesson.ear {
            questions = EarTraining.questions(for: spec, using: &rng)
        }
        index = 0; selected = nil; correct = 0; isComplete = false
        playPrompt()
    }

    func stop() { player.stop() }
}

struct EarTrainingView: View {
    @State private var model: EarTrainingViewModel
    private let onFinished: (() -> Void)?
    private let onClose: () -> Void

    init(lesson: Lesson, onFinished: (() -> Void)? = nil, onClose: @escaping () -> Void) {
        _model = State(initialValue: EarTrainingViewModel(lesson: lesson))
        self.onFinished = onFinished
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            ArcticBackground(glow: model.isComplete)
            if model.isComplete { completionView } else { quizView }
        }
        .preferredColorScheme(.dark)
        .onAppear { model.playPrompt() }
        .onDisappear { model.stop() }
        .onChange(of: model.isComplete) { _, complete in
            if complete { onFinished?() }
        }
    }

    // MARK: - Quiz

    private var quizView: some View {
        VStack(spacing: 0) {
            topBar.padding(.top, 12)
            Spacer()
            if let question = model.current {
                VStack(spacing: 22) {
                    if model.hasPrompt {
                        Button { model.playPrompt() } label: {
                            ZStack {
                                Circle().fill(Theme.teal.opacity(0.16)).frame(width: 132, height: 132)
                                Circle().stroke(Theme.teal.opacity(0.5), lineWidth: 2).frame(width: 132, height: 132)
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 44)).foregroundStyle(Theme.teal)
                            }
                        }
                        .buttonStyle(.plain)
                        Text("Tap to hear it again")
                            .font(Theme.light(12)).tracking(2).foregroundStyle(Theme.frost.opacity(0.5))
                    }
                    Text(question.text)
                        .font(Theme.display(22)).foregroundStyle(.white)
                        .multilineTextAlignment(.center).padding(.horizontal, 30)
                    choiceButtons(question)
                }
            }
            Spacer()
            nextButton.padding(.horizontal, 30).padding(.bottom, 28)
        }
    }

    private func choiceButtons(_ question: EarTraining.Question) -> some View {
        VStack(spacing: 10) {
            ForEach(Array(question.choices.enumerated()), id: \.offset) { index, choice in
                Button { model.choose(index) } label: {
                    Text(choice)
                        .font(Theme.title(17))
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .foregroundStyle(choiceForeground(index, question))
                        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(choiceBackground(index, question)))
                        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(.white.opacity(0.12), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(model.selected != nil)
            }
        }
        .padding(.horizontal, 30)
        .animation(.snappy, value: model.selected)
    }

    private func choiceForeground(_ index: Int, _ q: EarTraining.Question) -> Color {
        guard model.selected != nil else { return .white }
        if index == q.answerIndex { return Color(hex: 0x06222A) }
        return index == model.selected ? .white : Theme.frost.opacity(0.4)
    }

    private func choiceBackground(_ index: Int, _ q: EarTraining.Question) -> AnyShapeStyle {
        guard let selected = model.selected else { return AnyShapeStyle(.white.opacity(0.06)) }
        if index == q.answerIndex { return AnyShapeStyle(Theme.teal) }              // reveal the right one
        if index == selected { return AnyShapeStyle(Color(hex: 0xE8836B).opacity(0.55)) }  // your miss
        return AnyShapeStyle(.white.opacity(0.03))
    }

    private var topBar: some View {
        VStack(spacing: 14) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.frost.opacity(0.85))
                        .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(model.lesson.title.uppercased())
                    .font(Theme.display(18)).tracking(4).foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            // Question progress dots.
            HStack(spacing: 8) {
                ForEach(0..<max(1, model.questions.count), id: \.self) { i in
                    Capsule()
                        .fill(i < model.index ? Theme.teal
                              : (i == model.index ? Theme.frost.opacity(0.85) : .white.opacity(0.15)))
                        .frame(width: i == model.index ? 22 : 10, height: 6)
                }
            }
        }
        .padding(.horizontal, 20)
        .animation(.snappy, value: model.index)
    }

    private var nextButton: some View {
        Button { model.next() } label: {
            Text(model.index + 1 < model.questions.count ? "NEXT" : "FINISH")
                .font(Theme.display(18)).tracking(3)
                .frame(maxWidth: .infinity).frame(height: 56)
                .foregroundStyle(model.selected == nil ? Theme.frost.opacity(0.35) : Color(hex: 0x06222A))
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(model.selected == nil ? AnyShapeStyle(.white.opacity(0.07)) : AnyShapeStyle(Theme.teal)))
        }
        .buttonStyle(.plain)
        .disabled(model.selected == nil)
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: model.isMastered ? "checkmark.seal.fill" : "ear.fill")
                .font(.system(size: 84))
                .foregroundStyle(model.isMastered ? Theme.teal : Theme.cyan)
                .shadow(color: model.isMastered ? Theme.teal.opacity(0.7) : .clear, radius: 26)
            Text(model.isMastered ? "MASTERED" : "GOOD LISTENING")
                .font(Theme.display(30)).tracking(4).foregroundStyle(.white)
            Text("\(model.correct) / \(model.questions.count) correct")
                .font(Theme.body(18)).foregroundStyle(Theme.frost.opacity(0.8))

            VStack(spacing: 12) {
                Button { model.restart() } label: {
                    Text("TRY AGAIN")
                        .font(Theme.display(18)).tracking(3)
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
                Button(action: onClose) {
                    Text("DONE")
                        .font(Theme.display(18)).tracking(3)
                        .frame(maxWidth: .infinity).frame(height: 58)
                        .foregroundStyle(Color(hex: 0x06222A))
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.teal))
                        .shadow(color: Theme.teal.opacity(0.5), radius: 16, y: 6)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40).padding(.top, 14)
        }
        .padding()
    }
}

/// Routes a lesson to the right player: ear drills get the quiz, everything
/// else gets the mic-scored LessonView. Use this everywhere lessons launch.
struct LessonPlayer: View {
    let lesson: Lesson
    var onFinished: (() -> Void)? = nil
    let onClose: () -> Void

    var body: some View {
        if lesson.ear != nil {
            EarTrainingView(lesson: lesson, onFinished: onFinished, onClose: onClose)
        } else {
            LessonView(lesson: lesson, onFinished: onFinished, onClose: onClose)
        }
    }
}
