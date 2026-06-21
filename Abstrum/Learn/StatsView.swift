//
//  StatsView.swift
//  Your-progress dashboard. Competence first (SDT): leads with skills learned
//  and path progress; the habit-loop metrics (streak, level/XP, practice time)
//  are demoted below. Reads ProgressStore.
//

import SwiftUI

struct StatsView: View {
    let onClose: () -> Void
    private let store = ProgressStore.shared

    var body: some View {
        ZStack {
            ArcticBackground()
            VStack(spacing: 0) {
                topBar.padding(.top, 12)
                ScrollView {
                    VStack(spacing: 22) {
                        competenceHero
                        statsGrid
                        levelCard       // XP/level demoted below competence (SDT)
                        weekStrip
                    }
                    .padding(.horizontal, 24).padding(.top, 12).padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
        .onAppear { store.refreshStreak() }
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark").font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.frost.opacity(0.85))
                    .frame(width: 40, height: 40).background(Circle().fill(.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            Spacer()
            Text("YOUR PROGRESS").font(Theme.display(18)).tracking(4).foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }

    private var skillsLearned: Int {
        LessonLibrary.all.filter { store.completedLessonIDs.contains($0.id) }.count
    }
    private var pathTotal: Int { LessonLibrary.all.count }
    private var pathProgress: Int {
        guard pathTotal > 0 else { return 0 }
        return Int((Double(skillsLearned) / Double(pathTotal) * 100).rounded())
    }
    private var dueCount: Int { store.dueForReview().count }

    private var competenceHero: some View {
        VStack(spacing: 6) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 52))
                .foregroundStyle(Theme.teal)
                .shadow(color: Theme.teal.opacity(0.6), radius: 18)
            Text("\(skillsLearned)")
                .font(.custom("Rajdhani-SemiBold", size: 64)).foregroundStyle(.white)
            Text(skillsLearned == 1 ? "SKILL LEARNED" : "SKILLS LEARNED")
                .font(Theme.light(12)).tracking(4).foregroundStyle(Theme.frost.opacity(0.7))
            Text("\(pathProgress)% of the path"
                 + (dueCount > 0 ? "  ·  \(dueCount) due to review" : "  ·  all caught up"))
                .font(Theme.body(13)).foregroundStyle(Theme.frost.opacity(0.55))
                .padding(.top, 2)
            pathBar.padding(.top, 12).padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(RoundedRectangle(cornerRadius: 22, style: .continuous).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private var pathBar: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.10))
                Capsule().fill(Theme.teal)
                    .frame(width: geo.size.width * CGFloat(pathProgress) / 100)
                    .shadow(color: Theme.teal.opacity(0.5), radius: 8)
            }
        }
        .frame(height: 8)
    }

    private var levelCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("LEVEL \(store.level)").font(Theme.display(20)).foregroundStyle(.white)
                Spacer()
                Text("\(store.xpIntoLevel) / \(ProgressStore.xpPerLevel) XP")
                    .font(Theme.body(13)).foregroundStyle(Theme.frost.opacity(0.6))
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10))
                    Capsule().fill(Theme.teal)
                        .frame(width: geo.size.width * progress)
                        .shadow(color: Theme.teal.opacity(0.6), radius: 8)
                }
            }
            .frame(height: 10)
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private var progress: CGFloat {
        CGFloat(store.xpIntoLevel) / CGFloat(ProgressStore.xpPerLevel)
    }

    private var statsGrid: some View {
        let cols = [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)]
        return LazyVGrid(columns: cols, spacing: 14) {
            tile("\(dueCount)", "TO REVIEW", "clock.arrow.circlepath")
            tile("\(store.practiceMinutes)", "MIN PRACTICED", "clock.fill")
            tile("\(store.currentStreak)", "DAY STREAK", "flame.fill")
            tile("\(store.bestStreak)", "BEST STREAK", "trophy.fill")
        }
    }

    private func tile(_ value: String, _ label: String, _ icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.system(size: 18)).foregroundStyle(Theme.teal)
            Text(value).font(.custom("Rajdhani-SemiBold", size: 30)).foregroundStyle(.white)
            Text(label).font(Theme.light(10)).tracking(2).foregroundStyle(Theme.frost.opacity(0.6))
        }
        .frame(maxWidth: .infinity).padding(.vertical, 18)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private var weekStrip: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("LAST 7 DAYS").font(Theme.light(11)).tracking(3).foregroundStyle(Theme.frost.opacity(0.6))
            HStack(spacing: 0) {
                ForEach(lastSevenDays, id: \.key) { day in
                    VStack(spacing: 8) {
                        Circle()
                            .fill(day.active ? AnyShapeStyle(Theme.teal) : AnyShapeStyle(.white.opacity(0.08)))
                            .frame(width: 26, height: 26)
                            .overlay(day.active
                                ? Image(systemName: "checkmark").font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(Color(hex: 0x06222A))
                                : nil)
                        Text(day.label).font(Theme.light(11)).foregroundStyle(Theme.frost.opacity(0.6))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(18)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private struct Day { let key: String; let label: String; let active: Bool }

    private var lastSevenDays: [Day] {
        let cal = Calendar.current
        let now = Date()
        let symbols = cal.veryShortWeekdaySymbols   // ["S","M","T",...]
        return (0..<7).reversed().map { offset in
            let date = cal.date(byAdding: .day, value: -offset, to: now) ?? now
            let key = ProgressStore.dayKey(date)
            let weekday = cal.component(.weekday, from: date)   // 1 = Sunday
            return Day(key: key, label: symbols[(weekday - 1) % symbols.count],
                       active: store.activeDays.contains(key))
        }
    }
}
