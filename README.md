# FemmeTrack

Initial SwiftUI iOS skeleton for a local-first estradiol tracking app.
Open `FemmeTrack.xcodeproj` in Xcode. The existing deployment target is preserved.
The app links the local `Packages/EstradiolPK` Swift package; no external dependencies.

## Structure

- `FemmeTrack/Features`: Levels, Wellbeing and Regimen tabs.
- `FemmeTrack/Domain`: regimen history, injection overrides and quick check-ins.
- `FemmeTrack/Services`: scheduling and local notification contracts.
- `FemmeTrack/Persistence`: local repository contract.
- `Packages/EstradiolPK`: UI-independent model inputs and outputs; enanthate intramuscular and subcutaneous prediction models.
- `Docs/Architecture.md`: behavior and implementation boundaries.

## Current status

Navigation and draft controls only. Nothing is saved; buttons are disabled.
No hormone curves, scheduling, notifications, calibration or clinical scoring
are implemented. Slider values are preview state, not recorded answers.
No application tests have been added; existing Xcode template tests are retained.
MADRS-S is reserved for a later optional feature.
