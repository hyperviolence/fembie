import SwiftUI

struct RegimenSummarySection: View {
    let regimen: Regimen?
    let title: String

    var body: some View {
        Section(title) {
            if let regimen {
                LabeledContent("Formulation", value: regimen.ester)
                LabeledContent("Route", value: regimen.route.displayName)
                LabeledContent("Dose", value: regimen.doseMilligramsOfEster.formatted(.number.precision(.fractionLength(0...2))) + " mg")
                LabeledContent("Interval", value: (regimen.intervalHours / 24).formatted(.number.precision(.fractionLength(0...2))) + " days")
                LabeledContent("Effective from", value: regimen.effectiveFrom.formatted(date: .abbreviated, time: .shortened))
                if let until = regimen.effectiveUntil {
                    LabeledContent("Effective until", value: until.formatted(date: .abbreviated, time: .shortened))
                }
                LabeledContent("Time zone", value: regimen.timeZoneIdentifier)
            } else {
                ContentUnavailableView("No saved regimen", systemImage: "cross.case",
                                       description: Text("Save a regimen to see it here."))
            }
        }
    }
}
