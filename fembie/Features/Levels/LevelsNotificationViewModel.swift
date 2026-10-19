import Foundation
import Observation
import EstradiolPK

@MainActor
@Observable
final class LevelsNotificationViewModel {
    var preferences: LevelsNotificationPreferences {
        didSet {
            if !preferences.enabled { message = nil }
            if let data = try? JSONEncoder().encode(preferences) { settings.set(data, forKey: Self.settingsKey) }
        }
    }
    private(set) var message: String?
    private(set) var scheduledCount = 0

    @ObservationIgnored private let settings: UserDefaults
    @ObservationIgnored private let scheduler: any LevelNotificationScheduling
    @ObservationIgnored private let calculator: any LevelsPredictionCalculating
    @ObservationIgnored private var revision = 0
    private static let settingsKey = "levelsNotificationPreferences"

    init(settings: UserDefaults = .standard,
         scheduler: any LevelNotificationScheduling = LevelNotificationScheduler(),
         calculator: any LevelsPredictionCalculating = LevelsPredictionCalculator()) {
        self.settings = settings
        self.scheduler = scheduler
        self.calculator = calculator
        if let data = settings.data(forKey: Self.settingsKey),
           let saved = try? JSONDecoder().decode(LevelsNotificationPreferences.self, from: data) {
            preferences = saved
        } else {
            preferences = LevelsNotificationPreferences()
        }
    }

    func refresh(input: LevelsPredictionInput, now: Date = Date()) async {
        revision += 1
        let requestRevision = revision
        let selected = preferences
        func isCurrent() -> Bool {
            revision == requestRevision && preferences == selected && !Task.isCancelled
        }
        do {
            guard selected.enabled else {
                _ = try await scheduler.replace(events: [])
                if isCurrent() { scheduledCount = 0 }
                return
            }
            message = nil
            let allowed = try await scheduler.authorize()
            guard isCurrent() else { return }
            guard allowed else {
                preferences.enabled = false
                message = "Notifications are disabled in iOS. Allow notifications for fembie in Settings, then turn this on again."
                _ = try await scheduler.replace(events: [])
                scheduledCount = 0
                return
            }
            guard let regimen = input.regimen, LevelsPredictionCalculator.model(for: regimen) != nil else {
                _ = try await scheduler.replace(events: [])
                guard isCurrent() else { return }
                scheduledCount = 0
                message = "Save a supported regimen to schedule estimated level alerts."
                return
            }
            guard !selected.kinds.isEmpty else {
                _ = try await scheduler.replace(events: [])
                guard isCurrent() else { return }
                scheduledCount = 0
                return
            }
            let points: [EstradiolPK.PredictionPoint]
            do {
                points = try await calculator.predict(regimen: regimen, now: now,
                    calibrationResult: input.calibrationResult, alignSamplesToHour: true, horizon: .notifications)
            } catch LevelsPredictionError.invalidCalibration {
                points = try await calculator.predict(regimen: regimen, now: now, calibrationResult: nil, alignSamplesToHour: true, horizon: .notifications)
            }
            guard isCurrent() else { return }
            let events = LevelEventDetector().events(in: points, kinds: selected.kinds, after: now)
            let count = try await scheduler.replace(events: events)
            guard isCurrent() else { return }
            scheduledCount = count
            if events.isEmpty {
                message = "No selected turning points are predicted in the next \(LevelsPredictionHorizon.notifications.futureDays) days."
            } else if count < events.count {
                message = "The nearest \(count) alerts are scheduled. Open fembie regularly to schedule later events."
            }
        } catch {
            guard isCurrent() else { return }
            _ = try? await scheduler.replace(events: [])
            guard isCurrent() else { return }
            scheduledCount = 0
            message = "Could not schedule notifications: \(error.localizedDescription)"
        }
    }
}
