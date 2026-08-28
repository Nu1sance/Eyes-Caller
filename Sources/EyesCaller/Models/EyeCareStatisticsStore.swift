import Foundation
import SwiftUI

@MainActor
final class EyeCareStatisticsStore: ObservableObject {
    private struct Payload: Codable {
        static let currentSchemaVersion = 2

        var schemaVersion: Int
        var firstUsedAt: Date
        var firstUsedDayKey: String
        var dailyCounts: [String: Int]
    }

    private struct LegacyPayloadV1: Codable {
        var schemaVersion: Int
        var firstUsedAt: Date
        var dailyCounts: [String: Int]
    }

    static let suiteName = "com.eyescaller.statistics"

    @Published private var payload: Payload

    private let defaults: UserDefaults
    private let calendar: Calendar
    private let nowProvider: () -> Date
    private let storageKey = "eye-care-statistics.payload"

    init(
        defaults: UserDefaults? = nil,
        calendar: Calendar? = nil,
        now: @escaping () -> Date = { .now }
    ) {
        let defaults = defaults ?? UserDefaults(suiteName: Self.suiteName) ?? .standard
        let calendar = calendar ?? Self.makeStableCalendar()
        let currentDate = now()
        let storageKey = "eye-care-statistics.payload"

        self.defaults = defaults
        self.calendar = calendar
        self.nowProvider = now

        var shouldPersist = false
        if let data = defaults.data(forKey: storageKey) {
            if let saved = try? JSONDecoder().decode(Payload.self, from: data),
               saved.schemaVersion == Payload.currentSchemaVersion {
                payload = saved
            } else if let legacy = try? JSONDecoder().decode(LegacyPayloadV1.self, from: data),
                      legacy.schemaVersion == 1 {
                payload = Payload(
                    schemaVersion: Payload.currentSchemaVersion,
                    firstUsedAt: legacy.firstUsedAt,
                    firstUsedDayKey: Self.dateKey(for: legacy.firstUsedAt, calendar: calendar),
                    dailyCounts: Self.migrateLegacyDailyCounts(
                        legacy.dailyCounts,
                        targetCalendar: calendar
                    )
                )
                shouldPersist = true
            } else {
                let backupKey = "\(storageKey).unreadable.\(Int(currentDate.timeIntervalSince1970))"
                defaults.set(data, forKey: backupKey)
                payload = Self.emptyPayload(at: currentDate, calendar: calendar)
                shouldPersist = true
            }
        } else {
            payload = Self.emptyPayload(at: currentDate, calendar: calendar)
            shouldPersist = true
        }

        if shouldPersist {
            persist()
        }
    }

    var firstUsedAt: Date {
        date(fromKey: payload.firstUsedDayKey) ?? payload.firstUsedAt
    }

    var currentDate: Date {
        nowProvider()
    }

    var todayCount: Int {
        count(on: nowProvider())
    }

    var totalCount: Int {
        payload.dailyCounts.values.reduce(0, +)
    }

    var companionDays: Int {
        let firstDay = date(fromKey: payload.firstUsedDayKey)
            ?? calendar.startOfDay(for: payload.firstUsedAt)
        let today = calendar.startOfDay(for: nowProvider())
        let elapsed = calendar.dateComponents([.day], from: firstDay, to: today).day ?? 0
        return max(1, elapsed + 1)
    }

    func count(on date: Date) -> Int {
        payload.dailyCounts[Self.dateKey(for: date, calendar: calendar), default: 0]
    }

    func recordCompletion(at date: Date = .now) {
        let key = Self.dateKey(for: date, calendar: calendar)
        var updated = payload
        updated.dailyCounts[key, default: 0] += 1
        payload = updated
        persist()
    }

    private func date(fromKey key: String) -> Date? {
        let values = key.split(separator: "-").compactMap { Int($0) }
        guard values.count == 3 else { return nil }
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = values[0]
        components.month = values[1]
        components.day = values[2]
        return calendar.date(from: components)
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func emptyPayload(at date: Date, calendar: Calendar) -> Payload {
        Payload(
            schemaVersion: Payload.currentSchemaVersion,
            firstUsedAt: date,
            firstUsedDayKey: dateKey(for: date, calendar: calendar),
            dailyCounts: [:]
        )
    }

    private static func dateKey(for date: Date, calendar: Calendar) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }

    private static func migrateLegacyDailyCounts(
        _ counts: [String: Int],
        targetCalendar: Calendar
    ) -> [String: Int] {
        // V1 used Calendar.autoupdatingCurrent to create its string keys. Parse
        // with that same policy, then normalize every bucket to Gregorian.
        var legacyCalendar = Calendar.autoupdatingCurrent
        legacyCalendar.timeZone = .autoupdatingCurrent
        var migrated: [String: Int] = [:]

        for (key, count) in counts {
            let values = key.split(separator: "-").compactMap { Int($0) }
            guard values.count == 3 else {
                migrated[key, default: 0] += count
                continue
            }

            var components = DateComponents()
            components.calendar = legacyCalendar
            components.timeZone = legacyCalendar.timeZone
            components.year = values[0]
            components.month = values[1]
            components.day = values[2]

            guard let date = legacyCalendar.date(from: components) else {
                migrated[key, default: 0] += count
                continue
            }
            migrated[dateKey(for: date, calendar: targetCalendar), default: 0] += count
        }
        return migrated
    }

    private static func makeStableCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
}
