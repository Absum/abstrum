//
//  OnboardingView.swift
//  First-run flow: get a player from launch to "the app heard me play" in well
//  under a minute, with no signup. A light placement lets experienced players
//  skip the absolute basics.
//

import AVFoundation
import Observation
import SwiftUI

struct OnboardingView: View {
    let onFinish: () -> Void

    @State private var step = 0
    @State private var listener = OnboardingListener()

    var body: some View {
        ZStack {
            ArcticBackground()
            VStack(spacing: 0) {
                progressDots.padding(.top, 14)
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .padding(.horizontal, 32)
            .padding(.bottom, 12)
        }
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.3), value: step)
        .onAppear {
            #if DEBUG
            if let s = ProcessInfo.processInfo.environment["ABSTRUM_ONBOARD_STEP"], let n = Int(s) { step = n }
            #endif
        }
        .onDisappear { listener.stop() }
    }

    @ViewBuilder private var content: some View {
        switch step {
        case 0: welcome
        case 1: micStep
        case 2: notificationsStep
        case 3: playStep
        default: placementStep
        }
    }

    // MARK: - Steps

    private var welcome: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "guitars.fill")
                .font(.system(size: 72)).foregroundStyle(Theme.teal)
                .shadow(color: Theme.teal.opacity(0.6), radius: 24)
            Text("ABSTRUM").font(Theme.display(34)).tracking(8).foregroundStyle(.white)
            Text("Learn guitar by ear.\nYour phone listens and guides you as you play.")
                .font(Theme.body(16)).foregroundStyle(Theme.frost.opacity(0.75))
                .multilineTextAlignment(.center).lineSpacing(4)
            Spacer()
            primaryButton("GET STARTED") { step = 1 }
        }
    }

    private var micStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "mic.fill")
                .font(.system(size: 64)).foregroundStyle(Theme.teal)
                .shadow(color: Theme.teal.opacity(0.6), radius: 20)
            Text("Let Abstrum hear you").font(Theme.display(26)).foregroundStyle(.white)
            Text("Abstrum uses your microphone to hear what you play and give instant feedback. Nothing is recorded or saved.")
                .font(Theme.body(15)).foregroundStyle(Theme.frost.opacity(0.75))
                .multilineTextAlignment(.center).lineSpacing(4)
            Spacer()
            primaryButton("ENABLE MICROPHONE") {
                AVAudioApplication.requestRecordPermission { _ in
                    DispatchQueue.main.async { step = 2 }
                }
            }
        }
    }

    private var notificationsStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "flame.fill")
                .font(.system(size: 64)).foregroundStyle(Theme.teal)
                .shadow(color: Theme.teal.opacity(0.6), radius: 20)
            Text("Build a streak").font(Theme.display(26)).foregroundStyle(.white)
            Text("A daily reminder keeps you coming back so your streak — and your playing — actually grows.")
                .font(Theme.body(15)).foregroundStyle(Theme.frost.opacity(0.75))
                .multilineTextAlignment(.center).lineSpacing(4)
            Spacer()
            primaryButton("TURN ON REMINDERS") {
                ReminderScheduler.shared.requestAuthorization { _ in step = 3 }
            }
            secondaryButton("NOT NOW") { step = 3 }
        }
    }

    private var playStep: some View {
        VStack(spacing: 18) {
            Spacer()
            ZStack {
                Circle()
                    .fill(listener.heardNote != nil ? Theme.teal.opacity(0.18) : .white.opacity(0.06))
                    .frame(width: 150, height: 150)
                Image(systemName: listener.heardNote != nil ? "checkmark" : "waveform")
                    .font(.system(size: 56, weight: .semibold))
                    .foregroundStyle(listener.heardNote != nil ? Theme.teal : Theme.frost.opacity(0.7))
                    .shadow(color: listener.heardNote != nil ? Theme.teal.opacity(0.7) : .clear, radius: 18)
            }
            if let note = listener.heardNote {
                Text("Nice — I heard \(note)!").font(Theme.display(24)).foregroundStyle(Theme.teal)
                Text("That's it. The app is listening as you play.")
                    .font(Theme.body(15)).foregroundStyle(Theme.frost.opacity(0.7))
            } else {
                Text("Play any string").font(Theme.display(26)).foregroundStyle(.white)
                Text(listener.micDenied
                     ? "Microphone is off — you can enable it later in Settings."
                     : "Pluck or strum your guitar so Abstrum can hear it.")
                    .font(Theme.body(15)).foregroundStyle(Theme.frost.opacity(0.75))
                    .multilineTextAlignment(.center).lineSpacing(4)
            }
            Spacer()
            if listener.heardNote == nil {
                secondaryButton(listener.micDenied ? "CONTINUE" : "SKIP") { step = 4 }
            }
        }
        .onAppear { listener.start() }
        .onChange(of: listener.heardNote) { _, note in
            guard note != nil else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
                listener.stop()
                step = 4
            }
        }
    }

    private var placementStep: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("Where are you starting?").font(Theme.display(26)).foregroundStyle(.white)
                .multilineTextAlignment(.center)
            Text("So we can pick the right first lesson.")
                .font(Theme.body(15)).foregroundStyle(Theme.frost.opacity(0.7))
            Spacer()
            choiceButton("I'm brand new", "Start from holding the guitar") { finish(experienced: false) }
            choiceButton("I know a few chords", "Skip the absolute basics") { finish(experienced: true) }
        }
    }

    // MARK: - Finish

    private func finish(experienced: Bool) {
        listener.stop()
        if experienced {
            // Skip ahead: mark the intro (tier 0) course's lessons complete.
            if let intro = CourseLibrary.all.min(by: { $0.tier < $1.tier }) {
                for lesson in intro.lessons { ProgressStore.shared.markCompleted(lesson.id) }
            }
        }
        onFinish()
    }

    // MARK: - Building blocks

    private func primaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.display(17)).tracking(3)
                .frame(maxWidth: .infinity).frame(height: 56)
                .foregroundStyle(Color(hex: 0x06222A))
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.teal))
                .shadow(color: Theme.teal.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    private func secondaryButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(Theme.display(16)).tracking(3)
                .frame(maxWidth: .infinity).frame(height: 52)
                .foregroundStyle(Theme.frost)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func choiceButton(_ title: String, _ subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(Theme.display(18)).foregroundStyle(.white)
                    Text(subtitle).font(Theme.body(13)).foregroundStyle(Theme.frost.opacity(0.65))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.frost.opacity(0.5))
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<5, id: \.self) { i in
                Circle().fill(i == step ? Theme.teal : .white.opacity(0.18))
                    .frame(width: 7, height: 7)
            }
        }
    }
}

/// Listens to the mic just long enough to confirm the user played something.
@Observable
final class OnboardingListener {
    var heardNote: String?
    var micDenied = false

    private let audio = AudioEngine()

    init() {
        audio.onResult = { [weak self] in self?.handle($0) }
    }

    func start() {
        AVAudioApplication.requestRecordPermission { [weak self] granted in
            DispatchQueue.main.async {
                guard let self else { return }
                guard granted else { self.micDenied = true; return }
                try? self.audio.start()
            }
        }
    }

    func stop() { audio.stop() }

    private func handle(_ result: AudioEngine.Result?) {
        guard heardNote == nil,
              let frequency = result?.frequency, frequency > 60, frequency < 1300,
              let reading = NoteMath.reading(forFrequency: frequency) else { return }
        heardNote = reading.displayName
        audio.stop()
    }
}
