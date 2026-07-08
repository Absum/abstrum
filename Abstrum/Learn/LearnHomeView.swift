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
    @State private var showMastery = false
    @State private var showReview = false
    @State private var showSession = false
    @State private var mixLesson: Lesson?
    private let store = ProgressStore.shared

    var body: some View {
        NavigationStack(path: $path) {
            ZStack {
                ArcticBackground()
                VStack(spacing: 0) {
                    header.padding(.top, 12)
                    competenceStrip.padding(.horizontal, 22).padding(.top, 14)
                    ScrollView {
                        VStack(spacing: 16) {
                            let session = DailySession.today(store)
                            if session.count > 1 { todaysPracticeCard(steps: session.count) }
                            let dueCount = store.dueForReviewCurrent().count
                            if dueCount > 0 { dueReviewCard(count: dueCount) }
                            let mixPool = InterleavedDrill.pool(completed: store.completedLessonIDs)
                            if mixPool.count >= InterleavedDrill.minPool { mixCard(poolSize: mixPool.count) }
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
        .fullScreenCover(isPresented: $showSession) {
            DailySessionView(items: DailySession.today(store)) { showSession = false }
        }
        .fullScreenCover(isPresented: $showReview) {
            ReviewSessionView(lessonIDs: store.dueForReviewCurrent()) { showReview = false }
        }
        .fullScreenCover(item: $mixLesson) { lesson in
            LessonView(lesson: lesson) { mixLesson = nil }
        }
        .sheet(isPresented: $showMastery) { MasteryView { showMastery = false } }
        .sheet(isPresented: $showStats) { StatsView { showStats = false } }
        .onAppear {
            store.refreshStreak()
            #if DEBUG
            if let raw = ProcessInfo.processInfo.environment["ABSTRUM_COMPLETE"] {
                raw.split(separator: ",").forEach { store.markCompleted(String($0)) }
            }
            if let id = ProcessInfo.processInfo.environment["ABSTRUM_COURSE"],
               let course = CourseLibrary.all.first(where: { $0.id == id }) {
                path = [course]
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_SEED_REVIEW"] != nil {
                // Backdate a few masteries so their reviews fall due today.
                let past = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
                ["chord-em", "chord-am", "chord-d"].forEach { store.markCompleted($0, on: past) }
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_REVIEW"] != nil {
                showReview = true
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_SESSION"] != nil {
                showSession = true
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_MIX"] != nil {
                mixLesson = InterleavedDrill.lesson(completed: store.completedLessonIDs)
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_PLAYALONG"] != nil {
                showPlayAlong = true
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_HIGHWAY"] != nil {
                showHighway = true
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_SEED_STATS"] != nil, store.xp == 0 {
                let cal = Calendar.current, now = Date()
                for offset in [6, 5, 4, 2, 1, 0] {
                    store.registerActivity(on: cal.date(byAdding: .day, value: -offset, to: now)!)
                }
                store.awardXP(260)
                store.addPracticeTime(64 * 60)
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_STATS"] != nil {
                showStats = true
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_SEED_MASTERY"] != nil, store.completedLessonIDs.isEmpty {
                ["open-strings", "string-switching", "low-to-high", "chord-em"].forEach { store.markCompleted($0) }
                for _ in 0..<3 { store.recordRun("chord-am", score: 0.9) }   // in progress, improving
                for _ in 0..<2 { store.recordRun("chord-e", score: 0.7) }    // earlier, improving
                store.markCompleted("chord-d"); store.recordRun("chord-d", score: 0.2)   // slipping
            }
            if ProcessInfo.processInfo.environment["ABSTRUM_MASTERY"] != nil {
                showMastery = true
            }
            #endif
        }
    }

    private var header: some View {
        VStack(spacing: 3) {
            Text("ABSTRUM").font(Theme.display(22)).tracking(10).foregroundStyle(.white)
            Text("LEARN").font(Theme.light(12)).tracking(4).foregroundStyle(Theme.frost.opacity(0.6))
        }
    }

    // Competence first (SDT): the home leads with what you're getting good at
    // and what's due, not the streak/XP loop (those move into the stats detail).
    private var skillsLearned: Int {
        LessonLibrary.all.filter { store.completedLessonIDs.contains($0.id) }.count
    }
    private var pathProgress: Int {
        let total = LessonLibrary.all.count
        guard total > 0 else { return 0 }
        return Int((Double(skillsLearned) / Double(total) * 100).rounded())
    }

    private var competenceStrip: some View {
        let due = store.dueForReviewCurrent().count
        return Button { showMastery = true } label: {
            HStack(spacing: 0) {
                stat(icon: "checkmark.seal.fill", value: "\(skillsLearned)", label: "SKILLS", tint: Theme.teal)
                statDivider
                stat(icon: "clock.arrow.circlepath", value: "\(due)", label: "TO REVIEW",
                     tint: due > 0 ? Theme.teal : Theme.frost.opacity(0.5))
                statDivider
                stat(icon: "chart.line.uptrend.xyaxis", value: "\(pathProgress)%", label: "OF PATH", tint: Theme.teal)
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

    private func todaysPracticeCard(steps: Int) -> some View {
        // Near-black ink for text/icon — far higher contrast on teal than the
        // old translucent navy, while the icon tile matches the other cards' shape.
        let ink = Color(hex: 0x042521)
        return Button { showSession = true } label: {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 16) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .fill(ink).frame(width: 56, height: 56)
                        Image(systemName: "figure.strengthtraining.traditional")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(Theme.teal)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Today's Practice").font(Theme.display(24)).foregroundStyle(ink)
                        Text("\(steps) steps · ~\(max(5, steps * 2)) min, guided")
                            .font(Theme.body(15)).foregroundStyle(ink.opacity(0.9))
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(ink.opacity(0.65))
                }
                Text("WARM-UP · REVIEW · NEW · SONG · COOL-DOWN")
                    .font(Theme.title(11)).tracking(1.5).foregroundStyle(ink.opacity(0.8))
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(LinearGradient(colors: [Theme.teal, Color(hex: 0x1FA597)],
                                         startPoint: .top, endPoint: .bottom))
            )
            .shadow(color: Theme.teal.opacity(0.4), radius: 16, y: 6)
        }
        .buttonStyle(.plain)
    }

    private func mixCard(poolSize: Int) -> some View {
        Button { mixLesson = InterleavedDrill.lesson(completed: store.completedLessonIDs) } label: {
            HStack(spacing: 16) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.cyan.opacity(0.9)).frame(width: 58, height: 58)
                    Image(systemName: "shuffle").font(.system(size: 23, weight: .semibold))
                        .foregroundStyle(Color(hex: 0x06222A))
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Mixed Chords").font(Theme.display(23)).foregroundStyle(.white)
                    Text("Shuffle \(poolSize) chords you know — build recall")
                        .font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.75))
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
