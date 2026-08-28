import Foundation
import SwiftUI

extension Notification.Name {
    static let eyesCallerAppearanceWillChange = Notification.Name("EyesCallerAppearanceWillChange")
}

enum AppearanceMode: String, Codable, CaseIterable, Sendable {
    case day
    case night

    var opposite: AppearanceMode {
        self == .day ? .night : .day
    }

    var colorScheme: ColorScheme {
        self == .day ? .light : .dark
    }
}

@MainActor
final class AppearanceController: ObservableObject {
    private struct Payload: Codable {
        static let currentSchemaVersion = 1

        var schemaVersion: Int
        var automaticEnabled: Bool
        var dayStartMinutes: Int
        var nightStartMinutes: Int
        var manualMode: AppearanceMode
        var overrideMode: AppearanceMode?
        var overrideExpiresAt: Date?
    }

    static let suiteName = "com.eyescaller.preferences"

    @Published private(set) var mode: AppearanceMode
    @Published private(set) var automaticEnabled: Bool
    @Published private(set) var dayStartMinutes: Int
    @Published private(set) var nightStartMinutes: Int
    @Published private(set) var overrideExpiresAt: Date?

    private var payload: Payload
    private let defaults: UserDefaults
    private let calendar: Calendar
    private let nowProvider: () -> Date
    private let managesSchedule: Bool
    private let storageKey = "appearance.preferences"
    private var scheduleTask: Task<Void, Never>?
    private nonisolated(unsafe) var clockObservers: [NSObjectProtocol] = []

    init(
        defaults: UserDefaults? = nil,
        calendar: Calendar? = nil,
        now: @escaping () -> Date = { .now },
        startsTicker: Bool = true
    ) {
        let defaults = defaults ?? UserDefaults(suiteName: Self.suiteName) ?? .standard
        let calendar = calendar ?? Self.makeCalendar()
        let initialPayload: Payload

        if let data = defaults.data(forKey: "appearance.preferences"),
           let saved = try? JSONDecoder().decode(Payload.self, from: data),
           saved.schemaVersion == Payload.currentSchemaVersion {
            initialPayload = Self.sanitized(saved)
        } else {
            initialPayload = Payload(
                schemaVersion: Payload.currentSchemaVersion,
                automaticEnabled: false,
                dayStartMinutes: 8 * 60,
                nightStartMinutes: 20 * 60,
                manualMode: .day,
                overrideMode: nil,
                overrideExpiresAt: nil
            )
        }

        self.defaults = defaults
        self.calendar = calendar
        self.nowProvider = now
        managesSchedule = startsTicker
        payload = initialPayload
        automaticEnabled = initialPayload.automaticEnabled
        dayStartMinutes = initialPayload.dayStartMinutes
        nightStartMinutes = initialPayload.nightStartMinutes
        overrideExpiresAt = initialPayload.overrideExpiresAt
        mode = initialPayload.manualMode

        reconcile(at: now())
        persist()

        if startsTicker {
            installClockObservers()
            scheduleNextWake(after: now())
        }
    }

    deinit {
        scheduleTask?.cancel()
        for observer in clockObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    var isTemporarilyOverridden: Bool {
        automaticEnabled && payload.overrideMode != nil && overrideExpiresAt != nil
    }

    func toggleManual(at date: Date? = nil) {
        let now = date ?? nowProvider()
        let target = mode.opposite

        if automaticEnabled {
            let scheduled = scheduledMode(at: now)
            if target == scheduled {
                payload.overrideMode = nil
                payload.overrideExpiresAt = nil
            } else {
                payload.overrideMode = target
                payload.overrideExpiresAt = nextBoundary(after: now)
            }
        } else {
            payload.manualMode = target
        }

        reconcile(at: now)
        persist()
        scheduleNextWake(after: now)
    }

    func setAutomaticEnabled(_ enabled: Bool, at date: Date? = nil) {
        let now = date ?? nowProvider()
        if !enabled {
            payload.manualMode = mode
        }
        payload.automaticEnabled = enabled
        if automaticEnabled != enabled {
            automaticEnabled = enabled
        }
        payload.overrideMode = nil
        payload.overrideExpiresAt = nil
        reconcile(at: now)
        persist()
        scheduleNextWake(after: now)
    }

    func setDayStart(from date: Date) {
        setScheduleMinutes(day: minutes(from: date), night: nil)
    }

    func setNightStart(from date: Date) {
        setScheduleMinutes(day: nil, night: minutes(from: date))
    }

    func dateForTimePicker(minutes: Int, referenceDate: Date = .now) -> Date {
        let hour = normalized(minutes) / 60
        let minute = normalized(minutes) % 60
        return calendar.date(
            bySettingHour: hour,
            minute: minute,
            second: 0,
            of: referenceDate
        ) ?? referenceDate
    }

    func scheduledMode(at date: Date) -> AppearanceMode {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        let day = normalized(payload.dayStartMinutes)
        let night = normalized(payload.nightStartMinutes)

        if day < night {
            return currentMinutes >= day && currentMinutes < night ? .day : .night
        }
        return currentMinutes >= day || currentMinutes < night ? .day : .night
    }

    func nextBoundary(after date: Date) -> Date {
        let candidates = [payload.dayStartMinutes, payload.nightStartMinutes].compactMap { minutes in
            nextOccurrence(of: minutes, after: date)
        }
        return candidates.min() ?? date.addingTimeInterval(24 * 60 * 60)
    }

    func reconcile(at date: Date? = nil) {
        let now = date ?? nowProvider()
        var payloadChanged = false

        if automaticEnabled, let overrideMode = payload.overrideMode {
            let scheduled = scheduledMode(at: now)
            let storedBoundaryHasPassed = payload.overrideExpiresAt.map { $0 <= now } ?? true
            if storedBoundaryHasPassed || overrideMode == scheduled {
                payload.overrideMode = nil
                payload.overrideExpiresAt = nil
                payloadChanged = true
            } else {
                let localBoundary = nextBoundary(after: now)
                if payload.overrideExpiresAt != localBoundary {
                    payload.overrideExpiresAt = localBoundary
                    payloadChanged = true
                }
            }
        } else if payload.overrideMode != nil || payload.overrideExpiresAt != nil {
            payload.overrideMode = nil
            payload.overrideExpiresAt = nil
            payloadChanged = true
        }

        let resolved = automaticEnabled
            ? (payload.overrideMode ?? scheduledMode(at: now))
            : payload.manualMode

        payload.automaticEnabled = automaticEnabled
        payload.dayStartMinutes = dayStartMinutes
        payload.nightStartMinutes = nightStartMinutes
        if overrideExpiresAt != payload.overrideExpiresAt {
            overrideExpiresAt = payload.overrideExpiresAt
        }
        if mode != resolved {
            NotificationCenter.default.post(
                name: .eyesCallerAppearanceWillChange,
                object: resolved
            )
            mode = resolved
        }
        if payloadChanged {
            persist()
        }
    }

    private func setScheduleMinutes(day: Int?, night: Int?) {
        var proposedDay = normalized(day ?? payload.dayStartMinutes)
        var proposedNight = normalized(night ?? payload.nightStartMinutes)
        if proposedDay == proposedNight {
            // DatePickers can briefly collide while the user swaps a daytime
            // and nighttime schedule. Keep the interval valid and predictable.
            if day != nil {
                proposedNight = normalized(proposedDay + 12 * 60)
            } else {
                proposedDay = normalized(proposedNight + 12 * 60)
            }
        }

        payload.dayStartMinutes = proposedDay
        payload.nightStartMinutes = proposedNight
        if dayStartMinutes != proposedDay {
            dayStartMinutes = proposedDay
        }
        if nightStartMinutes != proposedNight {
            nightStartMinutes = proposedNight
        }
        payload.overrideMode = nil
        payload.overrideExpiresAt = nil
        let now = nowProvider()
        reconcile(at: now)
        persist()
        scheduleNextWake(after: now)
    }

    private func scheduleNextWake(after date: Date) {
        guard managesSchedule else { return }
        scheduleTask?.cancel()
        scheduleTask = nil
        guard automaticEnabled else { return }

        let wakeDate = nextBoundary(after: date)
        let delay = max(0.1, wakeDate.timeIntervalSince(date))
        scheduleTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(delay))
            guard !Task.isCancelled, let self else { return }
            let now = self.nowProvider()
            self.reconcile(at: now)
            self.scheduleNextWake(after: now)
        }
    }

    private func installClockObservers() {
        let names: [Notification.Name] = [
            .NSSystemTimeZoneDidChange,
            .NSSystemClockDidChange
        ]
        clockObservers = names.map { name in
            NotificationCenter.default.addObserver(
                forName: name,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    let now = self.nowProvider()
                    self.reconcile(at: now)
                    self.scheduleNextWake(after: now)
                }
            }
        }
    }

    private func minutes(from date: Date) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    private func nextOccurrence(of minutes: Int, after date: Date) -> Date? {
        let value = normalized(minutes)
        var components = DateComponents()
        components.hour = value / 60
        components.minute = value % 60
        components.second = 0
        return calendar.nextDate(
            after: date,
            matching: components,
            matchingPolicy: .nextTime,
            repeatedTimePolicy: .first,
            direction: .forward
        )
    }

    private func normalized(_ minutes: Int) -> Int {
        Self.normalizedMinutes(minutes)
    }

    private static func sanitized(_ payload: Payload) -> Payload {
        var result = payload
        result.dayStartMinutes = normalizedMinutes(result.dayStartMinutes)
        result.nightStartMinutes = normalizedMinutes(result.nightStartMinutes)
        if result.dayStartMinutes == result.nightStartMinutes {
            result.nightStartMinutes = normalizedMinutes(result.dayStartMinutes + 12 * 60)
        }
        return result
    }

    private static func normalizedMinutes(_ minutes: Int) -> Int {
        ((minutes % 1440) + 1440) % 1440
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(payload) else { return }
        defaults.set(data, forKey: storageKey)
    }

    private static func makeCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = .autoupdatingCurrent
        return calendar
    }
}
