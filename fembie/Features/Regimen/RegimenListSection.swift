import SwiftUI

struct RegimenListSection: View {
    let model: RegimenViewModel
    let onAdd: () -> Void
    let onEdit: (Regimen) -> Void
    @State private var regimenPendingDeletion: Regimen?
    @State private var isShowingDeleteConfirmation = false

    var body: some View {
        Section {
            if model.regimens.isEmpty {
                ContentUnavailableView("No saved regimens", systemImage: "cross.case",
                    description: Text("Add a regimen to generate a dose schedule."))
            } else {
                ForEach(model.regimens) { regimen in
                    Button {
                        onEdit(regimen)
                    } label: {
                        RegimenListRow(regimen: regimen, now: model.now)
                    }
                    .buttonStyle(.plain)
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button("Delete", systemImage: "trash") {
                            regimenPendingDeletion = regimen
                            isShowingDeleteConfirmation = true
                        }
                        .tint(.red)
                    }
                }
            }
            Button("Add regimen", systemImage: "plus", action: onAdd)
        } header: {
            Text("Regimens")
        } footer: {
            Text("Overlapping regimens are combined when estimated estradiol levels are calculated.")
        }
        .confirmationDialog(
            "Delete regimen?",
            isPresented: $isShowingDeleteConfirmation,
            titleVisibility: .visible,
            presenting: regimenPendingDeletion
        ) { regimen in
            Button("Delete \(regimen.ester)", role: .destructive) {
                Task { await model.deleteRegimen(regimen) }
            }
            Button("Cancel", role: .cancel) { }
        } message: { regimen in
            Text("This permanently deletes the regimen and its dose history. This action cannot be undone.")
        }
    }
}

private struct RegimenListRow: View {
    let regimen: Regimen
    let now: Date

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(regimen.ester).bold()
                Text("\(regimen.doseMilligramsOfEster.formatted(.number.precision(.fractionLength(0...2)))) mg every \((regimen.intervalHours / 24).formatted(.number.precision(.fractionLength(0...2)))) days")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(dateRange)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Image(systemName: "chevron.right").foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
    }

    private var dateRange: String {
        let start = regimen.effectiveFrom.formatted(date: .abbreviated, time: .shortened)
        let end = regimen.effectiveUntil?.formatted(date: .abbreviated, time: .shortened) ?? "No end date"
        let status = regimen.isEffective(at: now) ? "Active" : (regimen.effectiveFrom > now ? "Upcoming" : "Ended")
        return "\(status) · \(start) – \(end)"
    }
}
