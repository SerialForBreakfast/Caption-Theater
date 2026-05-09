# Multi-Speaker Caption Support Showcase

Date: 2026-05-08

## Summary

Yes: the existing offline **Tears of Steel** HLS mock is a reasonable first showcase source for multi-speaker caption experiments.

It is useful because:

- it is already repo-local at `CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`;
- it is true ultra-wide content (`1920x800`), so Caption Theater can demonstrate top-justified video with a lower caption region;
- the first five minutes include dialogue between multiple characters, including Thom, Celia, Robot, and Barley references;
- the current English WebVTT gives real timed subtitle data without requiring a live network stream.

The limitation: the current WebVTT mostly contains plain dialogue text, not explicit speaker labels. It names characters inside some lines, but it does not reliably say "Celia:" or "Thom:" for each cue. For the proof of concept, speaker identity should be added through a local fixture annotation layer rather than by pretending the original subtitles contain metadata they do not.

## Product Opportunity

Caption Theater has more room than native bottom captions. That extra room should do more than make text larger: it can make dialogue easier to follow.

Multi-speaker support should help users answer:

- who said this line;
- whether the current line belongs to the same speaker as the previous line;
- when a fast exchange switches speakers;
- which retained cue belongs to which speaker after the cue has already disappeared from native timing.

This is especially valuable for:

- fast back-and-forth dialogue;
- off-screen speakers;
- scenes with overlapping reactions;
- translated subtitles where line length expands;
- SDH-style content where speaker identity is part of comprehension;
- living-room viewing where faces may be small or partially out of frame.

## Showcase Concept

Use the ultrawide video top-justified. Use the lower Caption Theater band as a persistent, speaker-aware dialogue surface.

The hero moment:

1. Native playback shows standard timed subtitles over or near the picture.
2. Caption Theater prompts and the viewer opts in.
3. The active picture pins to the top without distortion.
4. The lower band becomes a readable dialogue region.
5. Current and recently presented cues remain visible.
6. Speaker identity is preserved visually so fast exchanges are easier to follow.

The feature must still obey the core product rules:

- persist only already-presented cues;
- never reveal future cues by default;
- preserve video geometry;
- keep ads/native playback boundaries intact;
- fail closed when speaker identity is unknown or unsafe to infer;
- avoid turning the product into a transcript viewer.

## Candidate Visual Treatments

### 1. Conversation Bubbles

Render retained cues like a restrained messaging conversation:

- left/right alignment by speaker;
- compact rounded rectangles;
- speaker name or initials above the first cue in a run;
- current cue uses stronger contrast;
- older retained cues fade slightly but remain readable.

Pros:

- instantly communicates speaker changes;
- makes rapid exchanges easy to scan;
- uses the lower band in a way native subtitles cannot.

Risks:

- can feel too much like a chat app if overstyled;
- left/right mapping may imply screen position even when speaker position is unknown;
- bubbles must not become decorative clutter.

Best use:

- demo mode and user research;
- scenes with two primary speakers.

### 2. Speaker Color Stripes

Keep captions centered or stacked, but add a small speaker-colored leading stripe or chip:

```text
[Celia]  You're a jerk, Thom.
[Thom]   Look Celia, we have to follow our passions;
```

Visual form:

- colored vertical stripe or small circular initial;
- speaker label in text;
- color repeats for the same speaker;
- unknown speaker uses neutral styling.

Pros:

- compact;
- less visually opinionated than bubbles;
- works with more than two speakers;
- easier to make accessible because color is not the only signal.

Risks:

- less novel than conversation bubbles;
- requires careful contrast and label handling.

Best use:

- likely first production-shaped design.

### 3. Speaker Lanes

Reserve horizontal lanes in the caption band:

- one lane per active speaker in the recent window;
- current cue appears in the speaker's lane;
- prior cues remain in that lane until aged out.

Pros:

- makes speaker continuity extremely clear;
- useful for overlapping or rapid dialogue;
- could be compelling in a wide lower band.

Risks:

- can waste vertical space;
- hard when many speakers enter;
- may resemble a transcript/timeline if not tightly bounded.

Best use:

- experimental prototype, not MVP default.

### 4. Spatial Speaker Anchoring

If speaker position is known or manually annotated, position the speaker chip near the horizontal region associated with the speaker.

Pros:

- connects dialogue to the picture;
- potentially very intuitive for two-person scenes.

Risks:

- wrong position is worse than no position;
- requires visual/screen metadata we do not currently have;
- should not be inferred from face detection for MVP.

Best use:

- later research path with trusted annotations.

### 5. Hybrid Recommended MVP

Use a restrained hybrid:

- stacked captions in the lower band;
- speaker chip with name/initials;
- consistent speaker accent color;
- optional left/right alignment only when the fixture explicitly marks a two-speaker exchange;
- current cue emphasized;
- previous cues dimmed but still readable.

This gives the demo a novel, beneficial feel without overcommitting to chat UI as the product direction.

## Data Model Proposal

Keep the canonical cue model extensible:

```swift
struct CaptionTheaterCue {
    let id: String
    let startTime: TimeInterval
    let endTime: TimeInterval
    let text: String
    let speaker: CaptionTheaterSpeaker?
}

struct CaptionTheaterSpeaker {
    let id: String
    let displayName: String
    let shortLabel: String
    let accentRole: CaptionTheaterSpeakerAccentRole
    let confidence: CaptionTheaterSpeakerConfidence
}
```

Speaker confidence should be explicit:

- `authored`: WebVTT voice spans, SDH labels, or trusted provider metadata;
- `fixtureAnnotated`: local demo annotation file reviewed by us;
- `inferredWeak`: heuristics only, not suitable for default UI;
- `unknown`: no speaker styling beyond neutral display.

For the current Tears of Steel mock, use `fixtureAnnotated`.

## Fixture Annotation Plan

Add a sidecar fixture file rather than editing the downloaded WebVTT:

```text
CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/speaker-map.json
```

Suggested shape:

```json
{
  "source": "TearsOfSteelFiveMinuteMock",
  "reviewStatus": "manual-poc-annotation",
  "speakers": [
    { "id": "celia", "displayName": "Celia", "shortLabel": "C" },
    { "id": "thom", "displayName": "Thom", "shortLabel": "T" },
    { "id": "robot", "displayName": "Robot", "shortLabel": "R" },
    { "id": "barley", "displayName": "Barley", "shortLabel": "B" }
  ],
  "cues": [
    {
      "start": 23.0,
      "end": 24.5,
      "speakerID": "celia",
      "note": "Line addresses Thom."
    }
  ]
}
```

Use time ranges, not cue indexes only, because segmented WebVTT can duplicate cue numbers across segment boundaries.

## Renderer Behavior

Rules:

- Use speaker styling only when `speaker.confidence` is `authored` or `fixtureAnnotated`.
- Show a speaker label on the first cue in a run.
- If consecutive cues share the same speaker, reduce repeated labels.
- If speaker is unknown, render neutral text.
- Color must never be the only speaker indicator.
- Retained cues should remain bounded by the existing scrolling/history policy.
- The renderer must not change cue timing or reveal future text.

Current cue:

- highest contrast;
- larger text according to user caption text size;
- speaker chip visible.

Retained cue:

- slightly lower contrast;
- same speaker identity treatment;
- no future timeline preview.

## Accessibility Requirements

Speaker-aware captions must work without relying on color.

Requirements:

- include speaker names or initials as text;
- preserve high contrast;
- ensure VoiceOver reads speaker identity before the cue when exposed as accessible text;
- respect caption text-size presets;
- do not use speaker color palettes that conflict with common color-vision deficiencies;
- support Reduce Motion by avoiding animated speaker lane transitions;
- keep focus out of the passive caption band unless an explicit review mode exists later.

## Test Plan

Unit tests:

- decode `speaker-map.json`;
- reject unknown `speakerID` references;
- match cue time ranges to WebVTT cue windows;
- preserve unknown speaker fallback;
- verify no future cues enter the rendered retained list;
- verify repeated speaker runs do not duplicate labels excessively.

Snapshot tests:

- two-speaker exchange;
- three-speaker exchange;
- unknown speaker fallback;
- long translated line wrapping with speaker chip;
- high-contrast mode;
- largest text-size preset.

Manual demo checks:

- top-justified video remains undistorted;
- lower band clearly shows who spoke each line;
- fast exchanges are easier to follow than native subtitles;
- retained speaker-labeled cues do not feel like a transcript wall.

## Implementation Slices

### Slice 1: Fixture and Parser

- Add `speaker-map.json` for the offline Tears of Steel mock.
- Add `CaptionTheaterSpeakerAnnotation` types.
- Decode and validate the sidecar file.
- Add unit tests.

### Slice 2: Cue Enrichment

- Extend the cue entry model to optionally carry speaker metadata.
- Match sidecar speaker annotations by cue time range.
- Keep the existing plain-text path as fallback.

### Slice 3: Renderer Prototype

- Add speaker chip rendering in the caption band.
- Start with the hybrid MVP design.
- Keep bubble/lane variants behind a code-level experiment flag.

### Slice 4: Demo Review

- Record a short demo script comparing:
  - native subtitles;
  - Caption Theater with normal retained captions;
  - Caption Theater with speaker-aware retained captions.

## Open Questions

- Should speaker labels be visible for every cue, or only on speaker changes?
- Should left/right alignment require explicit screen-position metadata?
- How many speaker accent colors are safe before the UI becomes noisy?
- Should SDH labels from authored subtitles be trusted automatically?
- Should speaker styling be a user-facing setting or only a renderer behavior when metadata exists?

## Recommendation

Use the offline Tears of Steel HLS mock as the first showcase source, with a manually reviewed `speaker-map.json` sidecar. Prototype the hybrid speaker-chip renderer first. Keep conversation bubbles and speaker lanes as optional demo variants, not default product behavior.

This best fits Caption Theater's product direction: it uses unused cinema-layout space to improve caption comprehension while preserving video geometry and avoiding future-cue preview.
