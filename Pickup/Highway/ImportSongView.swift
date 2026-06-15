//
//  ImportSongView.swift
//  Paste a simple single-note tab to add your own highway track.
//

import SwiftUI

struct ImportSongView: View {
    private let editing: ImportedSong?
    private let onClose: () -> Void

    @State private var title: String
    @State private var bpm: Double
    @State private var tab: String
    @State private var error: String?
    private let store = ImportStore.shared

    init(editing: ImportedSong? = nil, onClose: @escaping () -> Void) {
        self.editing = editing
        self.onClose = onClose
        _title = State(initialValue: editing?.title ?? "")
        _bpm = State(initialValue: Double(editing?.bpm ?? 100))
        _tab = State(initialValue: editing.map { Self.tokens(from: $0.steps) } ?? "")
    }

    /// Rebuild the token text from stored steps (for editing), including rhythm.
    private static func tokens(from steps: [[Int]]) -> String {
        steps.map { s -> String in
            let sixteenths = s.count > 2 ? s[2] : 4
            let letter = TabImport.letter(forBeats: Double(sixteenths) / 4.0)
            let suffix = letter == "q" ? "" : letter
            return s[0] < 0 ? "r" + suffix : "\(6 - s[0]):\(s[1])" + suffix
        }
        .joined(separator: " ")
    }

    var body: some View {
        ZStack {
            Theme.bgGradient.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header

                    field("TITLE") {
                        TextField("My Song", text: $title)
                            .textInputAutocapitalization(.words)
                            .foregroundStyle(.white)
                    }

                    field("TEMPO · \(Int(bpm)) BPM") {
                        Slider(value: $bpm, in: 40...200, step: 1).tint(Theme.teal)
                    }

                    field("TAB") {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("string:fret per note — string 1 = high e … 6 = low E.\nAdd a value for rhythm: q quarter, e eighth, h half, s 16th ('.' = dotted). Rest = r.\nExample: 1:0e 1:0e 1:1q  rq")
                                .font(Theme.body(12)).foregroundStyle(Theme.frost.opacity(0.6))
                            TextEditor(text: $tab)
                                .frame(height: 150)
                                .scrollContentBackground(.hidden)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(.black.opacity(0.25)))
                                .foregroundStyle(.white)
                                .font(.system(.body, design: .monospaced))
                        }
                    }

                    if let error {
                        Text(error).font(Theme.body(13)).foregroundStyle(.orange)
                    }

                    importButton
                }
                .padding(22)
            }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        HStack {
            Text(editing == nil ? "IMPORT A SONG" : "EDIT SONG").font(Theme.display(20)).tracking(3).foregroundStyle(.white)
            Spacer()
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.frost.opacity(0.85))
                    .frame(width: 38, height: 38).background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
        }
    }

    private func field<Content: View>(_ label: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label).font(Theme.light(12)).tracking(2).foregroundStyle(Theme.frost.opacity(0.6))
            content()
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var importButton: some View {
        Button {
            let steps = TabImport.parse(tab)
            guard steps.contains(where: { $0.string >= 0 }) else {
                error = "No valid notes found. Use tokens like 1:0 1:3 (add q/e/h for rhythm)."
                return
            }
            if let editing {
                store.update(id: editing.id, title: title, bpm: Int(bpm), steps: steps)
            } else {
                store.add(title: title, bpm: Int(bpm), steps: steps)
            }
            onClose()
        } label: {
            Text(editing == nil ? "ADD TO HIGHWAY" : "SAVE CHANGES").font(Theme.display(19)).tracking(3)
                .frame(maxWidth: .infinity).frame(height: 58)
                .foregroundStyle(Color(hex: 0x06222A))
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.teal))
                .shadow(color: Theme.teal.opacity(0.5), radius: 14, y: 5)
        }
        .buttonStyle(.plain)
    }
}
