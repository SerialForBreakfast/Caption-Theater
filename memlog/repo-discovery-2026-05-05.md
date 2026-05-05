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

## 2026-05-05 Fixture Update

- Added decision scenario fixtures under `CaptionTheater/CaptionTheaterTests/Fixtures/DecisionScenarios`.
- Added fixture documentation with expected outcomes for eligible, native fallback, and uncertain decisions.
- Added a fixture-driven unit test that loads the JSON scenario matrix from the test bundle.
- Made decision snapshot and evidence value types `Codable` so sanitized fixtures can exercise the engine without playback dependencies.
- Verified the full `CaptionTheater` scheme again, then removed repo-local build artifacts.

## 2026-05-05 HLS Manifest Update

- Added `HLSManifestInspector`, a stateless nonisolated parser for sanitized in-memory HLS manifest text.
- Added models for variant streams, media renditions, declared subtitle transports, date-range metadata, discontinuities, and encryption signals.
- Added sanitized HLS manifest fixtures for sidecar subtitles, embedded closed captions, ad date ranges, discontinuities, encryption markers, and no-subtitle control cases.
- Added unit tests that load HLS fixtures from the test bundle and verify extracted metadata facts.
- Verified the full `CaptionTheater` scheme, then removed repo-local build artifacts.

## 2026-05-05 Provider Metadata Update

- Added `ProviderMetadataInspector`, a stateless nonisolated decoder/evaluator for sanitized provider-side QC metadata.
- Added a local JSON schema for policy, trusted source/confidence, active-picture rect, safe caption regions, allowed layouts, warnings, and timeline segments.
- Added provider metadata fixtures for trusted eligibility, blocklisted burned-in subtitle risk, native-only timeline segments, and incomplete metadata.
- Added tests showing trusted provider metadata can authorize a protected-content decision path, missing/incomplete metadata fails closed, and blocklist metadata forces native presentation.
- Updated `TASKS.md` to reflect the decision-engine approach, completed HLS manifest foundation, and completed provider metadata stub foundation.
- Verified the full `CaptionTheater` scheme, then removed repo-local build artifacts.

## 2026-05-05 Subtitle Classification Update

- Added `SubtitleMetadataClassifier`, a stateless nonisolated classifier for sanitized selected subtitle-track metadata.
- Added fixtures for sidecar WebVTT dialogue, sidecar WebVTT SDH, forced WebVTT, embedded CEA-608 captions, image-based subtitles, burned-in subtitles, missing selected tracks, and unknown subtitle formats.
- Added tests for persistent cue eligibility, authored-timing-only WebVTT, native-only embedded captions, image-based subtitles, burned-in subtitles, missing tracks, and unknown formats.
- Updated `TASKS.md` to mark CT-0203 foundation work complete and separate CT-0204 DRM feasibility as future work.
- Verified the full `CaptionTheater` scheme, then removed repo-local build artifacts.
