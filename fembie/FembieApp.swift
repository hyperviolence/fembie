import SwiftUI

@main
struct FembieApp: App {
    @State private var regimenModel: RegimenViewModel
    @State private var checkInModel: CheckInViewModel
    @State private var labResultsModel: LabResultsViewModel
    @State private var dataExportModel: DataExportViewModel
    @State private var notifications = LevelsNotificationViewModel()
    @State private var regimenNotifications = RegimenNotificationViewModel()
    @State private var checkInReminder = CheckInReminderViewModel()
    @State private var navigation: NotificationNavigationModel
    private let notificationCenterDelegate: NotificationCenterDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let repository = FileTrackingRepository()
        let navigation = NotificationNavigationModel()
        _navigation = State(initialValue: navigation)
        notificationCenterDelegate = NotificationCenterDelegate(navigation: navigation)
        _regimenModel = State(initialValue: RegimenViewModel(repository: repository))
        _checkInModel = State(initialValue: CheckInViewModel(repository: repository))
        _labResultsModel = State(initialValue: LabResultsViewModel(repository: repository))
        _dataExportModel = State(initialValue: DataExportViewModel(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            ContentView(navigation: navigation)
                .environment(regimenModel)
                .environment(checkInModel)
                .environment(labResultsModel)
                .environment(dataExportModel)
                .environment(notifications)
                .environment(checkInReminder)
                .environment(regimenNotifications)
                .task(id: RegimenNotificationInput(
                    prediction: LevelsPredictionInput(regimen: regimenModel.savedRegimen,
                                                      isActive: scenePhase == .active),
                    preferences: regimenNotifications.preferences)) {
                    guard scenePhase == .active else { return }
                    if !regimenModel.hasLoaded { await regimenModel.load() }
                    guard !Task.isCancelled else { return }
                    while !Task.isCancelled {
                        await regimenNotifications.refresh(regimen: regimenModel.savedRegimen)
                        guard regimenNotifications.preferences.enabled else { return }
                        do { try await Task.sleep(for: .seconds(60)) }
                        catch { return }
                    }
                }
                .task(id: CheckInReminderInput(preferences: checkInReminder.preferences,
                                              isActive: scenePhase == .active)) {
                    guard scenePhase == .active else { return }
                    await checkInReminder.refresh()
                }
                .task(id: LevelsNotificationInput(
                    prediction: LevelsPredictionInput(regimen: regimenModel.savedRegimen,
                        isActive: scenePhase == .active,
                        calibrationEnabled: labResultsModel.useLatestE2ResultForCalibration,
                        calibrationResult: labResultsModel.useLatestE2ResultForCalibration ? labResultsModel.latestE2Result : nil),
                    preferences: notifications.preferences)) {
                    guard scenePhase == .active else { return }
                    if !regimenModel.hasLoaded { await regimenModel.load() }
                    await labResultsModel.load()
                    guard !Task.isCancelled else { return }
                    let input = LevelsPredictionInput(regimen: regimenModel.savedRegimen,
                        calibrationEnabled: labResultsModel.useLatestE2ResultForCalibration,
                        calibrationResult: labResultsModel.useLatestE2ResultForCalibration ? labResultsModel.latestE2Result : nil)
                    while !Task.isCancelled {
                        await notifications.refresh(input: input)
                        guard notifications.preferences.enabled else { return }
                        do { try await Task.sleep(for: .seconds(60)) }
                        catch { return }
                    }
                }
        }
    }
}
