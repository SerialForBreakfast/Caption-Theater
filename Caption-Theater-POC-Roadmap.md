# Caption Theater Proof of Concept Roadmap

# Caption Theater Product Frame

Caption Theater is a persistent timed-text readability mode.

The primary value is not previewing future subtitles and not merely moving widescreen video. The primary value is increasing readable dwell time for subtitle/caption text that has already appeared, while preserving original playback timing and failing closed when safety cannot be proven.

Product thesis:

> Caption Theater helps viewers keep up with captions by preserving recent subtitle context in verified safe screen space, while maintaining native playback whenever visual safety, subtitle semantics, ad state, or platform compatibility is uncertain.

Core rules:

1. Persist already-presented cues; do not reveal future cues by default.
2. Treat subtitle text as content, not decoration.
3. Treat black/blank space as untrusted until verified.
4. Separate viewport eligibility from subtitle-format eligibility.
5. Ads, promos, legal text, burned-in subtitles, unsupported formats, unknown DRM safety, and variable aspect ratio can all force native fallback.
6. The feature must be opt-in, reversible, measurable, and explainable in debug tools.
7. The MVP should prove value with a controlled demo before attempting production integration.

Date: 2026-05-04  
Status: Draft Product Roadmap  
Related ADR: `ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md`  
Platforms: iOS, tvOS, macOS  
Primary Goal: Prove whether a native Apple-platform player can safely detect unused visual regions and use them to provide a better subtitle reading experience.

---

## 1. Product Thesis

Caption Theater is an opt-in playback accessibility mode that gives subtitles more readable space when the video presentation leaves stable unused screen regions.

The feature is not only about widescreen films. It is a timed-text reading mode that can adapt to different content layouts:

- Cinematic letterbox content.
- 16:9 full-frame content.
- 4:3 pillarboxed content.
- Archival/windowboxed content.
- Variable-aspect-ratio content.
- Live and VOD streams.
- Content with SSAI/DAI/CSAI ad breaks.
- Content with pause ads, promos, and player overlays.

The first proof of concept should answer a limited set of hard questions:

1. Can we reliably identify unused visual regions?
2. Can we tell when those regions are intentionally used?
3. Can we render subtitles into a larger region without breaking timing, semantics, or accessibility?
4. Can this work beside native Apple playback integrations without breaking controls, PiP, AirPlay, ads, focus, or captions?
5. Can we define safe fallback behavior when we are uncertain?

The POC should fail closed. When the system is unsure, it returns to native playback and native captions.

---

## 2. Product Principles

### 2.1 Accessibility First

The mode should help users read timed text more comfortably. It should not primarily be an ad, branding, or layout gimmick.

### 2.2 User Control

The user must be able to turn the feature on and off. The feature should not permanently alter playback presentation.

### 2.3 Preserve Creative Intent

Black regions are not automatically unused. They may contain creative composition, subtitles, legal text, credits, watermarks, visual effects, app overlays, or ads.

### 2.4 Fail Closed

If eligibility is uncertain, use native centered playback.

### 2.5 Modular Integration

The POC should be built as a plug-in style layer around playback so it can integrate with different apps, playback surfaces, and subtitle pipelines.

### 2.6 Measurable Claims

Do not claim improved readability until the POC has measurable evidence:
- larger usable caption region,
- stable cue layout,
- fewer occlusions,
- no duplicated captions,
- no ad or overlay conflicts,
- no regressions to playback controls.

---

## 3. Target Users and User Stories

### 3.1 Deaf or Hard-of-Hearing Viewer

As a viewer who relies on captions, I want subtitles to have more room, so I can read dense dialogue without losing picture context.

Acceptance:
- Captions remain synchronized.
- Speaker labels and sound effects remain visible.
- The feature does not hide or duplicate captions.
- The user can return to native captions immediately.

### 3.2 Second-Language Viewer

As a viewer using translated subtitles, I want longer subtitles to be easier to scan, so text expansion from translation does not feel cramped.

Acceptance:
- Longer translated cues can wrap into the reserved region.
- The previous cue can remain visible briefly when useful.
- Future cues are not shown by default.

### 3.3 tvOS Viewer Using Remote and VoiceOver

As a tvOS viewer, I want the feature to work without interfering with focus, the Siri Remote, player controls, or VoiceOver.

Acceptance:
- Captions are not focusable unless intentionally exposed.
- Player controls remain reachable.
- Pause/resume/scrub behavior is predictable.
- VoiceOver does not get trapped in overlay UI.

### 3.4 Product / Ads Stakeholder

As an ads stakeholder, I need ad pods, pause ads, promos, CTAs, and legal text to remain unmodified, so the feature does not create brand-safety, measurement, or contractual issues.

Acceptance:
- Ad pods force native presentation.
- Pause promos are suppressed or placed only in verified safe regions.
- Unknown ad state suspends Caption Theater.
- Analytics include suppression/fallback reasons.

### 3.5 Playback Engineer

As a playback engineer, I need the feature to be modular and observable, so I can integrate it without rewriting the entire player stack.

Acceptance:
- Viewport analysis, subtitle rendering, ad coordination, and layout are separate modules.
- The system has deterministic state transitions.
- Analysis is cancellable.
- MainActor UI work is isolated from frame analysis.

---

## 4. Scope

### 4.1 In Scope for POC

- Local sample assets.
- HLS sample streams where available.
- `AVPlayerLayer`-based custom viewport container.
- Frame sampling through `AVPlayerItemVideoOutput` where available.
- Basic WebVTT parsing/rendering if app-controlled WebVTT is available.
- Synthetic test frames for detector validation.
- Debug overlay showing detected active picture bounds.
- Runtime feature flag.
- iOS first, then tvOS, then macOS wrapper.
- Ad-state abstraction with simulated ad pod and pause promo events.
- Measurement/logging of eligibility and fallback decisions.

### 4.2 Out of Scope for First POC

- Full production player replacement.
- Full native AVKit control recreation.
- DRM/FairPlay support beyond feasibility checks.
- OCR of burned-in subtitles.
- Image-based subtitle reflow.
- Per-word karaoke timing.
- Fully custom Metal playback renderer.
- Production ad SDK integration unless a stable test harness already exists.
- User studies beyond internal dogfooding.

### 4.3 Explicitly Deferred

- Side-panel captions for 4:3 pillarbox.
- Transcript panel.
- Live sports scoreboard awareness.
- Multi-angle playback.
- VisionOS immersive playback.
- Downloaded/offline asset behavior.
- Full localization quality scoring.

---

## 5. System Architecture

```text
+---------------------------------------------------------------+
|                       Host Playback App                       |
+--------------------------+------------------------------------+
                           |
                           v
+---------------------------------------------------------------+
|                 CaptionTheaterCoordinator                     |
|  - Owns state machine                                         |
|  - Consumes playback state, ad state, subtitle state           |
|  - Publishes layout mode and caption mode                      |
+-----+-------------------+-------------------+-----------------+
      |                   |                   |
      v                   v                   v
+-------------+   +----------------+   +------------------------+
| Viewport    |   | Subtitle       |   | Ad / Promo             |
| Analyzer    |   | Eligibility    |   | Coordinator            |
|             |   | + Renderer     |   |                        |
+------+------+   +-------+--------+   +-----------+------------+
       |                  |                        |
       v                  v                        v
+-------------+   +----------------+   +------------------------+
| Frame       |   | Cue Model      |   | Ad State Provider      |
| Sampler     |   | WebVTT/Other   |   | SSAI/DAI/CSAI/Pause    |
+------+------+   +-------+--------+   +-----------+------------+
       |                  |                        |
       +------------------+------------------------+
                          |
                          v
+---------------------------------------------------------------+
|          TopJustifiedPlayerView / Caption Overlay             |
|  iOS: UIView + AVPlayerLayer                                  |
|  tvOS: UIView + focus-safe overlays                           |
|  macOS: NSView + AVPlayerLayer                                |
+---------------------------------------------------------------+
```

---

## 6. Component Definitions

### 6.1 `CaptionTheaterCoordinator`

The central decision engine.

Responsibilities:
- Own the state machine.
- Combine viewport analysis, subtitle eligibility, ad state, user setting, and platform capability.
- Publish a single authoritative presentation mode.
- Cancel in-flight work when playback item, ad state, subtitle track, route, or app state changes.
- Emit analytics/debug logs.

Public model:

```swift
enum CaptionTheaterState: Sendable {
    case disabledByUser
    case nativeCentered(reason: CaptionTheaterFallbackReason)
    case analyzing
    case eligiblePreview
    case active(CaptionTheaterPresentation)
    case suspended(CaptionTheaterSuspensionReason)
}
```

Concurrency requirement:
- Coordinator may be an actor for state transitions.
- UI application must occur on `@MainActor`.
- All async analysis must be cancellable.

### 6.2 `ViewportAnalyzer`

Determines whether the video has stable inactive regions.

Responsibilities:
- Read presentation size and track metadata.
- Sample frames where allowed.
- Detect active picture bounds.
- Score confidence.
- Detect unsafe use of black/blank regions.
- Identify variable-aspect transitions.
- Cache results per asset segment when safe.

Outputs:

```swift
struct ViewportAnalysis: Sendable {
    let activePictureRect: CGRect
    let inactiveRegions: [InactiveViewportRegion]
    let presentationSize: CGSize
    let activeAspectRatio: CGFloat
    let classification: ViewportClassification
    let confidence: Double
    let unsafeRegionEvidence: [UnsafeRegionEvidence]
    let sampledTimeRange: CMTimeRange
}
```

### 6.3 `FrameSampler`

A bounded utility for acquiring frames.

Responsibilities:
- Attach an `AVPlayerItemVideoOutput` when supported.
- Sample a small number of frames around stable playback windows.
- Avoid blocking playback startup.
- Avoid storing frame images.
- Return reduced metrics rather than full frames where possible.

Failure modes:
- Protected content blocks output.
- Pixel buffers are unavailable at requested times.
- Startup buffering delays sampling.
- Variant switches alter resolution.
- Live stream windows prevent reliable lookahead.

### 6.4 `SubtitleEligibilityService`

Determines whether the selected subtitle track can support Caption Theater.

Responsibilities:
- Identify selected subtitle format.
- Determine whether text is available.
- Detect cue positioning semantics.
- Identify forced narrative/sign/song cues when possible.
- Decide whether reflow is safe.
- Return renderer policy.

Initial compatibility:
- WebVTT: preferred MVP.
- IMSC/TTML text profile: future candidate.
- CEA-608/708: semantic-preserving support only.
- Burned-in subtitles: not eligible.
- Image-based subtitles: not eligible for reflow.

### 6.5 `CaptionRenderer`

Renders cues in the reserved reading region.

Responsibilities:
- Display current cue.
- Optionally retain previous cue.
- Avoid future-cue display by default.
- Respect caption styling as much as possible.
- Avoid overlapping controls, pause promos, ad UI, and system overlays.
- Reset on seek, track change, ad boundary, and asset transition.

### 6.6 `AdPlaybackViewportCoordinator`

Ensures ads and promos override Caption Theater when needed.

Responsibilities:
- Consume ad lifecycle state from host app, ad SDK, HLS markers, or simulated events.
- Force native presentation during linear ad pods.
- Suppress or safely place pause promos.
- Suspend Caption Theater when ad state is unknown.
- Require content revalidation after ad exit.

### 6.7 `TopJustifiedPlayerView`

Applies final video and caption layout.

Responsibilities:
- Host `AVPlayerLayer`.
- Apply layout from coordinator.
- Keep layer changes on the main actor.
- Support iOS, tvOS, and macOS wrapper views.
- Provide debug overlay.

---

## 7. State Machine

### 7.1 Primary States

```swift
enum CaptionTheaterModeState: Sendable {
    case off
    case native
    case analyzing
    case eligibleInactiveSpace
    case active
    case suspendedForAdPod
    case suspendedForPausePromo
    case suspendedForUnsafeRegionUse
    case suspendedForVariableAspect
    case suspendedForUnsupportedSubtitleFormat
    case suspendedForProtectedContent
    case failedClosed
}
```

### 7.2 Transition Rules

| Event | Current State | Next State | Reason |
|---|---:|---:|---|
| User enables mode | native | analyzing | Start eligibility |
| Frame output unavailable | analyzing | suspendedForProtectedContent | Cannot validate |
| Stable letterbox detected | analyzing | eligibleInactiveSpace | Candidate |
| Subtitle unsupported | eligibleInactiveSpace | suspendedForUnsupportedSubtitleFormat | Cannot render safely |
| User confirms / auto allowed | eligibleInactiveSpace | active | Enable |
| Ad pod starts | any | suspendedForAdPod | Ads override |
| Ad pod ends | suspendedForAdPod | analyzing | Revalidate |
| Pause promo appears | active | suspendedForPausePromo or active | Depends on caption priority |
| Unsafe region motion/text detected | active | suspendedForUnsafeRegionUse | Fail closed |
| Variable aspect transition | active | suspendedForVariableAspect | Prevent flicker |
| User disables mode | any | off | User control |
| Seek/scrub | active | analyzing | Rebuild context |
| Subtitle track changes | active | analyzing | Re-evaluate format |

---

## 8. Aspect Ratio and Region Handling

### 8.1 Supported Classifications

```swift
enum ViewportClassification: Sendable {
    case fullFrame16x9
    case cinematicLetterbox
    case pillarbox4x3
    case windowboxed
    case squareOrVertical
    case variableAspectRatio
    case unknown
}
```

### 8.2 Policy by Classification

| Classification | MVP Behavior | Future Behavior |
|---|---|---|
| Full-frame 16:9 | Native captions only | Optional transcript/reading panel |
| Cinematic letterbox | Primary target | Caption Theater bottom region |
| 4:3 pillarbox | Detect but do not reflow | Side-panel captions after UX research |
| Windowboxed | Ineligible by default | Allowlist only |
| Square/vertical | Ineligible by default | Per-format layout research |
| Variable aspect | Ineligible automatic mode | Segment-aware mode with hysteresis |
| Unknown | Native | None |

### 8.3 Why “All Aspect Ratios” Does Not Mean “All Are Repositioned”

The POC should classify all aspect ratios but only activate Caption Theater when a safe reading region is proven. This distinction matters:

- 16:9 has no blank region to reclaim.
- 4:3 has side regions, but captions in side panels are a new UX pattern.
- Windowboxed content often uses borders as part of archival or creative presentation.
- Variable-aspect content can create layout flicker or hide intentional framing.
- Cinematic letterbox is the highest-value and lowest-risk starting point.

---

## 9. Detecting Intentional Use of Blank Space

### 9.1 Unsafe Region Evidence

```swift
enum UnsafeRegionEvidence: Sendable {
    case textLikeEdges
    case burnedInSubtitleDetected
    case logoOrWatermarkDetected
    case qrCodeLikePatternDetected
    case legalTextRegionDetected
    case motionInsideInactiveRegion
    case brightnessChangeInsideInactiveRegion
    case inconsistentBoundary
    case creditsOrLowerThirdDetected
    case adOrPromoOverlayDetected
}
```

### 9.2 Detection Strategy

The detector should not merely test for black pixels. It should answer:

> Is this region stable, visually empty, and safe to repurpose?

Signals:
- Luminance mean and variance.
- Edge density.
- Motion/change over time.
- Horizontal consistency.
- Boundary stability.
- Text-like shape density.
- Presence of subtitle-like lower-third shapes.
- Known overlay/ad state.
- Whether cue positions already target the region.

### 9.3 Confidence Thresholds

Suggested initial thresholds:

| Confidence | Behavior |
|---:|---|
| 0.00–0.49 | Native only |
| 0.50–0.74 | Debug eligible only |
| 0.75–0.89 | Internal dogfood eligible |
| 0.90+ | Candidate for user-facing experiment |

Thresholds should be tuned against labeled assets, not guessed permanently.

---

## 10. Metadata Opportunities

### 10.1 Metadata Worth Inspecting

- `AVAssetTrack.naturalSize`
- `AVAssetTrack.preferredTransform`
- `AVPlayerItem.presentationSize`
- HLS master/media playlist resolution attributes.
- Subtitle rendition metadata.
- HLS `EXT-X-DATERANGE` entries.
- SCTE-35-derived ad markers.
- `EXT-X-DISCONTINUITY` boundaries.
- `EXT-X-PROGRAM-DATE-TIME` for live correlation.
- Asset/catalog metadata if provider has aspect ratio or title tags.
- Timed metadata groups from the player item.
- Ad SDK lifecycle events.
- Subtitle cue positioning settings.
- Content ratings/genre/content type where product policy may differ.

### 10.2 Metadata That Would Be Ideal But May Not Exist

- Authored active-picture aperture.
- Safe caption region.
- Segment-level aspect-ratio changes.
- Burned-in subtitle presence.
- Whether letterbox bars are intentional.
- Variable-aspect timeline map.
- Ad pod boundaries before playback.
- Pause promo placement constraints.

### 10.3 Metadata vs Pixel Analysis

Metadata is cheap and deterministic, but often incomplete. Pixel analysis is more flexible, but probabilistic.

Recommended approach:

1. Use metadata for preclassification.
2. Use pixel sampling for verification.
3. Use ad/subtitle lifecycle state as authoritative overrides.
4. Use allowlists/blocklists for known edge-case assets.
5. Fail closed when metadata and pixels disagree.

---

## 11. Buffering and Lookahead

### 11.1 Does Looking Ahead Help?

Yes, but only in constrained ways.

Helpful:
- Sampling a few frames shortly after playback becomes stable.
- Sampling around upcoming segment boundaries.
- Prechecking downloaded VOD segments if the app already has them.
- Detecting variable aspect ratio before enabling the mode.
- Building cue history around the current playback time.

Risky or too big for MVP:
- Aggressively buffering future video solely for analysis.
- Decoding large lookahead windows.
- Looking through DRM-protected content.
- Predicting future ads or promos from pixels alone.
- Showing future subtitle cues by default.

### 11.2 MVP Lookahead Policy

The POC should use **shallow opportunistic lookahead**, not a heavy prebuffering system.

Recommended:
- Analyze 5–12 frames across the first stable 10–30 seconds of content.
- Revalidate around discontinuity/ad boundaries.
- Revalidate after seek.
- For VOD only, optionally sample a few additional points if already buffered.
- Do not block playback start.

### 11.3 Live Content Policy

For live streams:
- Use current and recent frames only.
- Do not assume future layout stability.
- Prefer a higher confidence threshold.
- Suspend around unknown discontinuities.
- Keep native fallback easy.

---

## 12. Proof of Concept Milestones

## Milestone 0: Research Harness and Test Assets

Goal:
Create a repeatable local environment for detector and layout experiments.

Deliverables:
- Sample app shell.
- Local asset catalog.
- Synthetic frame generator.
- Debug overlay design.
- Baseline documentation.

Tasks:
1. Create a minimal iOS sample app with `AVPlayerLayer`.
2. Add local test assets:
   - 16:9 full frame.
   - 2.39:1 letterboxed.
   - 2.31:1 letterboxed.
   - 4:3 pillarboxed.
   - windowboxed archival.
   - dark scene false positive.
   - burned-in subtitle sample.
   - variable-aspect sample.
3. Generate synthetic still frames with known active rects for unit tests.
4. Define debug overlay colors/labels.
5. Define logging schema.

Acceptance Criteria:
- App plays local video through custom layer.
- Debug overlay can draw expected active rect.
- Synthetic test frames are deterministic.
- Test assets are documented with expected classifications.

Parallelizable:
- Sample app shell.
- Synthetic test generator.
- Asset catalog curation.
- Debug overlay UI.

---

## Milestone 1: Metadata Preclassification

Goal:
Classify likely aspect behavior before doing pixel analysis.

Tasks:
1. Read presentation size and track size.
2. Normalize size with preferred transform.
3. Compute source aspect ratio.
4. Classify obvious 16:9, 4:3, vertical, square, and unknown.
5. Add HLS metadata parser stubs for future playlist/ad markers.
6. Add unit tests for classification.

Acceptance Criteria:
- 16:9, 4:3, cinematic, vertical, and unknown test cases classify correctly.
- No layout change occurs from metadata alone.
- Metadata result can be logged and inspected.

Feature Complete When:
- Metadata preclassification can reject obvious non-candidates and identify likely candidates without rendering any custom layout.

Parallelizable:
- Track metadata reader.
- Classification unit tests.
- Debug panel display.

---

## Milestone 2: Pixel-Based Active Picture Detection

Goal:
Detect stable inactive regions from sampled frames.

Tasks:
1. Add `AVPlayerItemVideoOutput` frame sampler.
2. Convert sampled pixel buffers into reduced luminance metrics.
3. Detect top/bottom/side inactive bands.
4. Compute active picture rect.
5. Score confidence.
6. Detect unsafe region evidence.
7. Add golden-image tests using synthetic frames.

Acceptance Criteria:
- Detects known letterbox regions in synthetic frames.
- Rejects full-frame 16:9.
- Rejects dark-scene false positives.
- Detects inconsistent/variable boundaries.
- Returns confidence and evidence.
- Does not persist frames.

Feature Complete When:
- Detector returns stable active-picture rects and fail-closed reasons across the local test corpus.

Parallelizable:
- Pixel metric extraction.
- Confidence scoring.
- Synthetic frame fixtures.
- Unsafe evidence detectors.

---

## Milestone 3: Viewport Layout Engine

Goal:
Compute safe video and caption-region layout without modifying playback.

Tasks:
1. Define layout input/output models.
2. Compute top-justified active-picture placement.
3. Preserve aspect ratio.
4. Account for safe areas and tvOS overscan.
5. Compute caption region.
6. Add layout tests for screen sizes and aspect ratios.
7. Add debug overlay for computed regions.

Acceptance Criteria:
- Layout never stretches video.
- Caption region is non-negative and safe-area aware.
- tvOS overscan-safe mode can be simulated.
- Rotation/window resize recomputes correctly.
- 16:9 returns native layout.

Feature Complete When:
- Given an analysis result and container size, layout output is deterministic and testable.

Parallelizable:
- Geometry engine.
- Platform safe-area adapter.
- Unit tests.
- Debug overlay.

---

## Milestone 4: Caption Theater State Machine

Goal:
Centralize decisions and fallback rules.

Tasks:
1. Implement coordinator state enum.
2. Add transition reducer.
3. Add user setting input.
4. Add playback event input.
5. Add subtitle eligibility input.
6. Add ad state input.
7. Add analytics/debug event output.
8. Add state-machine unit tests.

Acceptance Criteria:
- Ad pod start always suspends mode.
- Unknown ad state suspends mode.
- Subtitle track change re-enters analysis.
- Seek revalidates context.
- User disable wins over all other states.
- Unsafe region evidence suspends mode.
- Transitions are deterministic and logged.

Feature Complete When:
- The coordinator can be tested without AVPlayer or UI.

Parallelizable:
- State reducer.
- Event model.
- Unit tests.
- Debug logger.

---

## Milestone 5: WebVTT MVP Caption Renderer

Goal:
Render text-based cues into the reserved region.

Tasks:
1. Define internal cue model.
2. Parse or ingest WebVTT cues.
3. Render current cue.
4. Render previous cue in de-emphasized style.
5. Support speaker labels and basic italics if available.
6. Preserve timing.
7. Reset on seek/track change/ad boundary.
8. Disallow future cue display by default.
9. Add renderer snapshot tests.

Acceptance Criteria:
- Current cue appears at correct time.
- Previous cue retention does not alter semantic cue timing.
- Future cues are not shown.
- Cue history resets correctly.
- Renderer respects maximum lines/region bounds.
- No duplicate native/custom captions in test harness.

Feature Complete When:
- WebVTT subtitles can be shown in Caption Theater bottom region in the sample app.

Parallelizable:
- Cue model.
- Parser/adapter.
- Renderer view.
- Snapshot fixtures.

---

## Milestone 6: Ad and Promo Simulation

Goal:
Prove that ad state overrides layout and captions safely.

Tasks:
1. Add simulated ad pod events.
2. Add simulated pause promo events.
3. Add unknown ad state.
4. Add resume/revalidation behavior.
5. Add debug UI to trigger events.
6. Add transition tests.

Acceptance Criteria:
- Ad pod start returns to native centered presentation.
- Caption Theater does not resume until content revalidates.
- Pause promo is suppressed when captions are visible.
- Unknown ad state fails closed.
- Resume dismisses pause promo immediately.

Feature Complete When:
- The POC proves ad/promo safety policy independent of a production ad SDK.

Parallelizable:
- Simulated ad provider.
- Coordinator tests.
- Debug controls.
- UX copy.

---

## Milestone 7: iOS Integrated POC

Goal:
Demonstrate full flow on iOS.

Tasks:
1. Wire player item to analyzer.
2. Wire analyzer to coordinator.
3. Wire coordinator to layout engine.
4. Wire layout to `TopJustifiedPlayerView`.
5. Wire selected WebVTT track to renderer.
6. Add user toggle.
7. Add debug overlay.
8. Add basic analytics logger.
9. Test rotation and safe areas.

Acceptance Criteria:
- User can enable/disable Caption Theater.
- Eligible asset enters Caption Theater.
- Ineligible asset stays native.
- Captions render in bottom region.
- Rotation does not corrupt layout.
- Ad simulation suspends/resumes safely.
- Failure reason is visible in debug UI.

Feature Complete When:
- A developer can run the iOS sample app and verify the entire user journey with documented test assets.

Parallelizable:
- UI toggle/settings.
- Player wiring.
- Caption renderer.
- Debug overlay.

---

## Milestone 8: tvOS POC

Goal:
Validate focus, remote, overscan, and player-control behavior.

Tasks:
1. Port wrapper view to tvOS.
2. Add remote-safe toggle or debug menu.
3. Validate focus does not enter caption overlay.
4. Validate play/pause/scrub behavior.
5. Validate VoiceOver basics.
6. Validate overscan-safe layout.
7. Add tvOS UI tests where reliable.

Acceptance Criteria:
- Siri Remote controls remain functional.
- Focus is stable.
- Caption overlay is noninteractive unless intentionally exposed.
- VoiceOver can operate controls.
- Pause promo simulation does not trap focus.
- Overscan-safe caption region works.

Feature Complete When:
- tvOS playback remains usable with Caption Theater enabled and disabled.

Parallelizable:
- tvOS wrapper.
- Focus QA.
- Overscan layout tests.
- Remote-control tests.

---

## Milestone 9: macOS POC

Goal:
Validate resizable desktop playback.

Tasks:
1. Add `NSView` wrapper.
2. Validate window resize.
3. Validate full-screen behavior.
4. Validate keyboard shortcuts.
5. Validate caption overlay accessibility.
6. Validate backing scale factor changes.

Acceptance Criteria:
- Resize recomputes layout.
- Full screen preserves layout.
- Keyboard playback controls still work.
- Captions remain readable.
- Debug overlay works.

Feature Complete When:
- The same core detector/coordinator/layout code runs on macOS with a thin platform adapter.

Parallelizable:
- NSView wrapper.
- Layout tests.
- Keyboard QA.

---

## Milestone 10: Evaluation and Decision

Goal:
Decide whether the concept is viable.

Tasks:
1. Run test matrix.
2. Review detector accuracy.
3. Review subtitle readability.
4. Review ad safety.
5. Review platform integration cost.
6. Identify production blockers.
7. Update ADR with final decision.
8. Create next-phase production tasks.

Acceptance Criteria:
- Detector accuracy is measured against labeled assets.
- False positive/negative examples are documented.
- User-facing value is demonstrated with before/after captures.
- Production blockers are explicit.
- Recommendation is one of:
  - proceed,
  - proceed with limited scope,
  - keep as accessibility experiment,
  - stop.

---

## 13. Workstreams and Parallelization

### Workstream A: Detection

Can proceed independently using synthetic frames and local assets.

Includes:
- metadata preclassification,
- pixel analysis,
- confidence scoring,
- unsafe evidence detection.

### Workstream B: Layout

Can proceed with fake analysis inputs.

Includes:
- geometry engine,
- safe-area handling,
- debug overlay,
- platform wrappers.

### Workstream C: Caption Rendering

Can proceed with static cue fixtures.

Includes:
- cue model,
- WebVTT adapter,
- rendering,
- persistent cue policy.

### Workstream D: State Machine

Can proceed without AVPlayer.

Includes:
- coordinator,
- transition tests,
- ad/promo state,
- fallback reasons.

### Workstream E: Platform Integration

Depends on A–D reaching usable interfaces.

Includes:
- iOS wrapper,
- tvOS wrapper,
- macOS wrapper,
- native controls impact,
- accessibility QA.

### Workstream F: Product/UX

Can proceed throughout.

Includes:
- setting labels,
- debug UX,
- eligibility messaging,
- user education,
- pause promo policy,
- analytics schema.

---

## 14. Plug-and-Play Integration Model

The feature should integrate as a module with narrow interfaces.

### 14.1 Host App Provides

```swift
protocol CaptionTheaterHostPlaybackContext: Sendable {
    var playerItemIdentifier: String { get }
    var presentationSize: CGSize { get }
    var selectedSubtitleTrack: SubtitleTrackDescriptor? { get }
    var adState: PlaybackAdState { get }
    var platformCapabilities: PlatformPlaybackCapabilities { get }
}
```

### 14.2 Module Provides

```swift
protocol CaptionTheaterControlling: Sendable {
    func handlePlaybackEvent(_ event: CaptionTheaterPlaybackEvent) async
    func currentPresentation() async -> CaptionTheaterPresentation
}
```

### 14.3 Platform View Adapter

```swift
@MainActor
protocol CaptionTheaterRenderable: AnyObject {
    func applyPresentation(_ presentation: CaptionTheaterPresentation)
    func applyCaptionCues(_ cues: CaptionTheaterCueDisplayState)
}
```

### 14.4 Integration Rule

The host player remains authoritative for:
- playback,
- entitlement,
- ads,
- media selection,
- route changes,
- PiP/AirPlay,
- native controls.

Caption Theater remains authoritative only for:
- eligibility,
- layout recommendation,
- caption-region rendering when enabled.

---

## 15. Testing Plan

### 15.1 Unit Tests

Detector:
- letterbox detection,
- pillarbox detection,
- full-frame rejection,
- dark-scene rejection,
- unsafe region evidence,
- confidence scoring,
- variable boundary detection.

Layout:
- safe-area handling,
- tvOS overscan,
- rotation,
- window resize,
- no negative caption region,
- preserve aspect ratio.

Coordinator:
- user setting wins,
- ad state wins,
- unknown ad state fails closed,
- subtitle unsupported fails closed,
- seek resets,
- track change resets,
- unsafe evidence suspends.

Caption renderer:
- cue timing,
- previous cue retention,
- no future cue default,
- line wrapping,
- speaker labels,
- reset behavior.

### 15.2 Snapshot Tests

- eligible cinematic layout,
- native 16:9 layout,
- 4:3 pillarbox native layout,
- paused with captions,
- paused with promo suppressed,
- persistent cue display,
- large text captions.

### 15.3 UI Tests

iOS:
- enable/disable setting,
- rotate device,
- seek,
- pause/resume,
- subtitle track switch.

tvOS:
- focus movement,
- remote play/pause,
- scrub,
- VoiceOver smoke test,
- pause promo suppression.

macOS:
- resize window,
- enter full-screen,
- keyboard shortcuts.

### 15.4 Manual QA

- HDR and SDR assets.
- Live and VOD.
- HLS discontinuities.
- DAI/SSAI ad markers.
- Long translated subtitles.
- SDH captions.
- Forced subtitles.
- Burned-in subtitles.
- Variable aspect ratio.
- Dark scenes.
- Credits.
- Logos/watermarks.
- Sports/news lower thirds.

---

## 16. Completion Definition

### 16.1 POC Complete

The POC is complete when:

- The sample app can play at least one eligible asset in Caption Theater.
- At least five ineligible/unsafe assets correctly stay native.
- The detector has automated tests.
- The layout engine has automated tests.
- The coordinator has automated tests.
- WebVTT persistent cue rendering works.
- Ad pod simulation suspends the feature.
- Pause promo simulation does not cover captions.
- Debug UI explains why the feature is active or inactive.
- iOS demo is stable enough to record.
- tvOS/macOS feasibility is documented, even if not polished.

### 16.2 Production Candidate Complete

The feature is production-candidate only when:

- It works against real representative HLS/TS streams.
- It handles real ad lifecycle events.
- It has a tested subtitle track integration.
- It has no duplicate captions.
- It honors accessibility settings as much as possible.
- It has remote kill switch support.
- It has analytics.
- It has content/product/legal sign-off.
- It has documented fallback behavior.
- It passes platform QA.

---

## 17. Known Failure Modes

### 17.1 Detection Failures

- Dark scenes mistaken for black bars.
- Black bars with subtle gradients.
- Fade-ins.
- Variable aspect ratio.
- Credits over black.
- Burned-in subtitles in bars.
- Watermarks/logos in bars.
- Picture-in-picture content inside black region.
- Low-quality compression artifacts.
- HDR/EDR luminance interpretation differences.
- Animated letterbox effects.

### 17.2 Subtitle Failures

- Native captions duplicate custom captions.
- Cue timing is lost.
- Speaker labels removed.
- SDH sound effects visually downgraded.
- Forced narrative subtitles moved incorrectly.
- Positioned signs/song lyrics reflow incorrectly.
- RTL/vertical writing broken.
- Image subtitles cannot reflow.
- CEA roll-up semantics flattened incorrectly.

### 17.3 Playback Failures

- PiP ignores custom layout.
- AirPlay route shows native layout only.
- DRM blocks frame extraction.
- Variant switching changes dimensions.
- Buffering delays detection.
- Seek invalidates cached analysis.
- Live discontinuity breaks assumptions.
- tvOS focus enters overlay.
- Player controls overlap caption region.

### 17.4 Ad / Promo Failures

- SSAI ad not marked.
- DAI lifecycle delayed.
- Pause promo overlays captions.
- QR/legal text appears in black region.
- Companion ad requires reserved space.
- Measurement overlay conflicts.
- Ad pod returns at a different aspect ratio.
- Ad state unknown during startup.

---

## 18. How We Will Know We Have the Right Cropping

We will never know with absolute certainty from pixels alone. This is a soft computer-vision problem. The correct bar is “safe enough with strong fallback,” not “perfect.”

Evidence that cropping/alignment is correct:

1. Metadata and pixel analysis agree.
2. Active-picture boundary is stable across multiple samples.
3. Inactive region has low luminance variance.
4. Inactive region has low edge density.
5. No motion is detected in the inactive region.
6. No subtitle/text/logo/QR/legal evidence appears.
7. The inferred active aspect ratio is plausible.
8. The result remains stable after seek and ad boundary.
9. Human-labeled test corpus agrees.
10. User can disable immediately.

Evidence that we are wrong:

1. Boundary shifts repeatedly.
2. Text-like shapes appear in the inactive region.
3. Inactive region changes during playback.
4. Captions overlap important visual content.
5. Users disable the mode quickly.
6. QA labels an asset as creatively unsafe.
7. Ad/promo overlays appear in the region.
8. Native controls conflict with the caption region.

---

## 19. Open Research Questions

### Feasibility

1. Is `AVPlayerItemVideoOutput` available for representative protected streams?
2. Does attaching video output affect performance, battery, or playback stability?
3. Can we reliably disable native captions when using custom captions?
4. Can we obtain WebVTT cue text from the app’s current pipeline?
5. Can we detect SSAI/DAI boundaries early enough?
6. Can tvOS focus remain stable with custom overlays?
7. Does PiP need to disable Caption Theater?

### Product

1. Is “persistent cue” actually better for users?
2. Should the feature be per-profile, per-device, or per-playback session?
3. Should users discover it through settings or an in-player prompt?
4. Should pause ads always be suppressed when captions are enabled?
5. Should 4:3 side-panel captions become a separate future mode?

### Legal / Content

1. Are we allowed to reposition the video presentation?
2. Are we allowed to reflow subtitles?
3. Are we allowed to suppress pause promos when captions are visible?
4. Do licensors require native subtitle rendering?
5. Are there caption compliance constraints by market?

---

## 20. Recommended Build Order

1. State machine model and fallback reasons.
2. Synthetic frame generator.
3. Metadata classifier.
4. Pixel detector.
5. Layout engine.
6. Debug overlay.
7. iOS `AVPlayerLayer` sample.
8. WebVTT cue renderer.
9. Ad/promo simulator.
10. End-to-end iOS demo.
11. tvOS feasibility pass.
12. macOS feasibility pass.
13. Real-stream validation.
14. Production decision.

This order minimizes wasted work. The detector, layout engine, and coordinator can be validated before building a polished player UI.

---

## 21. MVP Slices

### MVP 1: Detector-Only

Question:
Can we identify safe inactive regions?

Includes:
- metadata classifier,
- synthetic frame tests,
- pixel sampling,
- debug overlay.

Excludes:
- custom captions,
- ad SDK,
- tvOS/macOS.

Decision Gate:
Proceed only if detector can reject dark scenes and burned-in subtitle cases.

### MVP 2: Layout-Only

Question:
Can we top-align active picture safely?

Includes:
- layout engine,
- iOS player view,
- debug overlay,
- user toggle.

Excludes:
- custom captions.

Decision Gate:
Proceed only if layout is visually stable and does not break basic playback.

### MVP 3: Caption Theater WebVTT

Question:
Can captions use the reclaimed space meaningfully?

Includes:
- WebVTT cue model,
- current/previous cue renderer,
- no future cues,
- pause/seek handling.

Decision Gate:
Proceed only if captions are more readable without duplicate rendering.

### MVP 4: Ad/Promo Safety

Question:
Can this coexist with monetization?

Includes:
- ad pod simulator,
- pause promo simulator,
- unknown ad state,
- forced native fallback.

Decision Gate:
Proceed only if ads/promos never compete with captions or get visually altered.

### MVP 5: Platform Feasibility

Question:
Can the architecture move beyond iOS?

Includes:
- tvOS wrapper,
- macOS wrapper,
- platform QA checklist.

Decision Gate:
Proceed only if platform-specific costs are acceptable.

---

## 22. Documentation Deliverables

- ADR: architectural decision and tradeoffs.
- Roadmap: this document.
- Test Matrix: asset-by-asset expected behavior.
- Detector Tuning Notes: thresholds and false positives.
- Caption Format Matrix: support status by format.
- Ad Integration Contract: required lifecycle events from host app.
- Accessibility QA Checklist.
- Production Readiness Checklist.
- Rollout / Kill Switch Plan.

---

## 23. Immediate Next Actions

1. Create a sample app repo or sample module in an existing playback sandbox.
2. Add synthetic frame fixtures.
3. Implement `ViewportClassification`.
4. Implement metadata preclassification.
5. Implement a pure Swift layout engine with unit tests.
6. Build the coordinator state reducer with tests.
7. Add a debug screen that can run without real playback.
8. Add real playback only after the pure components are testable.

---

---

## Caption Persistence Model

Caption Theater should not preview future subtitles. The core behavior should be **persistence**: keep already-presented caption information available longer when there is safe reading space, without revealing text that has not yet occurred in the program.

This is an important product distinction.

### Product Rule

> Caption Theater may persist past and current cues. It must not reveal future cues by default.

The value is not prediction. The value is additional reading time, context, and scanability for text the viewer has already been allowed to see.

### Persistence Policies

```swift
enum CaptionPersistencePolicy: Sendable {
    case authoredTimingOnly
    case retainExpiredCueBriefly
    case retainRecentCueHistory
    case pauseOnlyHistory
    case transcriptPanelOnly
}
```

Recommended MVP:

```swift
let defaultPersistencePolicy: CaptionPersistencePolicy = .retainExpiredCueBriefly
```

This means:

- The current cue appears during its authored time.
- When it expires, it may remain visible briefly in a visually de-emphasized style.
- Once a new cue appears, the renderer can keep a small recent history if space allows.
- The retained cue must clearly look historical, not current speech.
- The renderer never shows text from a cue whose start time is in the future.

### Generalized Cue History

Instead of designing around “previous/current/next,” model the caption region as a small rolling history of already-eligible cue fragments.

```swift
struct CaptionPersistenceWindow: Sendable {
    let currentPlaybackTime: CMTime
    let retainedCues: [RenderedCaptionCue]
    let maximumCueAge: CMTime
    let maximumVisibleCueCount: Int
    let allowsFutureCues: Bool
}
```

Default:

```swift
let allowsFutureCues: Bool = false
```

### Retention Constraints

Persistence should be bounded and conservative.

Recommended initial constraints:

- Keep no more than 1–3 recent cues.
- Expire retained cues after a short configured age.
- Clear history on seek, track change, audio change, ad boundary, discontinuity, or asset transition.
- Do not retain legal, ad disclosure, forced narrative, sign translation, lyric, or unknown-intent cues unless explicitly allowed.
- Do not retain cues across a pause ad or promo boundary.
- Do not allow retained text to cover controls or active picture.
- Do not retain text if the user disables captions or switches caption tracks.

### Cue Intent and Persistence

Persistence should vary by cue intent.

| Cue Intent | Default Persistence |
|---|---|
| Dialogue | Allowed when text-based and safe |
| Speaker identification | Allowed with dialogue cue |
| Sound effect / SDH | Allowed briefly when part of accessibility caption |
| Music / lyrics | Authored timing only by default |
| Forced narrative | Authored timing only by default |
| Sign / on-screen text translation | Authored timing only by default |
| Legal disclosure | Authored timing only |
| Ad disclosure | Authored timing only; ad policy wins |
| Sports/news lower third | Native/preserve authored layout |
| Unknown | Authored timing only |

### Pause Behavior

On pause, Caption Theater may preserve the current persisted caption history because the viewer has intentionally paused playback.

Rules:

- Pause should freeze the visible cue state.
- Pause promos must not cover persisted captions.
- Scrubbing should clear or rebuild history from the scrubbed time.
- Resume should continue from the live cue timeline and age out retained cues normally.

### Why This Avoids the Main Preview Risk

Future subtitle display can spoil content, reveal jokes before delivery, expose sports results before the viewer sees them, or break dramatic timing. Persistence avoids that by using only text that has already entered the viewer’s timeline.

This makes Caption Theater closer to a readability/accessibility enhancement than a transcript preview feature.

## 24. Final Product Recommendation

Caption Theater is worth prototyping because it has a clear accessibility value proposition and a technically plausible path on Apple platforms. The riskiest parts are not the top-justified layout itself; the riskiest parts are:

- safely identifying unused regions,
- preserving subtitle semantics,
- avoiding ad/promo conflicts,
- integrating with native player behavior,
- handling protected and variable content.

The right proof of concept should therefore be modular, test-heavy, and conservative. Do not start by building a polished player. Start by proving detection, layout, state transitions, and subtitle rendering independently. Then integrate them into a sample app only after the core decisions are observable and testable.

---

## Actionable POC Execution Reference

This document is now aligned with `Caption-Theater-Showcase-and-Execution-Plan.md`.

Execution priority:

1. Build a controlled demo that shows the readability benefit.
2. Implement pure, testable modules before platform polish.
3. Use fixture manifests, fixture subtitles, synthetic frames, and local video before real streams.
4. Prove fail-closed behavior with unsafe examples.
5. Only then test real HLS/TS, DRM, DAI/SSAI, pause promos, tvOS, and macOS.

Feature-complete POC requires:

- persistent cue rendering with no future cue display,
- detector evidence and fallback reasons,
- manifest/subtitle/ad evidence model,
- custom layout engine,
- debug inspector,
- before/after showcase clips,
- unit tests for detection, layout, state transitions, and cue persistence,
- UI smoke tests for enable/disable, pause/resume, seek, and fallback states.
