

# Caption Theater

Caption Theater transforms the unused space around cinema-aspect-ratio video into a premium, unobstructed reading area for captions.

Many ultra-widescreen films and shows are presented on 16:9 screens with black letterbox space above and below the active picture. Caption Theater uses that otherwise empty space to give subtitles and captions more room, more dwell time, and more context without covering the image. Instead of forcing viewers to choose between watching the scene and racing to read dense text, the active picture can shift into a theater-style layout while recent caption cues persist in the open lower region.

The result is a cleaner caption experience for fast dialogue, translated subtitles, SDH cues, and living-room viewing: captions become easier to scan, less likely to obstruct the content, and less likely to force viewers into rewind-and-replay loops.

The project explores how to build this as a modular playback add-on for native iOS, tvOS, and macOS players using AVFoundation, AVKit-adjacent integrations, HLS metadata, timed-text analysis, active-picture layout, and runtime safety guardrails.

**Implementation note:** The Xcode repository currently ships native **tvOS** and **macOS** targets. The tvOS target remains the primary living-room prototype; the macOS target is a native demo/QA surface for offline HLS playback, Caption Theater layout review, and window aspect-ratio presets.

**Open source readiness note:** Caption Theater source code is licensed under Apache License 2.0. Third-party media, HLS segments, subtitle files, and copied public-stream content may have separate terms. Before changing this repository to public visibility, review `Docs/OpenSourceReleaseChecklist.md` and either confirm redistribution rights for retained media or remove/replace those assets. The generated widescreen fixture is project-owned and intended to be the safe default demo asset.

**POC media note:** Any downloaded third-party media, HLS segments, subtitle files, or copied public-stream content in this repository is for private proof-of-concept use only unless its license and attribution terms explicitly allow broader redistribution. The bundled offline HLS mock should not be treated as release media without a separate rights review.

---

## License

Caption Theater source code is licensed under the Apache License, Version 2.0. See `LICENSE` and `NOTICE`.

Third-party media and sample assets are not automatically covered by the source license. See `THIRD_PARTY_NOTICES.md` and `Docs/OpenSourceReleaseChecklist.md` before publishing, redistributing, or packaging demo media.

---

## Developer Demo Controls

Launch arguments can preselect demo and engineering settings:

```text
--caption-theater-offline-hls
--caption-theater-generated-hls
-CaptionTheater.playbackDemoSource bundledGeneratedWidescreenFixture
--caption-theater-playback-demo-source=bundledGeneratedWidescreenFixture
--caption-theater-playback-debug-hud=yes
-CaptionTheater.playbackDebugHUD YES
--caption-theater-playback-layout-border=yes
--caption-theater-mac-startup-aspect=twentyOneByNine
```

Available demo media raw values:

- `bundledGeneratedWidescreenFixture`
- `muxTearsOfSteelHLS`
- `bundledOfflineHLSMock`
- `bundledSyntheticSample`

`bundledGeneratedWidescreenFixture` uses the repo-owned no-audio HLS package under `CaptionTheater/CaptionTheater/Media/OfflineHLS/CaptionTheaterGeneratedWidescreenFixture/`. It contains 1920x800 generated video plus timed WebVTT captions for offline layout and caption QA.

`bundledOfflineHLSMock` pointed at a private, Mux-derived five-minute HLS package under `CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`. That media has been removed from the public repository (redistribution rights were never cleared); the demo source still exists in code and fails closed with a missing-resource placeholder. Regenerate it locally with `Scripts/download_mux_offline_hls_mock.py` if you need it for private testing — see `Docs/Sources.md` and `THIRD_PARTY_NOTICES.md`.

---

## Product Thesis

> Caption Theater turns unused cinema letterbox space into a dedicated caption reading area, giving viewers longer-lasting subtitle context without covering the active picture.

When ultra-widescreen content leaves empty space on a 16:9 display, Caption Theater can make that space useful. The feature preserves the cinematic image, moves eligible content into a deliberate theater-style layout, and gives captions a larger region where recent cues can remain visible long enough to be read comfortably.

The feature is designed around three product values:

1. **Readable dwell time**  
   Captions that have already appeared can remain visible briefly so users have more time to scan them.

2. **Context preservation**  
   The active picture remains visible and undistorted while recent caption context stays available in a stable reading region.


3. **Trustworthy fallback**  
   If the system cannot prove the experience is safe, it returns to native playback and native caption behavior.

### First Demo Scenario

The first showcase targets ultra-widescreen content playing on a 16:9 screen.

When eligible content is detected, the viewer is prompted to enter Caption Theater mode. If accepted, the active picture transitions from centered presentation to top-aligned presentation, preserving the correct aspect ratio while creating a larger lower reading region for captions. Current and recently presented captions can use that region to provide more readable dwell time and context during fast dialogue.

Ads continue to play normally in fullscreen/native presentation. Caption Theater suspends during ad playback and resumes or revalidates when content playback returns.

---

## Why This Matters

Native subtitles often disappear as soon as their authored cue timing ends, and they commonly sit on top of the picture. That behavior is correct for synchronization, but it can be hard for viewers when captions are dense, translated, fast-moving, or visually competing with important content.

Caption Theater is intended to help viewers who:

- rely on closed captions or SDH captions;
- watch translated subtitles that expand beyond the spoken phrase length;
- watch fast dialogue, documentaries, educational content, news, or technical content;
- watch from living-room distances on tvOS;
- need more time to scan short-lived captions;
- want to avoid repeated rewinds just to recover recently missed subtitle context.

The goal is not to turn subtitles into a transcript wall. The goal is to use otherwise empty cinema-layout space to preserve a small, bounded window of already-presented timed text, giving viewers a cleaner and more forgiving way to read captions while the picture remains unobstructed.

---

## Core Rules

1. Persist already-presented cues; do not reveal future cues by default.
2. Treat subtitle and caption text as meaningful content, not decoration.
3. Use verified inactive screen space only when it is safe.
4. Keep the active picture visible, undistorted, and aligned with the authored playback timeline.
5. Separate viewport eligibility from subtitle-format eligibility.
6. Return to native playback for unsafe, unsupported, ad, or uncertain states, then resume or revalidate when content playback returns.
7. Keep the feature opt-in, reversible, measurable, and explainable.
8. Prove the user value with controlled fixtures before attempting production integration.

---

## What Caption Theater Does

Caption Theater can:

- detect active picture boundaries in non-DRM test content;
- classify whether a visual region is likely inactive and safe;
- use provider metadata or QC metadata when pixel analysis is unavailable;
- create a stable reading region when safe inactive display space exists;
- prompt the viewer before entering Caption Theater mode for eligible ultra-widescreen content;
- render current caption cues and retain recently expired cues briefly;
- visually distinguish current cues from retained historical cues;
- reset caption history on seek, track change, audio change, ad boundary, discontinuity, or asset transition;
- explain activation or fallback reasons in debug tooling;
- suspend itself around ad pods, pause promos, unknown ad states, unsafe regions, or unsupported formats.

---

## What Caption Theater Avoids

Caption Theater should not:

- reveal future dialogue by default;
- stretch, crop, or distort the active picture;
- assume black bars are unused;
- move or reflow burned-in subtitles;
- convert image subtitles to text using OCR in production playback;
- alter fullscreen/native ad presentation, legal disclosures, QR codes, CTAs, or measurement overlays;
- persist legal, ad, lyric, forced narrative, or unknown-intent cues unless explicitly allowed;
- depend on raw frame access for DRM-protected playback;
- replace the full native player stack before the core behavior is proven.

---

## Platform Goals

### tvOS (current Xcode target)

The repository begins with **tvOS** because living-room viewing is a primary readability scenario.

Near-term engineering goals:

- SwiftUI host shell with stable playback controls on Siri Remote;
- integrate modular Caption Theater components behind fixture-backed eligibility decisions;
- VoiceOver and focus-safe overlays;
- overscan-aware layout;
- pause promo and native-control coexistence policies validated against fixtures.

Longer-term validation (may overlap Phase 7):

- remote ergonomics;
- avoiding unintended focus traps in caption surfaces unless intentionally designed.

### iOS (roadmap)

The **iOS** proof of concept remains the strongest handheld stakeholder demo path:

- local video playback;
- custom `AVPlayerLayer` container;
- fixture subtitle rendering;
- Caption Theater enable/disable toggle;
- debug overlay;
- pause/resume/seek behavior;
- native fallback for unsafe fixtures.

### macOS (current QA target)

macOS validation focuses on:

- resizable player windows;
- full-screen playback;
- keyboard shortcuts;
- backing scale changes;
- shared core module compatibility.
- offline HLS fixture playback;
- native menu-bar aspect presets for 4:3, 16:9, 21:9, 2.39:1, and source aspect.

---

### Documentation alignment

Earlier drafts described iOS as the first integrated POC host. **Repository reality is tvOS-first.** Shared parsing and eligibility logic stay platform-neutral so iOS and macOS targets can adopt the same modules later.

---

## Technical Strategy
Caption Theater should be built as modular playback infrastructure rather than a monolithic custom player.

```text
+---------------------------------------------------------------+
|                       Host Playback App                       |
+--------------------------+------------------------------------+
                           |
                           v
+---------------------------------------------------------------+
|                 CaptionTheaterCoordinator                     |
|  - Owns lifecycle wiring across playback sources               |
|  - Consumes playback state, ad state, subtitle state           |
|  - Applies eligibility snapshots / decision-engine outputs      |
|  - Publishes layout mode and caption mode                      |
+-----+-------------------+-------------------+-----------------+
      |                   |                   |
      v                   v                   v
+-------------+   +----------------+   +------------------------+
| Viewport    |   | Subtitle       |   | Ad / Promo             |
| Analyzer    |   | Eligibility    |   | Coordinator            |
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

## Core Components

### `CaptionTheaterCoordinator`

Coordinates playback-facing presentation from **stateless eligibility decisions** (for example `CaptionTheaterDecisionEngine` outputs), timers, and host-player events—not an internal reducer graph.

Responsibilities:

- combine viewport, subtitle, ad, user-setting, and platform evidence into snapshots for evaluation;
- publish the current presentation mode;
- cancel in-flight work when playback state changes;
- fail closed for unsafe or unknown states;
- emit debug and analytics events.

Suggested model:

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

> Concurrency requirement: state transitions should be isolated in an actor or otherwise made deterministic and thread-safe. UI presentation must be applied on the main actor.

### `ViewportAnalyzer`

Determines whether there is safe inactive screen space.

Responsibilities:

- read presentation size and track metadata;
- classify encoded raster and likely active picture type;
- sample frames where allowed;
- detect active picture bounds;
- detect unsafe use of proposed inactive regions;
- produce confidence-scored evidence.

Suggested model:

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

### `FrameSampler`

Performs bounded frame sampling for non-DRM or test content.

Responsibilities:

- attach `AVPlayerItemVideoOutput` when supported;
- sample a small number of frames;
- reduce frames to luminance, edge, and motion metrics;
- avoid storing raw frames;
- avoid blocking playback startup.

DRM policy:

> Caption Theater must not depend on raw frame access for DRM-protected playback. For protected content, eligibility must come from trusted metadata, provider-side analysis, or explicit allowlisting.

### `SubtitleEligibilityService`

Determines whether the selected subtitle source can support persistence.

Responsibilities:

- identify subtitle transport kind;
- identify text-based vs. image-based formats;
- classify cue intent where possible;
- decide whether cue persistence is safe;
- preserve authored layout for risky cue types.

### `CaptionPersistenceRenderer`

Renders current and recently expired cues.

Responsibilities:

- render current cue during authored timing;
- retain recently expired cues briefly when safe;
- visually de-emphasize retained cues;
- bound retention by age and cue count;
- avoid showing future cues;
- reset history at playback and track boundaries.

Suggested model:

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

Default:

```swift
let allowsFutureCues: Bool = false
```

### `AdPlaybackViewportCoordinator`

Ensures monetization and legal surfaces remain safe.

Responsibilities:

- consume ad lifecycle state;
- force native presentation during linear ad pods;
- suppress or safely place pause promos;
- fail closed when ad state is unknown;
- require content revalidation after ad exit.

### `TopJustifiedPlayerView`

Applies the final video and caption layout.

Responsibilities:

- host `AVPlayerLayer`;
- apply native or Caption Theater geometry;
- keep layout updates on the main actor;
- expose a debug overlay;
- provide thin platform adapters for iOS, tvOS, and macOS.

---

## Evidence-Based Eligibility

Caption Theater should not use a single boolean like `isLetterboxed`. It should make a decision from multiple evidence sources.

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

Rule:

> `uncertain` means native playback.

---

## Aspect Ratio Policy

Caption Theater should classify all aspect ratios, but only activate when there is a safe, useful reading region.

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

| Classification | MVP Behavior | Future Behavior |
|---|---|---|
| Full-frame 16:9 | Native captions only | Optional transcript or reading panel |
| Cinematic letterbox | Primary target | Expanded bottom reading region |
| 4:3 pillarbox | Detect but do not reflow | Possible side-panel mode after UX research |
| Windowboxed | Ineligible by default | Allowlist only |
| Square/vertical | Ineligible by default | Future layout research |
| Variable aspect ratio | Ineligible automatic mode | Segment-aware mode only with trusted timeline metadata |
| Unknown | Native | None |

---

## Subtitle Format Policy

### WebVTT

First implementation candidate.

Why:

- text-based;
- explicit cue timing;
- cue positioning support;
- commonly used with HLS;
- easier to adapt into an internal cue model.

Architecture requirement:

- WebVTT can render first, but the cue model should be broad enough to support the main subtitle and caption formats over time.

### IMSC / TTML

Strong future candidate.

Why:

- rich styling and regions;
- text-profile support;
- delivery-oriented subtitle format.

Risk:

- more complex layout semantics;
- image-profile subtitles are not reflow-friendly.

### CEA-608 / CEA-708

Important accessibility format, but not a naive MVP reflow target.

Risks:

- roll-up/pop-on semantics matter;
- placement can be meaningful;
- native rendering may be the safest initial behavior.

### Burned-In Subtitles

Not eligible for persistence or reflow.

Burned-in subtitles are pixels inside the video image. Caption Theater should not attempt to move, OCR, duplicate, or extend them during production playback.

### Image-Based Subtitles

Native/fixed-placement by default.

Do not convert image subtitles to text with OCR in production playback unless a separate trusted text representation exists.

---

## Cue Intent Policy

Subtitle text can represent many different kinds of content.

```swift
enum CaptionCueIntent: Sendable {
    case dialogue
    case speakerIdentification
    case soundEffect
    case musicOrLyrics
    case forcedNarrative
    case signOrOnScreenText
    case legalDisclosure
    case adDisclosure
    case sportsOrNewsLowerThird
    case unknown
}
```

| Cue Intent | Default Persistence |
|---|---|
| Dialogue | Allowed when text-based and safe |
| Speaker identification | Allowed with related dialogue cue |
| Sound effect / SDH | Allowed briefly when part of accessibility caption |
| Music / lyrics | Authored timing only by default |
| Forced narrative | Authored timing only by default |
| Sign / on-screen text translation | Authored timing only by default |
| Legal disclosure | Authored timing only |
| Ad disclosure | Authored timing only; ad policy wins |
| Sports/news lower third | Native or preserve authored layout |
| Unknown | Authored timing only |

---

## HLS and Metadata Strategy

`.m3u8` metadata is useful evidence, but it cannot prove visual safety by itself.

Useful HLS metadata includes:

- `EXT-X-STREAM-INF` for variants, resolution, codecs, and rendition groups;
- `EXT-X-MEDIA` for audio, subtitle, and closed-caption groups;
- `FORCED`, `DEFAULT`, `AUTOSELECT`, `LANGUAGE`, `ASSOC-LANGUAGE`, and `CHARACTERISTICS` for subtitle and audio hints;
- `EXT-X-DISCONTINUITY` for revalidation boundaries;
- `EXT-X-DATERANGE` for timed metadata and possible ad/splice markers;
- `EXT-X-KEY` and `EXT-X-SESSION-KEY` for encrypted playback signals.

Metadata can help answer:

- Are selectable subtitles declared?
- Are captions embedded or sidecar?
- Is a subtitle track forced?
- Is the stream encrypted?
- Are there discontinuity or ad-like boundaries?
- What is the encoded raster size?

Metadata usually cannot answer:

- Are letterbox bars visually empty?
- Are subtitles burned into the video?
- Is black space creative content?
- Does the title change aspect ratio later?
- Are legal disclosures or watermarks in the inactive region?

Production-quality DRM support likely requires provider-side QC metadata.

Example provider metadata:

```json
{
  "captionTheater": {
    "policy": "eligible",
    "source": "provider-qc",
    "confidence": 0.99,
    "supportsPersistence": true,
    "allowedLayouts": ["expandedBottomRegion"],
    "notes": [
      "stable-letterbox",
      "no-burned-in-subtitles",
      "no-variable-aspect"
    ]
  }
}
```

---

## Ad and Promo Policy

Ads and promos are hard boundaries for Caption Theater.

### Linear Ad Pods

Linear ads should force native playback presentation.

Rules:

- ad pod start immediately suspends Caption Theater;
- unknown ad state fails closed;
- active analysis is cancelled or ignored;
- Caption Theater revalidates content after ad exit;
- ad captions, legal disclosures, QR codes, CTAs, and measurement overlays are not altered.

### DAI / SSAI

Dynamic ad insertion and server-side ad insertion may not create a new player item. Caption Theater must treat ad markers, discontinuities, and ad lifecycle callbacks as segment-level state.

Rules:

- do not carry layout eligibility across suspected ad boundaries;
- suspend around unknown discontinuities;
- require host-app ad state when available;
- never rely only on pixel detection to identify ads.

### Pause Ads and Promos

Pause promos are overlay policy, not playback-layout policy.

Rules:

- captions have priority over pause promos;
- pause promos should be suppressed when they would cover current or retained captions;
- resume, seek, scrub, back, or subtitle-menu interactions dismiss pause promos;
- pause promo suppression reasons should be logged.

---

## State Machine

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

Important transitions:

| Event | Next State | Reason |
|---|---|---|
| User enables mode | `analyzing` | Start eligibility |
| Eligible space + supported subtitles | `active` | Caption Theater can run |
| Ad pod starts | `suspendedForAdPod` | Ads override |
| Ad pod ends | `analyzing` | Revalidate content |
| Unknown ad state | `failedClosed` | Safety unknown |
| Unsafe region evidence appears | `suspendedForUnsafeRegionUse` | Visual region no longer safe |
| Variable aspect ratio detected | `suspendedForVariableAspect` | Avoid layout flicker |
| Unsupported subtitle format | `suspendedForUnsupportedSubtitleFormat` | Cannot preserve semantics |
| Protected content without trusted metadata | `suspendedForProtectedContent` | Cannot verify visual safety |
| User disables mode | `off` | User control wins |

---

## Testing Strategy

### Unit Tests

Detection:

- detects known letterbox regions;
- rejects full-frame 16:9;
- rejects dark-scene false positives;
- rejects burned-in subtitles in proposed inactive regions;
- rejects variable active-picture boundaries;
- emits confidence and evidence.

Layout:

- preserves aspect ratio;
- avoids crop and stretch;
- handles safe areas;
- simulates tvOS overscan;
- recomputes on size changes;
- returns native layout for 16:9.

Coordinator:

- user disable wins;
- ad state wins;
- unknown state fails closed;
- subtitle changes reset history;
- seek resets history;
- unsafe evidence suspends mode.

Caption persistence:

- current cue appears during authored time;
- expired cue can persist briefly;
- future cue is never displayed;
- retained cue is visually distinct;
- legal/ad/forced/lyrics/unknown cues do not persist by default;
- history clears on required boundaries.

### Snapshot Tests

- native captions;
- Caption Theater active;
- retained cue state;
- large caption text;
- pause with persisted captions;
- pause promo suppressed;
- debug overlay.

### UI Tests

iOS:

- enable/disable Caption Theater;
- pause/resume;
- seek;
- rotate;
- switch subtitle track;
- verify fallback label/debug reason.

tvOS:

- remote play/pause;
- focus movement;
- scrub;
- VoiceOver smoke test;
- pause promo suppression.

macOS:

- resize;
- full screen;
- keyboard controls;
- caption overlay stability.

---

## Roadmap

### MVP 0: Fixtures and Debug Harness

Goal: create deterministic test inputs.

Deliverables:

- synthetic frame fixtures (future);
- WebVTT fixtures (within subtitle-metadata fixtures today; expanded cues later);
- HLS manifest fixtures;
- provider metadata fixtures;
- expected-result documentation (`Docs/Fixture-Inventory.md`);
- debug inspector shell.

### MVP 1: Evidence Model and Decision Engine

Goal: make every eligibility decision explainable.

Deliverables:

- evidence model;
- eligibility snapshots feeding a **pure decision engine**;
- deterministic transitions documented through snapshots plus coordinator glue (no reducer framework requirement);
- fallback reasons;
- unit tests.

### MVP 2: Manifest and Metadata Inspector

Goal: understand what HLS and metadata can tell us.

Deliverables:

- manifest parser fixtures;
- subtitle transport classification;
- forced subtitle detection;
- discontinuity/ad-risk evidence;
- DRM-risk evidence;
- debug inspector output.

### MVP 3: Viewport Detection

Goal: determine whether proposed inactive regions are safe enough.

Deliverables:

- metadata preclassification;
- pixel region detector;
- unsafe evidence detection;
- confidence scoring;
- detector tests.

### MVP 4: Layout Engine

Goal: compute native and Caption Theater geometry.

Deliverables:

- native layout;
- expanded bottom region layout;
- safe-area handling;
- overscan simulation;
- layout tests.

### MVP 5: Caption Persistence Renderer

Goal: render already-presented cues with bounded persistence, starting with WebVTT while keeping the model extensible for the main subtitle/caption formats.

Deliverables:

- cue model;
- WebVTT adapter;
- persistence window;
- renderer view;
- snapshot tests.

### MVP 6: End-to-End Showcase Demo

Goal: prove the user value in a controlled showcase.

Deliverables:

- playable **tvOS** sample (this repo today); optional **iOS** sample when a second target exists;
- native vs. Caption Theater mode;
- eligible fixture;
- unsafe fixtures;
- debug overlay;
- before/after demo script.

### MVP 7: Ad and Promo Simulation

Goal: prove that ads continue to play normally fullscreen/native while Caption Theater suspends and resumes or revalidates around ad playback.

Deliverables:

- ad pod simulator;
- unknown ad state simulator;
- pause promo simulator;
- revalidation after ad exit;
- tests.

### MVP 8: Additional Platform Feasibility

Goal: validate cross-platform potential beyond the tvOS-first host.

Deliverables:

- macOS wrapper and optional **iOS** target feasibility;
- **tvOS** focus and remote QA;
- resize and full-screen QA;
- feasibility report.

---

## Recommended Immediate Sprint

Sprint goal:

> Build the non-playback foundation that makes Caption Theater explainable and testable.

Tickets:

1. Maintain fixture inventory (`Docs/Fixture-Inventory.md`) as new deterministic inputs land.
2. Implement evidence model wiring into playback-facing coordinators as modules stabilize.
3. Treat eligibility updates as **snapshot + decision-engine** evaluation (see `CaptionTheaterDecisionEngine`).
4. Extend manifest and metadata inspectors as new edge cases appear.
5. Implement layout engine with fake analysis input.
6. Implement caption persistence window with WebVTT fixture cues and an extensible internal cue model.
7. Build debug inspector with fake/fixture data.

Acceptance criteria:

- no AVPlayer dependency is required for core tests;
- fixture decisions are deterministic;
- debug inspector explains eligibility;
- future cue display is impossible by default;
- uncertainty always returns native fallback.

---

## Showcase Plan

The showcase should make the benefit obvious before explaining the technology.

Demo flow:

1. Show native captions during dense dialogue.
2. Show the cue disappearing before the viewer can finish scanning it.
3. Replay the same clip with Caption Theater.
4. Show the already-presented cue persisting briefly in a stable reading region.
5. Emphasize that no future cue is shown.
6. Show one unsafe fallback case.
7. Show ad or pause promo fallback.
8. Show debug evidence briefly.

Hero clip requirements:

- 15–30 seconds;
- sidecar WebVTT subtitles;
- dense translated or SDH-style captions;
- verified inactive display region;
- no burned-in subtitles;
- no ad overlays;
- no variable aspect ratio.

Success criteria:

- the viewer can read more comfortably;
- the viewer does not need to rewind as much;
- the active picture remains visible;
- retained text is clearly historical;
- no future content is revealed;
- unsafe cases visibly fail closed.

---

## Production Readiness Criteria

Caption Theater is production-candidate only when:

- representative HLS/TS streams are tested;
- DRM path uses trusted metadata or allowlisting;
- real ad lifecycle integration exists;
- real subtitle pipeline integration exists;
- native/custom caption duplication is prevented;
- accessibility settings are honored as much as technically possible;
- platform QA passes for iOS, tvOS, and macOS targets;
- analytics and remote kill switch exist;
- content, legal, ads, accessibility, and product stakeholders approve rollout constraints.

---

## Known Risks

| Risk | Impact | Mitigation |
|---|---|---|
| Burned-in subtitles in black bars | False safe region | Pixel detection for non-DRM, provider metadata for DRM |
| DRM blocks frame analysis | Cannot verify pixels | Trusted metadata, allowlist, or native fallback |
| Subtitle semantics lost | Accessibility regression | Cue intent policy and authored-layout preservation |
| Future text revealed | Spoiler/timing regression | Future cues disabled by default |
| Ads altered | Brand/legal/measurement risk | Ads force native presentation |
| Pause promos cover captions | Accessibility conflict | Captions win; promos suppressed or moved |
| Variable aspect ratio | Layout flicker or creative-intent risk | Suspend unless trusted timeline metadata exists |
| tvOS focus issues | Usability regression | Passive overlays and focus testing |
| Native controls overlap captions | Player regression | Control-aware layout and fallback |
| Manifest metadata overtrusted | Unsafe activation | Evidence model; manifest cannot prove visual safety |

---

## Project Status

Current status: **tvOS-first codebase** with deterministic **fixture-backed** parsing and eligibility modules (`CaptionTheaterDecisionEngine`, `HLSManifestInspector`, `ProviderMetadataInspector`, `SubtitleMetadataClassifier`) covered by unit tests. Playback integration and viewport detection remain ahead.

Next recommended action:

1. Keep fixtures documented in `Docs/Fixture-Inventory.md`.
2. Introduce `CaptionTheaterCoordinator` wiring on tvOS behind fixture playback.
3. Build viewport preclassification and bounded pixel analysis for safe regions.
4. Build caption persistence renderer on WebVTT fixtures.
5. Build layout engine.
6. Deliver tvOS end-to-end showcase; add iOS target when ready.

---

## License

TBD.
