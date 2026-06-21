//
//  CourseDetailView.swift
//  Lessons within a course, with completed / unlocked / locked states.
//

import SwiftUI

struct CourseDetailView: View {
    let course: Course

    @Environment(\.dismiss) private var dismiss
    @State private var activeLesson: Lesson?
    private let store = ProgressStore.shared

    var body: some View {
        ZStack {
            ArcticBackground()
            VStack(spacing: 0) {
                header.padding(.top, 12)
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(course.lessons) { lesson in
                            let completed = store.isCompleted(lesson.id)
                            let unlocked = LessonLibrary.isUnlocked(lesson, completed: store.completedLessonIDs)
                            Button { if unlocked { activeLesson = lesson } } label: {
                                lessonCard(lesson, completed: completed, unlocked: unlocked)
                            }
                            .buttonStyle(.plain)
                            .disabled(!unlocked)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 20)
                }
            }
        }
        .preferredColorScheme(.dark)
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .fullScreenCover(item: $activeLesson) { lesson in
            LessonView(lesson: lesson) { activeLesson = nil }
        }
        .onAppear {
            #if DEBUG
            if let id = ProcessInfo.processInfo.environment["ABSTRUM_LESSON_ID"],
               let lesson = course.lessons.first(where: { $0.id == id }) {
                activeLesson = lesson
            }
            #endif
        }
    }

    private var header: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Theme.frost.opacity(0.85))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            Spacer()
            VStack(spacing: 2) {
                Text(course.title.uppercased()).font(Theme.display(18)).tracking(4).foregroundStyle(.white)
                Text("\(CourseLibrary.completedCount(course, completed: store.completedLessonIDs)) / \(course.lessons.count) lessons")
                    .font(Theme.light(11)).tracking(2).foregroundStyle(Theme.frost.opacity(0.6))
            }
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }

    private func lessonCard(_ lesson: Lesson, completed: Bool, unlocked: Bool) -> some View {
        let icon = completed ? "checkmark.seal.fill" : (unlocked ? "guitars.fill" : "lock.fill")
        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(unlocked ? Theme.teal.opacity(0.18) : .white.opacity(0.05))
                    .frame(width: 54, height: 54)
                Image(systemName: icon).font(.system(size: 22))
                    .foregroundStyle(unlocked ? Theme.teal : Theme.frost.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).font(Theme.display(21))
                    .foregroundStyle(unlocked ? .white : Theme.frost.opacity(0.5))
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
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(unlocked ? 0.06 : 0.03)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(unlocked ? 0.12 : 0.07), lineWidth: 1))
    }
}
