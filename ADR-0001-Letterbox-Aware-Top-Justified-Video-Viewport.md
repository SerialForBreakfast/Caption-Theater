# ADR-0001: Active-Picture-Aware Viewport and Subtitle Space Optimization

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
Status: Proposed  
Platforms: iOS, tvOS, macOS  
Owners: Playback, Accessibility, Captioning, Client Platform  
Related Areas: AVFoundation, AVKit, HLS/TS playback, subtitle rendering, accessibility, localization  
**Implementation alignment (2026-05-05):** The Caption Theater Xcode project currently ships **tvOS-only** targets. ADR integration guidance remains platform-neutral; the first integrated shell should assume **tvOS** unless/until additional targets are added.

---

## Context

Video assets may use many presentation patterns: full-frame 16:9, cinematic widescreen letterbox such as 2.31:1/2.35:1/2.39:1, classic 4:3 pillarbox, square/vertical video, mixed-aspect programming, credits with side panels, or variable-aspect-ratio titles that switch between formats. On a fixed player viewport, inactive black or near-black regions may appear above, below, left, or right of the active picture. In some cases those regions are merely padding; in others they are intentionally used for creative composition, subtitles, burnt-in translations, credits, logos, UI, archival framing, or aspect-ratio transitions.

For users who rely on subtitles, closed captions, SDH, translated subtitles, or dense ephemeral text cues, the bottom letterbox area is valuable space. If the active picture can be top-justified while preserving aspect ratio, the lower unused region can provide more readable caption layout space. This could allow longer cue text, larger caption styling, better multi-line wrapping, and longer perceptual scan time without obscuring important picture content.

The goal is to explore a native Apple-platform playback add-on that detects the active picture region for any aspect ratio, determines whether unused regions are truly safe to repurpose, and optionally repositions eligible content so captions can use available inactive space more effectively. For widescreen letterboxed content this usually means top-justifying the active picture and using the bottom region for captions. For pillarboxed, 4:3, square, vertical, or variable-aspect content, the feature may choose a different behavior or do nothing.

This ADR intentionally treats the feature as user-selectable and accessibility-oriented. It should not change the default creative presentation unless enabled by the user, a feature flag, or a title-specific experiment.

---

## Problem Statement

Native AVKit playback is optimized for standard player behavior. `AVPlayerViewController` and `AVPlayerLayer` expose video gravity options such as aspect-fit, aspect-fill, and stretch, but they do not provide a first-class “preserve aspect ratio, remove redundant letterbox space, top-align active picture, and reserve bottom caption region” mode.

We need an architecture that can:

1. Detect whether the content contains meaningful letterbox bars.
2. Determine whether the active picture is wide enough to benefit from top-justification.
3. Preserve original image geometry without stretching or unintended cropping.
4. Create a bottom caption-safe region when appropriate.
5. Work across iOS, tvOS, and macOS.
6. Avoid breaking native player controls, AirPlay, PiP, accessibility, subtitles, closed captions, HDR, FairPlay/DRM, and HLS playback.
7. Remain opt-in and easy to disable.

---

## Decision

Adopt a feature-gated **Active-Picture-Aware Viewport Mode** implemented as a playback add-on with three operating levels:

### Level 1: Active Picture Detection and Safety Classification

Detect wide letterboxed content and expose a capability result:

```swift
struct LetterboxViewportAnalysis: Sendable {
    let isEligible: Bool
    let confidence: Double
    let detectedActiveVideoRect: CGRect
    let sourcePresentationSize: CGSize
    let estimatedActiveAspectRatio: CGFloat
    let detectedPaddingRegions: EdgeInsets
    let aspectMode: ActivePictureAspectMode
    let safetyClassification: ViewportSafetyClassification
    let recommendedCaptionRegions: [CaptionRegionCandidate]
}
```

Suggested model types:

```swift
/// Describes the dominant active-picture shape detected for the current playback window.
///
/// This value is derived from metadata and bounded frame sampling. It must not be treated as a
/// permanent asset-level truth unless the classifier has observed stability across representative
/// playback windows.
enum ActivePictureAspectMode: Sendable, Equatable {
    case fullFrame16x9
    case cinematicWide(estimatedRatio: CGFloat)
    case standard4x3
    case square
    case vertical(estimatedRatio: CGFloat)
    case pillarboxed(estimatedRatio: CGFloat)
    case letterboxed(estimatedRatio: CGFloat)
    case windowboxed(estimatedRatio: CGFloat)
    case variable(observedModes: [String])
    case unknown
}

/// Describes whether inactive-looking regions are safe to use for caption layout.
///
/// `.safeToRepurpose` should require stable inactive regions, no detected visual content in those
/// regions, and no evidence of upcoming aspect-ratio transitions. `.unsafeIntentionalUse` and
/// `.variableAspectRatio` must force fallback to native centered presentation.
enum ViewportSafetyClassification: Sendable, Equatable {
    case safeToRepurpose
    case unsafeIntentionalUse(reason: String)
    case variableAspectRatio
    case insufficientConfidence
    case protectedPlaybackUnavailable
    case unsupportedCaptionMode
}

/// Represents a possible caption placement region created by inactive space around active picture.
///
/// The region is a candidate, not a command. The caption renderer still needs to account for
/// safe areas, system caption settings, playback controls, focus overlays, and language-specific
/// line wrapping behavior.
struct CaptionRegionCandidate: Sendable, Equatable {
    let frame: CGRect
    let edge: CaptionRegionEdge
    let confidence: Double
}

enum CaptionRegionEdge: Sendable, Equatable {
    case top
    case bottom
    case leading
    case trailing
}
```

Level 1 does not alter playback. It allows logging, experimentation, QA validation, title allowlisting, blocklisting, variable-aspect detection, and UI affordance discovery.

### Level 2: Optional Viewport Repositioning with Caption Region

When enabled, the player presents active video content in a safer layout that preserves geometry while exposing a caption region. For cinematic letterbox this can top-align the active picture and reserve lower inactive space. For 4:3 or pillarboxed content, this should generally avoid lateral caption placement unless the caption experience has been explicitly designed for it. For 16:9 full-frame content, no active-picture repositioning should occur.

For captions, prefer a custom caption presentation layer for enhanced layouts when business/product requirements allow it. Continue supporting native AVKit caption selection where required, but recognize that native caption placement may not provide the layout control needed for this feature.

### Level 3: Adaptive Runtime Guardrails

Even after a title is classified as eligible, the feature must keep watching for aspect-ratio mode changes, creative use of the inactive regions, burnt-in captions, logos, credits, or UI that appear in those regions. When detected, the system must gracefully return to the default centered presentation or temporarily suspend the expanded caption layout.

---

## Non-Goals

- Do not stretch, crop, or distort the active picture.
- Do not globally replace native AVKit playback for all titles.
- Do not disable system accessibility features or user caption preferences.
- Do not force the feature on for all cinematic content.
- Do not attempt to infer creative intent beyond detecting unused letterbox regions.
- Do not modify source media.
- Do not burn subtitles into the video.

---

## Aspect Ratio Policy

The feature must support classification across all common aspect-ratio presentations, but support does not imply repositioning every case.

### Full-Frame 16:9

Default behavior: no repositioning.

Reasoning: there is no reliable inactive region to repurpose. Any caption expansion would overlap active picture content or require reducing/scaling the video, which is outside the MVP.

### Cinematic Widescreen / Letterboxed Content

Default behavior: eligible for top-justification only when the inactive top and bottom regions are stable and unused.

Examples:

- 2.31:1
- 2.35:1
- 2.39:1
- Similar wide theatrical ratios

Recommended layout: move active picture upward, preserve aspect ratio, and reserve a bottom caption region. Do not crop the active picture.

### 4:3 / Pillarboxed Content

Default behavior: classify, but do not automatically move captions into side bars for MVP.

Reasoning: side captions can be hard to read, may conflict with platform controls, and may create unusual scan patterns. Pillarbox detection is still useful because it prevents the system from mistaking side bars for available bottom subtitle space.

Possible future behavior: allow side-region supplemental metadata, sign-language video, or secondary cue presentation only after explicit design and accessibility validation.

### Square and Vertical Video

Default behavior: classify, but do not reposition unless product explicitly designs a layout for these formats.

Reasoning: vertical and square assets often intentionally use surrounding space for background art, app UI, creator graphics, or social-video framing. Treat unused-looking regions as unsafe until proven otherwise.

### Windowboxed Content

Default behavior: ineligible unless manually allowlisted.

Reasoning: windowboxed content may be archival, upscaled, or embedded inside a designed frame. The outer black regions may be part of the source presentation, and aggressive repositioning can make the content feel broken.

### Variable Aspect Ratio

Default behavior: ineligible for automatic repositioning.

Reasoning: some titles switch between 16:9, IMAX-like expanded scenes, cinematic letterbox, 4:3 archival footage, credits layouts, or mixed-media segments. A feature that moves the active picture based on one segment can become distracting or wrong when the aspect ratio changes.

Allowed behavior: temporary per-segment repositioning only if transitions are detected cleanly, the change is not visually disruptive, and QA/product explicitly approve that mode. MVP should avoid this.

---

## Intentional Use of Blank or Black Regions

The detector must assume black space may be intentional until proven safe. “Looks black” is not the same as “safe for captions.”

### Examples of Intentional Use

- Burnt-in subtitles or translations placed in a letterbox bar.
- Opening titles, intertitles, credits, or lower-third text.
- Logos, ratings bugs, broadcast marks, sports/event graphics, or watermarks.
- Split-screen or framed compositions.
- Archival footage intentionally presented inside a black frame.
- Variable-aspect-ratio sequences where bars appear and disappear.
- Very dark scenes where image detail exists near the edges.
- Director-approved compositions where vertical centering is part of presentation intent.

### Required Safety Heuristics

The system must reject or suspend expanded subtitle space when any of these are true:

1. The detected active picture rect changes materially over a short time window.
2. The bar regions contain text-like edges, logos, motion, or non-black structure.
3. The asset transitions between 16:9, 4:3, cinematic, or windowboxed modes.
4. The content contains burnt-in captions in or near the inactive region.
5. Confidence drops below threshold during playback.
6. Protected playback prevents verification and no trusted metadata/allowlist exists.
7. User/system caption settings require native rendering that cannot be safely repositioned.

### Runtime Fallback Behavior

Fallback must be graceful and non-jarring. Recommended behavior:

- Do not rapidly toggle layouts on and off.
- Require hysteresis before changing modes.
- Prefer returning to default centered playback at the next cue boundary, scene boundary, or player-control transition.
- Keep captions readable during the transition.
- Log the fallback reason using derived metadata only.

Suggested thresholds for experimentation:

- Enter expanded mode only after 5–12 stable samples.
- Exit expanded mode after 2–3 contradictory samples or one high-confidence unsafe-content detection.
- Cool down for at least 30–60 seconds after fallback before reconsidering.
- Never enter expanded mode during the first fade-in unless metadata/allowlist explicitly supports it.

---

## Technical Background

Apple playback APIs provide several relevant building blocks:

- `AVPlayerViewController` is the high-level AVKit player UI.
- `AVPlayerViewController.videoGravity` supports standard modes: `resizeAspect`, `resizeAspectFill`, and `resize`.
- `AVPlayerLayer.videoGravity` similarly controls how visual content is scaled within a layer.
- `AVPlayerViewController.contentOverlayView` and `AVPlayerView.contentOverlayView` can host overlay content between video and playback controls, but are not full viewport-layout APIs.
- `AVPlayerItemVideoOutput` can output video frames from a player item for analysis.
- `AVMutableVideoComposition` and composition layer instructions can express transforms/cropping, but they add complexity and may have compatibility/performance implications.
- AVFoundation supports subtitle and alternate audio selection, and AVKit can render selected legible text in standard player views.

Reference URLs:

- https://developer.apple.com/documentation/AVKit/AVPlayerViewController
- https://developer.apple.com/documentation/avkit/avplayerviewcontroller/videogravity
- https://developer.apple.com/documentation/avfoundation/avlayervideogravity/resizeaspect
- https://developer.apple.com/documentation/avkit/avplayerviewcontroller/contentoverlayview
- https://developer.apple.com/documentation/avkit/avplayerview/contentoverlayview
- https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput
- https://developer.apple.com/documentation/avfoundation/avplayeritemvideooutput/copypixelbuffer%28foritemtime%3Aitemtimefordisplay%3A%29
- https://developer.apple.com/documentation/avfoundation/avvideocomposition
- https://developer.apple.com/documentation/avfoundation/selecting-subtitles-and-alternative-audio-tracks

---

## Options Considered

### Option 1: Use `AVPlayerViewController.videoGravity` Only

Set the player to one of the built-in gravity modes.

#### Pros

- Minimal implementation.
- Keeps native controls, native subtitle rendering, PiP, AirPlay, and platform behavior intact.
- Lowest risk.

#### Cons

- Does not provide top-justification.
- Does not reserve bottom caption space.
- Cannot reliably differentiate encoded letterbox bars from active picture.
- Does not solve the core accessibility/readability problem.

#### Assessment

Rejected for the full feature. Acceptable only as baseline behavior.

---

### Option 2: Use `AVPlayerViewController.contentOverlayView` for Extra Captions

Keep native video layout and add a supplemental caption overlay in the lower area.

#### Pros

- Preserves native AVKit player.
- Allows noninteractive overlay content.
- Lower engineering cost than custom rendering.
- Useful for prototypes or experiments.

#### Cons

- Video remains vertically centered, so bottom caption region still overlaps the lower letterbox and/or active picture depending on source.
- Native subtitles may still render independently.
- Overlay views are not a complete layout model for transforming the actual video viewport.
- Risk of duplicated captions if native captions and custom captions are both active.

#### Assessment

Useful for early proof of concept, but insufficient for a polished production feature unless paired with custom caption policy and careful native-caption disabling.

---

### Option 3: Custom `AVPlayerLayer` Viewport Container

Build a platform-native player container that owns an `AVPlayerLayer`, computes the active picture rect, and positions the layer so the active video image is top-justified while preserving aspect ratio.

#### Pros

- Gives direct control over video layer frame and layout.
- Can work across iOS, tvOS, and macOS with platform-specific wrapper views.
- Preserves AVFoundation playback pipeline.
- Enables a bottom caption-safe region without modifying source media.
- Supports feature flags, experiments, and title-specific gating.

#### Cons

- More work than `AVPlayerViewController`.
- Native player controls must be recreated, wrapped, or selectively delegated.
- Subtitle behavior needs careful design.
- PiP, AirPlay, Now Playing, remote commands, focus, scrubbing, and accessibility must be validated.
- DRM/HLS behavior must be tested thoroughly.

#### Assessment

Recommended primary approach for production exploration.

---

### Option 4: Apply an `AVMutableVideoComposition` Transform/Crop

Use an `AVVideoComposition` or mutable composition layer instruction to spatially transform the video before display.

#### Pros

- Uses AVFoundation-native composition concepts.
- Could theoretically create a transformed presentation stream.
- May be useful for offline/export or controlled playback cases.

#### Cons

- Adds complexity to the decode/render pipeline.
- Potential HDR, DRM, performance, battery, and device compatibility risks.
- May interfere with HLS variant switching or protected content.
- Overkill for a layout problem where the source media should remain unchanged.

#### Assessment

Not recommended for the first production path. Keep as a research fallback for specific content classes.

---

### Option 5: Custom Metal/Core Image Renderer

Use `AVPlayerItemVideoOutput` or newer video-output APIs to acquire frames and render them manually with Metal/Core Image.

#### Pros

- Maximum control over image placement, color handling, analysis, overlays, and post-processing.
- Strong research path for advanced accessibility rendering.

#### Cons

- Highest complexity.
- Must handle timing, synchronization, color spaces, HDR/EDR, FairPlay constraints, dropped frames, captions, PiP, AirPlay, and power usage.
- Likely too risky for a general playback add-on.

#### Assessment

Rejected for MVP. Useful only for research prototypes or specialized non-DRM playback.

---

## Recommended Architecture

### Components

#### `LetterboxViewportFeatureFlag`

Controls rollout and experimentation.

Responsibilities:

- Enable or disable the feature globally.
- Scope by platform.
- Scope by content type, asset provider, or title allowlist.
- Support remote config and local debug override.
- Record analytics exposure.

#### `LetterboxAnalyzer`

Analyzes the content to determine active picture bounds.

Responsibilities:

- Read video presentation size and track metadata.
- Sample a limited number of frames using `AVPlayerItemVideoOutput` where allowed.
- Detect black or near-black horizontal bands at the top and bottom.
- Avoid false positives from naturally dark scenes.
- Return confidence-scored analysis.
- Cache results per asset/version.

Detection should not rely on a single frame. It should sample multiple frames across the first safe window after playback readiness, and optionally revalidate later.

Suggested heuristic:

1. Wait until the player item is ready.
2. Sample N frames across a short interval.
3. For each frame, inspect luminance near top and bottom scan regions.
4. Estimate the first row from the top and bottom where content becomes meaningfully non-black.
5. Compare inferred active aspect ratio against common cinematic ranges.
6. Require confidence threshold and stability across sampled frames.
7. Reject content where bars are inconsistent, animated, or likely creative content.

#### `LetterboxViewportLayoutEngine`

Computes player-layer geometry.

Inputs:

- Container bounds.
- Source presentation size.
- Detected active video rect.
- Safe area insets.
- Overscan considerations, especially tvOS.
- Platform caption-safe area.
- User caption size/style preference.
- Whether native controls are visible.

Outputs:

- `videoLayerFrame`
- `activeVideoFrame`
- `captionRegionFrame`
- `overlayAvoidanceInsets`

Layout rule:

- Preserve source aspect ratio.
- Do not scale beyond the intended aspect-fit width unless explicitly allowed.
- Align active picture top edge to the top safe display region.
- Place reserved caption region below active picture.
- Avoid obscuring playback controls.

#### `TopJustifiedPlayerView`

Platform-specific view that hosts an `AVPlayerLayer`.

iOS/tvOS:

- `UIView` subclass with `AVPlayerLayer` backing layer, or contained `AVPlayerLayer`.
- MainActor-isolated layout updates.
- tvOS focus and remote command integration validated separately.

macOS:

- `NSView` subclass with hosted `AVPlayerLayer`.
- Account for window resizing, full-screen behavior, and backing scale factor.

#### `CaptionPresentationController`

Optional enhanced caption renderer.

Responsibilities:

- Render selected subtitle/caption cues into the reserved bottom region.
- Respect system caption styling where possible.
- Apply readable line-length and duration rules.
- Avoid duplicating native captions.
- Support fallback to native AVKit subtitles when enhanced captions are unavailable.

Potential cue sources:

- HLS WebVTT sidecar/subtitle renditions.
- Timed metadata or text tracks exposed through AVFoundation.
- App-owned caption pipeline if the product already parses caption manifests.
- `AVPlayerItemLegibleOutput` only if compatibility and platform behavior meet requirements.

---

## Captioning Policy

The feature’s value depends heavily on caption control.

### Preferred Mode: Enhanced Caption Mode

When top-justified viewport is enabled:

1. Disable native subtitle rendering for the selected legible track if technically and legally allowed.
2. Use the app’s caption renderer to draw cues in the reserved bottom region.
3. Respect system caption/accessibility styling as closely as possible.
4. Preserve SDH/CC semantics.
5. Maintain language and media-selection behavior.

### Fallback Mode: Native Caption Mode

If custom rendering is unavailable:

1. Enable top-justified viewport only if native captions still appear acceptably.
2. Avoid claiming expanded subtitle capacity unless verified.
3. Treat the feature as picture repositioning, not full extended-caption mode.
4. Allow user to disable immediately.

### Do Not

- Render duplicate native and custom captions simultaneously.
- Hide closed captions without an equivalent replacement.
- Override user caption accessibility settings without consent.
- Assume all subtitles are short enough for the default AVKit layout.

---

## Detection Strategy

### Metadata-Based Precheck

Before sampling frames:

- Inspect `presentationSize`.
- Inspect natural track size and transform.
- Check HLS stream metadata where available.
- Compare video aspect ratio to display aspect ratio.
- Identify candidates where content is wider than 16:9.

This precheck is cheap but insufficient because encoded assets may already include letterbox bars in a 16:9 raster.

### Pixel-Based Letterbox Detection

Use sampled decoded frames only for candidate assets.

A robust detector should:

- Analyze luminance, not just RGB equality.
- Use a near-black threshold rather than exact black.
- Ignore a margin from the left/right edges where logos or overlays may appear.
- Require top and bottom bars to be horizontally consistent.
- Require stability over multiple frames.
- Handle fade-ins by delaying analysis.
- Handle HDR/SDR differences through normalized luminance.
- Avoid sampling every frame.

### Confidence Scoring

Example confidence inputs:

- Active aspect ratio near known widescreen ranges.
- Consistent top/bottom bar height across samples.
- Low luminance variance in detected bars.
- Clear boundary between bar region and active picture.
- No significant visual content detected inside bar regions.
- No inconsistent transitions over the analysis window.

---

## Segment Classification and State Machine

The viewport system should not make a one-time decision for the entire asset unless the asset is known to have a stable presentation. Instead, model presentation as a state machine.

### States

- `nativeCentered`: default AVKit-like presentation.
- `analyzing`: collecting bounded evidence, no layout change yet.
- `eligibleStableInactiveSpace`: stable inactive regions detected, no intentional use detected.
- `expandedCaptionSpaceActive`: repositioned viewport and enhanced caption region enabled.
- `suspendedUnsafeRegionUse`: detected text, motion, logo, credits, or other visual information in inactive region.
- `suspendedVariableAspect`: detected aspect-ratio transition or unstable active picture.
- `unsupported`: protected playback, unsupported caption mode, or insufficient platform capability.

### Transitions

- Start in `nativeCentered`.
- Move to `analyzing` only for candidate assets.
- Move to `eligibleStableInactiveSpace` only after confidence threshold is met.
- Move to `expandedCaptionSpaceActive` only when user setting, caption mode, and platform support all allow it.
- Move back to `nativeCentered` or suspended state when safety checks fail.
- Do not re-enter expanded mode until a cooldown period has elapsed.

### Why a State Machine Matters

A state machine prevents flicker and avoids treating variable-aspect titles as static. It also makes QA easier because each fallback path has a named reason and observable transition.

---

## Platform Considerations

### iOS

- Validate portrait and landscape behavior.
- Respect safe areas, Dynamic Island/notch devices, home indicator, and multitasking.
- Test AirPlay and PiP behavior.
- Avoid layout thrash during rotation or full-screen transitions.
- Ensure VoiceOver reads controls and captions predictably.

### tvOS

- Validate overscan-safe layouts.
- Ensure focus engine behavior remains stable.
- Avoid creating noninteractive overlays that interfere with player controls.
- Validate Siri Remote scrubbing, play/pause, subtitles menu, and system overlays.
- Test with VoiceOver, captions, and large text settings.
- Prefer predictable regions and avoid focusable caption overlays.

### macOS

- Support resizable windows and full-screen transitions.
- Validate `AVPlayerView` integration if native controls are required.
- Handle backing scale factor changes.
- Support keyboard shortcuts and accessibility focus.
- Consider separate behavior for windowed playback vs. full-screen playback.

---

## Accessibility Considerations

This is an accessibility-positive feature, but it must be implemented carefully.

Benefits:

- More vertical space for subtitles.
- Reduced overlap between subtitles and picture content.
- Better support for longer translated text.
- Better scanability for dense, short-lived cues.
- Potentially improved readability for deaf/hard-of-hearing users and second-language viewers.

Risks:

- Users may find top-justified video visually unfamiliar.
- Some titles may intentionally use black regions for visual composition.
- Native caption preferences may not fully map to a custom renderer.
- Caption duration cannot always be extended without desynchronizing text from speech.
- More text on screen is not always better; line length and cognitive load matter.

Requirement:

The feature must be opt-in and reversible.

---

## User Experience

### Settings

Possible setting names:

- “Use letterbox space for subtitles”
- “Move widescreen video up for captions”
- “Expanded subtitle space”
- “Top-align widescreen video”

Recommended label:

> Expanded subtitle space

Recommended description:

> For very wide videos, move the picture upward and use the lower letterbox area for larger or longer subtitles when available.

### States

- Off
- On
- Auto for eligible widescreen content
- Debug: show detected active-picture bounds

### Eligibility Messaging

If unavailable:

> Expanded subtitle space is not available for this video.

Possible reasons:

- Video is not letterboxed.
- Caption format is unsupported.
- Protected playback path does not allow analysis.
- Native player mode is required.
- Device/platform support is unavailable.

---

## Privacy and Security

- Frame analysis must run on-device.
- Do not upload video frames.
- Do not persist frame images.
- Cache only derived measurements, confidence scores, and asset identifiers.
- Avoid logging user-selected subtitle language in a way that could reveal sensitive preferences unless needed and permitted.
- Ensure DRM/protected content constraints are respected.

---

## Performance Requirements

- Analysis must be bounded and opportunistic.
- Do not block playback startup.
- Do not sample every frame.
- Do not run expensive image processing on the main thread.
- Layout updates must be MainActor-isolated.
- Detection should be cancellable when playback item changes.
- Cache successful analysis per asset version.
- Provide instrumentation for analysis duration, confidence, sampled frame count, and layout mode.

Suggested initial budget:

- Maximum sampled frames: 5–12 during startup/revalidation.
- Maximum analysis window: first stable 10–30 seconds of playback, excluding initial fade-in.
- Analysis queue: background serial queue or actor.
- UI updates: main actor only.
- Revalidation: optional, low frequency, only if confidence is low or content changes.

---

## Concurrency Requirements

All player item observation, frame sampling, and layout updates must be intentionally isolated.

Recommended model:

- `LetterboxAnalyzerActor`
  - Owns analysis state.
  - Receives immutable snapshots of player item metadata.
  - Performs bounded frame-analysis work off the main actor.
  - Returns `LetterboxViewportAnalysis`.

- `TopJustifiedPlayerView`
  - MainActor-isolated.
  - Applies layer geometry.
  - Does not perform pixel analysis.

- `CaptionPresentationController`
  - MainActor-isolated for UI updates.
  - May use a separate actor for cue parsing and timing model updates.

Concurrency comment requirement for implementation:

Every public async entry point should document:
- Which actor owns the state.
- Whether it can be cancelled.
- Whether it touches `AVPlayerItem`, `AVPlayerLayer`, or UI.
- Whether it must be called on the main actor.

---

## Testing Strategy

### Unit Tests

Test business logic, not trivial geometry arithmetic.

Important cases:

- Detects known 2.39:1 active image inside 16:9 raster.
- Classifies 4:3 pillarboxed content without creating a bottom caption region.
- Classifies square, vertical, and windowboxed content as non-MVP or unsafe by default.
- Rejects full-frame 16:9 content.
- Rejects dark scenes without stable top/bottom bars.
- Rejects variable-aspect-ratio sequences that switch between 16:9, cinematic, and 4:3.
- Rejects black regions containing text, logos, credits, burnt-in captions, or motion.
- Handles near-black bars, not just pure black.
- Computes caption region from active picture bounds.
- Keeps source aspect ratio unchanged.
- Applies safe-area constraints.
- Produces stable results across multiple sampled frames.
- Cancels analysis when player item changes.

### Snapshot / Golden Image Tests

Use generated frames with known active rects:

- 16:9 full-frame.
- 2.39:1 letterboxed.
- 2.31:1 letterboxed.
- 4:3 pillarboxed.
- Square and vertical video inside 16:9 containers.
- Windowboxed archival content.
- Variable-aspect sequences that switch between 16:9, 4:3, and cinematic.
- Fade-in frames.
- Dark scene with no true letterbox.
- Letterboxed content with subtitles already present.
- Content with logos/watermarks near bar regions.

### Integration Tests

- HLS with WebVTT subtitles.
- TS/HLS streams with embedded captions where available.
- DRM/FairPlay assets if applicable.
- AirPlay.
- PiP on iOS/macOS where supported.
- tvOS full-screen player controls.
- Native subtitle selection.
- Custom subtitle rendering.
- Device rotation.
- macOS window resize.
- tvOS overscan and VoiceOver.

### Accessibility QA

- VoiceOver enabled.
- Closed captions enabled by system preference.
- Large caption text.
- High contrast.
- Reduced transparency.
- Multiple subtitle languages.
- SDH captions with speaker labels and sound effects.
- Fast dialogue scenes.
- Dense translated subtitle scenes.

---

## Rollout Plan

### Phase 0: Research Prototype

- Build standalone sample app.
- Play local and HLS test assets.
- Implement frame sampling and active rect detection.
- Show debug overlay of detected bars and active picture.
- No production user exposure.

### Phase 1: Silent Analysis

- Ship detector behind internal flag.
- Log derived analysis only.
- Compare detector output against manually labeled assets.
- Tune false positive/negative thresholds.

### Phase 2: Internal Top-Justified Viewport

- Enable custom viewport for internal users.
- Use debug UI to toggle modes.
- Validate platform-specific player controls.
- Keep native captions initially.

### Phase 3: Enhanced Caption Renderer Experiment

- Integrate selected subtitle source.
- Render captions into reserved bottom region.
- Compare readability against native caption layout.
- Validate accessibility settings.

### Phase 4: Limited User Experiment

- Opt-in setting.
- Eligible assets only.
- Remote kill switch.
- Analytics for enablement, disablement, errors, and fallback.

### Phase 5: Production Decision

- Decide whether to graduate, keep experimental, or remove.

---

## Analytics

Collect derived telemetry only:

- Feature eligibility.
- User enablement.
- Platform and device class.
- Asset aspect classification.
- Detector confidence bucket.
- Caption renderer mode.
- Fallback reason.
- Playback errors.
- User disablement after enablement.
- Caption region size bucket.

Do not collect video frames.

---

## Risks

### False Positives

Dark scenes may look like letterbox bars.

Mitigation:

- Multi-frame sampling.
- Boundary detection.
- Confidence scoring.
- Title allowlist/blocklist.
- User opt-in.

### Creative Intent

Some directors intentionally compose around black regions or variable aspect ratios.

Mitigation:

- Detect stability.
- Disable for variable-aspect-ratio content.
- Use title metadata where available.
- Keep feature reversible.

### Native Caption Integration

Native AVKit captions may not be repositionable enough.

Mitigation:

- Separate viewport mode from enhanced caption mode.
- Build custom caption renderer only where cue source is reliable.
- Fallback gracefully.

### DRM and Protected Playback

Frame extraction may be unavailable or restricted for protected streams.

Mitigation:

- Treat failed analysis as ineligible.
- Use metadata and allowlists where possible.
- Do not bypass protected playback constraints.

### Platform Control Regression

Custom player containers can lose built-in AVKit behavior.

Mitigation:

- Limit feature to playback surfaces where custom container is already supported.
- Maintain AVPlayerViewController fallback.
- Test platform-specific controls heavily.

---

## Open Questions

1. Which caption formats must be supported first: WebVTT, IMSC/TTML, CEA-608/708, or app-owned cue models?
2. Can native caption rendering be disabled cleanly while preserving media selection state?
3. Is frame extraction available for our protected TS/HLS/FairPlay streams?
4. Do we already have an app-owned caption renderer that can be extended?
5. Should top-justification use the encoded frame or detected active picture boundary as the alignment source?
6. Should the feature allow larger captions, longer line wrapping, or simply more vertical caption lines?
7. Do product/legal/content partners allow presentation changes for premium films?
8. How should the feature behave for variable-aspect-ratio titles?
9. Should this be per-profile, per-device, or per-playback-session?
10. What is the minimum acceptable detector confidence before exposing the user-facing toggle?
11. Should variable aspect ratio always be a hard block, or can we support per-segment expansion after explicit QA?
12. What visual-content detector is good enough to identify intentional use of black regions without excessive false positives?
13. Should 4:3/pillarbox, square, and vertical content only be classified for safety, or should future caption layouts use their inactive regions?
14. Can content metadata or editorial tags identify titles where black-space repurposing is contractually or creatively prohibited?

---

## Acceptance Criteria

### MVP

- A sample player can detect 2.31:1–2.39:1 active picture inside a 16:9 raster.
- A sample player can classify 16:9, 4:3 pillarbox, square, vertical, windowboxed, and unknown content.
- Detection is confidence-scored and avoids single-frame decisions.
- The detector rejects variable-aspect-ratio and intentional-black-region usage by default.
- The player can top-align eligible video without stretching or cropping active content.
- A computed bottom caption region is exposed.
- The feature is behind a runtime flag.
- The feature can be disabled instantly.
- No video frames are uploaded or persisted.
- Playback remains functional when detection fails.
- iOS, tvOS, and macOS each have a documented integration path.

### Production Candidate

- Works with representative HLS/TS assets.
- Supports the required caption format(s).
- Avoids duplicate native/custom captions.
- Honors user caption/accessibility preferences as much as technically possible.
- Handles AirPlay/PiP/native controls according to platform policy.
- Has automated tests for detector and layout behavior.
- Has manual QA coverage for VoiceOver, subtitles, and platform controls.
- Has analytics and remote kill switch.
- Has content/product sign-off for presentation changes.

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

## Final Recommendation

Proceed with a research prototype using a custom `AVPlayerLayer` viewport container and a separate active-picture detector. Do not start by replacing the full native player stack. First prove that classification is accurate across 16:9, cinematic letterbox, 4:3 pillarbox, square, vertical, windowboxed, and variable-aspect content. Only enable repositioning for stable widescreen letterbox content where inactive regions are not being intentionally used.

Treat enhanced captions as a second-stage feature. The viewport work can be validated independently, but the full user value requires caption rendering control beyond what native AVKit layout may expose.

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
