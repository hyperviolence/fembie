import SwiftUI
import Charts

struct CheckInView: View {
    @State private var isAddingMetric = false
    @State private var mood = 5.0
    @State private var libido = 5.0
    @State private var energy = 5.0
    @State private var date: Date = Date()
    
    @Environment(CheckInViewModel.self) private var model

    var body: some View {
        NavigationStack {
            Form {
                Section("How do you feel?") {
                    rating("Mood", value: $mood, low: "Very low", high: "Very good")
                    rating("Libido", value: $libido, low: "No desire", high: "Very strong")
                    rating("Energy", value: $energy, low: "Exhausted", high: "Very energetic")
                    DatePicker(
                                "Date",
                                selection: $date,
                                displayedComponents: [.date, .hourAndMinute]
                            )
                    .datePickerStyle(.compact)
                    .labelsHidden()
                }
                CustomWellbeingSection(isAddingMetric: $isAddingMetric)
                Section {
                    Button(model.isSaving ? "Saving…" : model.isBusy ? "Loading check-ins…" : "Save check-in") {
                        let selectedDate = date
                        let selectedMood = mood
                        let selectedLibido = libido
                        let selectedEnergy = energy
                        Task {
                            await model.saveCheckIn(date: selectedDate, mood: selectedMood,
                                                    libido: selectedLibido, energy: selectedEnergy)
                        }
                    }
                    .disabled(model.isBusy)
                    if let savedDate = model.lastSavedCheckInDate {
                        Label("Check-in saved", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                        Text(savedDate, format: .dateTime.day().month(.abbreviated).year().hour().minute())
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let saveError = model.saveError {
                        Text(saveError)
                            .foregroundStyle(.red)
                    }
                    LabeledContent("Saved check-ins", value: model.checkIns.count.formatted())
                }
                Section("Check-in history") {
                    if let errorMessage = model.historyError {
                        Text(errorMessage)
                            .foregroundStyle(.secondary)
                    }
                    if model.checkIns.isEmpty {
                        if model.isBusy {
                            ProgressView("Loading check-ins…")
                        } else if model.historyError == nil {
                            ContentUnavailableView(
                                "No check-ins yet",
                                systemImage: "chart.xyaxis.line",
                                description: Text("Save a check-in to see your ratings over time.")
                            )
                        }
                    } else {
                        let dailyAverages = model.dailyAverages()
                        let firstDate = dailyAverages.first?.date ?? .now
                        let lastDate = dailyAverages.last?.date ?? firstDate

                        Chart(dailyAverages) { dailyAverage in
                            LineMark(
                                x: .value("Date", dailyAverage.date),
                                y: .value("Rating", dailyAverage.mood),
                                series: .value("Rating", "Mood")
                            )
                            .foregroundStyle(by: .value("Rating", "Mood"))
                            .symbol(by: .value("Rating", "Mood"))

                            LineMark(
                                x: .value("Date", dailyAverage.date),
                                y: .value("Rating", dailyAverage.libido),
                                series: .value("Rating", "Libido")
                            )
                            .foregroundStyle(by: .value("Rating", "Libido"))
                            .symbol(by: .value("Rating", "Libido"))

                            LineMark(
                                x: .value("Date", dailyAverage.date),
                                y: .value("Rating", dailyAverage.energy),
                                series: .value("Rating", "Energy")
                            )
                            .foregroundStyle(by: .value("Rating", "Energy"))
                            .symbol(by: .value("Rating", "Energy"))
                        }
                        .chartForegroundStyleScale([
                            "Mood": Color.pink,
                            "Libido": Color.purple,
                            "Energy": Color.orange
                        ])
                        .chartXScale(domain: firstDate.addingTimeInterval(-43_200)...lastDate.addingTimeInterval(43_200))
                        .chartYScale(domain: 0...10)
                        .chartYAxis {
                            AxisMarks(values: [0, 2, 4, 6, 8, 10])
                        }
                        .chartXAxis {
                            if dailyAverages.count == 1 {
                                AxisMarks(position: .bottom, values: [firstDate]) {
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.day().month(.abbreviated).year())
                                }
                            } else {
                                AxisMarks(position: .bottom, values: .automatic(desiredCount: 4)) {
                                    AxisGridLine()
                                    AxisTick()
                                    AxisValueLabel(format: .dateTime.day().month(.abbreviated))
                                }
                            }
                        }
                        .chartXAxisLabel("Date")
                        .chartYAxisLabel("Rating")
                        .frame(height: 220)
                        .accessibilityLabel("Daily average mood, libido, and energy ratings over time")
                        Text("Each point shows the average of that day's check-ins.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                if !model.checkIns.isEmpty {
                    CustomWellbeingHistory(metrics: model.customRatings, dailyAverages: model.dailyAverages())
                }
                CheckInReminderSection()
            }
            .navigationTitle("Wellbeing")
            .sheet(isPresented: $isAddingMetric) {
                AddWellbeingMetricView()
            }
            .task {
                await model.loadCheckIns()
                if let latest = model.checkIns.last {
                    mood = latest.mood
                    energy = latest.energy
                    libido = latest.libido
                }
            }
        }
    }

    private func rating(_ title: String, value: Binding<Double>, low: String, high: String) -> some View {
        VStack(alignment: .leading) {
            HStack {
                Text(title)
                Spacer()
                Text(value.wrappedValue, format: .number.precision(.fractionLength(0)))
            }
            Slider(value: value, in: 0...10, step: 1)
                .accessibilityLabel(title)
            HStack {
                Text(low)
                Spacer()
                Text(high)
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}
