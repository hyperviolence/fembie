# fembie architecture

fembie is a local-first SwiftUI app for iPhone and iPad, targeting iOS 26.5.
It has five tabs: Levels, Wellbeing, Labs, Regimen, and Settings.

## Structure

- `Features`: screens and their view models.
- `Domain`: regimen, injection, check-in, and lab-result types.
- `Persistence`: the `TrackingRepository` interface and JSON storage.
- `Services`: injection scheduling and a reminder interface.
- `Packages/EstradiolPK`: pure Swift prediction models.

The app creates one repository and shares it across the regimen, wellbeing,
and lab-result view models. Views receive these models through the environment.
View models use `@MainActor @Observable`; storage and prediction run in actors.

## Storage

`FileTrackingRepository` reads and writes JSON in `Application Support/Tracking`.
Writes are atomic, and loaded records are cached in memory.

- `regimens.json`: the current regimen and its injection events.
- `checkIns.json`: mood, libido, and energy ratings.
- `labResults.json`: saved blood-test results.
- `injectionEvents.json`: a separate event API; prediction uses the events inside
  the saved regimen instead.

Saving a new regimen replaces the previous one. Predictions stay in memory.
Calibration and notification preferences are saved in `UserDefaults`.

## Scheduling and predictions

`InjectionSchedule` spaces injections by elapsed hours and preserves corrections.
Untouched past injections are assumed taken; skipped events are excluded, and
moved events use their actual timestamps. Future injections remain projections.

Levels sends the saved regimen to `LevelsPredictionCalculator`, which selects
an EEn intramuscular or subcutaneous model from `EstradiolPK`. Unsupported
esters or routes show an unavailable state.

The calculator samples hourly across 14 days before and after now. Levels
shows concentration and rate of change, refreshing every minute while active.
A bottom button opens model details, the source link, and MIT attribution.
Input changes restart the task; cancellation and request revisions prevent
stale results from replacing newer ones.

Optional calibration uses the latest saved E2 result in pg/mL, dated within
the current regimen and no later than now. It shifts the whole curve by the
measurement offset and clamps negative levels to zero. Invalid calibration
falls back to the unadjusted model with an explanation.

## Wellbeing and labs

Wellbeing saves dated 0–10 mood, libido, and energy ratings and charts daily
averages. Levels can overlay those averages on its own independent 0–10 scale.
Labs supports adding, listing, and deleting results, plus the calibration toggle.

Settings contains the project description in About fembie and a Safety notice
explaining model limitations, intended use, and liability terms.

## Models and limits

The models are native Swift ports of Estrannaise. The subcutaneous model uses
the IM parameters with a 10% reduction in the absorption rate (`k1`); this is
a modeling assumption. Details and MIT attribution are in `Packages/EstradiolPK`.

Level alerts use local iOS notifications for selected E2 and signed rate-of-change
turning points. The app forecasts up to 90 days while active, updates
alerts after input changes, and cancels disabled alerts. Pending alerts can fire
while the app is closed; later events require reopening it. The scheduler keeps
the nearest alerts within the system's pending-notification budget.

There is no cloud sync, regimen-version history, or legacy-data migration.
Check-in reminders have an interface only. Predictions are estimates, not
blood-test measurements.

## Tests

App tests cover scheduling, storage, calibration, chart scaling, and level alerts.
Package tests check numerical predictions and rates against reference values.
See [README](../README.md) for build and test commands.
