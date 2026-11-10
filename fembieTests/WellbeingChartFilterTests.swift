import Foundation
import Testing
@testable import fembie

@MainActor
struct WellbeingChartFilterTests {
    @Test func defaultsShowAllAndSelectionsStayLocal() {
        let overview = WellbeingChartFilter()
        var detail = overview
        let id = UUID()
        detail.showsMood = false
        detail.showsLibido = false
        detail.showsEnergy = false
        detail.setCustomMetric(id: id, isVisible: false)
        #expect(overview.showsMood && overview.showsLibido && overview.showsEnergy)
        #expect(overview.showsCustomMetric(id: id))
        #expect(!detail.showsCustomMetric(id: id))
        #expect(detail.showsCustomMetric(id: UUID()))
        detail.setCustomMetric(id: id, isVisible: true)
        #expect(detail.showsCustomMetric(id: id))
        detail = WellbeingChartFilter()
        #expect(detail == overview)
    }

    @Test func accessibilityIncludesOnlySelectedMarkers() {
        let id = UUID()
        let checkIn = CheckIn(id: UUID(), recordedAt: .now, mood: 1, libido: 2, energy: 3,
                              customRatings: [.init(id: id, label: "Sleep", lowLabel: "Poor", highLabel: "Good", value: 8)])
        var filter = WellbeingChartFilter(showsMood: false, showsLibido: false, showsEnergy: false)
        #expect(filter.accessibilitySummary(for: checkIn).contains("Sleep: 8"))
        filter.setCustomMetric(id: id, isVisible: false)
        #expect(filter.accessibilitySummary(for: checkIn).isEmpty)
        filter.showsMood = true
        #expect(!filter.accessibilitySummary(for: checkIn).isEmpty)
        #expect(!filter.accessibilitySummary(for: checkIn).contains("Sleep"))
    }
}
