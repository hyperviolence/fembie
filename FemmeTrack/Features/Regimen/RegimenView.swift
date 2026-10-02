import SwiftUI

struct RegimenView: View {
    @State private var selectedEster: Ester = Ester.allCases.first!
    @State private var dose = ""
    @State private var intervalDays = ""
    @State private var firstInjection = Date()
    @State private var showSaveAlert = false
    @State private var saveAlertMessage = ""
    @State private var currentRegimen: Regimen?
    
    init(selectedEster: Ester? = nil) {
        _selectedEster = State(initialValue: selectedEster ?? Ester.allCases.first!)
    }
    
    private var parsedDose: Double? { Double(dose) }
    private var parsedIntervalDays: Double? { Double(intervalDays) }
    private var canSave: Bool { (parsedDose ?? 0) > 0 && (parsedIntervalDays ?? 0) > 0 }

    var body: some View {
        NavigationStack {
            Form {
                Section("Estradiol regimen") {
                    Picker("Formulation", selection: $selectedEster) {
                        ForEach(Ester.allCases) { ester in
                            Text(ester.displayName).tag(ester)
                        }
                    }
                    LabeledContent("Route", value: "Subcutaneous")
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
                                await MainActor.run { currentRegimen = regimen }
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
                    ContentUnavailableView("No scheduled injections", systemImage: "calendar",
                        description: Text("Your schedule will generate the event list here."))
                }
            }
            .navigationTitle("Regimen")
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
}

