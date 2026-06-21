//
//  ReviewSessionView.swift
//  The spaced-repetition review session: a hub that walks the user through the
//  skills due today, shoring up what's shaky before moving on to new material.
//  Each skill is practised via the normal LessonView; completing a run is
//  recorded as a review (see ProgressStore.recordRun), which pushes its next
//  due-date out — so a reviewed skill drops off today's queue automatically.
//

import SwiftUI

struct ReviewSessionView: View {
    /// The due-for-review queue, snapshotted when the session opened.
    let lessonIDs: [String]
    let onClose: () -> Void

    private let store = ProgressStore.shared
    @State private var activeLesson: Lesson?
    @State private var reviewedIDs: Set<String> = []

    private var lessons: [Lesson] {
        lessonIDs.compactMap { id in LessonLibrary.all.first { $0.id == id } }
    }
    private var remaining: [Lesson] { lessons.filter { !reviewedIDs.contains($0.id) } }
    private var allDone: Bool { remaining.isEmpty }

    var body: some View {
        ZStack {
            ArcticBackground(glow: allDone)
            VStack(spacing: 0) {
                header.padding(.top, 12)
                ScrollView {
                    VStack(spacing: 14) {
                        intro.padding(.top, 8)
                        ForEach(lessons) { lesson in
                            skillRow(lesson)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 18)
                }
                primaryButton.padding(.horizontal, 22).padding(.bottom, 24)
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $activeLesson) { lesson in
            LessonView(lesson: lesson) {
                // A completed run pushes the next review out, so it's no longer
                // due today; a bail-out leaves it due and still on the queue.
                if !store.isDueForReview(lesson.id) { reviewedIDs.insert(lesson.id) }
                activeLesson = nil
            }
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
                Text("REVIEW").font(Theme.display(18)).tracking(4).foregroundStyle(.white)
                Text("\(reviewedIDs.count) / \(lessons.count) done")
                    .font(Theme.light(11)).tracking(2).foregroundStyle(Theme.frost.opacity(0.6))
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }

    private var intro: some View {
        VStack(spacing: 6) {
            Image(systemName: allDone ? "checkmark.seal.fill" : "clock.arrow.circlepath")
                .font(.system(size: 40))
                .foregroundStyle(allDone ? Theme.teal : Theme.cyan)
                .shadow(color: allDone ? Theme.teal.opacity(0.6) : .clear, radius: 18)
            Text(allDone ? "All caught up" : "Shore up what's shaky")
                .font(Theme.display(22)).foregroundStyle(.white)
            Text(allDone
                 ? "Every due skill is reviewed for today."
                 : "These skills are due for a quick refresher.")
                .font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(.bottom, 4)
    }

    // MARK: - Rows

    private func skillRow(_ lesson: Lesson) -> some View {
        let done = reviewedIDs.contains(lesson.id)
        return Button { activeLesson = lesson } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(done ? Theme.teal.opacity(0.2) : Theme.cyan.opacity(0.16))
                        .frame(width: 44, height: 44)
                    Image(systemName: done ? "checkmark" : "arrow.counterclockwise")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(done ? Theme.teal : Theme.cyan)
                }
                VStack(alignment: .leading, spacing: 3) {
                    Text(lesson.title).font(Theme.display(19))
                        .foregroundStyle(done ? Theme.frost.opacity(0.6) : .white)
                    Text(done ? "Reviewed" : lesson.subtitle)
                        .font(Theme.body(13))
                        .foregroundStyle(done ? Theme.teal.opacity(0.8) : Theme.frost.opacity(0.65))
                }
                Spacer()
                if !done {
                    Image(systemName: "chevron.right").foregroundStyle(Theme.frost.opacity(0.5))
                }
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(.white.opacity(done ? 0.03 : 0.06)))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.white.opacity(done ? 0.07 : 0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Primary action

    private var primaryButton: some View {
        Button {
            if let next = remaining.first { activeLesson = next } else { onClose() }
        } label: {
            Text(allDone ? "DONE" : "REVIEW \(remaining.first?.title.uppercased() ?? "")")
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
