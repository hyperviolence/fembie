import SwiftUI

@main
struct FemmeTrackApp: App {
    @State private var regimenModel: RegimenViewModel
    @State private var checkInModel: CheckInViewModel
    @State private var labResultsModel: LabResultsViewModel
    @State private var notifications = LevelsNotificationViewModel()
    @Environment(\.scenePhase) private var scenePhase

    init() {
        let repository = FileTrackingRepository()
        _regimenModel = State(initialValue: RegimenViewModel(repository: repository))
        _checkInModel = State(initialValue: CheckInViewModel(repository: repository))
        _labResultsModel = State(initialValue: LabResultsViewModel(repository: repository))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(regimenModel)
                .environment(checkInModel)
                .environment(labResultsModel)
                .environment(notifications)
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
