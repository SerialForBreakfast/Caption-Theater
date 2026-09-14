# ADR-0003: Adjustable Caption Band Below Top-Pinned Video

## Caption Theater product frame

Caption Theater is a persistent timed-text readability mode. Its primary value is increasing readable dwell time for subtitle/caption text that has already appeared, in verified safe layout space, without covering or distorting the active picture.

This ADR extends [ADR-0001: Active-Picture-Aware Viewport and Subtitle Space Optimization](ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md). ADR-0001 establishes top-pinned active picture geometry and a lower `captionReadingRect`; this ADR decides how that lower region should behave when the product can offer an optional, user-adjustable subtitle view below the player.

Date: 2026-09-09  
Status: Proposed  
Platforms: tvOS first; iOS, iPadOS/foldable-class displays, and macOS as follow-on targets  
Owners: Playback, Accessibility, Captioning, Client Platform  
Related areas: top-pinned playback, retained captions, caption preferences, SwiftUI layout, AVFoundation legible output, foldable/large-canvas video UX  

---

## Context

Apple's iPhone Duo product page presents a foldable/large-canvas viewing model where video can be pinned at the top while the remaining display area stays useful for another surface. The page also describes seated and angled viewing modes where the device becomes a hands-free entertainment screen, with controls or other UI available on the lower portion of the display.

That interaction pattern maps closely to Caption Theater's existing architectural direction:

- keep the active picture top-pinned;
- preserve the video's original geometry;
- reserve the area below the active picture for a useful secondary view;
- make that secondary view optional and controllable by the user.

For Caption Theater, the secondary view should not become a general multitasking panel. The best product use is a dedicated subtitle surface that can provide larger type, better wrapping, and longer dwell time for already-presented cues.

Reference: [Apple iPhone Duo product page](https://www.apple.com/iphone-duo/), accessed 2026-09-09.

---

## Problem Statement

Caption Theater already has a top-pinned video concept and a lower caption band. The next product question is whether that lower region should be a fixed-size caption band or an optionally present view with customizable height.

Users have different caption needs:

1. Some want captions to behave close to traditional subtitles, with only the current cue visible.
2. Some benefit from retained recent lines, especially for fast dialogue, dense SDH text, noisy environments, language learning, or hearing impairment.
3. Some need larger text, which naturally requires more vertical space.
4. Some prefer minimal UI and should be able to hide or shrink the band.
5. Device posture matters: a foldable, tablet, Mac window, or TV may all have different available lower-region affordances.

The risk is product drift. If the lower area becomes an unbounded transcript panel, Caption Theater stops being a playback readability feature and starts becoming a separate transcript viewer. That conflicts with the project's core rules: no future cues by default, bounded retention, and preservation of the video experience.

---

## Decision

Adopt an **Adjustable Caption Band** below the top-pinned player.

The band is an optional, user-configurable Caption Theater surface that renders current and retained subtitle rows inside the existing `captionReadingRect`. It may grow or shrink within layout-defined bounds, but it must remain tied to playback time and must never reveal future cues by default.

### Default behavior

The default Caption Theater layout remains:

1. active picture top-pinned;
2. video aspect ratio preserved;
3. caption band below the video;
4. current cue emphasized;
5. retained cues de-emphasized and bounded.

For first implementation, the default band should be conservative:

- enabled only after the user accepts Caption Theater;
- height derived from the safe lower region produced by the layout engine;
- no future subtitles;
- no full transcript mode;
- no speaker-card or SMS metaphor by default.

### User-adjustable height

Expose a caption band height preference as a small set of semantic presets before exposing a raw pixel slider:

| Preset | Intended use |
|--------|--------------|
| Compact | Current cue or very short retained context |
| Standard | Current cue plus limited retained rows |
| Expanded | Larger text and longer retained dwell time |
| Auto | System chooses based on text size, device/window geometry, and available safe region |

The implementation can internally map these presets to layout weights or height fractions, for example:

```swift
enum CaptionBandHeightPreference: String, Sendable, CaseIterable {
    case compact
    case standard
    case expanded
    case automatic
}
```

The preference affects the caption surface, not the video aspect math. The active picture must not stretch. If the requested band height cannot fit without damaging the video experience, the layout engine should clamp it and expose a debug reason.

### Longer dwell time

Longer dwell time should be an explicit outcome of more available caption space, not a license to show a transcript wall.

The retained-caption policy should scale within strict bounds:

- more height can allow more retained rows;
- larger type may reduce retained row count;
- recent expired cues can remain visible longer within a maximum age;
- legal, forced, lyric, and other authored-timing-only cues should not persist by default;
- a seek, restart, item change, or legible-output flush clears retained history.

Suggested model:

```swift
struct CaptionBandPresentationPreferences: Equatable, Sendable {
    var heightPreference: CaptionBandHeightPreference
    var textSize: CaptionTheaterCaptionTextSizePreset
    var retentionMode: CaptionRetentionMode
}

enum CaptionRetentionMode: String, Sendable, CaseIterable {
    case currentOnly
    case recentContext
    case extendedDwell
}
```

Retention mode should remain bounded even in `extendedDwell`.

---

## Layout Policy

The lower subtitle view should be treated as a first-class region owned by the Caption Theater layout engine.

### Inputs

The layout engine should consider:

- container size;
- safe-area insets;
- active picture aspect ratio;
- Caption Theater opt-in state;
- text size preset;
- caption band height preference;
- platform class: tvOS, macOS, iOS/iPadOS/foldable-class display;
- playback controls and focus overlays;
- minimum acceptable video size.

### Outputs

The layout engine should produce:

- `activePictureRect`;
- `captionReadingRect`;
- `captionBandActualHeight`;
- `captionBandRequestedHeight`;
- `captionBandClampReason`, when applicable;
- a stable layout diagnostic token for screenshots and tests.

### Clamp rules

Clamp the requested caption band when:

1. the active picture would fall below the minimum acceptable height;
2. safe-area or focus overlays would make the band unusable;
3. the content is not eligible for Caption Theater;
4. the requested mode would require cropping, stretching, or covering the video;
5. platform controls would overlap the caption surface.

Fail closed to standard centered playback or a compact caption band when the layout cannot be proven safe.

---

## UI Policy

The adjustable caption surface should feel like part of video playback, not like an unrelated document panel.

### Recommended UI

- Current cue: strongest emphasis.
- Retained cues: lower contrast or reduced weight.
- Scroll only when needed; avoid implying the user should read far back in time.
- Keep rows inside `captionReadingRect`.
- Respect text size preferences.
- Keep passive captions non-focusable on tvOS.
- Provide a debug HUD readout for requested vs actual band height.

### Avoid by default

- Full transcript panel.
- Future cue preview.
- Chat/SMS UI unless separately accepted under ADR-0002 gates.
- Raw height sliders in the first user-facing version.
- Moving or resizing the band automatically while the user is reading, unless caused by a major device/window geometry change.

---

## Platform Notes

### tvOS

tvOS remains the first implementation target. The band should preserve focus behavior: the video/transport controls remain the interactive playback surface, while captions are passive readable content.

Expected first slice:

- semantic height presets behind feature toggles or debug settings;
- existing top-pinned layout;
- retained rows rendered in the caption band;
- screenshot/manual QA for compact, standard, expanded, and large-text cases.

### iOS, iPadOS, and foldable-class displays

The iPhone Duo page is useful because it frames a larger mobile display as a two-zone surface: video above, useful UI below. Caption Theater should use that idea without depending on one device.

For iOS/iPadOS/foldable-class layouts:

- use posture/window-size information when available;
- treat the lower region as a caption surface first, not a general app pane;
- preserve system gestures, safe areas, and playback controls;
- avoid assuming the fold line or hinge location is available unless the platform exposes it.

### macOS

The Mac target can use the same band preference model but should map it to window resizing and aspect presets:

- resizing the window may create more or less caption space;
- source aspect and window aspect presets should not distort video;
- the caption band can support visual QA and screenshots.

---

## Accessibility and Reading Experience

This feature is primarily an accessibility and comprehension improvement.

Important requirements:

1. Do not require color to distinguish current vs retained cues.
2. Maintain sufficient contrast in both current and retained rows.
3. Respect user text size preferences.
4. Avoid motion that makes retained captions harder to track.
5. Ensure VoiceOver behavior is intentional. Passive timed text should not steal focus, but the app should not block users from using system caption/accessibility features.
6. Keep line wrapping predictable. Wider caption bands should fill the available readable width, while line count and retention policy prevent the surface from becoming a transcript wall.

---

## Consequences

### Positive

- Makes the lower region more obviously valuable and user-controlled.
- Supports larger text without immediately sacrificing retained context.
- Gives users a practical way to choose between minimal captions and longer dwell time.
- Aligns with emerging large-canvas/foldable media UX while preserving Caption Theater's core product thesis.
- Keeps the MVP grounded in measurable readability improvements.

### Negative / costs

- Adds layout state and testing combinations.
- Requires clear clamp/debug behavior to avoid confusing users when a requested height cannot fit.
- Can drift toward transcript UI unless retention remains bounded.
- Needs careful tvOS focus and remote-control QA.

### Risks

- **Over-retention:** mitigated with age/count/character budgets.
- **Video degradation:** mitigated by minimum active-picture size and no distortion.
- **Accessibility regression:** mitigated by contrast, type-size, and non-focusable passive caption tests.
- **Platform overfitting:** mitigated by treating iPhone Duo as design inspiration, not a hard dependency.

---

## Implementation Plan

### Phase 1: Model and layout policy

- Add `CaptionBandHeightPreference`.
- Add caption band sizing inputs to the layout engine.
- Return requested vs actual band height and clamp reason.
- Unit test compact, standard, expanded, automatic, and large-text cases.

### Phase 2: tvOS rendering

- Wire the preference into the existing tvOS top-pinned layout.
- Render current and retained rows inside the computed `captionReadingRect`.
- Keep captions passive/non-focusable.
- Add debug HUD fields for band preference and clamp reason.

### Phase 3: Retention scaling

- Map compact/standard/expanded to row and age budgets.
- Keep future cues disallowed.
- Clear retained rows on seek, restart, item change, and legible flush.
- Test forced/lyrics/legal cue policies.

### Phase 4: User controls

- Start with feature toggles/debug configuration.
- Later expose a settings view with semantic presets.
- Avoid raw sliders until the presets prove insufficient.

### Phase 5: Platform expansion

- Reuse the model on macOS for screenshot QA and window resizing.
- Revisit iOS/iPadOS/foldable-class behavior when target platform APIs and app scope justify it.

---

## Verification Checklist

- [ ] Layout tests prove video geometry is preserved for each band preset.
- [ ] Retention tests prove no future cues appear.
- [ ] Large-text tests keep rows inside `captionReadingRect`.
- [ ] tvOS passive captions are not focusable.
- [ ] Seek/restart/item-change/flush clear retained rows.
- [ ] Debug HUD reports requested height, actual height, and clamp reason.
- [ ] Manual QA confirms compact, standard, expanded, and automatic presets.
- [ ] Manual QA confirms the lower band improves dwell time without becoming a transcript panel.

---

## Related Documents

| Document | Role |
|----------|------|
| [ADR-0001](ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md) | Top-pinned active picture and caption region architecture |
| [ADR-0002](ADR-0002-Multi-Speaker-Caption-Presentation.md) | Optional speaker presentation gates |
| [Docs/TechnicalArchitecture.md](Docs/TechnicalArchitecture.md) | Working architecture reference for layout and persistence components |
| [Docs/PlanMethodology.md](Docs/PlanMethodology.md) | Planning guardrails for practical, verifiable milestones |

---

## Status Lifecycle

| Status | Meaning |
|--------|---------|
| Proposed | This ADR; model/layout work may be planned |
| Accepted | Height preferences and bounded retention are implemented and tested on tvOS |
| Accepted (+Settings) | User-facing settings expose semantic presets |
| Accepted (+Mac) | Mac target supports the same caption band model |
| Parked | Adjustable height is deferred; retain fixed band behavior |

---

## Revision History

- 2026-09-09: Initial ADR-0003; uses iPhone Duo top-pinned video/lower-surface UX as product inspiration for adjustable Caption Theater caption bands.
