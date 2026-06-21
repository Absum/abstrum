//
//  MetronomeView.swift
//  Metronome in the dark arctic theme: pulsing BPM dial, beat dots, tempo
//  controls, time-signature pills, tap-tempo, and a start/stop control.
//

import SwiftUI

struct MetronomeView: View {
    @State private var model = MetronomeViewModel()
    @State private var pulse: CGFloat = 0

    private let signatures = [2, 3, 4, 6]

    var body: some View {
        ZStack {
            ArcticBackground(glow: model.isRunning && model.currentBeat == 0)

            GeometryReader { geo in
              ScrollView {
                VStack(spacing: 0) {
                header.padding(.top, 12)
                Spacer()
                bpmDial
                Spacer().frame(height: 26)
                beatDots
                Spacer().frame(height: 30)
                tempoControls.padding(.horizontal, 30)
                Spacer().frame(height: 22)
                signaturePicker
                Spacer()
                bottomControls.padding(.horizontal, 30).padding(.bottom, 18)
                }
                .frame(minHeight: geo.size.height)
              }
              .scrollBounceBehavior(.basedOnSize)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: model.currentBeat) { _, beat in
            guard beat >= 0 else { return }
            pulse = 1
            withAnimation(.easeOut(duration: 0.5)) { pulse = 0 }
        }
    }

    // MARK: - Pieces

    private var header: some View {
        VStack(spacing: 3) {
            Text("ABSTRUM").font(Theme.display(22)).tracking(10).foregroundStyle(.white)
            Text("METRONOME").font(Theme.light(12)).tracking(4)
                .foregroundStyle(Theme.frost.opacity(0.6))
        }
    }

    private var bpmDial: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.10), lineWidth: 2)
                .frame(width: 240, height: 240)
            Circle()
                .fill((model.currentBeat == 0 ? Theme.cyan : Theme.teal).opacity(0.20 * pulse))
                .frame(width: 240, height: 240)
                .scaleEffect(0.85 + 0.18 * pulse)
            VStack(spacing: 0) {
                Text("\(model.bpm)")
                    .font(.custom("Rajdhani-SemiBold", size: 104))
                    .foregroundStyle(.white)
                    .contentTransition(.numericText())
                    .animation(.snappy, value: model.bpm)
                Text("BPM").font(Theme.light(15)).tracking(8)
                    .foregroundStyle(Theme.frost.opacity(0.7))
            }
        }
    }

    private var beatDots: some View {
        HStack(spacing: 14) {
            ForEach(0..<model.beatsPerMeasure, id: \.self) { i in
                let isCurrent = i == model.currentBeat
                Circle()
                    .fill(isCurrent ? (i == 0 ? Theme.cyan : Theme.teal) : .white.opacity(0.15))
                    .frame(width: i == 0 ? 14 : 11, height: i == 0 ? 14 : 11)
                    .shadow(color: isCurrent ? Theme.teal.opacity(0.7) : .clear, radius: 8)
            }
        }
        .animation(.snappy, value: model.currentBeat)
    }

    private var tempoControls: some View {
        HStack(spacing: 18) {
            stepButton("minus") { model.adjust(by: -1) }
            Slider(
                value: Binding(get: { Double(model.bpm) },
                               set: { model.bpm = Int($0.rounded()) }),
                in: Double(model.tempoRange.lowerBound)...Double(model.tempoRange.upperBound),
                step: 1
            )
            .tint(Theme.teal)
            stepButton("plus") { model.adjust(by: 1) }
        }
    }

    private func stepButton(_ symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(.white.opacity(0.08)))
                .overlay(Circle().stroke(.white.opacity(0.15), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var signaturePicker: some View {
        HStack(spacing: 10) {
            ForEach(signatures, id: \.self) { n in
                let active = n == model.beatsPerMeasure
                Button { model.setBeatsPerMeasure(n) } label: {
                    Text("\(n)").font(Theme.display(20))
                        .foregroundStyle(active ? .white : Theme.frost.opacity(0.7))
                        .frame(width: 50, height: 46)
                        .background {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .fill(active ? AnyShapeStyle(Theme.teal.opacity(0.9))
                                             : AnyShapeStyle(.white.opacity(0.06)))
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(active ? Theme.teal : .white.opacity(0.14), lineWidth: 1)
                        }
                        .shadow(color: active ? Theme.teal.opacity(0.5) : .clear, radius: 10)
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.snappy, value: model.beatsPerMeasure)
    }

    private var bottomControls: some View {
        HStack(spacing: 12) {
            Button { model.tapTempo() } label: {
                Text("TAP").font(Theme.display(18)).tracking(2)
                    .foregroundStyle(Theme.frost)
                    .frame(width: 92, height: 62)
                    .background {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .fill(.white.opacity(0.08))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    }
            }
            .buttonStyle(.plain)

            Button(action: model.toggle) {
                HStack(spacing: 12) {
                    Image(systemName: model.isRunning ? "stop.fill" : "play.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text(model.isRunning ? "STOP" : "START")
                        .font(Theme.display(21)).tracking(4)
                }
                .frame(maxWidth: .infinity).frame(height: 62)
                .foregroundStyle(model.isRunning ? Theme.frost : Color(hex: 0x06222A))
                .background {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(model.isRunning ? AnyShapeStyle(.white.opacity(0.10))
                                              : AnyShapeStyle(Theme.teal))
                }
                .shadow(color: model.isRunning ? .clear : Theme.teal.opacity(0.5), radius: 18, y: 8)
            }
            .buttonStyle(.plain)
        }
    }
}

#Preview {
    MetronomeView()
}
