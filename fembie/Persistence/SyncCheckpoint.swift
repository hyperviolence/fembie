import Foundation

nonisolated struct SyncCheckpoint: Codable {
    var account: String?
    var baseline = SyncSnapshot()
    var pending: SyncSnapshot?
    var captured: SyncSnapshot?
}
