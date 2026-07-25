# Testing and continuous integration

OpenChord uses a layered test suite. Tests should live at the lowest level that
can prove the behaviour while still covering integration boundaries where they
matter.

## Test targets

### OpenChordTests

The unit-test bundle imports the application module with `@testable`. It covers
domain formatting and playback state without launching the UI.

`PlaybackController` receives a `PlaybackEngine`, so queue policy can be tested
without a media framework. Production uses `AVPlayerPlaybackEngine` and bundled
demo media. Integration tests verify media resolution, item creation, seeking
and completion events. Lower-level timing tests use `SimulatedPlaybackEngine`
with a `ManualPlaybackClock`, so they never wait for real time.

### OpenChordUITests

The UI-test bundle launches the application as a separate process. Its first
smoke test verifies that the primary navigation is present. Future critical
journeys should be added here, while detailed state combinations belong in unit
or snapshot tests.

## Running checks locally

List available simulator devices:

```shell
xcrun simctl list devices available
```

Run all tests using an installed simulator:

```shell
xcodebuild test \
  -project OpenChord.xcodeproj \
  -scheme OpenChord \
  -destination 'platform=iOS Simulator,name=iPhone 17,OS=latest'
```

Check formatting:

```shell
xcrun swift-format lint \
  --recursive \
  --strict \
  --configuration .swift-format \
  OpenChord OpenChordTests OpenChordUITests
```

## GitHub Actions

`.github/workflows/ci.yml` runs on pull requests targeting `main`, pushes to
`main` and manual dispatches. It exposes separate checks for:

- formatting;
- Xcode static analysis;
- application build;
- unit tests;
- UI tests.

Failed test jobs upload their `.xcresult` bundles as workflow artifacts. These
bundles can be opened in Xcode to inspect failures, logs, screenshots and
attachments.

The workflow intentionally has read-only repository permissions and does not
use signing credentials. TestFlight delivery will be introduced separately
after signing is configured through a protected GitHub environment.
