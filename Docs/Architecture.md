FemmeTrack
Version: v0.1

# Architecture

Tabs: E2 levels (E2 graph, dE2/dt graph, wellbeing graph mapped onto these level graphs), Wellbeing check-in (questions that user gets every day via push notification), regimen specifications (correct all the data set during initial setup phase, mark past and dosages either as taken (just confirm since it's the default), forgotten or delayed (enter time when the dosage will be/was taken))

Flow: initial setup (enter regimen - esther, route, dosage intake frequency; how many questions do you need in a daily check-in: mark questions with checkboxes, when to send push notifications) -> first tab 


## Event rules

Untouched past injections are assumed taken at the scheduled time. Future events
are projections, not past administrations. Skipped events contribute no dose.
Moved events contribute at the corrected timestamp, preserving the scheduled
origin and leaving subsequent events unchanged. A future correction cannot
contribute to a current estimate. Regimen changes affect future schedules while
preserving history. Use stable IDs and reversible overrides.

Choose elapsed intervals versus calendar recurrence explicitly. Store instants
and the schedule timezone. Collect enough pre-app dose history rather than
silently assuming steady state.

## Wellbeing

Three independent 0–10 ratings: mood, libido, energy. Require deliberate answers
before saving, timestamp them (default=now), and align with modeled E2 and rate of change.
Local reminders are opt-in with neutral lock-screen text. MADRS-S is a later,
separate feature requiring wording, rights, recall-period and support-flow review.

## Notes

Blood tests, calibration, other formulations/routes and MADRS-S are outside v0.1.
Do not display fabricated curves or numerical certainty while research is pending.
