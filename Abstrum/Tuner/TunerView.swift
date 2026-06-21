//
//  TunerView.swift
//  The guitar tuner — Abstrum's first surface, in the dark arctic theme.
//

import SwiftUI

struct TunerView: View {
    @State private var model = TunerViewModel()

    private var reading: TunerViewModel.Reading? { model.reading }
    private var inTune: Bool { reading?.isInTune ?? false }

    var body: some View {
        ZStack {
            ArcticBackground(glow: inTune)

            GeometryReader { geo in
              ScrollView {
                VStack(spacing: 0) {
                header
                    .padding(.top, 12)

                Spacer()
                noteBlock
                Spacer().frame(height: 30)

                TuningMeter(cents: reading?.cents ?? 0,
                            inTune: inTune,
                            active: reading != nil)
                    .frame(height: 60)
                    .padding(.horizontal, 30)

                statusLabel
                    .padding(.top, 16)
                Spacer()

                StringPicker(strings: GuitarTuning.standard,
                             activeID: model.activeStringID,
                             onSelect: model.selectString)
                    .padding(.bottom, 18)

                listenButton
                    .padding(.horizontal, 30)
                    .padding(.bottom, 18)
                }
                .frame(minHeight: geo.size.height)
              }
              .scrollBounceBehavior(.basedOnSize)
            }
        }
        .preferredColorScheme(.dark)
        .alert("Microphone access needed", isPresented: $model.permissionDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Enable microphone access for Abstrum in Settings so it can hear you play.")
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 3) {
            Text("ABSTRUM")
                .font(Theme.display(22)).tracking(10)
                .foregroundStyle(.white)
            Text(model.manualString == nil ? "GUITAR TUNER · AUTO" : "GUITAR TUNER · MANUAL")
                .font(Theme.light(12)).tracking(4)
                .foregroundStyle(Theme.frost.opacity(0.6))
        }
    }

    private var noteBlock: some View {
        VStack(spacing: 6) {
            ZStack {
                if inTune {
                    Circle()
                        .fill(Theme.teal.opacity(0.30))
                        .frame(width: 280, height: 280)
                        .blur(radius: 50)
                }
                if let name = reading?.string.name {
                    Text(name)
                        .font(.custom("Rajdhani-SemiBold", size: 184))
                        .foregroundStyle(.white)
                        .shadow(color: inTune ? Theme.teal.opacity(0.85) : .black.opacity(0.35),
                                radius: inTune ? 28 : 10)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: reading?.string.id)
                } else {
                    Image(systemName: "guitars.fill")
                        .font(.system(size: 76))
                        .foregroundStyle(Theme.frost.opacity(0.16))
                }
            }
            .frame(height: 200)

            Text(detailText)
                .font(Theme.body(17)).tracking(1)
                .foregroundStyle(Theme.frost.opacity(0.8))
        }
    }

    private var detailText: String {
        if let reading {
            return String(format: "%@  ·  %.1f Hz", reading.string.label, reading.frequency)
        }
        return model.isListening ? "Listening — play a string" : "Tap Tune to start"
    }

    private var statusLabel: some View {
        let text: String
        let color: Color
        if let reading {
            switch reading.direction {
            case .inTune:
                text = "IN TUNE"; color = Theme.teal
            case .flat:
                text = String(format: "TUNE UP  ▲  %.0f¢", abs(reading.cents)); color = Theme.frost
            case .sharp:
                text = String(format: "%.0f¢  ▼  TUNE DOWN", reading.cents); color = Theme.frost
            }
        } else {
            text = " "; color = .white
        }
        return Text(text)
            .font(Theme.title(19)).tracking(3)
            .foregroundStyle(color)
            .animation(.snappy, value: inTune)
    }

    private var listenButton: some View {
        Button(action: model.toggle) {
            HStack(spacing: 12) {
                Image(systemName: model.isListening ? "stop.fill" : "waveform")
                    .font(.system(size: 18, weight: .semibold))
                Text(model.isListening ? "STOP" : "TUNE")
                    .font(Theme.display(21)).tracking(4)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .foregroundStyle(model.isListening ? Theme.frost : Color(hex: 0x06222A))
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(model.isListening ? AnyShapeStyle(.white.opacity(0.10))
                                            : AnyShapeStyle(Theme.teal))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(model.isListening ? .white.opacity(0.18) : .clear, lineWidth: 1)
            }
            .shadow(color: model.isListening ? .clear : Theme.teal.opacity(0.5), radius: 18, y: 8)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TunerView()
}
