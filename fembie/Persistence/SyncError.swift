import Foundation

nonisolated enum SyncError: LocalizedError {
    case unsupportedVersion
    case unavailable
    case accountChanged
    case invalidData

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion: "This iCloud data requires a newer version of fembie."
        case .unavailable: "Sign in to iCloud in Settings and check your connection, then try again."
        case .accountChanged: "The iCloud account has changed. Sync is paused to keep your data from being uploaded to another account. Sign back in to the original account to resume."
        case .invalidData: "The iCloud data could not be read. Your local data has been kept."
        }
    }
}
