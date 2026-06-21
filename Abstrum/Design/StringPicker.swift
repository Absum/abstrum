//
//  StringPicker.swift
//  Row of the six open strings; the active/nearest one glows teal. Tapping a
//  string locks onto it (manual mode); tapping it again returns to auto.
//

import SwiftUI

struct StringPicker: View {
    let strings: [GuitarString]
    let activeID: Int?
    let onSelect: (GuitarString) -> Void

    var body: some View {
        HStack(spacing: 10) {
            ForEach(strings) { string in
                let active = string.id == activeID
                Button { onSelect(string) } label: {
                    VStack(spacing: 1) {
                        Text(string.name).font(Theme.display(22))
                        Text(string.label).font(Theme.body(11)).opacity(0.7)
                    }
                    .foregroundStyle(active ? .white : Theme.frost.opacity(0.7))
                    .frame(width: 48, height: 58)
                    .background {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(active ? AnyShapeStyle(Theme.teal.opacity(0.9))
                                         : AnyShapeStyle(.white.opacity(0.06)))
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .stroke(active ? Theme.teal : .white.opacity(0.14), lineWidth: 1)
                    }
                    .shadow(color: active ? Theme.teal.opacity(0.55) : .clear, radius: 12)
                }
                .buttonStyle(.plain)
                .animation(.snappy, value: active)
            }
        }
    }
}
