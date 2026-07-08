//
//  DailySessionView.swift
//  Plays a generated daily session in order — warm-up → review → new skill →
//  song → cool-down — through the normal LessonView. A guided, deliberate
//  practice flow that replaces free browsing.
//

import SwiftUI

struct DailySessionView: View {
    let items: [SessionItem]
    let onClose: () -> Void

    @State private var activeItem: SessionItem?
    @State private var doneItems: Set<String> = []   // SessionItem.id

    private var remaining: [SessionItem] { items.filter { !doneItems.contains($0.id) } }
    private var allDone: Bool { remaining.isEmpty }

    var body: some View {
        ZStack {
            ArcticBackground(glow: allDone)
            VStack(spacing: 0) {
                header.padding(.top, 12)
                ScrollView {
                    VStack(spacing: 12) {
                        intro.padding(.top, 8)
                        ForEach(items) { item in stepRow(item) }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                }
                primaryButton.padding(.horizontal, 22).padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $activeItem) { item in
            // Only a completed run checks the step off — bailing out with the X
            // leaves it on the list (onClose fires for both, onFinished doesn't).
            LessonView(lesson: item.lesson,
                       onFinished: { doneItems.insert(item.id) },
                       onClose: { activeItem = nil })
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.frost.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text("TODAY").font(Theme.display(18)).tracking(4).foregroundStyle(.white)
                Text("\(doneItems.count) / \(items.count) done")
                    .font(Theme.light(11)).tracking(2).foregroundStyle(Theme.frost.opacity(0.6))
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }

    private var intro: some View {
        VStack(spacing: 6) {
            Image(systemName: allDone ? "checkmark.seal.fill" : "figure.strengthtraining.traditional")
                .font(.system(size: 38))
                .foregroundStyle(allDone ? Theme.teal : Theme.cyan)
                .shadow(color: allDone ? Theme.teal.opacity(0.6) : .clear, radius: 18)
            Text(allDone ? "Session complete" : "Today's practice")
                .font(Theme.display(22)).foregroundStyle(.white)
            Text(allDone
                 ? "Nice work — you hit every step."
                 : "\(items.count) steps · about \(max(5, items.count * 2)) min, guided")
                .font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Rows

    private func stepRow(_ item: SessionItem) -> some View {
        let done = doneItems.contains(item.id)
        return Button { activeItem = item } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(done ? Theme.teal.opacity(0.2) : Theme.cyan.opacity(0.16))
                        .frame(width: 42, height: 42)
                    Image(systemName: done ? "checkmark" : phaseIcon(item.phase))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(done ? Theme.teal : Theme.cyan)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.phase.label.uppercased())
                        .font(Theme.light(10)).tracking(2)
                        .foregroundStyle(done ? Theme.teal.opacity(0.8) : Theme.frost.opacity(0.55))
                    Text(item.lesson.title).font(Theme.display(18))
                        .foregroundStyle(done ? Theme.frost.opacity(0.6) : .white)
                    Text(done ? "Done" : item.phase.blurb)
                        .font(Theme.body(13))
                        .foregroundStyle(done ? Theme.teal.opacity(0.8) : Theme.frost.opacity(0.6))
                }
                Spacer()
                if !done {
                    Image(systemName: "chevron.right").foregroundStyle(Theme.frost.opacity(0.5))
                }
            }
            .padding(15)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(done ? 0.03 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(done ? 0.07 : 0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func phaseIcon(_ phase: SessionPhase) -> String {
        switch phase {
        case .warmUp:   return "wind"
        case .review:   return "arrow.counterclockwise"
        case .newSkill: return "sparkles"
        case .song:     return "music.note"
        case .coolDown: return "leaf"
        }
    }

    // MARK: - Primary action

    private var primaryButton: some View {
        Button {
            if let next = remaining.first { activeItem = next } else { onClose() }
        } label: {
            Text(allDone ? "DONE" : "START \(remaining.first?.phase.label.uppercased() ?? "")")
                .font(Theme.display(17)).tracking(3)
                .lineLimit(1)
                .frame(maxWidth: .infinity).frame(height: 56)
                .foregroundStyle(Color(hex: 0x06222A))
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.teal))
                .shadow(color: Theme.teal.opacity(0.45), radius: 14, y: 5)
        }
        .buttonStyle(.plain)
    }
}
