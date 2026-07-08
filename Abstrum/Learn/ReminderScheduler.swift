//
//  ReminderScheduler.swift
//  The spacing loop: a local daily reminder pointed at skills due for review
//  (spaced repetition needs regular sessions), not the streak. Skips a day the
//  user has already practiced. No backend.
//

import Foundation
import Observation
import UserNotifications

@Observable
final class ReminderScheduler {
    static let shared = ReminderScheduler()

    private let requestID = "abstrum.dailyReminder"
    private let defaults = UserDefaults.standard

    var enabled: Bool {
        get { defaults.object(forKey: "reminderEnabled") as? Bool ?? true }
        set { defaults.set(newValue, forKey: "reminderEnabled"); reschedule() }
    }
    var hour: Int {
        get { defaults.object(forKey: "reminderHour") as? Int ?? 19 }
        set { defaults.set(newValue, forKey: "reminderHour"); reschedule() }
    }
    var minute: Int {
        get { defaults.object(forKey: "reminderMinute") as? Int ?? 0 }
        set { defaults.set(newValue, forKey: "reminderMinute"); reschedule() }
    }

    /// Ask the OS for permission; reschedule on grant.
    func requestAuthorization(_ completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { [weak self] granted, _ in
                DispatchQueue.main.async {
                    if granted { self?.reschedule() }
                    completion?(granted)
                }
            }
    }

    /// Cancel and (re)schedule the next reminder. Skips today if the user has
    /// already practiced; bakes the current streak into the message.
    func reschedule(now: Date = Date()) {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [requestID])
        guard enabled else { return }

        let store = ProgressStore.shared
        store.refreshStreak(now)          // streak still tracked for stats
        let practicedToday = store.isActiveToday(now)
        let msg = Self.message(due: store.dueForReviewCurrent(on: now).count,
                               skillsLearned: store.completedLessonIDs.count,
                               daysAway: store.daysSinceActive(now))
        let hour = self.hour, minute = self.minute

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }

            let fire = Self.nextFireDate(now: now, hour: hour, minute: minute,
                                         practicedToday: practicedToday)
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let content = UNMutableNotificationContent()
            content.title = msg.title
            content.body = msg.body
            content.sound = .default

            center.add(UNNotificationRequest(identifier: self.requestID, content: content, trigger: trigger))
        }
    }

    /// Reminder copy framed around spaced repetition: lead with skills due for
    /// review (escalating once they're overdue), nudge a first session if the
    /// user hasn't learned anything, or invite the next new skill when nothing's
    /// due. No streak framing — spacing, not a counter, is the reason to return.
    static func message(due: Int, skillsLearned: Int, daysAway: Int?) -> (title: String, body: String) {
        let lapsed = (daysAway ?? 0) >= 5

        // Skills are due for review — the core spacing nudge.
        if due > 0 {
            let s = due == 1 ? "skill is" : "skills are"
            if lapsed {
                return ("Your skills are slipping",
                        "🎸 \(due) \(s) overdue for review — a few minutes today brings them back.")
            }
            return ("Time for a quick review",
                    "🎸 \(due) \(s) due for review — a few minutes today keeps them sharp.")
        }

        // Nothing due, and nothing learned yet — get the first session in.
        guard skillsLearned > 0 else {
            return ("Pick up the guitar",
                    "🎸 Play your first chord today — it only takes a few minutes.")
        }

        // Learned skills, nothing due right now.
        if lapsed {
            return ("Keep your skills sharp",
                    "🎸 It's been a while — a short session keeps what you've learned solid.")
        }
        return ("Ready for more?",
                "🎸 Nothing due to review — learn something new today.")
    }

    /// The next moment the reminder should fire: today at the set time if it
    /// hasn't passed and the user hasn't practiced, otherwise tomorrow.
    static func nextFireDate(now: Date, hour: Int, minute: Int, practicedToday: Bool,
                             calendar: Calendar = .current) -> Date {
        let todayAt = calendar.date(bySettingHour: hour, minute: minute, second: 0, of: now) ?? now
        if !practicedToday && todayAt > now { return todayAt }
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) ?? now
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: tomorrow) ?? tomorrow
    }
}
