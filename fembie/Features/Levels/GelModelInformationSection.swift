import SwiftUI

struct GelModelInformationSection: View {
    var body: some View {
        Text("Generic gel approximation based on EstroGel and Divigel prescribing information.")
        Text("Uses only the estradiol dose applied. Brand, application site and area, washing, skin absorption, and individual differences can substantially change actual levels. Genital application is not represented.")
            .foregroundStyle(.secondary)
        Text("This experimental model combines published population summaries from postmenopausal women. It has not been clinically validated. Dose scaling beyond the studied 0.25–1 mg range and predictions of peaks or rates of change are extrapolations. Endogenous baseline cannot be separated reliably from the source data.")
            .foregroundStyle(.secondary)
        if let url = URL(string: "https://dailymed.nlm.nih.gov/dailymed/fda/fdaDrugXsl.cfm?setid=762ac371-bb8b-47e7-b48f-e80d452c9dd4") {
            Link("EstroGel prescribing information · Section 12.3", destination: url)
        }
        if let url = URL(string: "https://dailymed.nlm.nih.gov/dailymed/fda/fdaDrugXsl.cfm?setid=59e610dc-883e-4f07-9ec6-a5841b0bf9fb") {
            Link("Divigel prescribing information · Section 12.3", destination: url)
        }
    }
}
