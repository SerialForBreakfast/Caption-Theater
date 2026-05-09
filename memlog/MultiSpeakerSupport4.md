# Ruthless Multi-Speaker Demo Feasibility Plan

Date: 2026-05-08

## Summary

Do **not** implement text balloons, SMS UI, speaker lanes, or color-coded speaker layout until a real demo asset qualifies. The current plan is too speculative because we do not yet have a backed-up asset that combines: ultrawide video, timed subtitles, reliable speaker attribution, redistribution/backup clarity, and a scene that visually proves the UI.

The first milestone is an **asset qualification sprint**, not UI work. If that sprint fails, explicitly kill the SMS/balloon demo path and keep only practical caption improvements: wrapping, text size, persistence, and opportunistic SDH speaker-label chips.

## Key Changes

Add a hard demo asset contract:

- playable offline or backuppable locally;
- license/provenance documented before use;
- HLS VOD or source media convertible to local HLS;
- ultrawide or letterboxed enough to showcase Caption Theater space;
- timed text with **source-authored** speaker identity, not a sidecar we invent;
- at least 2 named speakers, 10+ alternating cues, and cue-level timing good enough for a balloon/SMS demo.

Evaluate these concrete candidates first:

- **Mux Tears of Steel**: already backed up, ultrawide, but currently fails speaker-metadata requirement.
- **Blender Tears of Steel source + official subtitles**: likely license-friendly, but likely fails speaker-metadata requirement unless official subtitles prove otherwise.
- **American Archive speaker-tagged transcripts** such as "Monuments to Failure" and "California Stories; Dreams": strong speaker labels, but likely fail ultrawide/playback/backup/cue-level timing requirements.
- **Bitmovin Sintel HLS**: known HLS subtitle sample, but currently CDN access blocked from this environment and not yet proven speaker-rich.
- **Additional public HLS/WebVTT/IMSC assets** found by targeted search for `<v Speaker>`, `ttm:agent`, SDH labels, and downloadable HLS subtitle renditions.

Add a go/no-go matrix with explicit outcomes:

- **Pass:** asset qualifies; proceed to SMS/balloon prototype.
- **Partial:** asset has speaker labels but not ultrawide/offline; use only for parser tests, not hero demo.
- **Fail:** no qualifying asset; stop SMS UI work.

## Actionable Tasks

### 1. Asset Discovery

- Search public HLS/VOD samples, Internet Archive/AAPB, Wikimedia, Blender/open-film sources, DASH/HLS test vectors, Mux/Bitmovin/JW samples, and captioning datasets.
- For each candidate, record URL, license, media type, resolution/aspect ratio, subtitle format, speaker attribution type, timing granularity, and backup feasibility.
- Reject assets immediately if they require private credentials, DRM, non-public stream URLs, unclear redistribution, or non-downloadable media.

### 2. Subtitle Inspection

- Inspect raw subtitle files for:
  - WebVTT `<v Speaker>` spans;
  - `Speaker:` / `>> Speaker:` / `[Speaker]` SDH conventions;
  - TTML/IMSC `ttm:agent`;
  - cue-level timing, not paragraph-only transcript timing.
- Count speaker-attributed cues and alternating speaker turns.
- Produce an asset scorecard before any renderer task is opened.

### 3. Backup Qualification

- For any candidate that passes subtitle inspection, verify local backup feasibility before UI work:
  - downloadable source or HLS segments;
  - local playlist rewrite possible;
  - subtitle files preserved locally;
  - checksum manifest and provenance file possible;
  - README/public-repo warning required.
- If backup is not feasible, the asset cannot be the perfect demo.

### 4. Decision Gate

- Proceed to SMS/balloon UI only if at least one asset passes all requirements.
- If no asset passes, document that the feature is not viable as a hero demo and downgrade to:
  - plain caption wrapping;
  - text-size controls;
  - retained-caption readability;
  - optional SDH speaker-chip parsing where authored labels already exist.

### 5. Only If Gate Passes: Prototype Scope

- Implement one demo-only balloon/SMS renderer behind a code-level feature toggle.
- Support only source-authored speaker identity.
- No inferred speaker identity.
- No sidecar speaker maps as proof of viability.
- No product copy implying broad platform support.

## Test Plan

Asset tests:

- fixture has local media, local subtitles, local playlists, provenance, and checksums;
- subtitle file contains expected speaker attribution count;
- cue timing is cue-level and stable.

Parser tests:

- parse WebVTT voice spans;
- parse SDH visible labels;
- reject unknown/inferred speaker identity for SMS mode;
- fallback to neutral captions when speaker identity is absent.

Renderer tests only after asset gate passes:

- two-speaker alternating scene;
- unknown speaker fallback;
- large text size;
- long wrapped lines;
- no future cues;
- offline playback works without network.

## Assumptions

- Source-authored speaker attribution is required for the "perfect demo."
- Locally invented sidecars are allowed only for parser experiments or labeled PoC demos, not as evidence that the product direction is viable.
- If no qualifying asset can be found, SMS/balloon UI is considered a dead end for now.
- The near-term valuable work remains caption readability: wrapping, text size, persistence, and preserving speaker labels when real captions already contain them.
