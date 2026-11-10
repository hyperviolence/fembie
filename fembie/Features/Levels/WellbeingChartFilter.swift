import Foundation

/// Owned by each detailed graph; a default value leaves overview graphs unfiltered.
struct WellbeingChartFilter: Equatable {
    var showsMood = true
    var showsLibido = true
    var showsEnergy = true
    var hiddenCustomIDs: Set<UUID> = []

    func showsCustomMetric(id: UUID) -> Bool {
        !hiddenCustomIDs.contains(id)
    }

    mutating func setCustomMetric(id: UUID, isVisible: Bool) {
        if isVisible { hiddenCustomIDs.remove(id) }
        else { hiddenCustomIDs.insert(id) }
    }

    func accessibilitySummary(for checkIn: CheckIn) -> String {
        var values: [String] = []
        if showsMood { values.append(String(localized: "Mood: \(checkIn.mood.formatted())")) }
        if showsLibido { values.append(String(localized: "Libido: \(checkIn.libido.formatted())")) }
        if showsEnergy { values.append(String(localized: "Energy: \(checkIn.energy.formatted())")) }
        values += checkIn.customRatings.filter { showsCustomMetric(id: $0.id) }
            .map { "\($0.label): \($0.value.formatted())" }
        guard !values.isEmpty else { return "" }
        return checkIn.recordedAt.formatted(date: .abbreviated, time: .shortened)
            + ": " + values.joined(separator: ", ")
    }
}
