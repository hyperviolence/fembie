import SwiftUI

struct RegimenView: View {
    @State private var selectedEster: EstradiolType = EstradiolType.allCases.first!
    @State private var selectedRoute: EstradiolRoute = EstradiolRoute.subcutaneous
    @State private var dose = ""
    @State private var intervalDays = ""
    @State private var firstInjection = Date()
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var currentRegimen: Regimen?
    @State private var pastInjectionsToShow = 2
    @State private var futureInjectionsToShow = 1
    
    private let enabledEstradiolTypes: Set<EstradiolType> = [EstradiolType.estradiolEnanthate]
    private let enabledAdministrationRoutes: Set<EstradiolRoute> = [EstradiolRoute.subcutaneous]

    
    private var parsedDose: Double? { Double(dose) }
    private var parsedIntervalDays: Double? { Double(intervalDays) }
    private var canSave: Bool { (parsedDose ?? 0) > 0 && (parsedIntervalDays ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Estradiol regimen") {
                    Picker("Formulation", selection: $selectedEster) {
                        ForEach(EstradiolType.allCases) { ester in
                            if enabledEstradiolTypes.contains(ester) {
                                Text(ester.displayName).tag(ester)
                            }
                        }
                    }
                    Picker("Route", selection: $selectedRoute) {
                        ForEach(EsterRoutes.getRoutes(ester: selectedEster)) { route in
                            if enabledAdministrationRoutes.contains(route) {
                                Text(route.displayName).tag(route)
                            }
                        }
                    }
                    TextField("Dose (mg)", text: $dose)
                        .keyboardType(.decimalPad)
                    TextField("Interval (days)", text: $intervalDays)
                        .keyboardType(.decimalPad)
                    DatePicker("First injection", selection: $firstInjection)
                    Button("Save regimen") {
                        guard let doseMg = parsedDose, let intervalDays = parsedIntervalDays else { return }
                        let regimen = Regimen(
                            id: UUID(),
                            ester: "Estradiol Enanthate (EEn)",
                            doseMilligramsOfEster: doseMg,
                            intervalHours: intervalDays * 24.0,
                            effectiveFrom: firstInjection,
                            effectiveUntil: nil,
                            timeZoneIdentifier: TimeZone.current.identifier
                        )
                        Task {
                            do {
                                let repo = try FileTrackingRepository()
                                try await repo.save(regimen)
                                await MainActor.run {
                                    currentRegimen = regimen
                                    pastInjectionsToShow = 2
                                    futureInjectionsToShow = 1
                                }
                                saveAlertMessage = "Regimen saved successfully."
                                showSaveAlert = true
                            } catch {
                                saveAlertMessage = "Could not save regimen: \(error.localizedDescription)"
                                showSaveAlert = true
                            }
                        }
                    }
                }
                Section("Current regimen") {
                    if let r = currentRegimen {
                        LabeledContent("Ester", value:r.ester)
                        LabeledContent("Dose", value: r.doseMilligramsOfEster.formatted(.number.precision(.fractionLength(0...2))) + " mg")
                        LabeledContent("Interval", value: (r.intervalHours / 24.0).formatted(.number.precision(.fractionLength(0...2))) + " days")
                        LabeledContent("Effective from", value: r.effectiveFrom.formatted(date: .abbreviated, time: .shortened))
                        if let until = r.effectiveUntil {
                            LabeledContent("Effective until", value: until.formatted(date: .abbreviated, time: .shortened))
                        }
                        LabeledContent("Time zone", value: r.timeZoneIdentifier)
                    } else {
                        ContentUnavailableView("No current regimen", systemImage: "cross.case", description: Text("Save a regimen to see it here."))
                    }
                }
                Section("Injection events") {
                    if let regimen = currentRegimen {
                        let dates = injectionDatesAroundNow(for: regimen, pastCount: pastInjectionsToShow, futureCount: futureInjectionsToShow)
                        if dates.isEmpty {
                            ContentUnavailableView("No scheduled injections", systemImage: "calendar",
                                description: Text("Your schedule will generate the event list here."))
                        } else {
                            Button("Show more past injections...") {
                                pastInjectionsToShow += 3
                            }.disabled(true)
                            ForEach(dates, id: \.self) { date in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                    HStack(spacing: 8) {
                                        Button("Taken") {
                                            // TODO: Implement action
                                        }
                                        .buttonStyle(.borderedProminent)

                                        Button("Forgotten") {
                                            // TODO: Implement action
                                        }
                                        .buttonStyle(.bordered)

                                        Button("Delayed") {
                                            // TODO: Implement action
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        
                            Button("Show more future injections...") {
                                futureInjectionsToShow += 3
                            }
                        }
                    } else {
                        ContentUnavailableView("No scheduled injections", systemImage: "calendar",
                            description: Text("Save a regimen to generate your injection schedule."))
                    }
                }
            }
            .navigationTitle("Regimen")
            .onChange(of: selectedEster) { newEster in
                let routes = EsterRoutes.getRoutes(ester: newEster)
                if let first = routes.first {
                    selectedRoute = first
                }
            }
            .task { await loadCurrentRegimen() }
            .alert("Save Regimen", isPresented: $showSaveAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(saveAlertMessage)
            }
        }
    }
    
    private func loadCurrentRegimen() async {
        do {
            let repo = try FileTrackingRepository()
            let regs = try await repo.regimens()
            let now = Date()
            let current = regs
                .filter { $0.effectiveFrom <= now && ($0.effectiveUntil == nil || $0.effectiveUntil! > now) }
                .max(by: { $0.effectiveFrom < $1.effectiveFrom })
            await MainActor.run { self.currentRegimen = current }
        } catch {
            // Non-fatal: leave currentRegimen as nil
            print("Failed to load current regimen: \(error)")
        }
    }
    
    private func injectionDatesAroundNow(for regimen: Regimen, pastCount: Int, futureCount: Int) -> [Date] {
        guard regimen.intervalHours > 0 else { return [] }
        let interval = regimen.intervalHours * 3600
        let now = Date()
        let start = regimen.effectiveFrom
        let end = regimen.effectiveUntil

        // If regimen starts in the future, show only future occurrences from start
        if start > now {
            var result: [Date] = []
            var current = start
            for _ in 0..<futureCount {
                if let end = end, current > end { break }
                result.append(current)
                current = current.addingTimeInterval(interval)
            }
            return result
        }

        // Compute the most recent occurrence at or before now
        let secondsSinceStart = now.timeIntervalSince(start)
        let n = floor(secondsSinceStart / interval)
        let lastPast = start.addingTimeInterval(n * interval)

        var dates: [Date] = []

        // Past occurrences (including lastPast), limited by start date
        var pastDates: [Date] = []
        var past = lastPast
        for _ in 0..<pastCount {
            if past < start { break }
            pastDates.append(past)
            past = past.addingTimeInterval(-interval)
        }
        pastDates.sort() // ascending
        dates.append(contentsOf: pastDates)

        // Future occurrences after lastPast, limited by effectiveUntil
        var next = lastPast.addingTimeInterval(interval)
        for _ in 0..<futureCount {
            if let end = end, next > end { break }
            dates.append(next)
            next = next.addingTimeInterval(interval)
        }

        return dates
    }
}
