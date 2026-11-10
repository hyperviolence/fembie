# fembie architecture

fembie is a local-first SwiftUI app for iPhone and iPad, targeting iOS 26.5.
It has five tabs: Levels, Wellbeing, Labs, Regimen, and Settings.

## Structure

- `Features`: screens and their view models.
- `Domain`: regimen, injection, check-in, and lab-result types.
- `Persistence`: the `TrackingRepository` interface and JSON storage.
- `Services`: injection scheduling and local notifications.
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
moved events use their actual timestamps. Marking a future injection taken
records the current time as an override; past moved injections appear confirmed.
Recurrence dates remain fixed. Loading repairs recognizable entries from the
earlier edit that overwrote those dates. Future injections remain projections.

Levels sends the saved regimen to `LevelsPredictionCalculator`, which selects
an EEn intramuscular/subcutaneous model or the generic transdermal gel model
from `EstradiolPK`. Unsupported formulations or routes show an unavailable state.
Gel requires only the mg of estradiol in each application. Existing persisted
`doseMilligramsOfEster` and injection-event field names are retained for storage
compatibility; for gel their dose is active estradiol applied, not gel weight.

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
averages. Levels overlays individual check-ins at their recorded timestamps on
its own independent 0–10 scale.
Labs supports adding, listing, and deleting results, plus the calibration toggle.

Settings contains the project description in About fembie and a Safety notice
explaining model limitations, intended use, and liability terms. Confirmed reset
actions delete regimen/injection data or wellbeing check-ins; regimen reset
also cancels its level alerts. Labs and notification preferences are retained.

## Models and limits

The enanthate models are native Swift ports/adaptations of Estrannaise. The subcutaneous model uses
the IM parameters with a 10% reduction in the absorption rate (`k1`); this is
a modeling assumption. Details and MIT attribution are in `Packages/EstradiolPK`.

The generic gel approximation equally combines two label-anchored Bateman
responses using EstroGel and Divigel exposure and apparent terminal rates.
It has no brand selector. It is not clinically validated and does not estimate
individual absorption or uncertainty. Full construction and limits are recorded
in `Packages/EstradiolPK/Evidence/TransdermalGel.md`. Model information shows
the label sources for gel and retains Estrannaise attribution for enanthate.

Level alerts use local iOS notifications for selected E2 and signed rate-of-change
turning points. The app forecasts up to 90 days while active, updates
alerts after input changes, and cancels disabled alerts. Pending alerts can fire
while the app is closed; later events require reopening it. The scheduler keeps
the nearest alerts within the system's pending-notification budget, reserving
one slot for a daily check-in reminder.

Regimen reminders use a chosen advance time: 30 minutes, 1 hour, 3 hours, or
1 day. They follow scheduled or moved future injections, exclude skipped/taken
ones, and refresh on changes and app activity. Up to 32 upcoming reminders
share the notification budget with level alerts and the daily check-in reminder;
a common coordinator serializes all updates.

## Optional iCloud sync

Settings contains an iCloud Sync toggle, disabled by default on each device.
When enabled, the app exchanges a versioned JSON snapshot through a CKAsset in
the user's private CloudKit database. The container is
`iCloud.com.hyperviolet.fembie`; the record type is `FembieSnapshot`, its
`snapshot` field is an Asset, and the fixed record name is `fembie-sync-v1`.
There is no public database or sharing.

Sync includes every stored regimen (with nested dose events), separate injection
events, check-ins, labs, calibration, and the three reminder preference groups.
The existing JSON export format remains unchanged. Notification authorization
and the iCloud opt-in remain device-specific.

Sync runs on activation and every 30 seconds while active, and Settings offers
Sync Now. It does not run in the background. Offline changes remain in local
JSON files and are retried on activation or the next scheduled/manual attempt.
Disabling sync retains both local and cloud data.

A persisted baseline supports a three-way merge by record ID, including
deletions. Independent record edits combine; concurrent changes to the same
record prefer the version already in iCloud. A regimen and its nested events
are one record. CloudKit conditional saves retry server-record conflicts.
Edits made locally during a network request are preserved for the next sync.
A local recovery journal is written before applying downloads. Incoming data
is validated before replacing local stores. The checkpoint binds sync to the
original iCloud account; account changes pause sync rather than uploading data
to the replacement account. A missing established cloud snapshot is treated as
an error rather than a request to delete local records.

### CloudKit release setup and verification

The app target includes CloudKit entitlements for both build configurations.
The signing team must register/associate the container with the app identifier.
Before distributing a production build, create the `FembieSnapshot` record type
with the `snapshot` Asset field in the development environment (a development
sync can create it), then deploy that schema to production in CloudKit Console.
No query indexes are required because the record is fetched by its fixed ID.

Verify on two signed-in devices using the same iCloud account: opt in on each,
add different records offline, reopen both apps, and confirm convergence.
Also verify deletions, reminder preferences, sign-out/account change, disabling
during a request, and offline retries. Simulator unit tests use an injected
transport and cannot verify Apple's provisioning or live CloudKit service.

There is no regimen-version history or legacy-data migration.
Wellbeing can schedule a repeating daily check-in reminder at a chosen local
time. Turning it off cancels the reminder. Predictions are estimates, not
blood-test measurements.

## Tests

App tests cover scheduling, storage, calibration, chart scaling, and level alerts.
Package tests check numerical predictions and rates against reference values.
See [README](../README.md) for build and test commands.
