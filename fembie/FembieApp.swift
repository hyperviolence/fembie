import SwiftUI

@main
struct FembieApp: App {
    @State private var regimenModel: RegimenViewModel
    @State private var checkInModel: CheckInViewModel
    @State private var labResultsModel: LabResultsViewModel
    @State private var dataExportModel: DataExportViewModel
    @State private var cloudSync: ICloudSyncViewModel
    @State private var notifications = LevelsNotificationViewModel()
    @State private var regimenNotifications = RegimenNotificationViewModel()
    @State private var checkInReminder = CheckInReminderViewModel()
    @State private var navigation: NotificationNavigationModel
    private let notificationCenterDelegate: NotificationCenterDelegate
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let repository = FileTrackingRepository()
        _cloudSync = State(initialValue: ICloudSyncViewModel(repository: repository))
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
                .environment(cloudSync)
                .task(id: "\(scenePhase)-\(cloudSync.enabled)") {
                    guard scenePhase == .active, cloudSync.enabled else { return }
                    while !Task.isCancelled {
                        await cloudSync.sync()
                        do { try await Task.sleep(for: .seconds(30)) }
                        catch { return }
                    }
                }
                .task(id: cloudSync.revision) {
                    guard cloudSync.revision > 0 else { return }
                    await regimenModel.load()
                    await checkInModel.reloadCheckIns()
                    await labResultsModel.load()
                    labResultsModel.useLatestE2ResultForCalibration = UserDefaults.standard.bool(forKey: "useLatestE2ResultForLevelsCalibration")
                    let decoder = JSONDecoder()
                    notifications.preferences = UserDefaults.standard.data(forKey: "levelsNotificationPreferences")
                        .flatMap { try? decoder.decode(LevelsNotificationPreferences.self, from: $0) } ?? .init()
                    regimenNotifications.preferences = UserDefaults.standard.data(forKey: "regimenNotificationPreferences")
                        .flatMap { try? decoder.decode(RegimenNotificationPreferences.self, from: $0) } ?? .init()
                    checkInReminder.preferences = UserDefaults.standard.data(forKey: "checkInReminderPreferences")
                        .flatMap { try? decoder.decode(CheckInReminderPreferences.self, from: $0) } ?? .init()
                }
                .environment(notifications)
                .environment(checkInReminder)
                .environment(regimenNotifications)
                .task(id: dataExportModel.importRevision) {
                    guard dataExportModel.importRevision > 0 else { return }
                    await regimenModel.load()
                    await checkInModel.reloadCheckIns()
                }
                .task(id: RegimenNotificationInput(
                    prediction: LevelsPredictionInput(regimens: regimenModel.regimens,
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
                    prediction: LevelsPredictionInput(regimens: regimenModel.regimens,
                        isActive: scenePhase == .active,
                        calibrationEnabled: labResultsModel.useLatestE2ResultForCalibration,
                        calibrationResult: labResultsModel.useLatestE2ResultForCalibration ? labResultsModel.latestE2Result : nil),
                    preferences: notifications.preferences)) {
                    guard scenePhase == .active else { return }
                    if !regimenModel.hasLoaded { await regimenModel.load() }
                    await labResultsModel.load()
                    guard !Task.isCancelled else { return }
                    let input = LevelsPredictionInput(regimens: regimenModel.regimens,
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
