//
//  LearnHomeView.swift
//  The Learn tab — the skill path. Lessons unlock as you complete prerequisites.
//

import SwiftUI

struct LearnHomeView: View {
    @State private var activeLesson: Lesson?
    private let store = ProgressStore.shared

    private var completedCount: Int { store.completedLessonIDs.count }
    private var total: Int { LessonLibrary.all.count }

    var body: some View {
        ZStack {
            ArcticBackground()
            VStack(spacing: 0) {
                header.padding(.top, 12)
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(LessonLibrary.all) { lesson in
                            let completed = store.isCompleted(lesson.id)
                            let unlocked = LessonLibrary.isUnlocked(lesson, completed: store.completedLessonIDs)
                            Button { if unlocked { activeLesson = lesson } } label: {
                                lessonCard(lesson, completed: completed, unlocked: unlocked)
                            }
                            .buttonStyle(.plain)
                            .disabled(!unlocked)
                        }
                        resetButton.padding(.top, 8)
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 22)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $activeLesson) { lesson in
            LessonView(lesson: lesson) { activeLesson = nil }
        }
        .onAppear {
            #if DEBUG
            if let raw = ProcessInfo.processInfo.environment["PICKUP_COMPLETE"] {
                raw.split(separator: ",").forEach { store.markCompleted(String($0)) }
            }
            if ProcessInfo.processInfo.environment["PICKUP_LESSON"] == "open" {
                activeLesson = LessonLibrary.openStrings
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 10) {
            VStack(spacing: 3) {
                Text("PICKUP").font(Theme.display(22)).tracking(10).foregroundStyle(.white)
                Text("LEARN").font(Theme.light(12)).tracking(4).foregroundStyle(Theme.frost.opacity(0.6))
            }
            progressBar.padding(.horizontal, 40).padding(.top, 4)
        }
    }

    private var progressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10))
                    Capsule().fill(Theme.teal)
                        .frame(width: geo.size.width * (total == 0 ? 0 : CGFloat(completedCount) / CGFloat(total)))
                }
            }
            .frame(height: 5)
            Text("\(completedCount) OF \(total) COMPLETE")
                .font(Theme.light(11)).tracking(3).foregroundStyle(Theme.frost.opacity(0.6))
        }
        .animation(.snappy, value: completedCount)
    }

    private func lessonCard(_ lesson: Lesson, completed: Bool, unlocked: Bool) -> some View {
        let iconName = completed ? "checkmark.seal.fill" : (unlocked ? "guitars.fill" : "lock.fill")
        let iconTint = unlocked ? Theme.teal : Theme.frost.opacity(0.5)
        let titleTint: Color = unlocked ? .white : Theme.frost.opacity(0.5)

        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(unlocked ? Theme.teal.opacity(0.18) : .white.opacity(0.05))
                    .frame(width: 56, height: 56)
                Image(systemName: iconName).font(.system(size: 23)).foregroundStyle(iconTint)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).font(Theme.display(22)).foregroundStyle(titleTint)
                Text(completed ? "Completed · tap to practice" : lesson.subtitle)
                    .font(Theme.body(14))
                    .foregroundStyle(completed ? Theme.teal.opacity(0.9) : Theme.frost.opacity(unlocked ? 0.7 : 0.45))
            }
            Spacer()
            if unlocked {
                Image(systemName: "chevron.right").foregroundStyle(Theme.frost.opacity(0.5))
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .fill(.white.opacity(unlocked ? 0.06 : 0.03)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous)
            .stroke(.white.opacity(unlocked ? 0.12 : 0.07), lineWidth: 1))
    }

    private var resetButton: some View {
        Button { store.reset() } label: {
            Text("RESET PROGRESS")
                .font(Theme.light(11)).tracking(3)
                .foregroundStyle(Theme.frost.opacity(0.4))
        }
        .buttonStyle(.plain)
        .opacity(completedCount > 0 ? 1 : 0)
    }
}
