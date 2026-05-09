# Multi-speaker captions and the ultrawide top-pinned band

## Purpose

This note describes how Caption Theater can **showcase scope / ultrawide playback with a dedicated caption reading region** so subtitles do more than sit under the picture: they can help viewers **tell who is speaking**, especially during fast back-and-forth dialogue. It also records what **test media exists today** in the repo versus what we would add for credible demos.

## What we have today (fixtures and content)

### Bundled ultrawide-ish demo with real multi-speaker *scene* (limited speaker *metadata*)

The **offline HLS mock** (`CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`) includes WebVTT segments whose dialogue is clearly a **two-person argument** (names appear in the text, e.g. “You’re a jerk, Thom.” / “Look Celia…”). Example from `subtitles/segments/seg000.vtt`:

- Cues are **plain dialogue lines** without a dedicated speaker field, `<v Name>` WebVTT voice spans, or consistent “Speaker:” prefixes.
- So the clip is **good for “dense dialogue in a letterboxed picture”**, but **not** yet a controlled corpus for **structured multi-speaker UI** (colors, rails, chat layout keyed to a stable speaker id).

### Metadata fixtures (not full speaker-rich VTT)

`Media/PlaybackScenarios/playback-subtitle-dialogue-webvtt.json` and test fixtures under `CaptionTheaterTests/Fixtures/Subtitles/` describe **track eligibility** (dialogue vs SDH, etc.). They do not by themselves provide multi-speaker **authored** distinctions beyond what the linked VTT contains.

### Gap

There is **no dedicated fixture** whose WebVTT (or future internal cue model) encodes **speaker identity in a machine-stable way** end-to-end for UI experiments. Adding one is the cheapest way to demo “beneficial” multi-speaker layout on the ultrawide top-pinned path.

## Product constraints (from project direction)

Any presentation must preserve:

- **No future cues by default**; only already-presented (and policy-eligible retained) text.
- **Caption reading region** bounded by layout (`CaptionTheaterLayoutGeometry/captionReadingRect`); typography should respect caption size prefs when the Phase 4 renderer fully consumes that rect.
- **Accessibility**: speaker distinction must not rely on **color alone**; pair color with weight, position, icons, or explicit names.

## Why the top-pinned + lower band helps multi-speaker UX

- **Vertical room**: a scrolling or stacked band can show **short conversational threads** (last N lines) without crowding the active picture.
- **Stable scanning**: readers can anchor “who spoke last” at a consistent vertical rhythm (newest-at-top is already a playback-shell policy direction; keep that consistent if we add speaker chrome).
- **Ultrawide context**: scope content often has **horizontal** “breathing room” in the layout story; the **main win** is still the **dedicated reading strip**, not squeezing labels into the video frame.

## Showcase patterns (novel or familiar)

Below are options that stay compatible with a **single reading region** (not rebuilding a full chat app). Mix 1–2 patterns; avoid visual noise.

### 1. “Transcript rail” (recommended baseline)

Each line (or cue) gets a **narrow lead column**: initials, a short name chip, or a small SF Symbol (person / person.wave.2). Body text wraps beside it. This maps cleanly to a future **speaker id** on an internal cue model and degrades to today’s plain text if id is missing.

### 2. Chat-thread metaphor (controlled)

- **Incoming alignment**: alternate **leading vs trailing** alignment for two principal speakers (like a two-person thread), **only** when speaker ids are known and count is small; otherwise fall back to centered transcript style.
- **Grouped bubbles**: soft rounded rectangles with low contrast so it still feels like captions, not iMessage. Respect **Reduce Transparency** / **Increase Contrast** settings when those APIs are in play.

### 3. Color coding (secondary signal)

- Assign a **stable hue per speaker id** (hash-based) for rail, left border, or name chip.
- **Always** pair with **name or initials** and distinct **alignment or weight** so meaning survives grayscale and color-blind use.

### 4. Typographic voice (subtle)

- Same color; differentiate with **semibold name** + regular body, or **slightly different tracking** per “voice class” (narrator vs character) if the cue model supports it later.

### 5. SDH-style discipline in authoring

Where providers already deliver **speaker change** cues (`[Thom]`, `(Celia)`, etc.), a parser pass can lift a **display speaker** string without inventing diarization. That is **not** novel visually, but it is **high trust** when the source is authored that way.

## Authoring and fixture strategy

### Short term (demo-quality)

Add a **small synthetic WebVTT** (or extend a mock segment set) that uses one or more of:

- WebVTT **voice tags** (`<v Celia>…`) if we decide to parse them in the adapter, or
- Consistent **prefix convention** in cue text (`Celia: …`) with a deterministic strip rule for display, or
- Separate **short cues** per speaker turn (already true in Tears segments) **plus** explicit labels for QA.

Bundle it next to existing offline HLS or as a pure VTT fixture for unit tests on **speaker extraction** and **layout snapshot** tests.

### Medium term (product-quality)

Align with **Phase 4 internal cue model** (see `TASKS.md` CT-0401): explicit optional **speaker id / display name**, **cue intent** (dialogue vs SDH), and **style hints** so the renderer chooses rail vs bubble vs flat without embedding presentation in the VTT file.

## Suggested acceptance criteria for a “multi-speaker showcase” milestone

1. Fixture encodes at least **two stable speakers** across **10+ alternating lines** in ultrawide or letterboxed content.
2. UI demonstrates **at least one** non-color-only differentiator (rail + name, or alignment + name).
3. With **Reduce Motion** on (when wired), avoid ornamental chat animations; prefer instant updates or opacity-only transitions.
4. **No cue** appears before its authored start time; retained lines obey persistence policy.

## Open questions

- **Speaker source of truth**: authored metadata only vs optional future **diarization** (out of scope unless explicitly approved; high privacy and complexity surface).
- **RTL / bilingual**: threading and rails must mirror correctly; use SwiftUI environment layout direction when implementing alignment tricks.
- **Many speakers** (crowd scenes): cap distinct chrome (e.g. rail shows “Speaker 3” or icon only) to avoid rainbow overload.

## Summary

**Today**, ultrawide demo content exists with **natural multi-speaker dialogue** (Tears of Steel mock VTT), but **not** with **structured speaker identity** suitable for distinguished UI. **Next step** for a compelling showcase is a **small authored fixture** plus renderer rules (rail + optional color/alignment) that exploit the **top-pinned lower reading band** without overlapping the picture or breaking Caption Theater persistence rules.
