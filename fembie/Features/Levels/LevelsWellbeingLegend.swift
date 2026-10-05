import SwiftUI

struct LevelsWellbeingLegend: View {
    let showsRateOfChange: Bool

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Label(showsRateOfChange ? "dE2/dt" : "E2", systemImage: "line.diagonal")
                    .foregroundStyle(.tint)
                Label("Mood", systemImage: "circle.fill")
                    .foregroundStyle(.pink)
                Label("Libido", systemImage: "square.fill")
                    .foregroundStyle(.purple)
                Label("Energy", systemImage: "triangle.fill")
                    .foregroundStyle(.orange)
            }
        }
        .font(.caption)
    }
}
