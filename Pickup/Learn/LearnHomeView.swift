//
//  LearnHomeView.swift
//  The Learn tab — the curriculum as a list of courses. Courses unlock as you
//  complete prerequisites; tap one to see its lessons.
//

import SwiftUI

struct LearnHomeView: View {
    @State private var path: [Course] = []
    @State private var showPlayAlong = false
    @State private var showHighway = false
    @State private var showStats = false
    @State private var showReview = false
    private let store = ProgressStore.shared

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ArcticBackground()
                VStack(spacing: 0) {
                    header.padding(.top, 12)
                    statsStrip.padding(.horizontal, 22).padding(.top, 14)
                    ScrollView {
                        VStack(spacing: 16) {
                            let dueCount = store.dueForReview().count
                            if dueCount > 0 { dueReviewCard(count: dueCount) }
                            playAlongCard
                            highwayCard
                            ForEach(CourseLibrary.all) { course in
                                let unlocked = CourseLibrary.isUnlocked(course, completed: store.completedLessonIDs)
                                courseCard(course, unlocked: unlocked)
                                    .contentShape(Rectangle())
                                    .onTapGesture { if unlocked { path.append(course) } }
                            }
                            resetButton.padding(.top, 8)
                        }
                        .padding(.horizontal, 22)
                        .padding(.top, 22)
                    }
                }
            }
            .navigationDestination(for: Course.self) { CourseDetailView(course: $0) }
            .toolbar(.hidden, for: .navigationBar)
        }
        .tint(Theme.teal)
        .fullScreenCover(isPresented: $showPlayAlong) {
            PlayAlongView { showPlayAlong = false }
        }
        .fullScreenCover(isPresented: $showHighway) {
            TabHighwayView { showHighway = false }
        }
        .fullScreenCover(isPresented: $showReview) {
            ReviewSessionView(lessonIDs: store.dueForReview()) { showReview = false }
        }
        .sheet(isPresented: $showStats) { StatsView { showStats = false } }
        .onAppear {
            store.refreshStreak()
            #if DEBUG
            if let raw = ProcessInfo.processInfo.environment["PICKUP_COMPLETE"] {
                raw.split(separator: ",").forEach { store.markCompleted(String($0)) }
            }
            if let id = ProcessInfo.processInfo.environment["PICKUP_COURSE"],
               let course = CourseLibrary.all.first(where: { $0.id == id }) {
                path = [course]
            }
            if ProcessInfo.processInfo.environment["PICKUP_SEED_REVIEW"] != nil {
                // Backdate a few masteries so their reviews fall due today.
                let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
                ["chord-em", "chord-am", "chord-d"].forEach { store.markCompleted($0, on: past) }
            }
            if ProcessInfo.processInfo.environment["PICKUP_REVIEW"] != nil {
                showReview = true
            }
            if ProcessInfo.processInfo.environment["PICKUP_PLAYALONG"] != nil {
                showPlayAlong = true
            }
            if ProcessInfo.processInfo.environment["PICKUP_HIGHWAY"] != nil {
                showHighway = true
            }
            if ProcessInfo.processInfo.environment["PICKUP_SEED_STATS"] != nil, store.xp == 0 {
                let cal = Calendar.current, now = Date()
                for offset in [6, 5, 4, 2, 1, 0] {
                    store.registerActivity(on: cal.date(byAdding: .day, value: -offset, to: now)!)
                }
                store.awardXP(260)
                store.addPracticeTime(64 * 60)
            }
            if ProcessInfo.processInfo.environment["PICKUP_STATS"] != nil {
                showStats = true
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

    private var statsStrip: some View {
        Button { showStats = true } label: {
            HStack(spacing: 0) {
                stat(icon: "flame.fill", value: "\(store.currentStreak)", label: "STREAK",
                     tint: store.isActiveToday() ? Theme.teal : Theme.frost.opacity(0.5))
                statDivider
                stat(icon: "bolt.fill", value: "LVL \(store.level)", label: "LEVEL", tint: Theme.teal)
                statDivider
                stat(icon: "clock.fill", value: "\(store.practiceMinutes)m", label: "PRACTICE", tint: Theme.teal)
                Image(systemName: "chevron.right").font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.frost.opacity(0.4)).padding(.trailing, 14)
            }
            .padding(.vertical, 12)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.06)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.12), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func stat(icon: String, value: String, label: String, tint: Color) -> some View {
        HStack(spacing: 7) {
            Image(systemName: icon).font(.system(size: 14)).foregroundStyle(tint)
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(Theme.display(15)).foregroundStyle(.white)
                Text(label).font(Theme.light(9)).tracking(1).foregroundStyle(Theme.frost.opacity(0.55))
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var statDivider: some View {
        Rectangle().fill(.white.opacity(0.10)).frame(width: 1, height: 26)
    }

    private func dueReviewCard(count: Int) -> some View {
        Button { showReview = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.teal).frame(width: 58, height: 58)
                    Image(systemName: "clock.arrow.circlepath").font(.system(size: 24, weight: .medium))
                        .foregroundStyle(Color(hex: 0x06222A))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Review").font(Theme.display(23)).foregroundStyle(.white)
                    Text("\(count) skill\(count == 1 ? "" : "s") due — keep them sharp")
                        .font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.8))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.frost.opacity(0.7))
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.teal.opacity(0.2)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.teal.opacity(0.55), lineWidth: 1.5))
            .shadow(color: Theme.teal.opacity(0.25), radius: 14, y: 5)
        }
        .buttonStyle(.plain)
    }

    private var playAlongCard: some View {
        Button { showPlayAlong = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.teal.opacity(0.9)).frame(width: 58, height: 58)
                    Image(systemName: "music.note").font(.system(size: 24)).foregroundStyle(Color(hex: 0x06222A))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Play Along").font(Theme.display(23)).foregroundStyle(.white)
                    Text("Play through a song in time").font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.frost.opacity(0.6))
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.teal.opacity(0.14)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.teal.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var highwayCard: some View {
        Button { showHighway = true } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.cyan.opacity(0.9)).frame(width: 58, height: 58)
                    Image(systemName: "arrow.down.to.line").font(.system(size: 24)).foregroundStyle(Color(hex: 0x06222A))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Tab Highway").font(Theme.display(23)).foregroundStyle(.white)
                    Text("Hit the notes as they fall").font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.75))
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(Theme.frost.opacity(0.6))
            }
            .padding(18)
            .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(Theme.cyan.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.cyan.opacity(0.4), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func courseCard(_ course: Course, unlocked: Bool) -> some View {
        let done = CourseLibrary.completedCount(course, completed: store.completedLessonIDs)
        let total = course.lessons.count
        let allDone = total > 0 && done == total
        let icon = !unlocked ? "lock.fill" : (allDone ? "checkmark.seal.fill" : "graduationcap.fill")

        return HStack(spacing: 16) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(unlocked ? Theme.teal.opacity(0.18) : .white.opacity(0.05))
                    .frame(width: 58, height: 58)
                Image(systemName: icon).font(.system(size: 24))
                    .foregroundStyle(unlocked ? Theme.teal : Theme.frost.opacity(0.5))
            }
            VStack(alignment: .leading, spacing: 5) {
                Text(course.title).font(Theme.display(23))
                    .foregroundStyle(unlocked ? .white : Theme.frost.opacity(0.5))
                Text(course.subtitle).font(Theme.body(14))
                    .foregroundStyle(Theme.frost.opacity(unlocked ? 0.7 : 0.45))
                if course.comingSoon {
                    Text("COMING SOON")
                        .font(Theme.light(12)).tracking(2)
                        .foregroundStyle(Theme.frost.opacity(0.45))
                } else if unlocked {
                    Text("\(done) / \(total) lessons")
                        .font(Theme.light(12)).tracking(2)
                        .foregroundStyle(allDone ? Theme.teal.opacity(0.9) : Theme.frost.opacity(0.55))
                }
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

    private var resetButton: some View {
        Button { store.reset() } label: {
            Text("RESET PROGRESS")
                .font(Theme.light(11)).tracking(3)
                .foregroundStyle(Theme.frost.opacity(0.4))
        }
        .buttonStyle(.plain)
        .opacity(store.completedLessonIDs.isEmpty ? 0 : 1)
    }
}
