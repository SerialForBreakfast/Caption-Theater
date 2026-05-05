# Repo Discovery - 2026-05-05

## Current State

- Caption Theater is a new tvOS Xcode project with generated SwiftUI app, unit test, and UI test targets.
- Product intent and implementation sequencing are documented in `README.md`, `TASKS.md`, `Caption-Theater-POC-Roadmap.md`, `Caption-Theater-Showcase-and-Execution-Plan.md`, `Caption-Theater-Metadata-Feasibility-Deep-Dive.md`, and `ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md`.
- The Swift implementation is still template-level: `CaptionTheaterApp`, `ContentView`, and empty generated tests.

## Constraints To Preserve

- Persist already-presented cues only; do not preview future cues by default.
- Preserve video geometry and fail closed when eligibility is uncertain.
- Keep ads, promos, legal overlays, DRM uncertainty, unsupported subtitles, and variable aspect ratio as native-playback fallback cases.
- Build pure, testable modules before platform playback integration.
- Keep generated fixtures and scripts project-local.

## Suggested Next Focus

- Reconcile the docs' iOS-first POC language with the current tvOS-only Xcode project.
- Start with fixture inventory and a stateless decision engine before AVPlayer work.
- Add meaningful tests with deterministic fixture data as each core model is introduced.

## 2026-05-05 Implementation Update

- Added a framework-free `CaptionTheaterDecisionEngine` that evaluates a point-in-time eligibility snapshot.
- Added `Sendable` domain models for decisions, evidence, ad state, subtitle state, viewport state, and protected-content policy.
- Replaced the generated empty unit test with decision-engine tests for eligible, user-disabled, ad, unknown-ad, unsupported-subtitle, unsafe-viewport, and DRM-uncertainty cases.
- Verified the full `CaptionTheater` scheme with repo-local derived data, then removed the generated build artifacts.
