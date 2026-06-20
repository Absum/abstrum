//
//  PlayAlongView.swift
//  Pick a song, then play through its chord chart in time with a click while
//  the app scores which bars you nailed.
//

import SwiftUI

struct PlayAlongView: View {
    let onClose: () -> Void
    @State private var song: Song?

    var body: some View {
        ZStack {
            ArcticBackground()
            if let song {
                PlayAlongRunner(song: song) { self.song = nil }
                    .id(song.id)
            } else {
                menu
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            #if DEBUG
            if let id = ProcessInfo.processInfo.environment["PICKUP_PLAYALONG"],
               let match = SongLibrary.all.first(where: { $0.id == id }) {
                song = match
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
                Text("PLAY ALONG").font(Theme.display(18)).tracking(4).foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20).padding(.top, 12)

            ScrollView {
                VStack(spacing: 14) {
                    ForEach(SongLibrary.all) { item in
                        Button { song = item } label: { songCard(item) }
                            .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 22).padding(.top, 22)
            }
        }
    }

    private func songCard(_ song: Song) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.teal.opacity(0.18)).frame(width: 52, height: 52)
                Image(systemName: "music.note").font(.system(size: 22)).foregroundStyle(Theme.teal)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(song.title).font(Theme.display(20)).foregroundStyle(.white)
                Text("\(song.credit) · \(song.bpm) BPM").font(Theme.body(13)).foregroundStyle(Theme.frost.opacity(0.65))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.frost.opacity(0.5))
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}

private struct PlayAlongRunner: View {
    @State private var model: PlayAlongViewModel
    let onBack: () -> Void

    init(song: Song, onBack: @escaping () -> Void) {
        _model = State(initialValue: PlayAlongViewModel(song: song))
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            if model.finished { results } else { player }
        }
        .onDisappear {
            if model.isPlaying { model.toggle() }
            if model.isPreviewing { model.togglePreview() }
        }
    }

    private var player: some View {
        VStack(spacing: 0) {
            topBar.padding(.top, 12)
            progressBar.padding(.horizontal, 24).padding(.top, 14)
            Spacer()
            currentChord
            Spacer().frame(height: 12)
            beatDots
            Spacer().frame(height: 10)
            nextHint
            Spacer()
            VStack(spacing: 10) {
                if !model.isPlaying { practiceControls }
                if !model.isPlaying { listenButton }
                controlButton
            }
            .padding(.horizontal, 30).padding(.bottom, 18)
        }
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
            VStack(spacing: 2) {
                Text(model.song.title.uppercased()).font(Theme.display(16)).tracking(2).foregroundStyle(.white)
                Text("BAR \(min(model.barIndex + 1, model.total)) / \(model.total)")
                    .font(Theme.light(11)).tracking(2).foregroundStyle(Theme.frost.opacity(0.6))
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }

    private var progressBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule().fill(Theme.teal).frame(width: geo.size.width * model.progress)
            }
        }
        .frame(height: 5)
        .animation(.snappy, value: model.progress)
    }

    private var currentChord: some View {
        VStack(spacing: 10) {
            Text(model.current.name)
                .font(.custom("Rajdhani-SemiBold", size: 96))
                .foregroundStyle(model.currentBarHit ? Theme.teal : .white)
                .shadow(color: model.currentBarHit ? Theme.teal.opacity(0.8) : .clear, radius: 22)
                .contentTransition(.numericText())
                .animation(.snappy, value: model.current.id)
            FretboardDiagram(positions: model.current.positions,
                             mutedStrings: model.current.mutedStrings, barre: model.current.barre)
                .frame(width: FretboardDiagram.practiceWidth, height: FretboardDiagram.practiceHeight)
        }
    }

    private var beatDots: some View {
        HStack(spacing: 12) {
            ForEach(0..<model.song.beatsPerBar, id: \.self) { i in
                Circle()
                    .fill(i < model.beatInBar ? Theme.teal : .white.opacity(0.15))
                    .frame(width: 10, height: 10)
            }
        }
        .animation(.snappy, value: model.beatInBar)
    }

    private var nextHint: some View {
        Text(model.nextChord.map { "NEXT  ·  \($0.name)" } ?? "LAST BAR")
            .font(Theme.title(15)).tracking(3).foregroundStyle(Theme.frost.opacity(0.7))
    }

    private var practiceControls: some View {
        HStack(spacing: 8) {
            ForEach([0.5, 0.75, 1.0], id: \.self) { s in
                Button { model.speed = s } label: {
                    Text(String(format: "%g×", s))
                        .font(Theme.title(13)).tracking(1)
                        .foregroundStyle(model.speed == s ? Color(hex: 0x06222A) : Theme.frost.opacity(0.8))
                        .frame(maxWidth: .infinity).frame(height: 36)
                        .background(Capsule().fill(model.speed == s ? AnyShapeStyle(Theme.teal) : AnyShapeStyle(.white.opacity(0.07))))
                        .overlay(Capsule().stroke(model.speed == s ? .clear : .white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            Button { model.loop.toggle() } label: {
                Image(systemName: model.loop ? "repeat.circle.fill" : "repeat")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(model.loop ? Theme.teal : Theme.frost.opacity(0.8))
                    .frame(width: 46, height: 36)
                    .background(Capsule().fill(model.loop ? Theme.teal.opacity(0.15) : .white.opacity(0.07)))
                    .overlay(Capsule().stroke(model.loop ? Theme.teal.opacity(0.5) : .white.opacity(0.14), lineWidth: 1))
            }
            .buttonStyle(.plain)
        }
    }

    private var listenButton: some View {
        Button(action: model.togglePreview) {
            HStack(spacing: 10) {
                Image(systemName: model.isPreviewing ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 15, weight: .semibold))
                Text(model.isPreviewing ? "STOP PREVIEW" : "LISTEN FIRST")
                    .font(Theme.display(17)).tracking(2)
            }
            .frame(maxWidth: .infinity).frame(height: 50)
            .foregroundStyle(Theme.frost)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var controlButton: some View {
        Button(action: model.toggle) {
            HStack(spacing: 12) {
                Image(systemName: model.isPlaying ? "stop.fill" : "play.fill")
                    .font(.system(size: 18, weight: .semibold))
                Text(model.isPlaying ? "STOP" : "PLAY ALONG")
                    .font(Theme.display(21)).tracking(4)
            }
            .frame(maxWidth: .infinity).frame(height: 62)
            .foregroundStyle(model.isPlaying ? Theme.frost : Color(hex: 0x06222A))
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(model.isPlaying ? AnyShapeStyle(.white.opacity(0.10)) : AnyShapeStyle(Theme.teal))
            }
            .shadow(color: model.isPlaying ? .clear : Theme.teal.opacity(0.5), radius: 16, y: 6)
            .opacity(model.isPreviewing ? 0.4 : 1)
        }
        .buttonStyle(.plain)
        .disabled(model.isPreviewing)
    }

    private var results: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note.list").font(.system(size: 72)).foregroundStyle(Theme.teal)
                .shadow(color: Theme.teal.opacity(0.6), radius: 22)
            Text("\(model.hits) / \(model.total)")
                .font(.custom("Rajdhani-SemiBold", size: 72)).foregroundStyle(.white)
            Text("CHORDS NAILED").font(Theme.light(12)).tracking(4).foregroundStyle(Theme.frost.opacity(0.7))

            VStack(spacing: 12) {
                Button { model.restart() } label: {
                    Text("PLAY AGAIN").font(Theme.display(18)).tracking(3)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .foregroundStyle(Color(hex: 0x06222A))
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.teal))
                }
                .buttonStyle(.plain)
                Button(action: onBack) {
                    Text("SONGS").font(Theme.display(18)).tracking(3)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .foregroundStyle(.white)
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.10)))
                        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40).padding(.top, 12)
        }
        .padding()
    }
}
