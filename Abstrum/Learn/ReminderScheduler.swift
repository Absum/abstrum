//
//  ReminderScheduler.swift
//  The streak's engagement loop: a local daily reminder that nudges the user
//  back before their streak breaks. Streak-aware copy, and it skips a day the
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
        store.refreshStreak(now)          // make sure a lapse is reflected
        let practicedToday = store.isActiveToday(now)
        let msg = Self.message(streak: store.currentStreak, bestStreak: store.bestStreak,
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

    /// Reminder copy, chosen by where the player is: keeping a live streak,
    /// just starting, or winning back after a lapse (escalating by time away).
    static func message(streak: Int, bestStreak: Int, daysAway: Int?) -> (title: String, body: String) {
        // On an active streak — the "don't lose it" nudge.
        if streak > 0 {
            return ("Keep your streak alive",
                    "🔥 You're on a \(streak)-day streak — play something today to keep it going.")
        }
        // Never played, or no past streak to win back.
        guard let days = daysAway, bestStreak > 0 else {
            return ("Start a streak", "🎸 Play something today and start your streak.")
        }
        // Lapsed — escalate the win-back the longer they've been gone.
        switch days {
        case ...4:
            return ("It's not too late",
                    "🎸 Your \(bestStreak)-day best is right there — pick it back up today.")
        case 5...13:
            return ("Your streak's waiting",
                    "Miss playing? Your \(bestStreak)-day best is waiting — 5 minutes today gets you rolling.")
        default:
            return ("Your guitar misses you",
                    "🎸 It's been a while — even one riff counts. Come back today.")
        }
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
