//
//  SettingsView.swift
//  Tunable global audio settings (mic sensitivity, chord strictness).
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @State private var settings = AudioSettings.shared
    @State private var reminders = ReminderScheduler.shared
    #if DEBUG
    @State private var showResetConfirm = false
    @State private var didReset = false
    #endif

    // Mic sensitivity 0…1 maps (inverted) to the RMS gate: higher = lower gate.
    private let gateMin: Double = 0.0008   // most sensitive
    private let gateMax: Double = 0.008    // least sensitive

    private var sensitivity: Binding<Double> {
        Binding(
            get: { (gateMax - Double(settings.inputGateRMS)) / (gateMax - gateMin) },
            set: { s in
                let clamped = min(1, max(0, s))
                settings.inputGateRMS = Float(gateMax - clamped * (gateMax - gateMin))
            }
        )
    }

    var body: some View {
        ZStack {
            ArcticBackground()
            VStack(spacing: 0) {
                header.padding(.top, 12)
                ScrollView {
                    VStack(spacing: 16) {
                        reminderCard
                        sliderCard(title: "MIC SENSITIVITY",
                                   subtitle: "Higher picks up quieter or softer playing.",
                                   value: sensitivity, range: 0...1,
                                   left: "Lower", right: "Higher")
                        sliderCard(title: "CHORD MATCH STRICTNESS",
                                   subtitle: "Higher needs a cleaner strum before a chord registers.",
                                   value: $settings.chordMatchThreshold, range: 0.5...0.9,
                                   left: "Loose", right: "Strict")
                        resetButton
                        footnote
                        #if DEBUG
                        tuningCard
                        devCard
                        #endif
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                }
            }
        }
        .preferredColorScheme(.dark)
        #if DEBUG
        .alert("Reset all data?", isPresented: $showResetConfirm) {
            Button("Reset", role: .destructive) { resetAllData() }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Clears progress, streak, XP, onboarding, and settings to a fresh-install state. Imported highway songs are kept. Relaunch to see onboarding again.")
        }
        #endif
    }

    #if DEBUG
    private var chordHoldBinding: Binding<Double> {
        Binding(get: { Double(settings.chordHoldFrames) },
                set: { settings.chordHoldFrames = Int($0.rounded()) })
    }

    private var tuningCard: some View {
        VStack(spacing: 16) {
            Text("DETECTION TUNING · DEV")
                .font(Theme.display(15)).tracking(2).foregroundStyle(Theme.teal)
                .frame(maxWidth: .infinity, alignment: .leading)
            sliderCard(title: "CHORD HOLD",
                       subtitle: "Frames a chord must hold to register — now \(settings.chordHoldFrames).",
                       value: chordHoldBinding, range: 1...8, left: "Fast", right: "Strict")
            sliderCard(title: "NOTE TOLERANCE",
                       subtitle: "How close a note must be — now \(Int(settings.noteToleranceCents))¢.",
                       value: $settings.noteToleranceCents, range: 20...100, left: "Tight", right: "Loose")
            sliderCard(title: "TIMING WINDOW",
                       subtitle: "Strum / onset window — now \(Int(settings.timingWindowMs)) ms.",
                       value: $settings.timingWindowMs, range: 100...350, left: "Tight", right: "Loose")
        }
    }

    private var devCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("DEVELOPER").font(Theme.display(18)).tracking(2).foregroundStyle(.white)
            Text(didReset
                 ? "Done. Relaunch the app to see onboarding from scratch."
                 : "Reset progress, streak, onboarding, and settings to a fresh install. Imported songs are kept.")
                .font(Theme.body(13)).foregroundStyle(didReset ? Theme.teal : Theme.frost.opacity(0.65))
            Button { showResetConfirm = true } label: {
                Text("RESET ALL DATA").font(Theme.display(16)).tracking(2)
                    .foregroundStyle(Color(hex: 0xF4B860))
                    .frame(maxWidth: .infinity).frame(height: 50)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Color(hex: 0xC2410C).opacity(0.18)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color(hex: 0xF4B860).opacity(0.4), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    /// Fresh-install state for QA — everything except imported songs (a separate
    /// store) and the audio core.
    private func resetAllData() {
        ProgressStore.shared.reset()
        settings.resetToDefaults()
        let defaults = UserDefaults.standard
        for key in ["didOnboarding", "reminderEnabled", "reminderHour",
                    "reminderMinute", "showFingerNumbers"] {
            defaults.removeObject(forKey: key)
        }
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        didReset = true
    }
    #endif

    private var header: some View {
        VStack(spacing: 3) {
            Text("ABSTRUM").font(Theme.display(22)).tracking(10).foregroundStyle(.white)
            Text("SETTINGS").font(Theme.light(12)).tracking(4).foregroundStyle(Theme.frost.opacity(0.6))
        }
    }

    private var reminderEnabled: Binding<Bool> {
        Binding(get: { reminders.enabled }, set: { on in
            reminders.enabled = on
            if on { reminders.requestAuthorization() }
        })
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: { Calendar.current.date(bySettingHour: reminders.hour, minute: reminders.minute,
                                         second: 0, of: Date()) ?? Date() },
            set: { date in
                let c = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminders.hour = c.hour ?? 19
                reminders.minute = c.minute ?? 0
            }
        )
    }

    private var reminderCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DAILY REMINDER").font(Theme.display(18)).tracking(2).foregroundStyle(.white)
                    Text("A nudge to keep your streak alive.")
                        .font(Theme.body(13)).foregroundStyle(Theme.frost.opacity(0.65))
                }
                Spacer()
                Toggle("", isOn: reminderEnabled).labelsHidden().tint(Theme.teal)
            }
            if reminders.enabled {
                HStack {
                    Text("Remind me at").font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.8))
                    Spacer()
                    DatePicker("", selection: reminderTime, displayedComponents: .hourAndMinute)
                        .labelsHidden().colorScheme(.dark)
                }
                .padding(.top, 2)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func sliderCard(title: String, subtitle: String,
                            value: Binding<Double>, range: ClosedRange<Double>,
                            left: String, right: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(Theme.display(18)).tracking(2).foregroundStyle(.white)
            Text(subtitle).font(Theme.body(13)).foregroundStyle(Theme.frost.opacity(0.65))
            Slider(value: value, in: range).tint(Theme.teal)
            HStack {
                Text(left)
                Spacer()
                Text(right)
            }
            .font(Theme.light(11)).tracking(1).foregroundStyle(Theme.frost.opacity(0.5))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var resetButton: some View {
        Button { settings.resetToDefaults() } label: {
            Text("RESET TO DEFAULTS")
                .font(Theme.display(16)).tracking(2)
                .foregroundStyle(Theme.frost)
                .frame(maxWidth: .infinity).frame(height: 52)
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .padding(.top, 6)
    }

    private var footnote: some View {
        Text("Changes apply next time you open a tuner, lesson, or chord.")
            .font(Theme.light(11)).tracking(1)
            .foregroundStyle(Theme.frost.opacity(0.4))
            .multilineTextAlignment(.center)
            .padding(.top, 8)
    }
}
