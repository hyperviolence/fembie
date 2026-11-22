import SwiftUI
import EstradiolPK

struct LevelsView: View {
    @Environment(RegimenViewModel.self) private var regimenModel
    @Environment(CheckInViewModel.self) private var checkInModel
    @Environment(LabResultsViewModel.self) private var labResultsModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = LevelsViewModel()
    @State private var showWellbeing: Bool = false
    @State private var showModelInformation = false

    var body: some View {
        NavigationStack {
            List {
                Section("Estimated estradiol") {
                    if let current = model.current {
                        LabeledContent("Estimated now · pg/mL") {
                            Text(current.estradiolPicogramsPerMilliliter,
                                 format: .number.precision(.fractionLength(0)))
                        }
                        NavigationLink {
                            LevelsChartDetailView(
                                input: LevelsPredictionInput(
                                    regimens: regimenModel.regimens,
                                    calibrationEnabled: labResultsModel.useLatestE2ResultForCalibration,
                                    calibrationResult: labResultsModel.useLatestE2ResultForCalibration
                                        ? labResultsModel.latestE2Result : nil
                                ),
                                now: current.timestamp,
                                showsRateOfChange: false,
                                showWellbeing: showWellbeing
                            )
                        } label: {
                            LevelsChart(points: model.points, now: current.timestamp, showWellbeing: showWellbeing, wellbeing: checkInModel.checkIns)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens a scrollable chart")
                        Text("Dashed line: projection assuming future doses are taken as scheduled. This is a rough estimation: DO NOT take as medical advice.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if labResultsModel.useLatestE2ResultForCalibration {
                            Text(model.calibrationMessage ?? "Updating calibration…")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Picker("Mode", selection: $showWellbeing) {
                            Text("E2").tag(false)
                            Text("E2 + Wellbeing").tag(true)
                        }
                        .pickerStyle(.segmented)
                    } else if model.isLoading {
                        ProgressView("Calculating estimates")
                    } else {
                        ContentUnavailableView("No estimate yet", systemImage: "chart.xyaxis.line",
                            description: Text(regimenModel.loadError ?? model.message ?? "Loading regimen…"))
                    }
                }
                Section("Rate of change · dE2/dt") {
                    if let current = model.current {
                        LabeledContent("Estimated now · (pg/mL)/hour") {
                            if (current.rateOfChangePicogramsPerMilliliterPerHour >= 0) {
                                Label("Arrow", systemImage: "arrow.up")
                                    .labelStyle(.iconOnly)
                                    .foregroundColor(.green)
                            } else {
                                Label("Arrow", systemImage: "arrow.down")
                                    .labelStyle(.iconOnly)
                                    .foregroundColor(.red)
                            }
                        }
                        NavigationLink {
                            LevelsChartDetailView(
                                input: LevelsPredictionInput(
                                    regimens: regimenModel.regimens,
                                    calibrationEnabled: labResultsModel.useLatestE2ResultForCalibration,
                                    calibrationResult: labResultsModel.useLatestE2ResultForCalibration
                                        ? labResultsModel.latestE2Result : nil
                                ),
                                now: current.timestamp,
                                showsRateOfChange: true,
                                showWellbeing: showWellbeing
                            )
                        } label: {
                            LevelsChart(points: model.points, now: current.timestamp, showsRateOfChange: true, showWellbeing: showWellbeing, wellbeing: checkInModel.checkIns)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Opens a scrollable chart")
                    } else {
                        Text("The graph appears when an estimate is available.")
                            .foregroundStyle(.secondary)
                    }
                }
                LevelsNotificationSection()
                Section {
                    Button("Model information", systemImage: "info.circle") {
                        showModelInformation = true
                    }
                }
            }
            .navigationTitle("Levels")
        }
        .sheet(isPresented: $showModelInformation) {
            LevelsModelInformationView(model: model)
        }
        .task(id: showWellbeing) {
            if showWellbeing { await checkInModel.loadCheckIns() }
        }
        .task {
            if !regimenModel.hasLoaded { await regimenModel.load() }
        }
        .task(id: LevelsPredictionInput(regimens: regimenModel.regimens,
                                       isActive: scenePhase == .active,
                                       calibrationEnabled: labResultsModel.useLatestE2ResultForCalibration,
                                       calibrationResult: labResultsModel.useLatestE2ResultForCalibration ? labResultsModel.latestE2Result : nil)) {
            let input = LevelsPredictionInput(regimens: regimenModel.regimens,
                                             isActive: scenePhase == .active,
                                       calibrationEnabled: labResultsModel.useLatestE2ResultForCalibration,
                                       calibrationResult: labResultsModel.useLatestE2ResultForCalibration ? labResultsModel.latestE2Result : nil)
            guard input.isActive else { return }
            while !Task.isCancelled {
                await model.refresh(input: input)
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
            }
        }
    }
}
