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

    private let requestID = "pickup.dailyReminder"
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
        let practicedToday = store.isActiveToday(now)
        let streak = store.currentStreak
        let hour = self.hour, minute = self.minute

        center.getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else { return }

            let fire = Self.nextFireDate(now: now, hour: hour, minute: minute,
                                         practicedToday: practicedToday)
            let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fire)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)

            let content = UNMutableNotificationContent()
            content.title = "Pickup"
            content.body = streak > 0
                ? "🔥 Keep your \(streak)-day streak alive — play something today."
                : "🎸 Time to practice — start a streak today."
            content.sound = .default

            center.add(UNNotificationRequest(identifier: self.requestID, content: content, trigger: trigger))
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
