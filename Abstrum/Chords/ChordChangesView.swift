//
//  ChordChangesView.swift
//  Pick a progression, then drill the transitions: play the current chord
//  cleanly to count a change and advance. Visual tempo pulse.
//

import SwiftUI

struct ChordChangesView: View {
    let onClose: () -> Void
    @State private var progression: ChordProgression?

    var body: some View {
        ZStack {
            ArcticBackground(glow: false)
            if let progression {
                ChordChangeRunner(progression: progression) { self.progression = nil }
                    .id(progression.id)
            } else {
                menu
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            #if DEBUG
            if let id = ProcessInfo.processInfo.environment["ABSTRUM_CHANGES"],
               let prog = ChordProgressions.all.first(where: { $0.id == id }) {
                progression = prog
            }
            #endif
        }
    }

    private var menu: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onClose) {
                    Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Theme.frost.opacity(0.85))
                        .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.08)))
                }
                .buttonStyle(.plain)
                Spacer()
                Text("CHORD CHANGES").font(Theme.display(18)).tracking(4).foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20).padding(.top, 12)

            Text("Pick a progression to drill")
                .font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.6))
                .padding(.top, 10)

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(ChordProgressions.all) { prog in
                        Button { progression = prog } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(prog.name).font(Theme.display(22)).foregroundStyle(.white)
                                    Text(prog.subtitle).font(Theme.body(13)).foregroundStyle(Theme.frost.opacity(0.65))
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
                }
                .padding(.horizontal, 22).padding(.top, 22)
            }
        }
    }
}

private struct ChordChangeRunner: View {
    @State private var model: ChordChangeViewModel
    let onBack: () -> Void

    init(progression: ChordProgression, onBack: @escaping () -> Void) {
        _model = State(initialValue: ChordChangeViewModel(progression: progression))
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar.padding(.top, 12)
            Spacer()
            stats
            Spacer().frame(height: 18)
            currentChord
            Spacer().frame(height: 14)
            nextHint
            Spacer()
            controlButton.padding(.horizontal, 30).padding(.bottom, 18)
        }
        .onAppear { /* wait for user to start */ }
        .onDisappear { if model.isRunning { model.toggle() } }
    }

    private var topBar: some View {
        HStack {
            Button(action: onBack) {
                Image(systemName: "chevron.left").font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.frost.opacity(0.85))
                    .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            Spacer()
            Text(model.progression.name).font(Theme.display(18)).tracking(3).foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }

    private var stats: some View {
        HStack(spacing: 40) {
            statItem("\(model.changes)", "CHANGES")
            pulseDot
            statItem(timeString, "TIME")
        }
    }

    private func statItem(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.custom("Rajdhani-SemiBold", size: 40)).foregroundStyle(.white)
                .contentTransition(.numericText())
            Text(label).font(Theme.light(11)).tracking(3).foregroundStyle(Theme.frost.opacity(0.6))
        }
    }

    private var pulseDot: some View {
        Circle()
            .fill(Theme.teal.opacity(model.isRunning ? (model.pulse ? 0.9 : 0.3) : 0.15))
            .frame(width: 16, height: 16)
            .scaleEffect(model.isRunning && model.pulse ? 1.25 : 1.0)
            .shadow(color: Theme.teal.opacity(model.isRunning && model.pulse ? 0.8 : 0), radius: 8)
            .animation(.easeOut(duration: 0.18), value: model.pulse)
    }

    private var timeString: String {
        String(format: "%d:%02d", model.seconds / 60, model.seconds % 60)
    }

    private var currentChord: some View {
        let chord = model.current
        return VStack(spacing: 10) {
            Text(chord.name)
                .font(.custom("Rajdhani-SemiBold", size: 80))
                .foregroundStyle(model.justMatched ? Theme.teal : .white)
                .shadow(color: model.justMatched ? Theme.teal.opacity(0.8) : .clear, radius: 22)
                .contentTransition(.numericText())
                .animation(.snappy, value: chord.id)
            FretboardDiagram(positions: chord.positions, mutedStrings: chord.mutedStrings, barre: chord.barre)
                .frame(width: FretboardDiagram.practiceWidth, height: FretboardDiagram.practiceHeight)
        }
    }

    private var nextHint: some View {
        Text("NEXT  ·  \(model.nextChord.name)")
            .font(Theme.title(16)).tracking(3)
            .foregroundStyle(Theme.frost.opacity(0.7))
    }

    private var controlButton: some View {
        Button {
            if !model.isRunning { model.resetCounters() }
            model.toggle()
        } label: {
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
                    .fill(model.isRunning ? AnyShapeStyle(.white.opacity(0.10)) : AnyShapeStyle(Theme.teal))
            }
            .shadow(color: model.isRunning ? .clear : Theme.teal.opacity(0.5), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
    }
}
