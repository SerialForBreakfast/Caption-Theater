# Caption Theater Metadata Feasibility Deep Dive

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
Status: Draft Research Addendum  
Related Documents:
- `ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md`
- `Caption-Theater-POC-Roadmap.md`

---

## 1. Executive Summary

Caption Theater is feasible only if we treat metadata as evidence, not truth.

HLS manifests, AVFoundation metadata, subtitle renditions, and ad markers can tell us many useful things:

- what video variants exist,
- what audio renditions exist,
- what subtitle and closed-caption renditions are declared,
- whether a stream has alternative renditions,
- whether discontinuities or date ranges may indicate ad/segment boundaries,
- whether subtitle tracks are forced, default, autoselect, language-specific, or characteristic-specific,
- whether timed metadata exists,
- whether the host app or stream pipeline can provide ad lifecycle events.

But manifests generally cannot prove:

- whether letterbox bars are visually empty,
- whether text is burned into the video,
- whether black space is creative content,
- whether a region contains legal text, QR codes, credits, watermarks, or title graphics,
- whether variable aspect ratio changes later in the content,
- whether a subtitle cue should be reflowed,
- whether spoken text is itself important visual/creative content,
- whether an ad or promo overlay will use the same space.

Therefore, the POC should implement a **metadata evidence model**:

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
```

And the decision should be:

```swift
enum CaptionTheaterDecision: Sendable {
    case eligible(evidence: [CaptionTheaterEvidence])
    case ineligible(reason: CaptionTheaterIneligibilityReason)
    case uncertain(reason: CaptionTheaterUncertaintyReason)
}
```

The correct default is:

> Uncertain means native playback.

---

## 2. What `.m3u8` Metadata Can Actually Tell Us

An HLS presentation has at least two useful metadata surfaces:

1. **Multivariant playlist**  
   Describes variant streams and alternative renditions.

2. **Media playlist**  
   Describes media segments, discontinuities, dates, encryption, and date ranges.

### 2.1 Variant Stream Metadata

Useful tags and attributes:

- `#EXT-X-STREAM-INF`
- `BANDWIDTH`
- `AVERAGE-BANDWIDTH`
- `CODECS`
- `RESOLUTION`
- `FRAME-RATE`
- `VIDEO`
- `AUDIO`
- `SUBTITLES`
- `CLOSED-CAPTIONS`

What this can help with:

- Determine encoded raster size.
- Determine whether the stream declares subtitle or closed-caption groups.
- Determine whether alternate audio/video groups exist.
- Determine whether a variant likely represents 16:9, 4:3, vertical, or another encoded shape.
- Detect obvious non-candidates where the encoded raster leaves no likely unused region.
- Detect incompatible variant/rendition combinations.

What this cannot prove:

- Active picture aperture inside the encoded raster.
- Whether letterbox bars are empty.
- Whether subtitles are burned into bars.
- Whether the asset switches aspect ratio later.
- Whether captions are duplicated in video and timed text.

### 2.2 `EXT-X-MEDIA`

Useful attributes:

- `TYPE=AUDIO`
- `TYPE=VIDEO`
- `TYPE=SUBTITLES`
- `TYPE=CLOSED-CAPTIONS`
- `GROUP-ID`
- `LANGUAGE`
- `ASSOC-LANGUAGE`
- `NAME`
- `DEFAULT`
- `AUTOSELECT`
- `FORCED`
- `CHARACTERISTICS`
- `CHANNELS`
- `URI`

What this can help with:

- Identify selectable subtitle tracks.
- Identify forced subtitle tracks.
- Identify closed-caption tracks.
- Identify audio descriptions or accessibility-labeled renditions when declared through characteristics.
- Identify language association between audio and subtitles.
- Determine whether closed captions are embedded in video segments or separate subtitle playlists.

Important distinction:

- `TYPE=SUBTITLES` usually points to a separate subtitle rendition URI.
- `TYPE=CLOSED-CAPTIONS` does not point to a subtitle URI in standard HLS; it declares captions carried in video segments.

Caption Theater implication:

```swift
enum SubtitleTransportKind: Sendable {
    case sidecarSubtitlePlaylist
    case embeddedClosedCaptions
    case appProvidedCueModel
    case nativeOnly
    case noneDeclared
}
```

Sidecar subtitle playlists are the best first target. Embedded captions are important but more semantically complex.

### 2.3 `FORCED`

Forced subtitles can indicate narrative translation cues, such as translated dialogue, signs, or foreign-language speech.

This is valuable metadata, but dangerous for reflow.

Policy:

- Forced subtitles should be preserved more conservatively than normal dialogue subtitles.
- Forced cues may be intended to appear at specific locations.
- Forced cues may overlap with burned-in or visual text.
- Do not assume forced subtitles are safe for teleprompter-style persistent display.

### 2.4 `CHARACTERISTICS`

`CHARACTERISTICS` can provide role hints for accessibility and content type. It may identify things like captions, subtitles, audio description, transcriptions, or other media characteristics depending on authoring.

Caption Theater implication:

- Use it as a hint for user-facing labels and eligibility.
- Do not use it alone to authorize reflow.
- Preserve it in diagnostics because it may reveal whether a track is intended for accessibility.

### 2.5 `RESOLUTION`

`RESOLUTION` tells us the encoded variant resolution, not the active picture region.

Example:

```text
#EXT-X-STREAM-INF:BANDWIDTH=6000000,RESOLUTION=1920x1080,CODECS="avc1.640028,mp4a.40.2"
movie_1080p.m3u8
```

This can still be a 2.39:1 movie letterboxed inside 1920x1080.

So:

```swift
if resolution == CGSize(width: 1920, height: 1080) {
    // This is only encoded raster evidence.
    // It is not active-picture evidence.
}
```

### 2.6 `EXT-X-DISCONTINUITY`

Discontinuities can mark changes in encoding parameters, timeline, content source, ad insertions, or other transitions.

Caption Theater implication:

- Treat discontinuity as a revalidation boundary.
- Suspend Caption Theater around discontinuities unless trusted state says otherwise.
- Do not carry active-picture assumptions across discontinuities without revalidation.

### 2.7 `EXT-X-DATERANGE`

Date ranges can carry timed metadata and are often used in SSAI/DAI workflows, including SCTE-35-derived signaling.

Caption Theater implication:

- Use date ranges as potential ad/promo/metadata boundaries.
- Date ranges are evidence, not guaranteed full ad truth.
- If date range class indicates ad/splice/placement, suspend Caption Theater.
- If date range class is unknown, fail closed until product-specific mapping is understood.

### 2.8 Encryption Tags

Useful tags:

- `#EXT-X-KEY`
- `#EXT-X-SESSION-KEY`

Caption Theater implication:

- Encrypted playback may still allow metadata inspection.
- Encrypted playback may prevent pixel-buffer analysis.
- Do not depend on on-device pixel analysis for DRM-protected content.
- For DRM, require trusted metadata or allowlisting.

---

## 3. What AVFoundation Can Tell Us

### 3.1 Asset and Track Metadata

Potential surfaces:

- `AVAssetTrack.naturalSize`
- `AVAssetTrack.preferredTransform`
- `AVPlayerItem.presentationSize`
- `AVAsset.metadata`
- `AVMetadataItem`
- `AVAsset.availableMediaCharacteristicsWithMediaSelectionOptions`
- `AVMediaSelectionGroup`
- `AVMediaSelectionOption`
- `AVPlayerItemMetadataCollector`
- `AVPlayerItemMetadataOutput`

Useful for:

- Listing selectable subtitle/caption/audio options.
- Identifying legible media characteristics.
- Reading asset metadata when exposed.
- Observing timed metadata.
- Detecting player item presentation changes.

Not enough for:

- Determining active picture aperture.
- Detecting burned-in subtitles.
- Determining whether a black region is safe.
- Understanding all ad states unless the app/ad stack exposes them.

### 3.2 Timed Metadata

Timed metadata can be valuable if the stream/provider authors useful events.

Possible uses:

- ad boundaries,
- chapters,
- overlays,
- content warnings,
- aspect-ratio timeline,
- safe-caption-region timeline,
- segment-level layout metadata,
- provider QC flags.

Caption Theater implication:

Timed metadata becomes powerful if we define our own provider-side contract.

Example provider metadata payload:

```json
{
  "type": "caption-theater-region",
  "version": 1,
  "activePictureRect": { "x": 0, "y": 132, "width": 1920, "height": 816 },
  "safeCaptionRegions": [
    { "x": 0, "y": 948, "width": 1920, "height": 132 }
  ],
  "confidence": 0.98,
  "policy": "eligible",
  "validFrom": 0,
  "validTo": 3600,
  "notes": ["no_burned_in_subtitles", "stable_letterbox"]
}
```

This would be far more reliable than client inference.

---

## 4. Subtitle Metadata and Cue Semantics

### 4.1 WebVTT

Useful cue-level fields:

- start time,
- end time,
- cue text,
- cue settings:
  - line,
  - position,
  - size,
  - align,
  - vertical.

Caption Theater implication:

- WebVTT is a strong first target.
- Text is available.
- Timing is available.
- Placement hints are available.
- Cue-level reflow can be controlled.

But there are caveats:

- Positioned cues may translate signs or labels.
- Karaoke/music cues may have timing semantics.
- Future cue display may spoil content.
- Author-provided line breaks may carry intent.
- Cue classes/styles may not map to native caption settings.

### 4.2 IMSC / TTML

Useful:

- regions,
- styles,
- timing,
- text profile vs image profile,
- writing modes,
- positioning.

Caption Theater implication:

- Text-profile IMSC/TTML can be suitable.
- It is richer and more complex than WebVTT.
- Region preservation matters.
- Image-profile subtitles are not reflow-friendly.

### 4.3 CEA-608 / CEA-708

Useful:

- accessibility-oriented captioning,
- roll-up/pop-on/paint-on modes,
- positioning semantics,
- speaker and sound-effect text.

Caption Theater implication:

- Critical format for accessibility.
- More dangerous to reflow naively.
- Roll-up mode may already behave like a teleprompter.
- Preserve semantics before trying to improve layout.

### 4.4 Burned-In Text

Not metadata. Pixels only.

This includes:

- subtitles burned into active picture,
- forced subtitles burned into letterbox bars,
- lower-thirds,
- credits,
- karaoke lyrics,
- captions inside old broadcast masters,
- legal disclaimers.

Caption Theater implication:

- Ineligible for custom reflow.
- If detected in a proposed inactive region, fail closed.
- For DRM, require provider-side metadata to confirm absence.

---

## 5. “Text of the Audio Is Content Too”

This is one of the biggest product gotchas.

A subtitle cue is not always just a convenience duplicate of speech. It can be:

- translation,
- accessibility caption,
- creative rhythm,
- comedic timing,
- spoiler-bearing content,
- speaker identity,
- sound design information,
- song lyrics,
- signs and on-screen text,
- legal or safety information,
- sports/news context,
- educational transcript,
- ad disclosure,
- interactive prompt,
- story-relevant written language.

Caption Theater must not assume all text can be made persistent or previewed.

### 5.1 Cue Intent Classification

The renderer should eventually distinguish:

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

MVP reality:

- We may not reliably know intent.
- Use conservative defaults.
- Reflow dialogue only when the track/cue is clearly suitable.
- Preserve authored placement for forced/sign/song/unknown cues.

### 5.2 Persistence Policy

```swift
enum CuePersistencePolicy: Sendable {
    case displayOnlyDuringAuthoredTime
    case retainPreviousCueBriefly
    case retainPreviousCueUntilNextCue
    case transcriptModeOnly
}
```

Default:

- Current cue respects authored time.
- Previous cue can remain briefly in a de-emphasized style only for suitable subtitle formats.
- Future cue display is off.

---

## 6. A Practical Evidence Model

Caption Theater eligibility should not be a boolean. It should be a decision with evidence and confidence.

```swift
struct CaptionTheaterEvidence: Sendable {
    let source: CaptionTheaterEvidenceSource
    let kind: CaptionTheaterEvidenceKind
    let confidence: Double
    let timeRange: CMTimeRange?
    let notes: [String]
}

enum CaptionTheaterEvidenceKind: Sendable {
    case encodedResolution(CGSize)
    case declaredSubtitleGroup
    case declaredClosedCaptionGroup
    case forcedSubtitleTrack
    case subtitleCuePositioning
    case adBoundary
    case discontinuity
    case encryptedPlayback
    case activePictureRect(CGRect)
    case safeCaptionRegion(CGRect)
    case unsafeRegionUse
    case variableAspectRatio
    case burnedInTextRisk
    case providerAllowlist
    case providerBlocklist
}
```

Decision rules:

```swift
struct CaptionTheaterEligibilityRule: Sendable {
    let requiresTrustedSafeRegion: Bool
    let allowsPixelAnalysis: Bool
    let allowsProviderMetadata: Bool
    let allowsSubtitleReflow: Bool
    let minimumConfidence: Double
}
```

Recommended policy:

- DRM content requires trusted provider metadata or allowlist.
- Non-DRM content may use pixel analysis.
- Ad/promo state overrides all positive evidence.
- Subtitle reflow requires text-based cue access.
- Unknown cue intent uses preserve-authored-layout.

---

## 7. Edge Cases From Metadata Alone

### 7.1 Selectable Captions Exist, But Video Also Has Burned-In Subtitles

Manifest says subtitles exist. Video still contains burned-in forced translations.

Risk:
- Duplicated text.
- Reflowed external captions conflict with baked-in subtitles.
- Letterbox area is falsely treated as empty.

Policy:
- Pixel detection for non-DRM.
- Provider metadata for DRM.
- User/QA blocklist if observed.

### 7.2 Closed Captions Declared But No Sidecar Subtitle URI

This is normal for HLS closed captions carried in video segments.

Risk:
- Harder to custom-render.
- Native rendering may be the only reliable path.
- Reflow may break CEA semantics.

Policy:
- Treat as native-only until a semantic caption extraction path exists.

### 7.3 Forced Subtitles Are The Only Text Track

Risk:
- Forced cues may translate signs/foreign dialogue and rely on placement.
- Teleprompter persistence may spoil timing.

Policy:
- Preserve authored timing/layout.
- No previous cue retention unless explicitly allowed.

### 7.4 `RESOLUTION=1920x1080` But Active Picture Is 2.39:1

Risk:
- Metadata says 16:9 raster, but visually it is letterboxed.

Policy:
- Metadata preclassifies as raster only.
- Pixel or provider active-picture metadata needed for eligibility.

### 7.5 Multiple Audio Tracks Change Caption Meaning

Example:
- English audio with English SDH.
- Spanish dub with Spanish subtitles.
- Commentary audio with unrelated caption track.

Risk:
- Captions do not match selected audio.
- Text is not just a transcript.
- Speaker and timing assumptions fail.

Policy:
- Tie subtitle eligibility to selected audio rendition.
- Use `LANGUAGE`, `ASSOC-LANGUAGE`, track name, and app media-selection state.
- Reset cue history on audio or subtitle track change.

### 7.6 Audio Description / Descriptive Audio

Risk:
- Additional spoken narration may not be represented in subtitle tracks.
- Text may be required for some users but absent from captions.
- Caption Theater cannot infer missing content.

Policy:
- Do not claim transcript completeness.
- Treat audio-description state as an accessibility mode that requires QA.

### 7.7 Songs and Lyrics

Risk:
- Lyrics are timed and creative.
- Persistence/preview can harm rhythm and intent.

Policy:
- Preserve authored timing.
- Do not show future lyric cues.

### 7.8 News, Sports, and Lower Thirds

Risk:
- On-screen text is part of content.
- Lower thirds may live in the same lower region as captions.
- Captions may duplicate or conflict with graphics.

Policy:
- Treat live/news/sports as high-risk.
- Consider separate product mode or native-only default.

### 7.9 Ad Legal Text

Risk:
- Pause ads or video ads may use black/lower areas for disclosures.

Policy:
- Ads override Caption Theater.
- Unknown ad state fails closed.

### 7.10 Variable Aspect Ratio Films

Risk:
- Some titles intentionally switch aspect ratio.
- Moving the video on every switch creates flicker and disrespects framing.

Policy:
- Detect and suspend automatic Caption Theater.
- Use provider timeline metadata if ever supported.

---

## 8. Recommended Metadata Contract

If we want this to work well at production quality, the best path is a provider-side metadata contract.

### 8.1 Content-Level Metadata

```json
{
  "captionTheater": {
    "policy": "eligible",
    "source": "provider-qc",
    "confidence": 0.99,
    "supportsReflow": true,
    "allowedLayouts": ["expandedBottomRegion"],
    "notes": [
      "stable-letterbox",
      "no-burned-in-subtitles",
      "no-variable-aspect"
    ]
  }
}
```

### 8.2 Timeline-Level Metadata

```json
{
  "segments": [
    {
      "start": 0.0,
      "end": 5820.0,
      "activePictureRect": { "x": 0, "y": 132, "width": 1920, "height": 816 },
      "safeCaptionRegions": [
        { "x": 0, "y": 948, "width": 1920, "height": 132 }
      ],
      "policy": "eligible"
    },
    {
      "start": 5820.0,
      "end": 5880.0,
      "policy": "native-only",
      "reason": "credits-over-black"
    }
  ]
}
```

### 8.3 Track-Level Metadata

```json
{
  "subtitleTracks": [
    {
      "language": "en",
      "format": "webvtt",
      "kind": "sdh",
      "supportsCaptionTheater": true,
      "supportsPreviousCueRetention": true,
      "supportsFutureCuePreview": false
    },
    {
      "language": "ja",
      "format": "webvtt",
      "kind": "forced",
      "supportsCaptionTheater": true,
      "supportsPreviousCueRetention": false,
      "preserveAuthoredPlacement": true
    }
  ]
}
```

### 8.4 Ad/Promo Metadata

```json
{
  "adPolicy": {
    "linearAds": "native-only",
    "pausePromos": "suppress-when-captions-visible",
    "unknownAdState": "native-only"
  }
}
```

This metadata could come from:
- catalog service,
- playback entitlement response,
- manifest sidecar,
- timed metadata,
- server-side QC pipeline,
- partner-provided asset metadata.

---

## 9. POC Additions Based on Metadata Risk

### 9.1 Add Manifest Parser MVP

Tasks:
1. Parse multivariant playlist.
2. Extract variant stream attributes.
3. Extract `EXT-X-MEDIA` groups.
4. Extract subtitle/closed-caption declarations.
5. Extract language/default/autoselect/forced/characteristics.
6. Extract media playlist discontinuities and date ranges.
7. Produce `ManifestEvidence`.

Acceptance:
- Given fixture manifests, parser identifies subtitle transport kind.
- Parser distinguishes sidecar subtitles from closed captions.
- Parser identifies forced tracks.
- Parser identifies discontinuity and date range boundaries.
- Parser never declares visual region eligibility by itself.

### 9.2 Add Evidence Inspector Debug UI

Show:
- encoded resolution,
- declared subtitle groups,
- selected audio/subtitle pair,
- forced/default/autoselect,
- date ranges,
- discontinuities,
- encryption,
- provider eligibility metadata,
- pixel-analysis status,
- final decision.

Acceptance:
- A QA engineer can explain why Caption Theater is active or inactive.

### 9.3 Add Provider Metadata Stub

Implement local JSON sidecar support.

Acceptance:
- DRM-like test asset can be marked eligible from trusted metadata.
- Same asset without metadata fails closed.
- Blocklist metadata overrides pixel analysis.

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

## 10. Final Recommendation

The POC should expand from “pixel detector + custom captions” into an **evidence-based eligibility system**.

Build order adjustment:

1. Manifest fixture parser.
2. Evidence model.
3. State-machine decision rules.
4. Synthetic provider metadata.
5. Pixel analysis.
6. Subtitle renderer.
7. Ad/promo coordinator.
8. Platform integration.

The most important product rule:

> Caption Theater should never infer creative safety from one source. It should require enough converging evidence for the current content, segment, subtitle track, ad state, and user setting.

When evidence is incomplete, the feature should not activate automatically.

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
