//
//  LearnHomeView.swift
//  The Learn tab — lesson list. Opens a lesson full-screen.
//

import SwiftUI

struct LearnHomeView: View {
    @State private var activeLesson: Lesson?

    var body: some View {
        ZStack {
            ArcticBackground()
            VStack(spacing: 0) {
                header.padding(.top, 12)
                ScrollView {
                    VStack(spacing: 16) {
                        ForEach(LessonLibrary.all) { lesson in
                            Button { activeLesson = lesson } label: { lessonCard(lesson) }
                                .buttonStyle(.plain)
                        }
                        comingSoonCard
                    }
                    .padding(.horizontal, 22)
                    .padding(.top, 26)
                }
            }
        }
        .preferredColorScheme(.dark)
        .fullScreenCover(item: $activeLesson) { lesson in
            LessonView(lesson: lesson) { activeLesson = nil }
        }
        .onAppear {
            #if DEBUG
            if ProcessInfo.processInfo.environment["PICKUP_LESSON"] == "open" {
                activeLesson = LessonLibrary.openStrings
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 3) {
            Text("PICKUP").font(Theme.display(22)).tracking(10).foregroundStyle(.white)
            Text("LEARN").font(Theme.light(12)).tracking(4).foregroundStyle(Theme.frost.opacity(0.6))
        }
    }

    private func lessonCard(_ lesson: Lesson) -> some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.teal.opacity(0.18))
                    .frame(width: 56, height: 56)
                Image(systemName: "guitars.fill").font(.system(size: 24)).foregroundStyle(Theme.teal)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(lesson.title).font(Theme.display(22)).foregroundStyle(.white)
                Text(lesson.subtitle).font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.7))
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(Theme.frost.opacity(0.5))
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.06)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
    }

    private var comingSoonCard: some View {
        HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.06))
                    .frame(width: 56, height: 56)
                Image(systemName: "lock.fill").font(.system(size: 20)).foregroundStyle(Theme.frost.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text("First Chords").font(Theme.display(22)).foregroundStyle(Theme.frost.opacity(0.55))
                Text("Coming soon").font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.4))
            }
            Spacer()
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.03)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }
}
