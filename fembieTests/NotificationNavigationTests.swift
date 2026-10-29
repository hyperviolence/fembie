import Testing
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
}
