import Foundation
import Observation
import UserNotifications

nonisolated enum AppTab: Hashable, Sendable {
    case levels
    case wellbeing
    case labs
    case regimen
    case settings

    static func notificationDestination(for identifier: String) -> AppTab? {
        if identifier.hasPrefix(LevelNotificationEvent.identifierPrefix) {
            return .levels
        }
        if identifier == CheckInReminderScheduler.identifier {
            return .wellbeing
        }
        if identifier.hasPrefix(RegimenNotificationEvent.identifierPrefix) {
            return .regimen
        }
        return nil
    }
}

@MainActor
@Observable
final class NotificationNavigationModel {
    var selectedTab: AppTab = .levels

    func openNotification(identifier: String) {
        guard let destination = AppTab.notificationDestination(for: identifier) else { return }
        selectedTab = destination
    }
}

@MainActor
final class NotificationCenterDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let navigation: NotificationNavigationModel

    init(
        navigation: NotificationNavigationModel,
        center: UNUserNotificationCenter = .current()
    ) {
        self.navigation = navigation
        super.init()
        center.delegate = self
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let identifier = response.notification.request.identifier
        await navigation.openNotification(identifier: identifier)
    }
}
