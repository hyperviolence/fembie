import SwiftUI

struct LabResultsView: View {
    @Environment(LabResultsViewModel.self) private var model

    var body: some View {
        @Bindable var model = model
        NavigationStack {
            Form {
                Section {
                    Toggle("Use latest E2 result for levels calibration", isOn: $model.useLatestE2ResultForCalibration)
                } footer: {
                    Text("Applies the difference between your E2 result and the model at the test's date/time to later estimates. Levels cannot go below zero.")
                    if model.useLatestE2ResultForCalibration {
                        if let result = model.latestE2Result {
                            Text("Latest E2: \(result.value.formatted()) \(result.unit), \(result.recordedAt.formatted(date: .abbreviated, time: .shortened)).")
                        } else {
                            Text("No E2 result is saved. Add an E2 result to apply calibration.")
                        }
                    }
                }
                Section("Add lab result") {
                    Picker("Test", selection: $model.test) {
                        ForEach(LabTest.allCases) { test in
                            Text(test.rawValue).tag(test)
                        }
                    }
                    TextField("Value", text: $model.value)
                        .keyboardType(.decimalPad)
                    Picker("Unit", selection: $model.unit) {
                        ForEach(model.test.unit, id: \.self) { unit in
                            Text(unit).tag(unit)
                        }
                    }
                    DatePicker("Date and time", selection: $model.recordedAt,
                               displayedComponents: [.date, .hourAndMinute])
                }
                .disabled(model.isBusy)

                Section {
                    Button(model.isBusy ? "Please wait…" : "Save lab result") {
                        Task { await model.save() }
                    }
                    .disabled(model.isBusy)
                    if model.didSave {
                        Label("Lab result saved", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                    if let message = model.message {
                        Text(message)
                            .foregroundStyle(.red)
                    }
                }

                Section("Latest results") {
                    if model.results.isEmpty {
                        if model.isBusy {
                            ProgressView("Loading lab results…")
                        } else {
                            Text("No lab results saved yet.")
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        ForEach(model.visibleResults) { result in
                            VStack(alignment: .leading) {
                                HStack {
                                    Text(result.test.rawValue)
                                        .font(.headline)
                                    Spacer()
                                    Text("\(result.value.formatted()) \(result.unit)")
                                }
                                Text(result.recordedAt, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button("Delete", systemImage: "trash", role: .destructive) {
                                    Task { await model.delete(result) }
                                }
                                .disabled(model.isBusy)
                            }
                        }
                        if model.hasMoreResults {
                            Button("Show 3 more") { model.showMore() }
                        }
                    }
                }
            }
            .navigationTitle("Lab results")
        }
    }
}
