# ADR-0002: Multi-Speaker Caption Presentation (Progressive Enhancement)

## Caption Theater product frame

Caption Theater is a persistent timed-text readability mode. Its **primary** value is increasing readable dwell time for subtitle/caption text that has **already appeared**, in verified safe layout space, without revealing future cues by default. Multi-speaker presentation is an **optional clarification layer** when the timed-text stream (or a clearly marked fixture) supplies trustworthy speaker attribution—not a separate product and not a prerequisite for Caption Theater eligibility.

This ADR extends [ADR-0001: Active-Picture-Aware Viewport and Subtitle Space Optimization](ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md). Layout (top-pinned picture, `captionReadingRect`) comes from ADR-0001 and [CT-0303](TASKS.md); this ADR governs **how** attributed text may be shown in that region when speaker identity is known vs unknown.

Product thesis (multi-speaker scope):

> When trustworthy speaker identity exists in the caption stream—or in PoC fixtures—Caption Theater may present names or initials alongside dialogue in a restrained transcript style. When it does not, the experience reverts to strong wrapping, sizing, and persistence with **no inferred speaker** and no layout that implies on-screen position.

Core rules (additive to ADR-0001):

1. **No future cues:** speaker chrome applies only to already-presented (and policy-eligible retained) text; never use speaker metadata to preview upcoming lines.
2. **Progressive enhancement:** baseline behavior must remain excellent **without** any speaker signal (plain captions in the lower band).
3. **Fail closed on ambiguity:** if attribution is missing, low-confidence, or heuristic-only, render **neutral** captions—no color-only identity, no chat alignment that implies certainty.
4. **Accessibility:** speaker distinction requires **visible text** (name, initials, or equivalent); color or accent is **secondary** only.
5. **No transcript-product drift:** bounded retention and scrolling policies stay in force; the feature must not become a full transcript viewer or future-subtitle previewer (see [AGENTS.md](AGENTS.md)).
6. **Fixture honesty:** local sidecar annotations and demo-only assets must be labeled PoC; they are not evidence of catalog-wide metadata availability (see [memlog/MultiSpeakerSupport3.md](memlog/MultiSpeakerSupport3.md), [memlog/MultiSpeakerSupport4.md](memlog/MultiSpeakerSupport4.md)).

Date: 2026-05-09  
Status: Proposed  
Platforms: iOS, tvOS, macOS (tvOS first per current Xcode targets)  
Owners: Playback, Accessibility, Captioning, Client Platform  
Related areas: WebVTT/IMSC semantics, `AVPlayerItemLegibleOutput`, cue persistence, SwiftUI caption band  

**Implementation alignment:** The tvOS playback shell currently receives legible output as [`NSAttributedString`](CaptionTheater/CaptionTheater/Playback/CaptionTheaterLegibleCaptionSink.swift) but flattens to plain text via [`.string`](CaptionTheater/CaptionTheater/Playback/CaptionTheaterLegibleCaptionFormatting.swift); any future use of attributed runs or raw WebVTT must be explicitly designed and tested.

---

## Context

### What formats can express “who spoke”

- **Visible text conventions** (SDH, captioning-key style): bracketed or parenthetical speaker labels, `>> Name:`-style conventions in some broadcast/live pipelines. These survive transcode to WebVTT/SRT and align with what [`AVPlayerItemLegibleOutput`](https://developer.apple.com/documentation/avfoundation/avplayeritemlegibleoutput) typically exposes as **plain cue text**.
- **WebVTT voice spans:** `<v Speaker>` per [WebVTT](https://webvtt.spec.whatwg.org/). Supported by the format; **prevalence** on consumer HLS catalogs is limited and must not be assumed (see [memlog/MultiSpeakerSupport3.md](memlog/MultiSpeakerSupport3.md) Research addendum).
- **TTML/IMSC `ttm:agent`:** Rich authoring metadata; **consumer** tvOS paths that deliver only normalized text may **strip** structure unless the app parses TTML/IMSC directly from packaged media.
- **HLS manifests:** Declare subtitle **renditions** (RFC 8216, Apple HLS authoring) but do **not** carry per-cue speaker identity; that lives in subtitle payload or app sidecars.

### What the repo ships today

- **Offline ultra-wide demo:** [`CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`](CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/) — `1920×800` HLS + segmented English WebVTT; **multi-character scene** but **no** machine-stable per-cue speaker ids in bundled VTT ([`Docs/Fixture-Inventory.md`](Docs/Fixture-Inventory.md)).
- **Executable proposal:** [Docs/MultiSpeakerProposal.md](Docs/MultiSpeakerProposal.md) defines MS-01…MS-07 tasks (e.g. optional PoC `speaker-map.json`, transcript rail, tests, runbook).

### Tension between “PoC sidecar” and “hero SMS demo”

- **[memlog/MultiSpeakerSupport3.md](memlog/MultiSpeakerSupport3.md)** allows **fixtureAnnotated** sidecars for demos and progressive chip/rail UI when **authored** visible labels or voice spans exist.
- **[memlog/MultiSpeakerSupport4.md](memlog/MultiSpeakerSupport4.md)** requires **source-authored** speaker identity in the subtitle **asset** before investing in **SMS/balloon** hero demos; it explicitly treats **invented sidecars** as **not** proving broad product viability for that visual metaphor.

**Resolution under this ADR:** **Transcript rail / speaker chip** tied to confidence tiers may use **fixtureAnnotated** sidecars for **internal** demos and tests. **Chat bubbles, conversational lanes, or strong spatial metaphors** default **off** until either (a) a qualified source-authored asset passes the stricter gate in MultiSpeakerSupport4, or (b) product explicitly accepts fixture-only hero demos with clear PoC labeling.

---

## Problem Statement

We need a single architecture decision that:

1. **Improves comprehension** when speaker changes matter (fast dialogue, off-screen speakers) **without** promising behavior that most streams cannot support.
2. **Avoids false certainty:** UI must not imply speaker identity or screen position when captions do not say so.
3. **Preserves ADR-0001 invariants:** timing, geometry, opt-in, ads/DRM boundaries, and “no future cues.”
4. **Accounts for implementation reality:** today’s legible path uses plain string flattening; structured signals may require parser work or attributed-string inspection.

---

## Decision

Adopt **tiered multi-speaker presentation** as **progressive enhancement**. Each tier has separate **acceptance** criteria and **marketing** implications.

### Tier A — Baseline (required)

**Capability:** Use `captionReadingRect` for wrapping, line breaks, caption size preferences, and retained-cue readability. No speaker chrome.

**Product promise:** Caption Theater makes captions easier to read in unused cinema-layout space (aligns with ADR-0001).

### Tier B — Opportunistic speaker affordances (recommended product extension)

**Capability:** When cues contain **credible authored visible** speaker labels (SDH / bracket / parenthetical / consistent `Name:` prefixes per parser rules), present a **transcript rail**: short label + dialogue, **run-collapsed** labels where consecutive lines share the same speaker, **neutral** fallback when parse finds no label.

**Confidence tier:** `authored` (visible text in cue) after normalization rules are documented and tested.

**Product promise:** “When captions already identify the speaker, we present that identity more clearly”—not “every line shows a speaker.”

### Tier C — WebVTT voice spans (`<v Speaker>`)

**Capability:** If **raw WebVTT** is parsed in-app **or** platform legible output **provably** preserves voice in `string` or attributes, lift speaker into the same rail/chip model as Tier B.

**Confidence tier:** `authored` when extracted from spec-correct `<v>` markup; requires **spike evidence** on target OS versions before relying on legible output alone.

**Product promise:** Opportunistic only; no catalog assumption.

### Tier D — Fixture-only annotation (PoC / tests)

**Capability:** Load `speaker-map.json` (or equivalent) with **time-range** keys aligned to known cue windows; merge into scrolling cue model for demos ([Docs/MultiSpeakerProposal.md](Docs/MultiSpeakerProposal.md)).

**Confidence tier:** `fixtureAnnotated` **only** for bundles marked PoC; must not be described as representative of streaming catalogs.

**Product promise:** Internal demo / QA only unless copy is explicitly scoped.

### Tier E — Deferred / gated hero metaphors (SMS bubbles, lanes, color-primary identity)

**Capability:** Conversation bubbles, left/right threading, multi-lane layouts, or **color as primary** differentiator.

**Gate:** Per [memlog/MultiSpeakerSupport4.md](memlog/MultiSpeakerSupport4.md)—**source-authored** timed speaker identity on a **qualifying** ultra-wide (or sufficient letterbox) asset with backup/redistribution clarity **before** these become **default** or **advertised** differentiators. **Fixture-only** hero is allowed only with explicit product approval and PoC labeling.

**Default under this ADR:** **Do not ship** Tier E as default UI.

### Tier F — Explicitly out of scope (unless product charter changes)

- Audio **diarization** with invented names in default UI.
- **Spatial** anchoring from inferred face/geometry without trusted metadata.
- **TTML/IMSC agent** parsing until a real ingested asset and parser path exist.

---

## Speaker confidence model

All speaker-specific chrome is gated:

| Confidence | Source | Chrome |
|------------|--------|--------|
| `authored` | Visible label in cue text; `<v>` from owned parser; provider metadata we trust | Full rail/chip (text + optional accent) |
| `fixtureAnnotated` | Repo sidecar / reviewed PoC map | Same as authored **only** in PoC/demo modes or labeled builds |
| `inferredWeak` | Heuristics, ASR guesses | **No** default speaker chrome; logging only if needed |
| `unknown` | No signal | Plain caption line |

**Rule:** Never use **color alone** for speaker identity; pair with textual label or initials.

---

## UI guidance

**Default production shape:** Restrained **transcript rail** (name/initials column + dialogue), optional **accent stripe** as secondary signal, **current vs retained** emphasis per existing persistence policy.

**Avoid by default:** Chat bubbles, iMessage metaphor, aggressive L/R alignment that implies on-screen speaker direction, rainbow palettes across many speakers.

**Reduce Motion / contrast:** Avoid ornamental animations for speaker transitions; respect system accessibility settings when wiring transitions.

---

## Consequences

### Positive

- Clearer attribution when captions already encode it; aligns with DCMP-style visible conventions.
- Baseline caption UX improves for **all** assets via Tier A regardless of speaker work.
- Explicit gates reduce reputational risk from over-claiming “smart speaker” behavior.

### Negative / costs

- Parser maintenance and false-positive QA for visible labels.
- Possible duplicate work if legible output later exposes richer structure—mitigate with small spikes before large parser investments.
- Documentation burden: PoC vs production paths must stay distinguishable in UI and docs.

### Risks

- **Metadata loss** in packaging or `AVPlayerItemLegibleOutput`—mitigate with fixtures and attributed-string inspection tests when pursuing Tier C.
- **Product drift** toward transcript wall—mitigate with retention caps and ADR-0001 rules.

---

## Verification checklist (before marking tier “Accepted”)

- [ ] Tier A: layout tests + manual demo on offline mock without speaker files.
- [ ] Tier B: unit tests on golden label strings; VoiceOver reads name then dialogue (or agreed order); no future-cue regressions.
- [ ] Tier D: `speaker-map.json` validated; provenance note in [Docs/Sources.md](Docs/Sources.md) or fixture README.
- [ ] Tier C: spike documented (platform + sample) or raw VTT parser path merged with tests.
- [ ] Tier E: explicit product sign-off + qualifying asset doc per MultiSpeakerSupport4 **if** shipping beyond PoC.

---

## Related documents

| Document | Role |
|----------|------|
| [ADR-0001](ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md) | Viewport, caption region, core Caption Theater rules |
| [memlog/MultiSpeakerSupport3.md](memlog/MultiSpeakerSupport3.md) | Feasibility audit, prevalence, research addendum |
| [memlog/MultiSpeakerSupport4.md](memlog/MultiSpeakerSupport4.md) | Ruthless asset gate for SMS/balloon hero |
| [memlog/MultiSpeakerSupport.md](memlog/MultiSpeakerSupport.md), [memlog/MultiSpeakerSupport2.md](memlog/MultiSpeakerSupport2.md) | Earlier UI and data-model exploration |
| [Docs/MultiSpeakerProposal.md](Docs/MultiSpeakerProposal.md) | MS-01…MS-07 task list, backup chain |
| [Docs/Fixture-Inventory.md](Docs/Fixture-Inventory.md) | Bundled offline HLS mock governance |

---

## Status lifecycle

| Status | Meaning |
|--------|---------|
| **Proposed** | This ADR; tiers A–D may proceed per TASKS and MultiSpeakerProposal |
| **Accepted (A+B)** | Baseline + opportunistic visible-label rail shipped with tests |
| **Accepted (+C)** | Voice-span or attributed-string path verified and merged |
| **Accepted (+E partial)** | Tier E demo-only behind flag with PoC label |
| **Rejected / parked** | Tier E cancelled for product; keep A–D only |

---

## Revision history

- **2026-05-09:** Initial ADR-0002; consolidates draft ADR content with memlog 3/4, MultiSpeakerProposal, and current legible-output implementation notes.
