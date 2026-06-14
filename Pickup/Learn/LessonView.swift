//
//  LessonView.swift
//  Guided practice: shows the target note, listens, and gives instant
//  per-note feedback — green when you hold the right note.
//

import SwiftUI

struct LessonView: View {
    @State private var model: LessonViewModel
    private let onClose: () -> Void

    init(lesson: Lesson, onClose: @escaping () -> Void) {
        _model = State(initialValue: LessonViewModel(lesson: lesson))
        self.onClose = onClose
    }

    var body: some View {
        ZStack {
            ArcticBackground(glow: model.feedback == .correct || model.isComplete)
            if model.isComplete { completionView } else { practiceView }
        }
        .preferredColorScheme(.dark)
        .onAppear { model.startListening() }
        .onDisappear { model.stopListening() }
    }

    // MARK: - Practice

    private var practiceView: some View {
        VStack(spacing: 0) {
            topBar.padding(.top, 12)
            Spacer()
            targetNote
            Spacer().frame(height: 20)
            detectedLine
            Spacer()
            prompt.padding(.bottom, 28)
        }
    }

    private var topBar: some View {
        VStack(spacing: 16) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.frost.opacity(0.85))
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                Spacer()
                Text(model.lesson.title.uppercased())
                    .font(Theme.display(18)).tracking(4).foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            stepDots
        }
        .padding(.horizontal, 20)
    }

    private var stepDots: some View {
        HStack(spacing: 8) {
            ForEach(model.lesson.steps) { step in
                let done = model.completedSteps.contains(step.id)
                let current = step.id == model.currentStep.id
                Capsule()
                    .fill(done ? Theme.teal : (current ? Theme.frost.opacity(0.85) : .white.opacity(0.15)))
                    .frame(width: current ? 22 : 10, height: 6)
            }
        }
        .animation(.snappy, value: model.currentStep.id)
        .animation(.snappy, value: model.completedSteps)
    }

    private var targetNote: some View {
        let correct = model.feedback == .correct
        return VStack(spacing: 12) {
            ZStack {
                if correct {
                    Circle().fill(Theme.teal.opacity(0.22)).frame(width: 250, height: 250).blur(radius: 44)
                }
                Circle()
                    .stroke(correct ? Theme.teal : .white.opacity(0.12), lineWidth: 3)
                    .frame(width: 250, height: 250)
                VStack(spacing: 2) {
                    Text(model.currentStep.note)
                        .font(.custom("Rajdhani-SemiBold", size: 148))
                        .foregroundStyle(correct ? Theme.teal : .white)
                    Text(model.currentStep.octaveLabel)
                        .font(Theme.light(18)).tracking(4)
                        .foregroundStyle(Theme.frost.opacity(0.7))
                }
            }
            Text(model.currentStep.hint)
                .font(Theme.body(16)).foregroundStyle(Theme.frost.opacity(0.8))
        }
        .animation(.snappy, value: model.feedback)
        .animation(.snappy, value: model.currentStep.id)
    }

    private var detectedLine: some View {
        Group {
            switch model.feedback {
            case .correct:
                Text("Nice — hold it").foregroundStyle(Theme.teal)
            case .close:
                Text(model.detectedLabel.map { "You're playing \($0) — adjust" } ?? "Almost")
                    .foregroundStyle(Theme.frost.opacity(0.85))
            case .waiting:
                Text(model.detectedLabel.map { "Heard \($0)" } ?? "Play the note")
                    .foregroundStyle(Theme.frost.opacity(0.6))
            }
        }
        .font(Theme.title(17)).tracking(1)
    }

    private var prompt: some View {
        Text(model.permissionDenied ? "Enable microphone access in Settings" : "Listening…")
            .font(Theme.light(13)).tracking(3)
            .foregroundStyle(Theme.frost.opacity(0.5))
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 22) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 92))
                .foregroundStyle(Theme.teal)
                .shadow(color: Theme.teal.opacity(0.7), radius: 26)
            Text("LESSON COMPLETE")
                .font(Theme.display(30)).tracking(4).foregroundStyle(.white)
            Text(model.lesson.title)
                .font(Theme.body(18)).foregroundStyle(Theme.frost.opacity(0.8))

            VStack(spacing: 12) {
                Button {
                    model.restart()
                    model.startListening()
                } label: {
                    Text("PRACTICE AGAIN")
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
