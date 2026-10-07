# fembie

An open-source iPhone and iPad health app for the transfemme community.
fembie helps you track your estradiol regimen, estimated levels, wellbeing,
and lab results. The official app's core health features are free to use.

## Download

You can find fembie on the [App Store](https://apps.apple.com/search?term=fembie).
This link opens App Store search; a direct listing link will replace it when
available. Availability depends on release status and your region.

## Features

- Save a regimen and track scheduled, confirmed, skipped, or moved injections.
- Plot estimated estradiol levels and their rate of change, with supported
  estradiol enanthate intramuscular and subcutaneous models.
- Record mood, libido, and energy check-ins and overlay each check-in at its recorded time on the
  level charts.
- Save lab results and optionally calibrate estimates using an E2 result.
- Receive injection reminders 30 minutes, 1 hour, 3 hours, or 1 day in advance.
- Set an optional daily check-in reminder in Wellbeing.
- Receive optional notifications for estimated E2 peaks, lows, and rate-of-change
  turning points, forecast up to 90 days ahead. The nearest alerts are queued;
  open the app regularly to refresh them.
- Store tracking data locally on your device.

Level predictions are mathematical estimates, not blood test measurements.

## Requirements

- A Mac with Xcode 26.6 or later and its iOS SDK and simulator runtime.
- iOS or iPadOS 26.5 or later on a device or simulator.

The app uses Swift 6 language mode and the local `EstradiolPK` Swift package.
No external package dependencies or API keys are required.

## Run from source

```sh
git clone https://github.com/hyperviolence/fembie.git
cd fembie
open fembie.xcodeproj
```

1. Select the **fembie** scheme in Xcode.
2. Choose an iPhone or iPad simulator running iOS 26.5 or later.
3. Choose **Product → Run** (⌘R).

To run on a physical device, select your own development team under the app
target's **Signing & Capabilities** settings. Use a bundle identifier you can
sign, select your connected device, and run the app.

## Build and test

Build for the simulator without device signing:

```sh
xcodebuild build \
  -project fembie.xcodeproj \
  -scheme fembie \
  -destination 'generic/platform=iOS Simulator' \
  CODE_SIGNING_ALLOWED=NO
```

Run the app's unit tests on an installed simulator. Replace the example device
name if needed; `xcrun simctl list devices available` lists available devices.

```sh
xcodebuild test \
  -project fembie.xcodeproj \
  -scheme fembie \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  -only-testing:fembieTests
```

Run the prediction package's tests independently:

```sh
cd Packages/EstradiolPK
swift test
```

For a device Release build or App Store archive, configure signing in Xcode,
select **Any iOS Device (arm64)**, and choose **Product → Archive**. Distribute
through the Organizer using your own Apple Developer account and App Store
Connect app record.

## Project structure

- `fembie/Features`: Levels, Regimen, Wellbeing, Labs, and Settings screens and logic.
- `fembie/Domain`: regimen, injection, check-in, and lab-result data types.
- `fembie/Persistence`: local storage and repository interfaces.
- `fembie/Services`: injection scheduling and local notifications.
- `Packages/EstradiolPK`: prediction models and their numerical tests.
- `fembieTests`: application logic, persistence, and chart regression tests.

## License and community access

fembie is licensed under **GNU GPL v3 only**, with an additional permission for
Apple App Store distribution. See [LICENSE](LICENSE) for the complete terms.
Distributed derivatives must remain under GPL v3 and provide their corresponding
source to recipients. Private modifications and independent applications are
not automatically subject to that requirement.

The official app's core health features are free to use. This is our community
access commitment, separate from the license: GPL permits others to charge for
redistribution while preserving recipients' rights to use, modify, and share
the software.

Contributions to fembie's own code are intended to use the same GPL v3 license
and App Store permission. Retain existing copyright and third-party notices.

The estradiol prediction models are native Swift ports of
[Estrannaise](https://github.com/WHSAH/estrannaise.js). The original model code
and parameters are MIT licensed, Copyright © 2025 alix. Their license remains in
[LICENSE-Estrannaise.txt](Packages/EstradiolPK/LICENSE-Estrannaise.txt) and must
be preserved in source and compiled distributions.
