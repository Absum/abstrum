//
//  MasteryView.swift
//  Per-skill mastery analytics: honest competence feedback. Each skill you've
//  started shows its mastery and recent trend (improving / slipping / steady);
//  the shakiest skills are surfaced first so deliberate practice points at
//  weaknesses. Habit stats sit one tap deeper.
//

import SwiftUI

struct MasteryView: View {
    let onClose: () -> Void
    private let store = ProgressStore.shared
    @State private var showStats = false

    private static let improving = Theme.teal
    private static let slipping = Color(hex: 0xE8836B)   // warm coral — gentle caution
    private static let steady = Theme.frost.opacity(0.5)
    private static let trendBand = 0.03

    private struct SkillStat: Identifiable {
        let lesson: Lesson
        let mastery: Double
        let baseline: Double
        var id: String { lesson.id }
        var trend: Double { mastery - baseline }
    }

    private var started: [SkillStat] {
        LessonLibrary.all.compactMap { lesson in
            let m = store.mastery(of: lesson.id)
            guard m > 0 else { return nil }
            return SkillStat(lesson: lesson, mastery: m, baseline: store.masteryBaseline(of: lesson.id))
        }
    }
    private var needsWork: [SkillStat] {
        started.filter { $0.mastery < ProgressStore.masteryThreshold }.sorted { $0.mastery < $1.mastery }
    }
    private var solid: [SkillStat] {
        started.filter { $0.mastery >= ProgressStore.masteryThreshold }.sorted { $0.mastery > $1.mastery }
    }

    var body: some View {
        ZStack {
            ArcticBackground()
            VStack(spacing: 0) {
                topBar.padding(.top, 12)
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        if started.isEmpty {
                            emptyState
                        } else {
                            if !needsWork.isEmpty { section("KEEP WORKING ON", needsWork) }
                            if !solid.isEmpty { section("SOLID", solid) }
                        }
                        practiceStatsLink
                    }
                    .padding(.horizontal, 24).padding(.top, 14).padding(.bottom, 30)
                }
            }
        }
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showStats) { StatsView { showStats = false } }
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
            Text("YOUR SKILLS").font(Theme.display(18)).tracking(4).foregroundStyle(.white)
            Spacer()
            Color.clear.frame(width: 40, height: 40)
        }
        .padding(.horizontal, 20)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "guitars.fill").font(.system(size: 44)).foregroundStyle(Theme.frost.opacity(0.3))
            Text("No skills yet").font(Theme.display(20)).foregroundStyle(.white)
            Text("Play a lesson and your mastery — and where it's shaky — shows up here.")
                .font(Theme.body(14)).foregroundStyle(Theme.frost.opacity(0.6))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity).padding(.vertical, 40)
    }

    private func section(_ title: String, _ skills: [SkillStat]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title).font(Theme.light(11)).tracking(3).foregroundStyle(Theme.frost.opacity(0.6))
            ForEach(skills) { skillRow($0) }
        }
    }

    private func skillRow(_ s: SkillStat) -> some View {
        let color = trendColor(s.trend)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: trendIcon(s.trend)).font(.system(size: 13, weight: .bold))
                    .foregroundStyle(color)
                Text(s.lesson.title).font(Theme.display(18)).foregroundStyle(.white)
                Spacer()
                Text("\(Int((s.mastery * 100).rounded()))%")
                    .font(Theme.display(18)).foregroundStyle(.white)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.10))
                    Capsule().fill(Theme.teal)
                        .frame(width: geo.size.width * CGFloat(min(1, max(0, s.mastery))))
                }
            }
            .frame(height: 7)
            if abs(s.trend) >= Self.trendBand {
                Text(s.trend > 0
                     ? "Improving — up from \(Int((s.baseline * 100).rounded()))%"
                     : "Slipping — was \(Int((s.baseline * 100).rounded()))%")
                    .font(Theme.light(11)).foregroundStyle(color.opacity(0.95))
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.05)))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
    }

    private func trendColor(_ trend: Double) -> Color {
        if trend >= Self.trendBand { return Self.improving }
        if trend <= -Self.trendBand { return Self.slipping }
        return Self.steady
    }
    private func trendIcon(_ trend: Double) -> String {
        if trend >= Self.trendBand { return "arrow.up.right" }
        if trend <= -Self.trendBand { return "arrow.down.right" }
        return "equal"
    }

    private var practiceStatsLink: some View {
        Button { showStats = true } label: {
            HStack(spacing: 10) {
                Image(systemName: "flame.fill").font(.system(size: 14)).foregroundStyle(Theme.frost.opacity(0.6))
                Text("Practice stats").font(Theme.body(15)).foregroundStyle(Theme.frost.opacity(0.85))
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.frost.opacity(0.5))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.05)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(.white.opacity(0.10), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}
