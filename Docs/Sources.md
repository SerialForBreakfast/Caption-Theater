

# Caption Theater Source Candidates

This document tracks possible real-world `.m3u8` and subtitle sources for Caption Theater testing.

The goal is to find ultra-widescreen HLS content where the encoded video is actually wider than 16:9, not a 16:9 raster with baked-in letterboxing. We also need subtitle or caption tracks so Caption Theater can test persistent timed-text rendering.

## What We Need

Ideal stream characteristics:

- HLS master playlist (`.m3u8`)
- ultra-widescreen encoded variant, for example around `1920x800`, `958x408`, or similar
- subtitle declaration in the manifest, preferably WebVTT
- not simply a 16:9 video with black bars baked into the image
- public or otherwise approved for test use
- suitable for AVFoundation playback testing

## Best Current Candidates

### 1. Tears of Steel — Mux HLS VOD

Stream URL:

```text
https://stream.mux.com/4XYzhPXzqArkFI8d1vDsScBLD69Gh1b2.m3u8
```

Supporting references:

- Mux subtitle article: https://www.mux.com/blog/subtitles-captions-webvtt-hls-and-those-magic-flags
- AVPro Video streaming sample list: https://www.renderheads.com/content/docs/AVProVideo/articles/feature-streaming.html

Why it is useful:

- Public HLS VOD test stream.
- Reported as Tears of Steel with WebVTT subtitles.
- Useful as the strongest current hero candidate for Caption Theater.
- Mux documentation discusses Tears of Steel HLS subtitle behavior.

Validation status (repo check, manifest-only fetch):

- Master playlist reachable from developer network via `curl`.
- Top video variant **`RESOLUTION=1920x800`** (true ultra-wide encoded raster, not 16:9 plus bars).
- **`#EXT-X-MEDIA:TYPE=SUBTITLES`** entries present (e.g. English, Française) with signed subtitle playlist URIs.
- **Remaining:** re-verify periodically if Mux changes asset IDs or drops the public demo; confirm **Apple TV Simulator/device** playback end-to-end.

Expected use:

- Hero demo candidate.
- Subtitle persistence candidate.
- Ultra-widescreen HLS manifest inspection candidate.

Offline mock note:

- A private POC-only five-minute offline HLS mock derived from this stream exists at `CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`.
- The mock includes one selected `1920x800` rendition with combined H.264/AAC media, matching English WebVTT subtitles, rewritten local playlists, and local segments.
- Treat this tree as **development-only fixture media** (not production catalog content). Remove or replace it if licensing cannot be cleared for your distribution channel.
- Do not treat that mock as release media.
- Before making this repository public, re-check the source license, attribution terms, and redistribution rights; remove or replace the mock if redistribution is not explicitly allowed.

---

### 2. Sintel — Bitmovin HLS

Stream URL:

```text
https://bitdash-a.akamaihd.net/content/sintel/hls/playlist.m3u8
```

Related subtitle URLs:

```text
https://bitdash-a.akamaihd.net/content/sintel/hls/subtitles_en.m3u8
https://bitdash-a.akamaihd.net/content/sintel/hls/subtitles_en.vtt
```

Supporting reference:

- ExoPlayer issue with stream and subtitle URLs: https://github.com/google/ExoPlayer/issues/2546

Why it is useful:

- Public HLS test stream.
- Documented subtitle playlist and WebVTT URL.
- Reported in public playback test discussions.
- Some known Sintel HLS variants are ultra-widescreen-ish rather than 16:9.

Validation needed:

- Akamai returned **Access Denied** for `playlist.m3u8` from automated fetch (2026-05); replace or mirror this URL if blocking persists.
- Confirm exact variant resolutions from a fresh manifest fetch once reachable again.
- Confirm subtitle group wiring and AVFoundation subtitle behavior once the playlist is reachable again.

Expected use:

- Secondary HLS/subtitle candidate.
- Useful for manifest parsing and WebVTT wiring tests.

---

## Candidate-Only Sources

These are interesting but not yet verified as matching all requirements.

### 3. JW Platform Tears of Steel 4K

Candidate URL:

```text
http://content.jwplatform.com/manifests/vM7nH0Kl.m3u8
```

Supporting reference:

- Video.js sample index mentioning HLS Tears of Steel 4K: https://github.com/FoxCouncil/videojs-max-quality-selector/blob/master/index.json

Validation needed:

- Confirm the manifest is still reachable.
- Confirm subtitle availability.
- Confirm variant resolutions.
- Confirm whether variants are true ultra-widescreen encodes.

Expected use:

- Possible higher-resolution Tears of Steel candidate.
- Do not treat as verified until inspected.

---

### 4. Blender PeerTube / Cosmos Laundromat

Candidate page:

```text
https://video.blender.org/w/wfW3bDTkUhQKRnEfT9Wpeq
```

Supporting reference:

- Blender video page: https://video.blender.org/w/wfW3bDTkUhQKRnEfT9Wpeq

Validation needed:

- Inspect network/player metadata for direct HLS playlist URL.
- Confirm subtitle availability.
- Confirm encoded aspect ratio.
- Confirm licensing/attribution details.

Expected use:

- Possible additional open-content candidate.
- Not yet a verified `.m3u8` source.

---

## Apple HLS Control References

Apple sample streams are useful even when they are not ultra-widescreen hero candidates.

Reference:

- Apple HLS example streams: https://developer.apple.com/streaming/examples/
- Example advanced **fMP4** multivariant master (control / parser harness):

```text
https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8
```

Expected use:

- AVFoundation/HLS control testing.
- WebVTT rendition behavior.
- TS/fMP4 behavior.
- 16:9 native fallback.
- 4:3 classification.
- Manifest parser validation.

These should not be treated as the main Caption Theater hero content unless a specific stream is verified to be true ultra-widescreen with captions.

---

## Generated Fixture Recommendation

Public streams may not give us five perfect real-world cases. We should also generate a known-answer HLS fixture.

Recommended generated fixture shape:

```text
video: 1920x800 or 1920x804
subtitles: WebVTT
master playlist: .m3u8 with EXT-X-MEDIA:TYPE=SUBTITLES
```

Why generated fixtures matter:

- We can guarantee non-16:9 encoded active picture.
- We can guarantee sidecar WebVTT subtitles.
- We can guarantee no baked-in letterbox.
- We can create unsafe variants for detector tests.
- We can keep all generated content project-local and deterministic.

Generated fixture variants:

- clean ultra-widescreen + WebVTT
- full-frame 16:9 fallback
- 4:3 pillarbox stretch goal
- variable-aspect switch stretch goal
- burned-in subtitles in proposed reading region
- logo/watermark in proposed reading region
- dark-scene false positive
- legal-text-like lower region

All generated content and generation scripts must stay inside the repository. Do not write to `/tmp`, `/private/tmp`, or `/var/tmp`.

---

## CT-0005: Cinematic open-content pipeline (repo-local)

**Task:** CT-0005 (see `TASKS.md`) — purpose-built offline HLS that exercises Caption Theater:
true ultra-wide raster, recognizable live-action imagery, and English dialogue via sidecar WebVTT.

**Script:** `Scripts/build_ct0005_cinematic_open_hls.py`

**Default sources (Blender Foundation mirrors):**

- Video master: `https://download.blender.org/demo/movies/ToS/tears_of_steel_720p.mov`
- English subtitles (official ``TOS-en.srt``): `https://download.blender.org/demo/movies/ToS/subtitles/TOS-en.srt`

Alternate masters from the same directory (for example `ToS-4k-1920.mov`) can be passed with `--video-url`. Downloads are cached under `Fixtures/SourceDownloads/ct0005-open-masters/` (ignored by Git).

**What it produces:**

- Output folder (default): `CaptionTheater/CaptionTheater/Media/OfflineHLS/BlenderToSCinematicClip/`
- Center cinematic crop toward **1920×800**, AAC audio, H.264 MPEG-TS segments, `master.m3u8` + `EXT-X-MEDIA` subtitles aligned to segment durations.
- Defaults trim **`--trim-start 22`** for **`--duration 120`** seconds so the clip lands on the iconic Amsterdam rooftop argument (“You're a jerk, Thom…” ) with dense dialogue — adjust as needed.

**Requirements:** `ffmpeg` and `ffprobe` on `PATH`.

**Licensing:** Re-verify Blender Foundation / *Tears of Steel* terms and attribution before publishing the repo or redistributing bundles. The blender.org `copyright.txt` in the demo folder primarily documents soundtrack licensing; confirm motion-picture reuse separately (`tearsofsteel.org`, Blender Foundation).

**Related:** Re-encoded offline ladder pulled directly from the public Mux multivariant stream (no crop) lives under `Scripts/download_mux_offline_hls_mock.py` and `Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`.

---

## Next Step: Manifest Inspection Report

Add a repo-local manifest inspection script that fetches only manifest text and writes reports to:

```text
Docs/StreamCandidateReports/
```

The report should include:

- master playlist URL
- variant resolutions
- aspect ratios
- subtitle groups
- subtitle playlist URLs
- closed-caption declarations
- encryption markers
- discontinuity/date-range markers
- whether top variants appear to be non-16:9
- whether the source is a hero candidate, control reference, or rejected candidate

Do not download media segments as part of this step.
