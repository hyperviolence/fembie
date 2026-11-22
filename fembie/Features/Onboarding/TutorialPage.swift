import SwiftUI

enum TutorialPage: Int, CaseIterable, Identifiable {
    case welcome
    case disclaimer
    case overview
    case extras

    var id: Self { self }

    var title: String {
        switch self {
        case .welcome: "Welcome to fembie"
        case .disclaimer: "A clear boundary"
        case .overview: "How fembie works"
        case .extras: "Lab results and custom metrics"
        }
    }

    var systemImage: String {
        switch self {
        case .welcome: "sparkles"
        case .disclaimer: "exclamationmark.shield"
        case .overview: "chart.xyaxis.line"
        case .extras: "slider.horizontal.3"
        }
    }
}
