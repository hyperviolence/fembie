import Foundation
import SwiftUI

nonisolated enum InjectionStatus {
    case upcoming, assumedTaken, confirmed, skipped, moved
    
    var color: Color {
        switch self {
        case .upcoming: .orange
        case .assumedTaken: .primary
        case .confirmed: .green
        case .skipped: .red
        case .moved: .orange
        }
    }

    init(event: InjectionEvent, now: Date) {
        switch event.adjustment {
        case .none: self = event.scheduledAt > now ? .upcoming : .assumedTaken
        case .confirmed: self = .confirmed
        case .skipped: self = .skipped
        case .moved(let actualAt): self = actualAt <= now ? .confirmed : .moved
        }
    }

    var title: String {
        switch self {
        case .upcoming: "Upcoming"
        case .assumedTaken: "Assumed taken"
        case .confirmed: "Confirmed taken"
        case .skipped: "Skipped"
        case .moved: "Moved"
        }
    }

    var systemImage: String {
        switch self {
        case .upcoming: "clock"
        case .assumedTaken: "checkmark.circle"
        case .confirmed: "checkmark.circle.fill"
        case .skipped: "xmark.circle"
        case .moved: "calendar.badge.clock"
        }
    }
}
