import SwiftUI

extension RegimenColor {
    var color: Color {
        switch self {
        case .pink: .pink
        case .purple: .purple
        case .blue: .blue
        case .teal: .teal
        case .green: .green
        case .orange: .orange
        case .red: .red
        }
    }

    var label: LocalizedStringResource {
        switch self {
        case .pink: "Pink"
        case .purple: "Purple"
        case .blue: "Blue"
        case .teal: "Teal"
        case .green: "Green"
        case .orange: "Orange"
        case .red: "Red"
        }
    }
}
