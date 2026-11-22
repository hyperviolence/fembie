import Foundation

nonisolated enum LabTest: String, Codable, CaseIterable, Identifiable, Sendable {
    case e2 = "E2"
    case testosterone = "Testosterone"
    case lh = "LH"
    case shbg = "SHBG"

    var id: Self { self }

    var unit: Array<String> {
        switch self {
        case .e2: ["pg/mL", "pmol/L"]
        case .testosterone: ["ng/dL", "pg/mL"]
        case .lh: ["mIU/mL", "mlE/ml"]
        case .shbg: ["nmol/L"]
        }
    }

    func standardizedValue(_ value: Double, from inputUnit: String) -> (value: Double, unit: String) {
        guard self == .e2, inputUnit == "pmol/L" else {
            return (value, inputUnit)
        }

        return (value * 0.27238, "pg/mL")
    }
}
