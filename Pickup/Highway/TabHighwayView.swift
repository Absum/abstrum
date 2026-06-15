//
//  TabHighwayView.swift
//  Falling-note highway: fret markers scroll down 6 string lanes to a strike
//  line; the pitch engine lights the ones you hit.
//

import SwiftUI

struct TabHighwayView: View {
    let onClose: () -> Void
    @State private var track: HighwayTrack?
    @State private var showImport = false
    @State private var editingSong: ImportedSong?
    private let imports = ImportStore.shared

    var body: some View {
        ZStack {
            ArcticBackground()
            if let track {
                HighwayRunner(track: track) { self.track = nil }
                    .id(track.id)
            } else {
                menu
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showImport) { ImportSongView(editing: nil) { showImport = false } }
        .sheet(item: $editingSong) { song in ImportSongView(editing: song) { editingSong = nil } }
        .onAppear {
            #if DEBUG
            if let id = ProcessInfo.processInfo.environment["PICKUP_HIGHWAY"],
               let match = HighwayLibrary.all.first(where: { $0.id == id }) {
                track = match
            }
            if ProcessInfo.processInfo.environment["PICKUP_IMPORT"] != nil {
                showImport = true
            }
            if ProcessInfo.processInfo.environment["PICKUP_SEED_IMPORT"] != nil, imports.songs.isEmpty {
                imports.add(title: "My Riff", bpm: 100,
                            steps: [(5, 0, 0.5), (5, 1, 0.5), (5, 3, 1), (4, 3, 1), (4, 1, 2)])
            }
            if ProcessInfo.processInfo.environment["PICKUP_EDIT"] != nil {
                editingSong = imports.songs.first
            }
            if ProcessInfo.processInfo.environment["PICKUP_PLAY_IMPORT"] != nil {
                track = imports.tracks.first
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
                Text("TAB HIGHWAY").font(Theme.display(18)).tracking(4).foregroundStyle(.white)
                Spacer()
                Color.clear.frame(width: 40, height: 40)
            }
            .padding(.horizontal, 20).padding(.top, 12)

            ScrollView {
                VStack(spacing: 14) {
                    importButton
                    ForEach(imports.tracks) { trackRow($0, deletable: true) }
                    ForEach(HighwayLibrary.all) { trackRow($0, deletable: false) }
                }
                .padding(.horizontal, 22).padding(.top, 22)
            }
        }
    }

    private var importButton: some View {
        Button { showImport = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "plus.circle.fill").font(.system(size: 18, weight: .semibold))
                Text("IMPORT A SONG").font(Theme.display(16)).tracking(2)
                Spacer()
            }
            .foregroundStyle(Theme.frost)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func trackRow(_ item: HighwayTrack, deletable: Bool) -> some View {
        HStack(spacing: 0) {
            Button { track = item } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 8) {
                            Text(item.title).font(Theme.display(22)).foregroundStyle(.white)
                            if item.licensed {
                                tag("LICENSED", .orange)
                            } else if deletable {
                                tag("MINE", Theme.teal)
                            }
                        }
                        Text("\(item.credit) · \(item.bpm) BPM").font(Theme.body(13))
                            .foregroundStyle(Theme.frost.opacity(0.65))
                    }
                    Spacer()
                    if !deletable {
                        Image(systemName: "chevron.right").foregroundStyle(Theme.frost.opacity(0.5))
                    }
                }
            }
            .buttonStyle(.plain)
            if deletable {
                Button { editingSong = imports.songs.first { $0.id == item.id } } label: {
                    Image(systemName: "pencil").font(.system(size: 16))
                        .foregroundStyle(Theme.frost.opacity(0.7)).padding(.leading, 14)
                }
                .buttonStyle(.plain)
                Button { imports.delete(item.id) } label: {
                    Image(systemName: "trash").font(.system(size: 16))
                        .foregroundStyle(Theme.frost.opacity(0.6)).padding(.leading, 14)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private func tag(_ text: String, _ color: Color) -> some View {
        Text(text).font(Theme.body(10)).tracking(1)
            .foregroundStyle(Color(hex: 0x06222A))
            .padding(.horizontal, 7).padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.85)))
    }
}

private struct HighwayRunner: View {
    @State private var model: TabHighwayViewModel
    let onBack: () -> Void

    private let stringLabels = ["E", "A", "D", "G", "B", "e"]
    private let speed: CGFloat = 170     // points per second

    init(track: HighwayTrack, onBack: @escaping () -> Void) {
        _model = State(initialValue: TabHighwayViewModel(track: track))
        self.onBack = onBack
    }

    var body: some View {
        ZStack {
            if model.finished { results } else { runner }
        }
        .onDisappear {
            if model.isPlaying { model.toggle() }
            if model.isPreviewing { model.togglePreview() }
        }
    }

    private let speeds: [Double] = [0.5, 0.75, 1.0, 1.25]

    private var runner: some View {
        VStack(spacing: 0) {
            topBar.padding(.top, 12)
            highway
            waitToggle.padding(.horizontal, 30).padding(.bottom, 8)
            speedSelector.padding(.horizontal, 30).padding(.bottom, 10)
            if !model.isPlaying { listenButton.padding(.horizontal, 30).padding(.bottom, 10) }
            controlButton.padding(.horizontal, 30).padding(.bottom, 18)
        }
    }

    private var listenButton: some View {
        Button(action: model.togglePreview) {
            HStack(spacing: 10) {
                Image(systemName: model.isPreviewing ? "stop.fill" : "speaker.wave.2.fill")
                    .font(.system(size: 14, weight: .semibold))
                Text(model.isPreviewing ? "STOP" : "LISTEN").font(Theme.display(17)).tracking(2)
            }
            .frame(maxWidth: .infinity).frame(height: 48)
            .foregroundStyle(Theme.frost)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.08)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.16), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var waitToggle: some View {
        Button { model.waitMode.toggle() } label: {
            HStack(spacing: 8) {
                Image(systemName: model.waitMode ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .semibold))
                Text("WAIT FOR EACH NOTE").font(Theme.title(13)).tracking(1)
                Spacer()
            }
            .foregroundStyle(model.waitMode ? Theme.teal : Theme.frost.opacity(0.7))
            .padding(.horizontal, 16).frame(height: 40)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(model.waitMode ? Theme.teal.opacity(0.5) : .white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(model.isPlaying || model.isPreviewing)
        .opacity(model.isPlaying || model.isPreviewing ? 0.4 : 1)
    }

    private var speedSelector: some View {
        HStack(spacing: 8) {
            ForEach(speeds, id: \.self) { s in
                Button { model.speed = s } label: {
                    Text(String(format: "%g×", s))
                        .font(Theme.title(14)).tracking(1)
                        .foregroundStyle(model.speed == s ? Color(hex: 0x06222A) : Theme.frost.opacity(0.8))
                        .frame(maxWidth: .infinity).frame(height: 34)
                        .background(Capsule().fill(model.speed == s ? AnyShapeStyle(Theme.teal) : AnyShapeStyle(.white.opacity(0.07))))
                        .overlay(Capsule().stroke(model.speed == s ? .clear : .white.opacity(0.14), lineWidth: 1))
                }
                .buttonStyle(.plain)
                .disabled(model.isPlaying)
            }
        }
        .opacity(model.isPlaying ? 0.4 : 1)
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
                Text(model.track.title.uppercased()).font(Theme.display(16)).tracking(2).foregroundStyle(.white)
                Text("\(model.hits) / \(model.total) HIT").font(Theme.light(11)).tracking(2)
                    .foregroundStyle(Theme.frost.opacity(0.6))
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }

    private var highway: some View {
        Canvas { ctx, size in
            let lanes = 6
            let laneW = size.width / CGFloat(lanes)
            let strikeY = size.height * 0.84
            let r: CGFloat = min(laneW * 0.34, 22)
            func laneX(_ s: Int) -> CGFloat { laneW * (CGFloat(s) + 0.5) }

            // Lanes
            for s in 0..<lanes {
                var p = Path()
                p.move(to: CGPoint(x: laneX(s), y: 0))
                p.addLine(to: CGPoint(x: laneX(s), y: size.height))
                ctx.stroke(p, with: .color(.white.opacity(0.08)), lineWidth: 1)
            }
            // Strike line
            var strike = Path()
            strike.move(to: CGPoint(x: 0, y: strikeY))
            strike.addLine(to: CGPoint(x: size.width, y: strikeY))
            ctx.stroke(strike, with: .color(Theme.teal.opacity(0.9)), lineWidth: 2)

            // Hit flashes: an expanding, fading ring in the lane that was hit.
            for (lane, t) in model.flashes {
                let age = model.currentTime - t
                guard age >= 0, age < 0.4 else { continue }
                let p = age / 0.4
                let radius = r + CGFloat(p) * r * 1.8
                let rect = CGRect(x: laneX(lane) - radius, y: strikeY - radius,
                                  width: radius * 2, height: radius * 2)
                ctx.stroke(Path(ellipseIn: rect),
                           with: .color(Theme.teal.opacity(0.9 * (1 - p))), lineWidth: 3)
            }
            // String labels below the strike line
            for s in 0..<lanes {
                ctx.draw(Text(stringLabels[s]).font(Theme.light(12)).foregroundColor(Theme.frost.opacity(0.5)),
                         at: CGPoint(x: laneX(s), y: strikeY + 18))
            }

            // Notes
            for note in model.notes {
                let y = strikeY - CGFloat(model.seconds(of: note) - model.currentTime) * speed
                if y < -r * 2 || y > strikeY + r { continue }
                let x = laneX(note.string)
                let hit = model.hitIDs.contains(note.id)
                let missed = model.seconds(of: note) < model.currentTime - 0.32 && !hit
                let color: Color = hit ? Theme.teal : (missed ? Theme.frost.opacity(0.22) : Theme.cyan)
                // Sustain tail: longer notes trail upward (toward where they fell from).
                let durSec = note.duration * 60.0 / Double(model.track.bpm) / max(0.25, model.speed)
                let tailLen = CGFloat(durSec) * speed - 2 * r - 6
                if tailLen > 4 {
                    let tw = r * 0.75
                    let tail = CGRect(x: x - tw, y: y - tailLen, width: 2 * tw, height: tailLen)
                    ctx.fill(Path(roundedRect: tail, cornerRadius: tw), with: .color(color.opacity(0.45)))
                }
                let rect = CGRect(x: x - r, y: y - r, width: 2 * r, height: 2 * r)
                ctx.fill(Path(ellipseIn: rect), with: .color(color))
                ctx.draw(Text("\(note.fret)").font(Theme.display(16)).foregroundColor(Color(hex: 0x06222A)),
                         at: CGPoint(x: x, y: y))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var controlButton: some View {
        Button(action: model.toggle) {
            HStack(spacing: 12) {
                Image(systemName: model.isPlaying ? "stop.fill" : "play.fill").font(.system(size: 18, weight: .semibold))
                Text(model.isPlaying ? "STOP" : "START").font(Theme.display(21)).tracking(4)
            }
            .frame(maxWidth: .infinity).frame(height: 62)
            .foregroundStyle(model.isPlaying ? Theme.frost : Color(hex: 0x06222A))
            .background {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(model.isPlaying ? AnyShapeStyle(.white.opacity(0.10)) : AnyShapeStyle(Theme.teal))
            }
            .shadow(color: model.isPlaying ? .clear : Theme.teal.opacity(0.5), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
    }

    private var results: some View {
        VStack(spacing: 20) {
            Image(systemName: "star.fill").font(.system(size: 64)).foregroundStyle(Theme.teal)
                .shadow(color: Theme.teal.opacity(0.6), radius: 20)
            Text("\(model.hits) / \(model.total)")
                .font(.custom("Rajdhani-SemiBold", size: 72)).foregroundStyle(.white)
            Text("NOTES HIT").font(Theme.light(12)).tracking(4).foregroundStyle(Theme.frost.opacity(0.7))
            VStack(spacing: 12) {
                Button { model.restart() } label: {
                    Text("PLAY AGAIN").font(Theme.display(18)).tracking(3)
                        .frame(maxWidth: .infinity).frame(height: 56)
                        .foregroundStyle(Color(hex: 0x06222A))
                        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.teal))
                }
                .buttonStyle(.plain)
                Button(action: onBack) {
                    Text("TRACKS").font(Theme.display(18)).tracking(3)
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
