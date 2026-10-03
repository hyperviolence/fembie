# fembie architecture

Version: v0.1 MVP. This document distinguishes implemented behavior from planned
features. The app is a local-first SwiftUI estradiol tracking app with three
tabs: Levels, Wellbeing, and Regimen.

## Project structure and boundaries

- `fembie/Features/Levels`: prediction orchestration, observable chart state,
  Swift Charts, and model attribution.
- `fembie/Features/Regimen`: regimen entry, validation, saved schedule, and
  injection corrections.
- `fembie/Features/Wellbeing`: check-in interface preview.
- `fembie/Domain`: Codable, Sendable regimen, injection, and check-in values.
- `fembie/Persistence`: asynchronous repository boundary and local JSON storage.
- `fembie/Services`: elapsed-time scheduling and future reminder contracts.
- `Packages/EstradiolPK`: UI-independent native Swift prediction models and tests.
- `fembieTests`: application logic and persistence tests.

The project and GitHub repository are named `fembie`; the local package remains
`EstradiolPK`. Some source types and filenames retain the earlier FemmeTrack name.
The app currently targets iOS 26.5, with Main Actor default isolation. Shared UI
state uses `@MainActor @Observable` classes. Persistence and prediction work use
actors and async/await. No third-party runtime frameworks are introduced.

## Current application flow

The Regimen tab saves the ester, route, dose in milligrams of ester, interval,
and first scheduled injection. Saving creates the schedule; Levels consumes the
saved regimen, rather than unsaved form selections. Users can confirm, skip,
move, or reset individual injections from the saved schedule.

Levels loads the shared regimen when needed and selects its model automatically
from the saved ester and route. There is no model-selection toggle. A missing
regimen, unsupported combination, or calculation failure produces an explanatory
unavailable state instead of a fabricated curve.

A dedicated initial-setup flow, question selection, and reminder configuration
remain planned.

## Stored data

`FileTrackingRepository` is the actor-backed implementation of
`TrackingRepository`. It serializes reads and atomic JSON writes under
`Application Support/Tracking`, and caches decoded values in memory:

| Store | Current responsibility |
| --- | --- |
| `regimens.json` | The saved regimen, including its injection events and corrections |
| `injectionEvents.json` | Separate event-storage API; not consumed by the current plotting flow |
| `checkIns.json` | Check-in storage API; not yet connected to the Wellbeing screen |

For the current Regimen and Levels features, events embedded in the saved
regimen are authoritative. Plotting must not combine them with the separate
event store and count a dose twice.

A `Regimen` records a UUID, ester, route, dose, elapsed interval in hours,
effective dates, schedule timezone, and injection events. Each `InjectionEvent`
has its own UUID, regimen ID, original scheduled instant, dose, and reversible
adjustment: none, confirmed, skipped, or moved to a corrected instant.

The repository currently replaces the entire saved regimen when a new regimen
is saved. It does not yet preserve a timeline of earlier regimen versions.
History-preserving regimen changes remain a required future improvement.
Likewise, older JSON records lacking the newly required route field have no
implemented migration; a route must not be silently inferred for prediction.

Persist inputs, not chart points or a periodically updated current E2 value.
Model parameters are bundled in Swift; prediction results live in memory and
are recalculated. Model selection follows the saved regimen. SwiftData, CloudKit,
and persistent prediction caches are not part of this MVP.

## Scheduling and injection rules

`InjectionSchedule` uses elapsed-time recurrence, not calendar-day recurrence.
The interval is converted from hours to seconds; the stored timezone does not
change the elapsed spacing. Effective end dates are exclusive. Extending a
schedule preserves existing IDs and corrections and enforces a 10,000-event
limit before generating an excessive schedule.

- Untouched past injections are assumed taken at their scheduled times.
- Confirmed injections contribute at their scheduled times.
- Skipped injections contribute no dose.
- Moved injections contribute at their corrected timestamps, preserving their
  original scheduled origins and leaving subsequent events unchanged.
- An administration with an effective timestamp in the future cannot contribute
  to a current or earlier estimate.
- Future scheduled events are projections, not evidence of administration.
  Future scheduled injections cannot be confirmed as already taken.

The regimen feature initially generates through approximately one year beyond
now or the first injection, whichever is later. Plotting can extend its input
schedule in memory through its own horizon without persisting that extension.
`ScheduleResolving` is an existing contract, but the MVP resolves effective doses
directly inside `LevelsPredictionCalculator`; it is not a second implemented
resolver.

## Prediction pipeline

```text
FileTrackingRepository
  -> RegimenViewModel.savedRegimen
  -> LevelsPredictionInput
  -> LevelsPredictionCalculator actor
  -> EstradiolPK PredictionModel
  -> LevelsViewModel
  -> LevelsView / LevelsChart
```

`LevelsPredictionInput` defines the refresh identity using the saved regimen's
ester, route, dose, interval, effective dates, event identities, doses,
corrections, and application active state. Changing these inputs restarts the
prediction task. While active, the task refreshes every 60 seconds. Cancellation
and request revisions prevent stale results from replacing newer chart state.

`LevelsPredictionCalculator` selects the model, extends the schedule as needed,
resolves effective administrations, and requests hourly samples spanning 14 days
before and 14 days after now: 673 points with now exactly on the grid. It includes
preceding administrations available in the saved schedule, even when they fall
outside the displayed window.

The current estimate is the prediction at now. Future predictions use the same
response calculation and include planned doses only after their effective
timestamps. Solid and dashed lines distinguish historical estimates and future
projections, with a rule marking now. Levels displays both E2 and dE2/dt.

## EEn intramuscular and subcutaneous models

Levels selects `EnanthateIntramuscularModel` for saved estradiol enanthate with
the intramuscular route, and `EnanthateSubcutaneousModel` for the subcutaneous
route. Unsupported esters or routes do not fall back to either model.

The subcutaneous model copies the IM calculation with `k1 = 0.119 * 0.9 = 0.1071`
per day; `d`, `k2`, and `k3` retain the IM values. Its identifier is
`fembie/enanthate-subcutaneous/im-k1-90-percent/v1`. The 10% reduction is a
requested modeling assumption, not an independently fitted SC parameter set.
See `Packages/EstradiolPK/Evidence/EnanthateSubcutaneous.md` for details.

The numerical implementation is a native Swift port of the single-dose
three-compartment response and EEn IM coefficients supplied in Estrannaise's
`models.js` and `modeldata.js`:

- Identifier: `estrannaise/enanthate-intramuscular/v1`.
- Parameters `[d, k1, k2, k3]`: `[191.4, 0.119, 0.601, 0.402]`.
- Input dose: milligrams of estradiol ester.
- Internal elapsed time: days; rate constants: inverse days.
- Output concentration: pg/mL.
- Rate of change: analytic derivative, converted from pg/mL/day to pg/mL/hour.

At each requested timestamp, the engine sums the individual dose responses.
It validates inputs, returns zero contribution before or exactly at an
administration, handles negligible negative roundoff in the response, and rejects
nonfinite results. Parameters are fixed and distinct; the MVP does not expose a
general arbitrary-parameter model or implement general equal-rate limits.

There is no JavaScript runtime dependency. Levels links to
[Estrannaise](https://estrannai.se/) and displays its MIT notice, copyright
(c) 2025 alix. The package also preserves the license in
`Packages/EstradiolPK/LICENSE-Estrannaise.txt`. Ported equations and data retain
attribution to the [upstream project](https://github.com/WHSAH/estrannaise.js).

These are modeled estimates, not blood test measurements or individualized
clinical predictions. The MVP has no endogenous baseline estimate, calibration,
uncertainty bands, or assumed steady state. Missing pre-app doses are not
invented; the screen explains that estimates include recorded history only.

## Wellbeing and reminders

The intended check-in records three independent 0–10 ratings: mood, libido, and
energy, timestamped with now as the default. Saving should require deliberate
answers, and recorded check-ins should eventually align with modeled E2 and its
rate of change.

Currently, Wellbeing is an interface preview with sliders initialized to 5 and a
disabled save button. Those values are not recorded answers. The domain and
repository support check-ins, but the screen does not save them or overlay them
on the level charts.

Local reminders are planned as explicit opt-in with neutral lock-screen text.
`CheckInReminderScheduling` is a contract only; notification authorization and
scheduling are not implemented. MADRS-S remains a separate later feature requiring
wording, rights, recall-period, and support-flow review.

## Verification and next steps

Package tests compare native Swift outputs with saved JavaScript single-dose and
repeated-dose fixtures, verify the analytic derivative against finite differences,
and exercise future doses, empty history, and invalid inputs. App tests cover
scheduling, persistence, skipped and moved injections, automatic selection by
saved ester and route, and plot refresh identity. Numerical agreement verifies
the port; it does not constitute clinical validation.

The plotting MVP and automatic selection passed builds and unit tests before the
project rename. Visual verification of the chart layout remains incomplete;
post-rename verification should be performed against `fembie.xcodeproj`.

Deferred work includes:

- Preserving administration history across regimen changes and defining storage
  migrations, including records without a route.
- Recording sufficient pre-app history without silently assuming steady state.
- Connecting check-in persistence, wellbeing overlays, and local reminders.
- Other supported formulations/routes, blood tests, and calibration.
- Parameter-uncertainty bands. If added, retain complete parameter tuples and
  use consistent samples across each trajectory; distinguish parameter
  uncertainty from variability between individuals.
- Explicit steady-state comparison scenarios and additional display units.

Keep future changes scoped to the feature being requested. Additional model
registries, generalized response engines, or persistent caches should be added
only when a concrete supported use case requires them.
