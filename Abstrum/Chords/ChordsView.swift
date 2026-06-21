//
//  ChordsView.swift
//  The Chords tab — a chord bank you can filter and practice.
//

import SwiftUI

struct ChordsView: View {
    @State private var activeChord: Chord?
    @State private var filter: ChordQuality?
    @State private var showChanges = false
    @AppStorage("showFingerNumbers") private var showFingers = false

    private let columns = [GridItem(.flexible(), spacing: 14),
                           GridItem(.flexible(), spacing: 14)]

    private var chords: [Chord] { ChordBank.chords(quality: filter) }

    var body: some View {
        ZStack {
            ArcticBackground()
            VStack(spacing: 0) {
                header.padding(.top, 12)
                practiceChangesButton.padding(.top, 14).padding(.horizontal, 20)
                filterBar.padding(.top, 14)
                fingerToggle.padding(.top, 12)
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(chords) { chord in
                            Button { activeChord = chord } label: { chordCard(chord) }
                                .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $activeChord) { chord in
            ChordPracticeView(chord: chord) { activeChord = nil }
        }
        .fullScreenCover(isPresented: $showChanges) {
            ChordChangesView { showChanges = false }
        }
        .onAppear {
            #if DEBUG
            if let id = ProcessInfo.processInfo.environment["ABSTRUM_CHORD"],
               let chord = ChordBank.all.first(where: { $0.id == id }) {
                activeChord = chord
            }
            if let raw = ProcessInfo.processInfo.environment["ABSTRUM_CHORD_FILTER"],
               let quality = ChordQuality(rawValue: raw) {
                filter = quality
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_CHANGES"] != nil {
                showChanges = true
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 3) {
            Text("ABSTRUM").font(Theme.display(22)).tracking(10).foregroundStyle(.white)
            Text("CHORDS").font(Theme.light(12)).tracking(4).foregroundStyle(Theme.frost.opacity(0.6))
        }
    }

    private var practiceChangesButton: some View {
        Button { showChanges = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "arrow.left.arrow.right").font(.system(size: 15, weight: .semibold))
                Text("PRACTICE CHANGES").font(Theme.display(16)).tracking(2)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).opacity(0.6)
            }
            .foregroundStyle(Color(hex: 0x06222A))
            .padding(.horizontal, 18).frame(height: 50)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.teal))
            .shadow(color: Theme.teal.opacity(0.4), radius: 12, y: 4)
        }
        .buttonStyle(.plain)
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", active: filter == nil) { filter = nil }
                ForEach(ChordQuality.allCases, id: \.self) { quality in
                    chip(label: quality.label, active: filter == quality) { filter = quality }
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private var fingerToggle: some View {
        VStack(spacing: 8) {
            Button { showFingers.toggle() } label: {
                HStack(spacing: 8) {
                    Image(systemName: showFingers ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 15, weight: .semibold))
                    Text("SHOW FINGER NUMBERS").font(Theme.title(13)).tracking(1)
                    Spacer()
                }
                .foregroundStyle(showFingers ? Theme.teal : Theme.frost.opacity(0.75))
                .padding(.horizontal, 16).frame(height: 38)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.06)))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(showFingers ? Theme.teal.opacity(0.5) : .white.opacity(0.12), lineWidth: 1))
            }
            .buttonStyle(.plain)
            if showFingers {
                Text("1 index   ·   2 middle   ·   3 ring   ·   4 pinky")
                    .font(Theme.light(11)).tracking(1).foregroundStyle(Theme.frost.opacity(0.65))
            }
        }
        .padding(.horizontal, 20)
        .animation(.easeInOut(duration: 0.18), value: showFingers)
    }

    private func chip(label: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(Theme.title(14)).tracking(1)
                .foregroundStyle(active ? Color(hex: 0x06222A) : Theme.frost.opacity(0.8))
                .padding(.horizontal, 16).frame(height: 36)
                .background(Capsule().fill(active ? AnyShapeStyle(Theme.teal) : AnyShapeStyle(.white.opacity(0.07))))
                .overlay(Capsule().stroke(active ? .clear : .white.opacity(0.14), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func chordCard(_ chord: Chord) -> some View {
        VStack(spacing: 6) {
            HStack {
                Text(chord.name).font(Theme.display(26)).foregroundStyle(.white)
                Spacer()
                Text(chord.quality.label).font(Theme.body(12)).foregroundStyle(Theme.frost.opacity(0.6))
            }
            FretboardDiagram(positions: chord.positions, mutedStrings: chord.mutedStrings,
                             barre: chord.barre, showFingers: showFingers)
                .frame(height: 124)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }
}
