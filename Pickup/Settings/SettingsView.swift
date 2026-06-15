//
//  SettingsView.swift
//  Tunable global audio settings (mic sensitivity, chord strictness).
//

import SwiftUI

struct SettingsView: View {
    @State private var settings = AudioSettings.shared

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
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 24)
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 3) {
            Text("PICKUP").font(Theme.display(22)).tracking(10).foregroundStyle(.white)
            Text("SETTINGS").font(Theme.light(12)).tracking(4).foregroundStyle(Theme.frost.opacity(0.6))
        }
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
