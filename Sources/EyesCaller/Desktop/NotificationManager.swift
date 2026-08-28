import AppKit
import Foundation
@preconcurrency import UserNotifications

extension Notification.Name {
    static let eyesCallerStartRest = Notification.Name("EyesCallerStartRest")
}

final class NotificationManager: NSObject, UNUserNotificationCenterDelegate, @unchecked Sendable {
    static let shared = NotificationManager()

    private enum Identifier {
        static let reminder = "eyes-caller.rest-reminder"
        static let category = "eyes-caller.rest-category"
        static let startRest = "eyes-caller.start-rest"
    }

    private var center: UNUserNotificationCenter?

    private override init() {
        super.init()
    }

    func configure() {
        // `swift run` launches a bare executable without a bundle identifier.
        // UserNotifications requires a real .app identity, so keep this path safe
        // and let the compact reminder panel act as the fallback.
        guard Bundle.main.bundleIdentifier != nil else { return }

        let center = UNUserNotificationCenter.current()
        self.center = center
        center.delegate = self

        let startAction = UNNotificationAction(
            identifier: Identifier.startRest,
            title: "开始远眺",
            options: [.foreground]
        )
        let category = UNNotificationCategory(
            identifier: Identifier.category,
            actions: [startAction],
            intentIdentifiers: [],
            options: [.customDismissAction]
        )
        center.setNotificationCategories([category])
        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func sendRestReminder(
        completion: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        guard let center else {
            finish(false, completion: completion)
            return
        }

        center.getNotificationSettings { settings in
            let isAuthorized: Bool
            switch settings.authorizationStatus {
            case .authorized, .provisional, .ephemeral:
                isAuthorized = true
            case .notDetermined, .denied:
                isAuthorized = false
            @unknown default:
                isAuthorized = false
            }

            let canPresentAlert = settings.alertSetting == .enabled
                && settings.alertStyle != .none
            guard isAuthorized, canPresentAlert else {
                self.finish(false, completion: completion)
                return
            }

            center.removePendingNotificationRequests(withIdentifiers: [Identifier.reminder])
            center.removeDeliveredNotifications(withIdentifiers: [Identifier.reminder])

            let content = UNMutableNotificationContent()
            content.title = "该看看远处了"
            content.body = "找一个约 6 米外的目标，让眼睛放松 20 秒。"
            content.sound = .default
            content.categoryIdentifier = Identifier.category

            let request = UNNotificationRequest(
                identifier: Identifier.reminder,
                content: content,
                trigger: nil
            )
            center.add(request) { error in
                self.finish(error == nil, completion: completion)
            }
        }
    }

    func clearReminder() {
        center?.removePendingNotificationRequests(withIdentifiers: [Identifier.reminder])
        center?.removeDeliveredNotifications(withIdentifiers: [Identifier.reminder])
    }

    private func finish(
        _ delivered: Bool,
        completion: @escaping @MainActor @Sendable (Bool) -> Void
    ) {
        Task { @MainActor in
            completion(delivered)
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier != UNNotificationDismissActionIdentifier else { return }
        let shouldStartRest = response.actionIdentifier == Identifier.startRest

        await MainActor.run {
            ReminderPanelController.shared.dismiss()
            if shouldStartRest {
                NotificationCenter.default.post(name: .eyesCallerStartRest, object: nil)
            }
            ApplicationVisibility.showMainWindow()
        }
    }
}
