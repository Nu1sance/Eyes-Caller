import Foundation
import SwiftUI

enum SessionPhase: Equatable {
    case focus
    case ready
    case resting
    case completed
}

@MainActor
final class RestSessionModel: ObservableObject {
    static let focusDuration: TimeInterval = 20 * 60
    static let restDuration: TimeInterval = 20

    @Published private(set) var phase: SessionPhase = .focus
    @Published private(set) var nextReminderAt: Date
    @Published private(set) var restSecondsRemaining = Int(restDuration)
    @Published private(set) var focusSecondsRemaining = Int(focusDuration)
    @Published private(set) var isReminderPreview = false

    private var restEndsAt: Date?
    private var tickerTask: Task<Void, Never>?
    private let statisticsStore: EyeCareStatisticsStore?

    init(
        now: Date = .now,
        statisticsStore: EyeCareStatisticsStore? = nil
    ) {
        self.statisticsStore = statisticsStore
        nextReminderAt = now.addingTimeInterval(Self.focusDuration)
        tickerTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { return }
                self?.tick()
            }
        }
    }

    deinit {
        tickerTask?.cancel()
    }

    var restProgress: Double {
        1 - (Double(restSecondsRemaining) / Self.restDuration)
    }

    var formattedFocusTime: String {
        let minutes = focusSecondsRemaining / 60
        let seconds = focusSecondsRemaining % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    func tick(now: Date = .now) {
        switch phase {
        case .focus:
            let remaining = max(0, Int(ceil(nextReminderAt.timeIntervalSince(now))))
            if focusSecondsRemaining != remaining {
                focusSecondsRemaining = remaining
            }
            if remaining == 0 {
                phase = .ready
            }

        case .ready:
            break

        case .resting:
            guard let restEndsAt else { return }
            let remaining = max(0, Int(ceil(restEndsAt.timeIntervalSince(now))))
            if restSecondsRemaining != remaining {
                restSecondsRemaining = remaining
            }
            if remaining == 0 {
                completeRest(at: restEndsAt)
            }

        case .completed:
            updateFocusCountdown(now: now)
            if focusSecondsRemaining == 0 {
                phase = .ready
            }
        }
    }

    func startRest(now: Date = .now) {
        if phase == .resting, let restEndsAt, now >= restEndsAt {
            completeRest(at: restEndsAt)
        }

        restSecondsRemaining = Int(Self.restDuration)
        restEndsAt = now.addingTimeInterval(Self.restDuration)
        isReminderPreview = false
        phase = .resting
    }

    func snooze(now: Date = .now) {
        nextReminderAt = now.addingTimeInterval(5 * 60)
        isReminderPreview = false
        phase = .focus
        updateFocusCountdown(now: now)
    }

    func returnToFocus(now: Date = .now) {
        isReminderPreview = false
        updateFocusCountdown(now: now)
        phase = focusSecondsRemaining == 0 ? .ready : .focus
    }

    func showReminderPreview() {
        isReminderPreview = true
        phase = .ready
    }

    func closeReminderPreview(now: Date = .now) {
        guard isReminderPreview else { return }
        returnToFocus(now: now)
    }

    private func completeRest(at now: Date) {
        restSecondsRemaining = 0
        restEndsAt = nil
        nextReminderAt = now.addingTimeInterval(Self.focusDuration)
        focusSecondsRemaining = Int(Self.focusDuration)
        statisticsStore?.recordCompletion(at: now)
        phase = .completed
    }

    private func updateFocusCountdown(now: Date) {
        let remaining = max(0, Int(ceil(nextReminderAt.timeIntervalSince(now))))
        if focusSecondsRemaining != remaining {
            focusSecondsRemaining = remaining
        }
    }
}
