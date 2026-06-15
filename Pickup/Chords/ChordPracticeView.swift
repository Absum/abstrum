//
//  ChordPracticeView.swift
//  Shows a chord's shape and verifies you played it (live match meter).
//

import SwiftUI

struct ChordPracticeView: View {
    @State private var model: ChordPracticeViewModel
    private let onClose: () -> Void

    init(chord: Chord, onClose: @escaping () -> Void) {
        _model = State(initialValue: ChordPracticeViewModel(chord: chord))
        self.onClose = onClose
    }

    private var chord: Chord { model.chord }

    var body: some View {
        ZStack {
            ArcticBackground(glow: model.matched)
            VStack(spacing: 0) {
                topBar.padding(.top, 12)

                Spacer(minLength: 16)

                VStack(spacing: 6) {
                    Text(chord.name)
                        .font(.custom("Rajdhani-SemiBold", size: 96))
                        .foregroundStyle(model.matched ? Theme.teal : .white)
                        .shadow(color: model.matched ? Theme.teal.opacity(0.8) : .clear, radius: 24)
                    Text(chord.quality.label.uppercased())
                        .font(Theme.light(13)).tracking(5).foregroundStyle(Theme.frost.opacity(0.7))
                }

                FretboardDiagram(positions: chord.positions, mutedStrings: chord.mutedStrings, barre: chord.barre)
                    .frame(width: 286, height: 232)
                    .padding(.top, 28)

                Spacer(minLength: 28)

                hearItButton

                Spacer(minLength: 32)

                matchMeter.padding(.horizontal, 44)
                statusLine.padding(.top, 18)

                Spacer(minLength: 28)

                prompt.padding(.bottom, 30)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { model.start() }
        .onDisappear { model.stop() }
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.frost.opacity(0.85))
                    .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            Spacer()
            Text("CHORD PRACTICE").font(Theme.display(18)).tracking(4).foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }

    private var hearItButton: some View {
        Button { model.playExample() } label: {
            HStack(spacing: 8) {
                Image(systemName: "speaker.wave.2.fill").font(.system(size: 15, weight: .semibold))
                Text("HEAR IT").font(Theme.display(16)).tracking(3)
            }
            .foregroundStyle(Theme.frost)
            .padding(.horizontal, 22).frame(height: 46)
            .background(Capsule().fill(.white.opacity(0.08)))
            .overlay(Capsule().stroke(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var matchMeter: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule()
                    .fill(model.matched ? Theme.teal : Theme.cyan)
                    .frame(width: geo.size.width * CGFloat(min(1, max(0, model.score))))
                    .shadow(color: (model.matched ? Theme.teal : Theme.cyan).opacity(0.7), radius: 8)
            }
        }
        .frame(height: 8)
        .animation(.snappy, value: model.score)
    }

    private var statusLine: some View {
        Group {
            if model.matched {
                Text("CHORD MATCHED ✓").foregroundStyle(Theme.teal)
            } else {
                Text("Strum the \(chord.name) chord").foregroundStyle(Theme.frost.opacity(0.75))
            }
        }
        .font(Theme.title(18)).tracking(2)
        .animation(.snappy, value: model.matched)
    }

    private var prompt: some View {
        Text(model.permissionDenied ? "Enable microphone access in Settings"
                                    : "\(Int(model.score * 100))% match")
            .font(Theme.light(13)).tracking(3).foregroundStyle(Theme.frost.opacity(0.5))
    }
}
