//
//  LessonView.swift
//  Guided practice: shows the target note + where to play it, listens, and
//  gives instant per-note feedback — green when you hold the right note.
//

import SwiftUI

struct LessonView: View {
    @State private var model: LessonViewModel
    private let onClose: () -> Void

    init(lesson: Lesson, onClose: @escaping () -> Void) {
        _model = State(initialValue: LessonViewModel(lesson: lesson))
        self.onClose = onClose
    }

    private var inTune: Bool { model.feedback == .correct }

    /// Temporary reveal of a faded prompt ("Show shape") in from-memory mode.
    @State private var peeking = false
    private var showsDiagram: Bool { model.scaffold.showsDiagram || peeking }
    private var showsFingerNumbers: Bool { model.scaffold.showsFingerNumbers || peeking }
    private var showsHint: Bool { model.scaffold != .fromMemory }

    /// Whether the user has cleared the pre-play "hear it first" primer.
    @State private var audiated = false
    /// Show the audiation primer only while first acquiring a skill (full
    /// scaffold). Once it's reduced/from-memory the learner already hears it.
    private var needsAudiation: Bool {
        if audiationDisabled { return false }
        return model.scaffold == .full
    }

    var body: some View {
        ZStack {
            ArcticBackground(glow: inTune || model.isComplete)
            if model.isComplete {
                completionView
            } else if needsAudiation && !audiated {
                audiationIntro
            } else {
                practiceView
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            if needsAudiation && !audiated {
                model.audiate()           // hear it first; the mic opens when they proceed
            } else {
                model.startListening()
            }
        }
        .onDisappear { model.stopListening() }
        .onChange(of: model.currentStep.id) { _, _ in peeking = false }   // re-fade each step
    }

    private func startPracticing() {
        audiated = true
        model.startListening()
    }

    // MARK: - Audiation primer (sound before symbol)

    private var audiationTargetName: String {
        model.currentStep.chord?.name ?? model.currentStep.note
    }

    private var audiationInstruction: String {
        if model.currentStep.strum != nil {
            return "Listen and feel the pulse — you'll be counted in, then strum."
        }
        if model.currentStep.chord != nil {
            return "Listen, then picture the shape and hum it before you play."
        }
        return "Listen, then hum it back before you play."
    }

    private var audiationIntro: some View {
        VStack(spacing: 0) {
            topBar.padding(.top, 12)
            Spacer()
            VStack(spacing: 16) {
                Text("HEAR IT FIRST").font(Theme.display(16)).tracking(4).foregroundStyle(Theme.cyan)
                Text(audiationTargetName)
                    .font(.custom("Rajdhani-SemiBold", size: 88))
                    .foregroundStyle(.white)
                Text(audiationInstruction)
                    .font(Theme.body(16)).foregroundStyle(Theme.frost.opacity(0.8))
                    .multilineTextAlignment(.center).padding(.horizontal, 44)
                Button { model.audiate() } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "speaker.wave.2.fill").font(.system(size: 14, weight: .semibold))
                        Text("HEAR AGAIN").font(Theme.display(15)).tracking(3)
                    }
                    .foregroundStyle(Theme.frost)
                    .padding(.horizontal, 20).frame(height: 42)
                    .background(Capsule().fill(.white.opacity(0.08)))
                    .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            Spacer()
            Button { startPracticing() } label: {
                Text("I'VE GOT IT — PLAY")
                    .font(Theme.display(18)).tracking(3)
                    .frame(maxWidth: .infinity).frame(height: 58)
                    .foregroundStyle(Color(hex: 0x06222A))
                    .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.teal))
                    .shadow(color: Theme.teal.opacity(0.5), radius: 16, y: 6)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 30).padding(.bottom, 28)
        }
    }

    private var audiationDisabled: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["PICKUP_NO_AUDIATION"] != nil
        #else
        return false
        #endif
    }

    /// Shown in place of a faded prompt: a "from memory" badge with a peek escape.
    private var fromMemoryBadge: some View {
        VStack(spacing: 14) {
            HStack(spacing: 7) {
                Image(systemName: "brain.head.profile").font(.system(size: 13))
                Text("FROM MEMORY").font(Theme.title(13)).tracking(2)
            }
            .foregroundStyle(Theme.frost.opacity(0.7))
            .padding(.horizontal, 16).frame(height: 36)
            .background(Capsule().fill(.white.opacity(0.06)))
            .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
            Button { withAnimation(.snappy) { peeking = true } } label: {
                Text("Show shape").font(Theme.body(14)).foregroundStyle(Theme.cyan)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Practice

    private var practiceView: some View {
        VStack(spacing: 0) {
            topBar.padding(.top, 12)
            if model.currentStep.strum != nil {
                strumBody
            } else {
                Spacer()
                if let chord = model.currentStep.chord {
                    chordTarget(chord)
                } else {
                    targetNote
                    if let position = model.currentStep.position {
                        if showsDiagram {
                            FretboardDiagram(positions: [position])
                                .frame(width: 236, height: 138)
                                .padding(.top, 14)
                        } else {
                            fromMemoryBadge.frame(height: 138).padding(.top, 14)
                        }
                    }
                }
                hearItButton.padding(.top, 14)
                Spacer().frame(height: 10)
                detectedLine
                Spacer()
                prompt.padding(.bottom, 26)
            }
        }
    }

    // MARK: - Strum step

    private var strumBody: some View {
        VStack(spacing: 0) {
            Spacer()
            if let chord = model.currentStep.chord {
                Text(chord.name)
                    .font(.custom("Rajdhani-SemiBold", size: 56))
                    .foregroundStyle(model.feedback == .correct ? Theme.teal : .white)
                if showsDiagram {
                    FretboardDiagram(positions: chord.positions, mutedStrings: chord.mutedStrings,
                                     barre: chord.barre, showFingers: showsFingerNumbers)
                        .frame(width: FretboardDiagram.practiceWidth, height: FretboardDiagram.practiceHeight).padding(.top, 6)   // match the chord-practice screen
                } else {
                    fromMemoryBadge.frame(width: 286, height: 232).padding(.top, 6)
                }
            }
            tempoPill.padding(.top, 16)
            beatIndicator.padding(.top, 14)
            Spacer()
            strumControl.padding(.horizontal, 30).padding(.bottom, 28)
        }
    }

    private var tempoPill: some View {
        HStack(spacing: 7) {
            Image(systemName: "metronome.fill").font(.system(size: 13))
            Text("\(model.currentBpm) BPM").font(Theme.title(15)).tracking(1)
            if model.isAtTargetTempo {
                Text("· FULL SPEED").font(Theme.light(11)).tracking(1).foregroundStyle(Theme.teal)
            } else {
                Text("· BUILDING UP").font(Theme.light(11)).tracking(1).foregroundStyle(Theme.frost.opacity(0.5))
            }
        }
        .foregroundStyle(Theme.frost.opacity(0.85))
        .padding(.horizontal, 16).frame(height: 36)
        .background(Capsule().fill(.white.opacity(0.06)))
        .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 1))
        .animation(.snappy, value: model.currentBpm)
    }

    private var beatIndicator: some View {
        let beats = model.currentStep.strum?.beats ?? 0
        return HStack(spacing: 10) {
            ForEach(0..<beats, id: \.self) { i in
                Circle()
                    .fill(model.strumHitBeats.contains(i) ? AnyShapeStyle(Theme.teal)
                          : (i == model.strumBeat ? AnyShapeStyle(Theme.frost.opacity(0.85))
                             : AnyShapeStyle(.white.opacity(0.15))))
                    .frame(width: i == model.strumBeat ? 16 : 12, height: i == model.strumBeat ? 16 : 12)
            }
        }
        .animation(.snappy, value: model.strumBeat)
        .animation(.snappy, value: model.strumHits)
    }

    @ViewBuilder private var strumControl: some View {
        if model.strumRunning {
            Text(model.strumBeat < 0 ? "Get ready…" : "Strum on every click")
                .font(Theme.title(17)).tracking(1).foregroundStyle(Theme.frost.opacity(0.8))
                .frame(height: 54)
        } else if model.strumFinished {
            VStack(spacing: 12) {
                Text("\(model.strumHits) / \(model.strumTarget) in time — almost!")
                    .font(Theme.title(16)).foregroundStyle(Theme.frost.opacity(0.85))
                strumButton("TRY AGAIN") { model.retryStrum() }
            }
        } else {
            VStack(spacing: 10) {
                Text(model.currentStep.hint)
                    .font(Theme.body(15)).foregroundStyle(Theme.frost.opacity(0.7))
                strumButton("START") { model.beginStrum() }
            }
        }
    }

    private func strumButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.display(17)).tracking(3)
                .frame(maxWidth: .infinity).frame(height: 54)
                .foregroundStyle(Color(hex: 0x06222A))
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.teal))
                .shadow(color: Theme.teal.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
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
        // Same treatment as the chord target — a large glowing name, no ring —
        // so note steps and chord steps look consistent within a lesson.
        VStack(spacing: 6) {
            Text(model.currentStep.note)
                .font(.custom("Rajdhani-SemiBold", size: 96))
                .foregroundStyle(inTune ? Theme.teal : .white)
                .shadow(color: inTune ? Theme.teal.opacity(0.7) : .clear, radius: 18)
            Text(model.currentStep.octaveLabel)
                .font(Theme.light(15)).tracking(3)
                .foregroundStyle(Theme.frost.opacity(0.7))
            if showsHint {
                Text(model.currentStep.hint)
                    .font(Theme.body(16)).foregroundStyle(Theme.frost.opacity(0.8))
                    .padding(.top, 4)
            }
        }
        .animation(.snappy, value: inTune)
        .animation(.snappy, value: model.currentStep.id)
    }

    private func chordTarget(_ chord: Chord) -> some View {
        VStack(spacing: 8) {
            Text(chord.name)
                .font(.custom("Rajdhani-SemiBold", size: 64))
                .foregroundStyle(inTune ? Theme.teal : .white)
                .shadow(color: inTune ? Theme.teal.opacity(0.7) : .clear, radius: 18)
            if showsDiagram {
                FretboardDiagram(positions: chord.positions, mutedStrings: chord.mutedStrings,
                                 barre: chord.barre, showFingers: showsFingerNumbers)
                    .frame(width: 286, height: 232)   // match the chord-practice screen
            } else {
                fromMemoryBadge.frame(width: 286, height: 232)
            }
            if showsHint {
                Text(model.currentStep.hint)
                    .font(Theme.body(16)).foregroundStyle(Theme.frost.opacity(0.8))
            }
        }
        .animation(.snappy, value: inTune)
        .animation(.snappy, value: model.currentStep.id)
    }

    private var hearItButton: some View {
        Button { model.playExample() } label: {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 14, weight: .semibold))
                Text("HEAR IT").font(Theme.display(15)).tracking(3)
            }
            .foregroundStyle(Theme.frost)
            .padding(.horizontal, 20).frame(height: 42)
            .background(Capsule().fill(.white.opacity(0.08)))
            .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var detectedLine: some View {
        Group {
            if model.scaffold.showsContinuousFeedback {
                continuousFeedback
            } else {
                thinFeedback   // from memory: flag errors only
            }
        }
        .font(Theme.title(17)).tracking(1)
    }

    @ViewBuilder private var continuousFeedback: some View {
        if model.currentStep.chord != nil {
            switch model.feedback {
            case .correct:
                Text("Nice — hold it").foregroundStyle(Theme.teal)
            case .close:
                Text(model.detectedLabel ?? "Almost — keep the shape")
                    .foregroundStyle(Theme.frost.opacity(0.85))
            case .waiting:
                Text(model.detectedLabel ?? "Strum the chord")
                    .foregroundStyle(Theme.frost.opacity(0.6))
            }
        } else {
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
    }

    /// From-memory feedback bandwidth: stay quiet while it's right or waiting,
    /// only speak up to flag a wrong note/shape so the learner self-corrects.
    @ViewBuilder private var thinFeedback: some View {
        switch model.feedback {
        case .close:
            Text(model.currentStep.chord != nil
                 ? (model.detectedLabel ?? "Not quite — adjust the shape")
                 : (model.detectedLabel.map { "That's \($0) — adjust" } ?? "Adjust"))
                .foregroundStyle(Theme.frost.opacity(0.85))
        case .correct, .waiting:
            Color.clear.frame(height: 1)
        }
    }

    private var prompt: some View {
        Text(model.permissionDenied ? "Enable microphone access in Settings" : "Listening…")
            .font(Theme.light(13)).tracking(3)
            .foregroundStyle(Theme.frost.opacity(0.5))
    }

    // MARK: - Completion

    private var masteryReadout: some View {
        VStack(spacing: 8) {
            Text("THIS RUN  ·  \(Int(model.lastRunScore * 100))% CLEAN")
                .font(Theme.title(14)).tracking(2).foregroundStyle(Theme.frost.opacity(0.8))
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10))
                    Capsule().fill(model.isMastered ? Theme.teal : Theme.cyan)
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, model.mastery))))
                }
            }
            .frame(height: 8)
            Text(model.isMastered
                 ? "Mastery \(Int(model.mastery * 100))% — learned!"
                 : "Mastery \(Int(model.mastery * 100))% — practice again to master it")
                .font(Theme.light(12)).tracking(1).foregroundStyle(Theme.frost.opacity(0.6))
        }
    }

    private var completionView: some View {
        VStack(spacing: 20) {
            Image(systemName: model.isMastered ? "checkmark.seal.fill" : "chart.line.uptrend.xyaxis")
                .font(.system(size: 84))
                .foregroundStyle(model.isMastered ? Theme.teal : Theme.cyan)
                .shadow(color: model.isMastered ? Theme.teal.opacity(0.7) : .clear, radius: 26)
            Text(model.isMastered ? "MASTERED" : "NICE RUN")
                .font(Theme.display(30)).tracking(4).foregroundStyle(.white)
            Text(model.lesson.title)
                .font(Theme.body(18)).foregroundStyle(Theme.frost.opacity(0.8))

            masteryReadout.padding(.horizontal, 40).padding(.top, 4)

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
