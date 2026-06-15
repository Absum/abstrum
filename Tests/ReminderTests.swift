//
//  ReminderTests.swift
//  Next-fire-date logic for the daily streak reminder.
//

import XCTest

final class ReminderTests: XCTestCase {
    private let cal = Calendar.current

    private func at(_ hour: Int, _ minute: Int = 0, day: Int = 15) -> Date {
        cal.date(from: DateComponents(year: 2026, month: 6, day: day, hour: hour, minute: minute))!
    }

    func testSchedulesTodayWhenTimeAheadAndNotPracticed() {
        let now = at(10)   // 10:00, reminder at 19:00
        let fire = ReminderScheduler.nextFireDate(now: now, hour: 19, minute: 0,
                                                  practicedToday: false, calendar: cal)
        XCTAssertEqual(cal.component(.day, from: fire), 15)
        XCTAssertEqual(cal.component(.hour, from: fire), 19)
    }

    func testSchedulesTomorrowWhenAlreadyPracticed() {
        let now = at(10)
        let fire = ReminderScheduler.nextFireDate(now: now, hour: 19, minute: 0,
                                                  practicedToday: true, calendar: cal)
        XCTAssertEqual(cal.component(.day, from: fire), 16)
        XCTAssertEqual(cal.component(.hour, from: fire), 19)
    }

    func testSchedulesTomorrowWhenTimeHasPassed() {
        let now = at(20)   // 20:00, already past the 19:00 reminder
        let fire = ReminderScheduler.nextFireDate(now: now, hour: 19, minute: 0,
                                                  practicedToday: false, calendar: cal)
        XCTAssertEqual(cal.component(.day, from: fire), 16)
    }
}
