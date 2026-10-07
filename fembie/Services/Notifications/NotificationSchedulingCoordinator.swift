import Foundation

/// All features update the shared system queue in order.
@MainActor
final class NotificationSchedulingCoordinator {
    static let shared = NotificationSchedulingCoordinator()
    private var updateTask: Task<Int, any Error>?

    func run(_ operation: @escaping @MainActor () async throws -> Int) async throws -> Int {
        let previous = updateTask
        let task = Task { @MainActor in
            _ = try? await previous?.value
            return try await operation()
        }
        updateTask = task
        return try await task.value
    }
}
