# Architecture and next steps

Flow: regimen history + injection corrections -> schedule resolver -> effective
dose events -> EstradiolPK -> E2 and dE2/dt graphs. Check-ins join that timeline
by timestamp; they never modify the pharmacokinetic model.

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
before saving, timestamp them, and align with modeled E2 and rate of change.
Local reminders are opt-in with neutral lock-screen text. MADRS-S is a later,
separate feature requiring wording, rights, recall-period and support-flow review.

## Implementation order

1. Evidence dossier and versioned enanthate/subcutaneous model specification.
2. Schedule resolution and local persistence with historical regimen versions.
3. Model implementation and reference-data validation.
4. Graphs, event editing, deliberate check-in input and storage.
5. Opt-in local notification settings.

Blood tests, calibration, other formulations/routes and MADRS-S are outside v1.
Do not display fabricated curves or numerical certainty while research is pending.
