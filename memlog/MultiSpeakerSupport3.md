# Multi-speaker caption support: feasibility audit

Date: 2026-05-08

This document supersedes the more optimistic synthesis in `MultiSpeakerSupport.md` and `MultiSpeakerSupport2.md`. Those notes are still useful for UI ideas, but this audit focuses on the practical question: can Caption Theater realistically depend on speaker-aware caption data at scale?

## Bottom line

**Speaker-aware captions are feasible as an opportunistic enhancement, not as a baseline product assumption.**

The practical version is:

- Use normal caption persistence and wrapping for every eligible WebVTT track.
- Detect and preserve explicit speaker labels when they are already in the caption text, especially SDH-style labels such as `[speaker] dialogue`.
- Parse WebVTT voice spans (`<v Speaker>`) when present.
- Treat TTML/IMSC agent metadata as a future input only if the app actually gains access to that text track representation.
- Use local sidecar speaker annotations only for demos, fixtures, and proof-of-concept work.
- Do not build the main product around needing per-speaker metadata, because most streaming captions we can reasonably expect to encounter will not expose stable speaker ids.

**Likelihood rating:** medium for controlled demos and curated assets; low-to-medium for arbitrary streaming assets; low for a product promise that all or most videos can show reliable speaker-aware layout.

## What is technically possible

There are real formats that can represent speaker identity.

### WebVTT voice spans

WebVTT supports voice spans such as:

```vtt
00:00:10.000 --> 00:00:12.000
<v Celia>You're a jerk, Thom.
```

The WebVTT spec uses this pattern in examples and allows styling voice spans by speaker. It also includes examples of split cue regions for two different speakers. So this is not invented or esoteric.

Practical limitation: the presence of `<v Speaker>` in the spec does not mean commercial or public HLS assets usually include it. In our current repo-local Tears of Steel mock, there are no WebVTT voice spans.

### SDH speaker labels in visible text

Professional SDH style guides commonly require speaker identifiers only when needed for comprehension, especially when the speaker cannot be visually identified. Netflix's English USA guide, for example, instructs SDH authors to use bracketed speaker IDs or sound effects and says the speaker ID and dialogue should ideally be on the same line.

This is the most practical signal because it survives format conversion. It is just text, so it works in SRT, WebVTT, TTML-derived delivery, and most player pipelines.

Practical limitation: SDH labels are editorial and intermittent. They usually identify off-screen or ambiguous speakers, not every turn in a normal visible conversation. They are also not structured metadata unless we parse text conventions.

### TTML / IMSC agent metadata

TTML has `ttm:agent` metadata and a `ttm:agent` attribute for associating content with the agent responsible for the line. IMSC is widely used for subtitles/captions in production and distribution workflows.

Practical limitation: this does not automatically help us on tvOS/HLS. The app must actually receive text track data in a form that preserves the metadata. If AVFoundation hands us only rendered text or normalized cue strings, the rich metadata may already be gone. Supporting TTML/IMSC directly is also a larger parser and packaging commitment than the current WebVTT-first path.

### HLS carriage

HLS supports subtitle renditions. RFC 8216 describes WebVTT subtitle segments and `EXT-X-MEDIA:TYPE=SUBTITLES`; Apple HLS authoring docs also recognize `wvtt` and `stpp.ttml.im1t` codec identifiers for WebVTT and IMSC text subtitles.

Practical limitation: the `.m3u8` manifest identifies subtitle renditions, languages, accessibility characteristics, and URIs. It does not provide per-cue speaker identity. Speaker data has to live inside the subtitle resource itself, inside a metadata track, or in an application-specific sidecar that we control.

## What exists widely enough to matter

### Widely available

- Plain subtitles with no speaker identity.
- SDH captions with visible labels for some speaker changes.
- HLS subtitle renditions declared as WebVTT or IMSC.
- Caption text that can be wrapped into a dedicated Caption Theater reading region.

These are practical enough for product behavior.

### Sometimes available

- WebVTT voice spans.
- TTML/IMSC metadata that names agents/speakers.
- Consistent `Speaker: dialogue` transcript-style captions in educational, interview, meeting, or generated-transcript contexts.
- Authoring pipelines that retain speaker labels as visible text.

These are worth supporting opportunistically.

### Not available enough to rely on

- Per-cue stable speaker ids across mainstream streaming catalogs.
- Accurate on-screen speaker positions.
- Public HLS test assets that combine ultrawide video, multi-speaker dialogue, and structured speaker metadata in a way we can treat as representative.
- A universal platform guarantee that AVFoundation/native HLS playback will expose structured speaker metadata to our renderer.

These should not be prerequisites for the feature.

## Evidence from our current assets

The repo-local offline HLS mock is still useful:

- `CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`
- `1920x800` video variant
- HLS WebVTT subtitle rendition
- Multiple-character dialogue in the first five minutes

But it does **not** contain structured speaker identity:

- no `<v Speaker>` WebVTT voice spans found in repo media;
- no consistent `Speaker:` prefix convention;
- no stable speaker ids in the manifest;
- character names appear inside dialogue occasionally, but that is not reliable attribution.

This means Tears of Steel is a good layout and offline-playback fixture, but not proof that multi-speaker metadata is available in the wild.

## Viability by implementation path

| Path | Feasibility | Product value | Scale risk | Recommendation |
|------|-------------|---------------|------------|----------------|
| Plain retained captions with better wrapping | High | High | Low | Must do regardless of speaker work. |
| Parse visible SDH speaker labels | High | Medium | Low | Practical first speaker feature. |
| Parse WebVTT `<v Speaker>` voice spans | Medium | Medium | Medium | Add if our parser owns raw VTT text. |
| Local `speaker-map.json` sidecar | High for demos | Medium for PoC | High for product | Use only for fixtures and demos. |
| TTML/IMSC `ttm:agent` support | Medium technically | Medium | High for current app scope | Defer until there is a real source asset and parser need. |
| Heuristic speaker inference from text | Low | Low-to-medium | High | Avoid default UI. |
| Audio diarization | Low for this app | Potentially high | Very high | Out of scope without explicit product decision. |
| Spatial speaker anchoring | Low | Unproven | Very high | Research only; do not imply position without metadata. |

## The realistic MVP

The MVP should not require exotic caption assets.

1. **Default path:** render ordinary cues in the Caption Theater lower band with strong wrapping, sizing, and persistence.
2. **Speaker label preservation:** if a cue starts with a credible SDH speaker label, render it as a speaker chip plus dialogue text.
3. **Voice span preservation:** if raw WebVTT contains `<v Speaker>`, lift `Speaker` into the same chip model.
4. **Unknown fallback:** if there is no trusted speaker signal, render normal captions. No color, no bubble alignment, no inferred speaker.
5. **Demo fixture:** use a repo-local sidecar for Tears of Steel only to demonstrate what the UI could do when speaker metadata exists. Label that fixture as PoC-only.

This is practical because it improves every asset through wrapping/persistence, improves some assets through authored speaker labels, and avoids making the rare metadata case the core value proposition.

## UI implications

The best production-shaped UI remains the restrained transcript rail:

```text
Celia  You're a jerk, Thom.
Thom   Look Celia, we have to follow our passions.
```

Use:

- speaker name or initials as visible text;
- optional accent stripe as secondary signal;
- run-collapsed labels for consecutive lines from the same speaker;
- neutral rendering when attribution is unknown;
- no future cues;
- no implied screen position unless explicitly authored.

Avoid default chat bubbles or left/right lanes unless a fixture or asset explicitly marks a two-speaker exchange. Those patterns are compelling in a demo, but they can overstate the certainty of the data.

## Intelligent wrapping

Wrapping is viable and should be prioritized independently of speaker metadata.

Practical rules:

- Fill the Caption Theater caption reading width, not the native video subtitle width.
- Preserve authored line breaks when they carry meaning.
- Otherwise wrap to the available caption region using balanced lines and readable phrase boundaries where possible.
- Keep speaker chips outside or beside the text flow so they do not steal unpredictable width from every line.
- At large text sizes, allow more vertical space and fewer retained cues rather than shrinking text below the selected size.

This means the lower band should be treated as the target reading surface. Native caption line breaks are useful hints, not hard geometry, because the Caption Theater layout is intentionally different from the video viewport.

## What would prove this is viable at scale

One public asset with rich speaker markup is not enough. A credible go/no-go bar would be:

- multiple HLS VOD assets from different sources that include WebVTT voice spans or equivalent structured speaker metadata;
- evidence that AVFoundation/custom parsing can access that metadata reliably in our playback path;
- at least one production-style SDH track where visible speaker labels appear often enough to improve comprehension;
- tests covering the fallback path where no speaker data exists.

If we cannot find representative public or licensable assets with structured speaker metadata, that is strong evidence against making speaker-specific layouts a core promise. It is not evidence against supporting authored labels opportunistically.

## Research addendum: availability estimate

This pass looked for proof that structured speaker identity is common enough to influence product direction. The result reinforces the conservative conclusion.

### Findings

**WebVTT voice spans are real, but public usage is hard to find.**

The WebVTT spec has first-class voice spans and a canonical example using `<v Roger Bingham>` and `<v Neil deGrasse Tyson>`. Search results for `<v ...>` overwhelmingly surface the spec, tutorials, validators, and copied examples rather than independently hosted production HLS subtitle assets. That suggests voice spans are format-supported but not obviously common in public streaming samples.

**Public HLS/VTT samples tend to be plain captions.**

The public Mux Tears of Steel WebVTT sample used in their captioning docs contains plain cues with no `<v Speaker>` spans, no stable `Speaker:` convention, and no bracketed speaker labels. This matches our bundled five-minute mock. The Bitmovin Sintel public sample is widely referenced as a WebVTT/HLS test stream, but direct read-only sampling from this environment returned CDN access-denied responses, so it should not be counted as inspected evidence either way.

**Commercial streaming workflows prioritize track carriage over speaker structure.**

Mux accepts SRT or WebVTT and turns them into HLS text tracks. AWS MediaConvert documents IMSC, TTML, and WebVTT sidecar output workflows. Bitmovin documents HLS WebVTT support and notes that tvOS subtitle styling/positioning is restricted to AVFoundation/System UI when using the system path. These are strong signals that text-track delivery is mainstream, but they do not establish that speaker identity survives as structured per-cue metadata.

**SDH guidance strongly supports visible speaker labels, not stable hidden IDs.**

Captioning Key says speaker identity is important and recommends placement, parenthesized names, and generic labels such as `(speaker #1)` or `(narrator)` when needed. Service-provider pages describe SDH as including dialogue, sound effects, and speaker identification across broadcast formats. This supports parsing visible labels as practical product input. It does not support assuming every cue has a machine-stable speaker id.

**Emerging ASR speaker ID is notable precisely because it is emerging.**

A 2025 broadcast subtitling report describes Verbit's live ASR speaker-identification feature as an "industry first" and gives an example output like `>> JONATHAN WILLIAMS:`. That is useful market evidence: speaker identification is valuable, but current systems often encode it as visible text conventions, and reliable live speaker ID is still treated as a differentiated capability rather than commodity caption infrastructure.

### Estimated prevalence by signal type

This is not a statistical corpus result; it is a product-risk estimate from public docs, public samples, and discoverability.

| Signal | Estimated availability in practical streaming assets | Confidence | Product implication |
|--------|------------------------------------------------------|------------|---------------------|
| Plain WebVTT/SRT subtitle text | High | High | Core path must optimize wrapping and retention. |
| HLS subtitle rendition in manifest | High for prepared streaming assets | High | Good basis for Caption Theater eligibility. |
| SDH visible speaker labels | Medium in SDH/caption tracks, low in translation subtitle tracks | Medium | Parse opportunistically; do not expect every turn. |
| WebVTT `<v Speaker>` voice spans | Low to unknown | Medium | Support if cheap, but do not plan around it. |
| TTML/IMSC agent metadata reaching app renderer | Low for current WebVTT-first tvOS path | Medium | Defer until we have source assets and ingestion proof. |
| Sidecar speaker map | High only for our own fixtures | High | Demo/testing only. |
| Automatic diarization with names | Low for this app | High | Out of scope unless the product changes materially. |

### Decision impact

The go/no-go bar should stay strict. We should not require "multiple HLS VOD assets with WebVTT voice spans" before supporting speaker chips, because visible SDH labels are a practical enough input. But we **should** require that bar before making chat bubbles, lanes, or speaker-specific layouts a core advertised feature.

The near-term decision should be:

1. Build robust plain-caption layout first.
2. Add a label extractor for visible SDH speaker conventions.
3. Add WebVTT voice-span parsing only if the app owns raw WebVTT parsing in that path.
4. Keep rich multi-speaker demos clearly marked as fixture-driven.
5. Revisit product priority only after we find multiple representative assets with structured speaker metadata and verify the tvOS ingestion path preserves it.

## Risk assessment

Primary risks:

- **Data availability:** most assets likely have plain subtitles or intermittent SDH labels, not stable per-cue speaker ids.
- **False certainty:** color, lanes, and chat alignment can imply identity or position that the caption file did not actually say.
- **Format loss:** metadata may exist upstream but be stripped during packaging, conversion, or platform playback.
- **Accessibility:** color-only speaker identity fails; labels must remain textual.
- **Product drift:** a large retained multi-speaker region can become a transcript viewer if not bounded.

Mitigations:

- confidence tiers: `authored`, `fixtureAnnotated`, `inferredWeak`, `unknown`;
- full speaker chrome only for `authored` or clearly marked local fixtures;
- neutral fallback for everything else;
- docs/tests that prove no future cues and no geometry distortion;
- demo labels that say sidecar speaker attribution is local PoC annotation.

## Decision

Build the feature as **progressive enhancement**:

1. Prioritize text size, wrapping, and retained-caption readability because those work for almost every subtitle asset.
2. Add speaker-chip rendering for authored visible labels and WebVTT voice spans.
3. Keep Tears of Steel sidecar annotation as a demo/testing tool, not evidence of real-world metadata availability.
4. Do not invest in TTML/IMSC agent parsing, diarization, or spatial speaker UI until we have real assets and a verified app ingestion path.

The possible is not the practical. The practical product promise is: **Caption Theater makes captions easier to read in the unused cinema-layout space, and when trustworthy speaker identity exists, it preserves that identity in a clearer way.**

## Source notes checked

- WebVTT spec: voice spans, cue wrapping, regions, and speaker examples are part of the format: https://www.w3.org/TR/webvtt1/
- HLS RFC 8216: HLS carries subtitle renditions and WebVTT subtitle segments, but speaker identity is inside subtitle content, not the manifest: https://www.rfc-editor.org/rfc/rfc8216
- Apple HLS authoring appendix: recognizes WebVTT (`wvtt`) and IMSC text subtitle (`stpp.ttml.im1t`) codec identifiers: https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices-appendixes
- Netflix English USA Timed Text Style Guide: SDH speaker IDs are visible text conventions used when needed, not guaranteed per-cue structured speaker metadata: https://partnerhelp.netflixstudios.com/hc/en-us/articles/217350977-English-USA-Timed-Text-Style-Guide
- TTML1 spec: `ttm:agent` metadata can associate content with speakers/agents, but this requires access to that TTML metadata in our pipeline: https://www.w3.org/TR/2018/PR-ttml1-20181004/
- Mux caption docs/blog: commercial HLS workflows commonly ingest SRT/WebVTT and emit HLS subtitle renditions; their Tears of Steel example is plain WebVTT, not speaker-rich WebVTT: https://www.mux.com/docs/guides/add-subtitles-to-your-videos and https://www.mux.com/blog/subtitles-captions-webvtt-hls-and-those-magic-flags
- Bitmovin subtitle support docs: HLS WebVTT is broadly supported; tvOS styling/positioning on the system UI path is restricted to AVFoundation: https://developer.bitmovin.com/playback/docs/subtitles-captions
- AWS MediaConvert docs: IMSC, TTML, and WebVTT sidecar captions are normal packaging outputs, but this is delivery-format support, not proof of speaker metadata availability: https://docs.aws.amazon.com/mediaconvert/latest/ug/ttml-and-webvtt-output-captions.html
- DCMP Captioning Key: speaker identification is important in captions and is often represented through visible placement/name conventions: https://dcmp.org/learn/captioningkey/603
- Verbit live ASR speaker-identification report: reliable live named-speaker captions are emerging/differentiated, often output as visible speaker text: https://www.tvbeurope.com/media-consumption/verbit-introduces-industry-first-speaker-identification-for-live-asr-broadcast-subtitles
