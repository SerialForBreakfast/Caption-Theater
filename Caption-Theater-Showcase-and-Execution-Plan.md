# Caption Theater Showcase and Execution Plan

Date: 2026-05-04  
Status: Draft Execution Plan  
Related Documents:
- `ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md`
- `Caption-Theater-POC-Roadmap.md`
- `Caption-Theater-Metadata-Feasibility-Deep-Dive.md`

---

## 1. Product Definition

Caption Theater is a persistent timed-text readability mode.

It gives users more time and space to read subtitle/caption text that has already appeared. It must not reveal future dialogue by default. It must not assume blank pixels are safe. It must not alter ads, legal text, burned-in subtitles, or native playback presentation when safety cannot be proven.

### 1.1 One-Sentence Pitch

Caption Theater helps viewers keep up with captions by preserving recent subtitle context in verified safe screen space without revealing future text.

### 1.2 What We Are Proving

The proof of concept must answer:

1. Can we demonstrate a visible readability benefit in a controlled clip?
2. Can we persist already-shown cues without previewing future cues?
3. Can we identify when a safe display region is available?
4. Can we fail closed for unsafe or uncertain content?
5. Can we keep ads, promos, burned-in text, DRM uncertainty, native controls, and platform behavior safe?
6. Can we build this as a modular add-on rather than a full player rewrite?

### 1.3 What We Are Not Proving Yet

The first POC is not expected to prove:

- all DRM/FairPlay production streams work,
- all subtitle formats are reflow-safe,
- all DAI/SSAI ad cases are fully supported,
- native AVKit controls can be fully replaced,
- Caption Theater is ready for public rollout.

The first POC should prove the concept and expose production blockers.

---

## 2. Showcase Strategy

The showcase should make the benefit obvious before explaining the technology.

### 2.1 Demo Narrative

1. Show native captions during a dense subtitle scene.
2. Show the viewer missing context because the cue disappears quickly.
3. Replay the same clip with Caption Theater.
4. Show already-presented cue text persisting in a stable lower reading region.
5. Show that future cues are not revealed.
6. Show fallback cases:
   - full-frame 16:9 content,
   - burned-in subtitles,
   - ad pod,
   - pause promo,
   - variable-aspect content,
   - unknown/protected content without trusted metadata.

### 2.2 Hero Demo Clip Requirements

Use a controlled local clip first.

Required characteristics:

- letterboxed or otherwise safe inactive display region,
- sidecar WebVTT subtitles,
- dense dialogue or translated text,
- no burned-in subtitles,
- no ad overlays,
- no variable aspect ratio,
- enough visual contrast to inspect active picture bounds,
- 15–30 seconds long.

### 2.3 Baseline vs Caption Theater

Baseline:

- native video presentation,
- native caption behavior or MVP-equivalent simple caption renderer,
- cue disappears at authored end time,
- no retained context.

Caption Theater:

- video uses safe active-picture layout only when eligible,
- current cue is prominent,
- recently expired cue persists briefly in a de-emphasized style,
- retained cue history is bounded,
- no future cue appears,
- debug overlay can show active picture and caption region.

### 2.4 Demo Success Criteria

A viewer should be able to say:

- I could read more comfortably.
- I did not need to rewind as much.
- I understood who was speaking or what sound happened.
- I was not shown future dialogue.
- The video did not feel distorted.
- The system refused unsafe content instead of guessing.

---

## 3. MVP Build Order

The build order should avoid premature player work. Build pure modules first.

### MVP 0: Fixtures and Debug Harness

Goal:
Create controlled inputs for repeatable tests and demos.

Tasks:
1. Create sample app shell.
2. Create fixture directory.
3. Add synthetic frames:
   - full-frame 16:9,
   - 2.39:1 letterbox,
   - 2.31:1 letterbox,
   - 4:3 pillarbox,
   - windowboxed,
   - dark-scene false positive,
   - burned-in subtitle in lower bar,
   - logo/watermark in bar,
   - variable active-picture boundary.
4. Add fixture WebVTT files:
   - normal dialogue,
   - dense translated dialogue,
   - SDH speaker/sound cue,
   - forced narrative,
   - lyrics,
   - legal/ad disclosure.
5. Add fixture HLS manifests:
   - sidecar subtitles,
   - embedded closed captions,
   - forced subtitles,
   - discontinuity,
   - date range/ad marker,
   - encrypted stream marker.
6. Add debug inspector screen with static fake data.

Acceptance Criteria:
- Fixtures are deterministic and documented.
- Debug UI can show a fake eligibility decision before playback exists.
- Unit tests can load fixtures.

Parallelizable:
- Synthetic frame generator.
- WebVTT fixtures.
- Manifest fixtures.
- Debug UI skeleton.

---

### MVP 1: Evidence Model and State Reducer

Goal:
Make decisions explainable before any video rendering exists.

Tasks:
1. Define evidence sources.
2. Define evidence kinds.
3. Define fallback and suspension reasons.
4. Define `CaptionTheaterDecision`.
5. Define state machine.
6. Add reducer-style transition tests.
7. Add debug output for every state transition.

Acceptance Criteria:
- User disable wins over all states.
- Ad pod start forces native.
- Unknown ad state forces native.
- DRM without trusted metadata is uncertain/native.
- Unsupported subtitle format is native.
- Unsafe region evidence is native.
- Seek, track change, audio change, discontinuity, and ad boundary reset cue history.

Suggested Types:

```swift
enum CaptionTheaterEvidenceSource: Sendable {
    case hlsManifest
    case avFoundationMetadata
    case subtitleCueMetadata
    case timedMetadata
    case adLifecycleEvent
    case providerSideQcMetadata
    case pixelAnalysis
    case userSetting
}

enum CaptionTheaterDecision: Sendable {
    case eligible(evidence: [CaptionTheaterEvidence])
    case ineligible(reason: CaptionTheaterIneligibilityReason)
    case uncertain(reason: CaptionTheaterUncertaintyReason)
}
```

Feature Complete When:
- The entire decision system can run in unit tests without AVPlayer.

---

### MVP 2: Manifest and Metadata Inspector

Goal:
Learn what `.m3u8` and app metadata can tell us.

Tasks:
1. Parse multivariant playlist fixtures.
2. Extract `EXT-X-STREAM-INF` data:
   - bandwidth,
   - average bandwidth,
   - codecs,
   - resolution,
   - frame rate,
   - audio group,
   - subtitle group,
   - closed-caption group.
3. Parse `EXT-X-MEDIA`:
   - type,
   - group id,
   - language,
   - associated language,
   - name,
   - default,
   - autoselect,
   - forced,
   - characteristics,
   - URI.
4. Parse media playlist markers:
   - discontinuity,
   - date range,
   - key/session key markers.
5. Convert parsed data into evidence.
6. Show manifest evidence in debug inspector.

Acceptance Criteria:
- Sidecar subtitles are distinguished from embedded closed captions.
- Forced subtitles are identified as higher-risk.
- Discontinuity/date-range markers create revalidation/ad-risk evidence.
- Encrypted marker creates DRM-risk evidence.
- Manifest parser never declares visual-region safety by itself.

Feature Complete When:
- QA can load a manifest fixture and understand what the stream declares and what remains unknown.

---

### MVP 3: Viewport Detection

Goal:
Determine whether a proposed inactive region is safe enough for Caption Theater.

Tasks:
1. Implement metadata preclassification:
   - full-frame 16:9,
   - cinematic letterbox candidate,
   - 4:3 pillarbox,
   - windowboxed,
   - square/vertical,
   - variable/unknown.
2. Implement pixel metric extraction from synthetic frames.
3. Detect active picture rect.
4. Detect unsafe region evidence:
   - text-like edges,
   - burned-in subtitle,
   - logo/watermark,
   - legal/ad text,
   - motion/change,
   - inconsistent boundary.
5. Add confidence scoring.
6. Add detector unit tests.

Acceptance Criteria:
- Detects known letterbox active rect in synthetic frames.
- Rejects 16:9 full frame.
- Rejects dark-scene false positives.
- Rejects burned-in subtitles in proposed caption region.
- Rejects variable active-picture boundary.
- Produces human-readable evidence and confidence.

Feature Complete When:
- Detector can correctly classify the fixture corpus with documented false positives/false negatives.

---

### MVP 4: Layout Engine

Goal:
Compute safe video/caption geometry deterministically.

Tasks:
1. Define layout input and output models.
2. Compute native layout.
3. Compute expanded bottom region layout.
4. Preserve aspect ratio.
5. Account for safe areas.
6. Account for tvOS overscan simulation.
7. Add tests for common device/window sizes.
8. Add debug overlay geometry.

Acceptance Criteria:
- Video is never stretched.
- Active picture is never cropped.
- Caption region is non-negative.
- 16:9 full-frame returns native.
- tvOS overscan-safe layout can be simulated.
- Layout recomputes on bounds changes.

Feature Complete When:
- Given fixed analysis and container bounds, layout output is stable and fully unit-tested.

---

### MVP 5: Caption Persistence Renderer

Goal:
Render already-presented cues with bounded persistence.

Tasks:
1. Define internal cue model.
2. Parse or adapt WebVTT fixture cues.
3. Render current cue.
4. Persist recently expired cue in de-emphasized style.
5. Bound retention by age and cue count.
6. Disallow future cues by default.
7. Clear history on seek/track/audio/ad/discontinuity/asset change.
8. Preserve SDH speaker/sound text.
9. Treat forced/lyrics/legal/ad/unknown cues as authored timing only.
10. Add unit and snapshot tests.

Acceptance Criteria:
- Current cue appears during authored time.
- Expired dialogue cue can persist briefly.
- Future cue is never shown.
- Retained cue is visually distinct from current cue.
- Cue history clears at required boundaries.
- Legal/ad/forced/lyrics/unknown cue types do not persist by default.
- Renderer can operate with fixture cues without AVPlayer.

Suggested Types:

```swift
enum CaptionPersistencePolicy: Sendable {
    case authoredTimingOnly
    case retainExpiredCueBriefly
    case retainRecentCueHistory
    case pauseOnlyHistory
    case transcriptPanelOnly
}

struct CaptionPersistenceWindow: Sendable {
    let currentPlaybackTime: CMTime
    let retainedCues: [RenderedCaptionCue]
    let maximumCueAge: CMTime
    let maximumVisibleCueCount: Int
    let allowsFutureCues: Bool
}
```

Feature Complete When:
- The renderer can produce a stable before/after demo with fixture subtitles.

---

### MVP 6: iOS End-to-End Demo

Goal:
Wire the modules into a playable local demo.

Tasks:
1. Build `AVPlayerLayer`-hosted player view.
2. Wire local video asset.
3. Wire subtitle fixture to renderer.
4. Wire detector result to layout engine.
5. Wire state reducer to final presentation.
6. Add toggle:
   - Native,
   - Caption Theater,
   - Debug overlay.
7. Add fallback reason display.
8. Add pause/resume/seek handling.
9. Record before/after showcase.

Acceptance Criteria:
- Eligible clip enters Caption Theater.
- Full-frame clip stays native.
- Burned-in subtitle clip stays native.
- Variable-aspect fixture stays native.
- User can enable/disable instantly.
- Pause freezes persisted cue state.
- Seek clears/rebuilds cue history.
- Debug UI explains active/inactive decision.

Feature Complete When:
- A 5-minute stakeholder demo can be recorded from the iOS sample app.

---

### MVP 7: Ad and Promo Simulation

Goal:
Prove monetization safety without needing a production ad SDK.

Tasks:
1. Add simulated linear ad pod events.
2. Add simulated DAI/SSAI marker events.
3. Add unknown ad state.
4. Add simulated pause promo.
5. Add promo suppression when captions are visible.
6. Add native fallback on ad start.
7. Add revalidation on ad end.
8. Add state tests.

Acceptance Criteria:
- Ad pod start immediately returns to native.
- Unknown ad state returns to native.
- Caption Theater does not resume until revalidated.
- Pause promo never covers persisted captions.
- Resume dismisses pause promo.
- Ad/legal cue types never persist by default.

Feature Complete When:
- Demo can show Caption Theater is accessibility-positive without being ad-hostile or brand-unsafe.

---

### MVP 8: tvOS and macOS Feasibility

Goal:
Confirm platform risks.

tvOS Tasks:
1. Add tvOS wrapper.
2. Validate focus does not enter caption overlay.
3. Validate Siri Remote play/pause/seek.
4. Validate overscan-safe layout.
5. Validate VoiceOver smoke behavior.
6. Validate pause promo simulation.

macOS Tasks:
1. Add NSView wrapper.
2. Validate resize.
3. Validate full-screen.
4. Validate keyboard controls.
5. Validate backing scale changes.

Acceptance Criteria:
- Shared core modules work on all platforms.
- Platform adapters remain thin.
- tvOS focus remains stable.
- macOS resize does not corrupt layout.
- Platform blockers are documented.

Feature Complete When:
- We know whether the architecture is realistically cross-platform.

---

## 4. Work Breakdown into Buildable Tickets

### Epic A: Fixtures and Harness

#### A1. Create Fixture Directory and Documentation

User Story:
As a developer, I need deterministic fixture assets so detector, layout, metadata, and renderer behavior can be repeatedly tested.

Tasks:
- Create `Fixtures/Video`.
- Create `Fixtures/Frames`.
- Create `Fixtures/Subtitles`.
- Create `Fixtures/Manifests`.
- Create `Fixtures/ProviderMetadata`.
- Add `Fixtures/README.md` with expected classifications.

Acceptance Criteria:
- Every fixture has an expected result.
- Tests can load fixture paths.
- Fixture documentation explains why each asset exists.

#### A2. Generate Synthetic Frame Fixtures

User Story:
As a detector developer, I need generated frames with known active-picture bounds so we can test without relying on real media.

Tasks:
- Generate 16:9 full frame.
- Generate 2.39:1 letterbox.
- Generate 4:3 pillarbox.
- Generate dark-scene false positive.
- Generate burned-in subtitle in bottom bar.
- Generate logo/watermark in bar.
- Generate variable-boundary sequence.

Acceptance Criteria:
- Frames are deterministic.
- Expected active rect is documented.
- Detector tests can run in CI.

---

### Epic B: Evidence and Decision Engine

#### B1. Define Evidence Model

User Story:
As a playback engineer, I need every eligibility decision to be explainable so unsafe activations can be debugged.

Tasks:
- Define evidence source enum.
- Define evidence kind enum.
- Define confidence model.
- Define time range support.
- Define fallback reasons.
- Define uncertainty reasons.

Acceptance Criteria:
- Evidence is `Sendable`.
- Evidence can be logged without raw video frames.
- Evidence can be displayed in debug UI.

#### B2. Implement State Reducer

User Story:
As a QA engineer, I need deterministic state transitions so ad, seek, subtitle, and unsafe-region behavior is predictable.

Tasks:
- Define state enum.
- Define event enum.
- Implement reducer.
- Add transition tests.
- Add state debug descriptions.

Acceptance Criteria:
- User disable wins.
- Ads win.
- Unknown wins by failing closed.
- Boundary events reset cue history.
- Tests cover every transition.

---

### Epic C: Manifest Metadata

#### C1. Build HLS Manifest Fixture Parser

User Story:
As a product/engineering team, we need to know what HLS metadata can and cannot tell us.

Tasks:
- Parse multivariant playlist fixtures.
- Parse `EXT-X-STREAM-INF`.
- Parse `EXT-X-MEDIA`.
- Parse `EXT-X-DISCONTINUITY`.
- Parse `EXT-X-DATERANGE`.
- Parse encryption markers.
- Convert to evidence.

Acceptance Criteria:
- Sidecar subtitles are detected.
- Embedded closed captions are detected.
- Forced subtitle tracks are detected.
- Discontinuities and date ranges are detected.
- Visual-region safety is never inferred from manifest alone.

#### C2. Add Provider Metadata Stub

User Story:
As a production architect, I need to simulate trusted provider/QC metadata because DRM streams may not allow pixel analysis.

Tasks:
- Define JSON schema.
- Add fixture metadata.
- Parse active-picture rect.
- Parse safe caption regions.
- Parse policy flags.
- Parse blocklist reasons.
- Integrate with decision engine.

Acceptance Criteria:
- Trusted metadata can mark a DRM-like asset eligible.
- Missing metadata leaves DRM-like asset native.
- Blocklist overrides positive evidence.

---

### Epic D: Viewport Detection

#### D1. Implement Metadata Preclassification

User Story:
As a detector developer, I need cheap preclassification before pixel work.

Tasks:
- Normalize presentation size.
- Classify raster aspect.
- Identify likely candidates and obvious non-candidates.
- Add tests.

Acceptance Criteria:
- Known aspect fixtures classify correctly.
- No layout activates from this alone.

#### D2. Implement Pixel Region Detector

User Story:
As a playback engineer, I need a bounded detector that can identify safe inactive regions in non-DRM content.

Tasks:
- Extract luminance metrics.
- Detect inactive top/bottom/side bands.
- Compute active picture rect.
- Score confidence.
- Detect unsafe evidence.
- Add unit tests.

Acceptance Criteria:
- Correct on synthetic fixture corpus.
- Rejects unsafe regions.
- Does not persist frames.
- Runs off main actor in real integration.

---

### Epic E: Layout

#### E1. Implement Layout Engine

User Story:
As a UI engineer, I need a deterministic geometry engine for native and Caption Theater modes.

Tasks:
- Define input/output.
- Implement native layout.
- Implement expanded bottom region layout.
- Preserve aspect ratio.
- Add safe-area/overscan handling.
- Add tests.

Acceptance Criteria:
- No stretch.
- No crop.
- Safe caption region.
- Stable output.

#### E2. Implement Debug Overlay

User Story:
As QA, I need to see active picture, inactive region, caption region, and fallback reason.

Tasks:
- Draw active picture rect.
- Draw safe caption region.
- Draw unsafe evidence markers.
- Show decision state.
- Toggle overlay.

Acceptance Criteria:
- Debug overlay matches layout engine output.
- Overlay can be hidden.
- Overlay is not part of production user UI.

---

### Epic F: Caption Persistence

#### F1. Implement Cue Model and WebVTT Adapter

User Story:
As a caption-rendering developer, I need a normalized cue model so persistence logic is not tied to one subtitle parser.

Tasks:
- Define cue model.
- Define cue intent.
- Parse WebVTT fixture cues.
- Preserve timing.
- Preserve basic styling/spans where feasible.
- Add tests.

Acceptance Criteria:
- Cues are sorted and time-addressable.
- Forced/legal/lyrics fixtures are identified by fixture metadata or cue hints.
- Cue model is `Sendable`.

#### F2. Implement Persistence Window

User Story:
As a viewer, I want recent captions to remain readable briefly without showing future text.

Tasks:
- Implement current cue selection.
- Implement expired cue retention.
- Enforce max age.
- Enforce max count.
- Clear on boundary events.
- Add tests.

Acceptance Criteria:
- No cue with future start time is displayed.
- Expired cue retention is bounded.
- Boundary events clear history.
- Cue intent policy is respected.

#### F3. Implement Caption Renderer View

User Story:
As a viewer, I need current and retained captions to be visually distinct and readable.

Tasks:
- Render current cue.
- Render retained cue history.
- Apply de-emphasis to retained cues.
- Enforce region bounds.
- Add snapshot tests.

Acceptance Criteria:
- Retained text does not look like current speech.
- Text stays within caption region.
- Large text mode has a strategy.
- No transcript wall in MVP.

---

### Epic G: Platform Demo

#### G1. iOS Demo Integration

User Story:
As a stakeholder, I need a working before/after demo to understand the value.

Tasks:
- Build iOS sample player view.
- Wire fixtures.
- Wire state engine.
- Wire layout.
- Wire caption renderer.
- Add enable/disable controls.
- Add debug inspector.
- Add showcase recording script/checklist.

Acceptance Criteria:
- The hero clip demonstrates benefit.
- Unsafe fixtures fail closed.
- Debug explains decisions.
- Demo can be repeated.

#### G2. tvOS Feasibility

User Story:
As a tvOS product team, we need to know if Caption Theater conflicts with focus, remote controls, or VoiceOver.

Tasks:
- Add tvOS target/wrapper.
- Test focus.
- Test remote.
- Test pause/resume/seek.
- Test VoiceOver smoke flow.
- Document blockers.

Acceptance Criteria:
- Focus does not enter passive caption overlay.
- Remote controls still work.
- Overscan-safe layout is available.

#### G3. macOS Feasibility

User Story:
As a macOS product team, we need to know if Caption Theater survives resize and full-screen playback.

Tasks:
- Add macOS wrapper.
- Test resize.
- Test full-screen.
- Test keyboard shortcuts.
- Document blockers.

Acceptance Criteria:
- Shared core compiles.
- Layout recomputes on resize.
- Keyboard controls remain functional.

---

### Epic H: Ads and Promos

#### H1. Add Ad State Simulator

User Story:
As an ads stakeholder, I need proof that Caption Theater will not alter ad presentation.

Tasks:
- Simulate ad start.
- Simulate ad end.
- Simulate unknown ad state.
- Simulate DAI/SSAI marker.
- Add tests.

Acceptance Criteria:
- Ad start forces native.
- Ad end revalidates content.
- Unknown ad state fails closed.

#### H2. Add Pause Promo Simulator

User Story:
As a product stakeholder, I need pause promos to coexist with caption accessibility.

Tasks:
- Simulate pause promo.
- Suppress when captions visible.
- Dismiss on resume/seek/back.
- Add tests.

Acceptance Criteria:
- Pause promo never covers current or persisted captions.
- Resume dismisses promo.
- Suppression reason is logged.

---

## 5. Definition of Done

### POC Definition of Done

The POC is complete when:

- iOS showcase demonstrates native vs Caption Theater benefit.
- Persistent cue model works with no future cue display.
- Detector accepts at least one eligible fixture.
- Detector rejects at least five unsafe fixtures.
- Manifest inspector identifies subtitle/ad/DRM risk evidence.
- Provider metadata stub can authorize DRM-like safe-region behavior.
- Ad/promo simulation proves fail-closed behavior.
- Debug UI explains every active/inactive decision.
- Unit tests cover evidence, state, detection, layout, and persistence.
- tvOS and macOS feasibility are documented.

### Production-Readiness Definition of Done

The feature is production-ready only when:

- Real representative HLS/TS streams are tested.
- DRM path uses trusted metadata or allowlisting.
- Real ad lifecycle integration exists.
- Real subtitle pipeline integration exists.
- Native/custom caption duplication is prevented.
- Accessibility settings are honored.
- Remote kill switch exists.
- Analytics exists.
- Legal/content/ad sign-off exists.
- Platform QA passes.

---

## 6. Risks and Mitigations

| Risk | Why It Matters | Mitigation |
|---|---|---|
| Burned-in subtitles in black bars | False safe region | Pixel detection for non-DRM, provider metadata for DRM |
| DRM blocks frame analysis | Cannot verify pixels | Trusted metadata/allowlist/fail closed |
| Subtitle semantics lost | Accessibility regression | Cue intent policy, preserve authored layout for risky cues |
| Future text revealed | Spoilers/timing issues | Future cues disabled by default |
| Ads altered | Brand/legal/measurement risk | Ads force native |
| Pause promos cover captions | Accessibility conflict | Captions win; promos suppressed or moved |
| Variable aspect ratio | Layout flicker/creative intent | Suspend unless provider timeline metadata exists |
| tvOS focus issues | Usability regression | Passive overlay, focus tests |
| Native controls overlap captions | Player regression | Control-avoidance layout and fallback |
| Manifest overtrusted | Unsafe activation | Evidence model; manifest cannot prove visual safety |

---

## 7. Recommended Immediate Next Sprint

### Sprint Goal

Build the non-playback foundation that makes the feature explainable and testable.

### Sprint Tickets

1. Create fixture directory and expected-results README.
2. Implement evidence model.
3. Implement state reducer.
4. Implement manifest fixture parser.
5. Implement provider metadata JSON stub.
6. Implement layout engine with fake analysis input.
7. Implement caption persistence window with fixture cues.
8. Build debug inspector with fake/fixture data.

### Sprint Acceptance Criteria

- No AVPlayer dependency is required for the core tests.
- A developer can run tests and see deterministic decisions.
- Debug inspector can explain eligibility for fixture scenarios.
- Future cue display is impossible in the persistence model by default.
- All uncertainty results in native fallback.

---

## 8. Recommended Second Sprint

### Sprint Goal

Build the playable iOS showcase.

### Sprint Tickets

1. Add iOS sample `AVPlayerLayer` view.
2. Wire local eligible clip.
3. Wire WebVTT fixture cues.
4. Wire layout engine to view.
5. Wire caption renderer.
6. Add enable/disable toggle.
7. Add debug overlay.
8. Add unsafe fixture clips.
9. Add before/after recording checklist.

### Sprint Acceptance Criteria

- Native vs Caption Theater demo can be recorded.
- Eligible fixture activates.
- Unsafe fixtures fail closed.
- Pause freezes persisted cue state.
- Seek clears/rebuilds cue state.
- Debug overlay validates layout.

---

## 9. Showcase Checklist

Before stakeholder demo:

- Use one hero clip only.
- Keep demo under five minutes.
- Show native first.
- Show Caption Theater second.
- Emphasize no future text.
- Show one unsafe fallback.
- Show ad/promo fallback.
- Show debug evidence briefly.
- End with the ask: approve deeper real-stream validation.

Demo script:

1. “Here is the problem: the cue disappears before many users can scan it.”
2. “Here is Caption Theater: the same text remains available briefly after it appears.”
3. “We are not previewing future captions.”
4. “We only activate when the visual region and subtitle format are safe.”
5. “When ads, burned-in text, DRM uncertainty, or variable layout appears, we fail closed.”
6. “The next step is validating this against real HLS/TS streams and platform ad/caption pipelines.”

---

## 10. Final Recommendation

Proceed with Caption Theater as a staged proof of concept.

The immediate plan is:

1. Revise all docs around persistence, not preview.
2. Build an evidence-based decision engine.
3. Build fixtures and debug tools.
4. Build detector/layout/persistence modules independently.
5. Build a controlled iOS showcase.
6. Add ad/promo safety simulation.
7. Validate tvOS/macOS feasibility.
8. Only then evaluate real production streams, DRM, DAI/SSAI, and native player integration.

This keeps the effort actionable while respecting the core reality: Caption Theater is valuable, but only if it is conservative, explainable, and safe.
