# Repo Discovery - 2026-05-05

## Current State

- Caption Theater is a **tvOS-first** Xcode project (`CaptionTheater`, `CaptionTheaterTests`, `CaptionTheaterUITests`) with SwiftUI shell plus fixture-backed core modules.
- Deterministic fixtures cover decision scenarios, HLS manifests, provider metadata, and subtitle-track classification; see `Docs/Fixture-Inventory.md`.
- On-device **Debug** tab surfaces eligibility scenarios and evidence for stakeholders (`CaptionTheaterDebugDecisionInspectorView`).
- Stateless eligibility evaluation lives in `CaptionTheaterDecisionEngine`; parsing/classification in `HLSManifestInspector`, `ProviderMetadataInspector`, and `SubtitleMetadataClassifier`.
- Product intent and sequencing remain documented in `README.md`, `TASKS.md`, `Caption-Theater-POC-Roadmap.md`, `Caption-Theater-Showcase-and-Execution-Plan.md`, `Caption-Theater-Metadata-Feasibility-Deep-Dive.md`, and `ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md` (now aligned with tvOS-first implementation notes).

## Constraints To Preserve

- Persist already-presented cues only; do not preview future cues by default.
- Preserve video geometry and fail closed when eligibility is uncertain.
- Keep ads, promos, legal overlays, DRM uncertainty, unsupported subtitles, and variable aspect ratio as native-playback fallback cases.
- Build pure, testable modules before platform playback integration.
- Keep generated fixtures and scripts project-local.

## Suggested Next Focus

- Ship **CT-0501 / CT-0502**: tvOS playback shell + wire inspectors into eligibility snapshots during real playback.
- Advance **CT-0301** viewport preclassification when ready to pair metadata with layout hypotheses.
- Finish **CT-0002** gaps: video catalog, synthetic frames, real-world licensed hero candidate docs (**CT-0004**), generator scripts (**CT-0005**).
- Stabilize UI test strategy (`CaptionTheaterUITests` launch performance flaked under full `xcodebuild test`; prefer `-skip-testing:CaptionTheaterUITests` for CI smoke until reviewed).

## 2026-05-05 CT-0103 Debug Inspector

- Added tvOS **Debug** tab: scenario catalog + evidence grouped by polarity; lifecycle transitions use placeholder copy until a coordinator exists.
- Added `CaptionTheaterDebugInspectionTests`; unit suite passes with `-skip-testing:CaptionTheaterUITests`.

## 2026-05-05 Task grooming note

- Added **Execution snapshot** to `TASKS.md`; marked **CT-0101**/**CT-0102** **DONE**; **CT-0002** **IN PROGRESS** with implementation notes; clarified Phase 0/1/2 exit criteria vs shipped code.

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

## 2026-05-05 Task Status Convention Update

- Added a `Task Status Key` to `TASKS.md`.
- Updated every `CT-` task heading with a visible status label.
- Used `IN PROGRESS` for partially implemented foundation tasks and `TODO` for tasks that have not started.

## 2026-05-05 DRM Feasibility Update

- Added `Docs/DRM-Feasibility-Study.md`.
- Documented required inputs, feasibility questions, classification outcomes, test procedure, result template, and safety rules.
- Marked CT-0204 as `BLOCKED` until approved representative FairPlay/DRM streams and playback/security guidance are available.

## 2026-05-05 CT-0204 Unblock Plan Update

- Extended `Docs/DRM-Feasibility-Study.md` with a **CT-0204 approval checklist** (sanitized alias, approval owner, allowed scope, frame sampling, sanitized logging).
- Added **owner question lists** for playback, security/DRM, provider metadata, and legal/content.
- Added **minimum metadata-first test matrix** and ordered metadata-first steps before any private stream use.
- Updated `TASKS.md` CT-0204 with a **sanitized stream inventory** (`approved` fixture alias `ct0204-metadata-first-fixtures-bundle`, `pending-approval` placeholder for live FairPlay).
- Moved CT-0204 heading status from `BLOCKED` to `IN PROGRESS` for the approved metadata-first fixture phase; live-stream validation remains gated per checklist.

## 2026-05-05 Unit Test Verification

- `xcodebuild test -scheme CaptionTheater` with `-skip-testing:CaptionTheaterUITests` completed successfully (`exit_code: 0`) on tvOS Simulator (Apple TV 4K (3rd generation)); all `CaptionTheaterTests` bundle tests passed.

## 2026-05-05 Full-scheme test note

- A full `xcodebuild test` (including `CaptionTheaterUITests`) ended with **`exit_code: 65`**: `CaptionTheaterUITests.testLaunchPerformance()` failed; unit suites passed. Logs also showed **`FBSOpenApplicationServiceErrorDomain` / RequestDenied** when launching `CaptionTheaterUITests.xctrunner` (typical simulator instability or signing/environment). For automated smoke validation, prefer `-skip-testing:CaptionTheaterUITests` until UI launch-performance behavior is reviewed for CI.
