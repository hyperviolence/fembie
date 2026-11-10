import Foundation

/// One chart point per local calendar day; original check-ins remain unchanged.
nonisolated struct DailyCheckInAverage: Identifiable, Sendable {
    let date: Date
    let mood: Double
    let libido: Double
    let energy: Double
    var customRatings: [CustomWellbeingRating] = []

    var id: Date { date }
}
