import Foundation

/// Historical regimen versions must remain available when future schedules change.
struct Regimen: Identifiable, Codable {
    let id: UUID
    var ester: String
    var doseMilligramsOfEster: Double
    var intervalHours: Double
    var effectiveFrom: Date
    var effectiveUntil: Date?
    var timeZoneIdentifier: String
    // v1 supports only estradiol enanthate, subcutaneous.
}
