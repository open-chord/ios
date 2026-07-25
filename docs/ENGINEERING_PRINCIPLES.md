# Engineering principles

OpenChord should feel like an adult product from its first public version. This
does not mean implementing every possible feature immediately. It means that
every feature we do implement is intentionally designed, maintainable and
verified.

## Beautiful outside

The interface is part of the product, not decoration added after development.
Screens should remain correct with long titles, missing artwork, unavailable
lyrics, slow networking, different device sizes and accessibility settings.

Visual quality includes:

- a coherent design system for spacing, colour, typography and motion;
- predictable navigation and controls that follow Apple conventions;
- polished transitions without sacrificing responsiveness;
- empty, loading, error and offline states;
- Dynamic Type, VoiceOver, contrast and reduced-motion support.

## Beautiful inside

The codebase should teach good Swift and Apple-platform engineering practices.
Feature boundaries, dependency ownership and state flow should be visible from
the project structure. External systems such as AVPlayer, GraphQL, storage and
time must sit behind explicit contracts so they can be replaced and tested.

We optimise for clarity first. Abstractions are introduced when they establish a
real boundary or remove proven duplication, not merely to imitate a large
company architecture.

## Confidence through automation

OpenChord will maintain a layered automated test suite:

1. Unit tests for models, formatting, queues, lyrics timing and playback state.
2. Integration tests for persistence, GraphQL mapping and media services.
3. Snapshot tests for stable reusable components and key screen states.
4. UI tests for critical journeys such as selecting an album, starting playback
   and navigating synchronized lyrics.
5. Accessibility and performance checks for flows where regressions would
   materially affect users.

GitHub Actions will build and test every pull request. Later, the same automation
will create signed release builds and deliver approved versions to TestFlight.
Secrets and signing material will live only in protected GitHub environments.

## Current state

The repository currently contains the SwiftUI prototype. The complete test
matrix and GitHub Actions pipelines described above are requirements for the
next engineering phase; they are not yet implemented.

