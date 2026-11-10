import Foundation

/// Stable JSON values, independent of SwiftUI's color encoding.
nonisolated enum RegimenColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case pink, purple, blue, teal, green, orange, red
    var id: String { rawValue }
}
