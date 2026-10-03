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
    @State private var takenEventIDs: Set<UUID> = []
    @State private var forgottenEventIDs: Set<UUID> = []
    
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
                        let events = injectionEventsAroundNow(for: regimen, pastCount: pastInjectionsToShow, futureCount: futureInjectionsToShow)
                        if events.isEmpty {
                            ContentUnavailableView("No scheduled injections", systemImage: "calendar",
                                description: Text("Your schedule will generate the event list here."))
                        } else {
                            Button("Show more past injections...") {
                                pastInjectionsToShow += 3
                            }
                            ForEach(events, id: \.id) { event in
                                VStack(alignment: .leading, spacing: 8) {
                                    Text(event.scheduledAt.formatted(date: .abbreviated, time: .shortened))
                                        .font(.headline)
                                    HStack(spacing: 8) {
                                        Button("Taken") {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if !takenEventIDs.contains(event.id) {
                                                    if let idx = currentRegimen?.injectionEvents.firstIndex(where: { $0.id == event.id }) {
                                                        currentRegimen!.injectionEvents[idx].adjustment = .none
                                                    }
                                                    forgottenEventIDs.remove(event.id)
                                                    takenEventIDs.insert(event.id)
                                                
                                                }
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(takenEventIDs.contains(event.id) ? .green : .accentColor)

                                        Button("Forgotten") {
                                            withAnimation(.easeInOut(duration: 0.2)) {
                                                if !forgottenEventIDs.contains(event.id) {
                                                    if let idx = currentRegimen?.injectionEvents.firstIndex(where: { $0.id == event.id }) {
                                                        currentRegimen!.injectionEvents[idx].adjustment = .skipped
                                                    }
                                                    takenEventIDs.remove(event.id)
                                                    forgottenEventIDs.insert(event.id)
                                                }
                                            }
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .tint(forgottenEventIDs.contains(event.id) ? .red)

                                        Button("Delayed") {
                                            //TODO: implement delay
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
    
    private func injectionEventsAroundNow(for regimen: Regimen, pastCount: Int, futureCount: Int) -> [InjectionEvent] {
        let events = regimen.injectionEvents.sorted { $0.scheduledAt < $1.scheduledAt }
        guard !events.isEmpty else { return [] }
        let now = Date()

        // If all events are in the future, return the next 'futureCount' events
        if let first = events.first, first.scheduledAt > now {
            return Array(events.prefix(futureCount))
        }

        // Find the last event that is at or before now
        guard let lastPastIndex = events.lastIndex(where: { $0.scheduledAt <= now }) else {
            return Array(events.prefix(futureCount))
        }

        // Past slice including the most recent past event
        let pastStart = max(0, lastPastIndex - (pastCount - 1))
        let pastSlice = events[pastStart...lastPastIndex]

        // Future slice right after the last past event
        let futureStart = min(events.count, lastPastIndex + 1)
        let futureEnd = min(events.count, futureStart + futureCount)
        let futureSlice = events[futureStart..<futureEnd]

        return Array(pastSlice) + Array(futureSlice)
    }
}

