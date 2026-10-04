import SwiftUI
import EstradiolPK

struct LevelsView: View {
    @Environment(RegimenViewModel.self) private var regimenModel
    @Environment(\.scenePhase) private var scenePhase
    @State private var model = LevelsViewModel()

    var body: some View {
        NavigationStack {
            List {
                Section("Estimated estradiol") {
                    if let current = model.current {
                        LabeledContent("Estimated now · pg/mL") {
                            Text(current.estradiolPicogramsPerMilliliter,
                                 format: .number.precision(.fractionLength(0)))
                        }
                        LevelsChart(points: model.points, now: current.timestamp)
                        Text("Dashed line: projection assuming future injections are taken as scheduled.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                        LevelsChart(points: model.points, now: current.timestamp, showsRateOfChange: true)
                    } else {
                        Text("The graph appears when an estimate is available.")
                            .foregroundStyle(.secondary)
                    }
                }
                Section("Model") {
                    Text("Estimates include recorded history only, with untouched past injections assumed taken. Earlier doses and individual variability are not included.")
                        .foregroundStyle(.secondary)
                    if let modelIdentifier = model.modelIdentifier {
                        Text(modelIdentifier)
                            .font(.caption)
                    }
                    if let sourceURL = URL(string: "https://estrannai.se") {
                        Link(model.modelSource, destination: sourceURL)
                    }
                    DisclosureGroup("MIT license · Copyright © 2025 alix") {
                        Text(EstrannaiseAttribution.license)
                            .font(.caption)
                    }
                    Text("Modeled estimates are not blood test measurements.")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Levels")
        }
        .task {
            if !regimenModel.hasLoaded { await regimenModel.load() }
        }
        .task(id: LevelsPredictionInput(regimen: regimenModel.savedRegimen,
                                       isActive: scenePhase == .active)) {
            let input = LevelsPredictionInput(regimen: regimenModel.savedRegimen,
                                             isActive: scenePhase == .active)
            guard input.isActive else { return }
            while !Task.isCancelled {
                await model.refresh(input: input)
                do { try await Task.sleep(for: .seconds(60)) }
                catch { return }
            }
        }
    }
}
