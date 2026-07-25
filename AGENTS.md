# OpenChord development rules

These rules apply to the entire repository and must be considered before every
code or design change.

## Product quality

OpenChord is built as a production-quality application from the beginning, not
as a disposable prototype.

- The product must be polished both externally and internally.
- UI work must consider layout, typography, animation, loading, empty, error,
  offline and accessibility states.
- Architecture and naming must remain understandable to a developer learning
  the codebase for the first time.
- Prefer native Apple platform conventions unless a deliberate product decision
  calls for custom behaviour.
- Avoid shortcuts that make the current screenshot look correct while leaving
  the component fragile at other screen sizes or with real data.
- Comments should explain decisions, contracts and non-obvious trade-offs.
  Comments that merely restate the code should not be added.

## Verification

Every behaviour should be verified at the lowest useful level, with additional
coverage where integration risk exists.

- Domain and state-management logic: unit tests.
- Data sources, persistence and API contracts: integration tests.
- Critical user journeys: XCUITest UI tests.
- Reusable visual components and important screens: snapshot tests.
- Accessibility identifiers and accessibility behaviour are part of the public
  UI contract and should be tested.
- Bugs should receive a regression test whenever the failure can be reproduced
  deterministically.
- A change is not complete while relevant tests or the application build fail.

Testability is an architectural requirement. Time, networking, storage, media
playback and other external effects must be represented by replaceable
interfaces rather than hidden global state.

## CI/CD

GitHub Actions is the canonical automation platform for this repository.

- Pull requests must build the application and run the automated test suite.
- CI should report formatting, static-analysis, build and test failures as
  separate, readable checks.
- Workflows must be reproducible locally where practical.
- The default branch should be protected once required checks are available.
- Release automation must not contain signing certificates, tokens or other
  secrets in the repository.
- CD should produce versioned artifacts first; TestFlight deployment should be
  enabled only after Apple signing and App Store Connect credentials are
  configured safely through GitHub secrets.

Do not claim that a quality gate exists until its workflow and tests are
committed and have run successfully.

## Definition of done

A task is complete when:

1. The implementation matches the intended product experience.
2. Relevant automated tests have been added or updated.
3. The app builds and all relevant tests pass locally.
4. CI configuration remains valid.
5. Documentation is updated when contracts or developer workflows change.

