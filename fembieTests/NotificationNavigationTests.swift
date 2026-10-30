import Testing
import UserNotifications
@testable import fembie

struct NotificationNavigationTests {
    @Test func levelNotificationsOpenLevelsTab() {
        #expect(AppTab.notificationDestination(for: "fembie.levels.e2Peak.1700000000") == .levels)
    }

    @Test func checkInReminderOpensWellbeingTab() {
        #expect(AppTab.notificationDestination(for: CheckInReminderScheduler.identifier) == .wellbeing)
    }

    @Test func regimenRemindersOpenRegimenTab() {
        #expect(AppTab.notificationDestination(for: "fembie.regimen.injection.1700000000") == .regimen)
    }

    @Test func unrelatedNotificationsDoNotChangeTabs() {
        #expect(AppTab.notificationDestination(for: "unrelated.notification") == nil)
    }

    @MainActor
    @Test func navigationModelKeepsSelectionForUnknownNotification() {
        let model = NotificationNavigationModel()
        model.selectedTab = .settings

        model.openNotification(identifier: "unrelated.notification")

        #expect(model.selectedTab == .settings)
    }

    @MainActor
    @Test func defaultNotificationResponseHopsToMainActorAndCompletes() async {
        let model = NotificationNavigationModel()
        let delegate = NotificationCenterDelegate(navigation: model)

        await confirmation("Completion handler called") { completion in
            await Task.detached {
                delegate.handleNotificationResponse(
                    actionIdentifier: UNNotificationDefaultActionIdentifier,
                    notificationIdentifier: CheckInReminderScheduler.identifier,
                    completionHandler: { completion() }
                )
            }.value
        }

        #expect(model.selectedTab == .wellbeing)
    }

    @MainActor
    @Test func nondefaultNotificationResponseCompletesWithoutNavigating() async {
        let model = NotificationNavigationModel()
        model.selectedTab = .settings
        let delegate = NotificationCenterDelegate(navigation: model)

        await confirmation("Completion handler called") { completion in
            await Task.detached {
                delegate.handleNotificationResponse(
                    actionIdentifier: UNNotificationDismissActionIdentifier,
                    notificationIdentifier: CheckInReminderScheduler.identifier,
                    completionHandler: { completion() }
                )
            }.value
        }

        #expect(model.selectedTab == .settings)
    }
}
