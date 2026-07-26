# Caption Theater Technical Architecture Reference

This document holds the modular-architecture sketch, policy tables, and state models referenced from the top-level [`README.md`](../README.md). It complements — rather than replaces — the formal architecture decision records:

- [`ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md`](../ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md) is the authoritative decision record for viewport/layout architecture, detection strategy, and rollout phasing.
- [`ADR-0002-Multi-Speaker-Caption-Presentation.md`](../ADR-0002-Multi-Speaker-Caption-Presentation.md) covers multi-speaker caption presentation decisions.

Where this document and an ADR disagree on naming or detail, the ADR wins — this file is a working design reference, not a decision record. For **current, git-status-groomed implementation status**, see [`TASKS.md`](../TASKS.md) — this document describes the target architecture, not necessarily what's shipped today.

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
- shared core module compatibility;
- offline HLS fixture playback;
- native menu-bar aspect presets for 4:3, 16:9, 21:9, 2.39:1, and source aspect.

### Documentation alignment

Earlier drafts described iOS as the first integrated POC host. **Repository reality is tvOS-first.** Shared parsing and eligibility logic stay platform-neutral so iOS and macOS targets can adopt the same modules later.

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
