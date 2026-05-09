# Multi-speaker caption support: synthesized plan

This document merges the working notes in `MultiSpeakerSupport.md` and `MultiSpeakerSupport2.md` into a single recommendation: what to build first, how to source reliable speaker identity, which visual patterns to prioritize, and how to stay inside Caption Theater’s rules (persistence, no future cues, geometry preserved).

For prior detail and alternatives, see:

- `MultiSpeakerSupport.md` — fixture gap, transcript rail vs chat vs color, Phase 4 cue-model alignment.
- `MultiSpeakerSupport2.md` — hero showcase narrative, bubble/stripe/lane options, `speaker-map.json` sketch, confidence enum, implementation slices, test matrix.

---

## Executive summary

**Showcase video:** Keep using the repo-local **Tears of Steel** offline HLS mock (`1920×800`, multi-character dialogue). It already proves **top-justified picture + lower reading band** without network dependency.

**Showcase metadata:** Do **not** pretend existing WebVTT cues carry stable speaker ids. Prefer one of:

1. **Sidecar annotation** (`speaker-map.json` keyed by **time ranges**, not cue indices, because segments reuse cue numbers), reviewed for PoC; or  
2. **Synthetic or extended WebVTT** with `<v Name>` voice tags or a strict `Name: ` prefix convention for tests and greenfield demos.

**Default UI direction:** A **hybrid**: **stacked lines in the lower band** + **speaker chip / transcript rail** (initials or short name) + **optional stable accent** (stripe or tint) **always paired with text**, not color alone. Use **controlled** left/right alignment or soft bubbles **only** when the data source **explicitly** marks a two-speaker exchange (or behind an experiment flag), to avoid implying on-screen position that does not exist.

**Not MVP default:** Full chat chrome, multi-lane “transcript timeline,” or spatial anchoring from inferred geometry (later research only).

---

## Why this fits the product

Both sources agree the lower band should earn its pixels: help viewers with **who spoke**, **continuity with the previous line**, and **fast handoffs**, especially for off-screen speakers, overlaps, long translated lines, and SDH where identity aids comprehension.

**Top-pinned scope layout** matters because:

- There is **vertical room** for a short thread (current + retained lines) without obscuring the picture.  
- **Stable rhythm** (e.g. newest-at-top policy) plus speaker chrome reduces scan cost.  
- The win is the **dedicated reading region**, not squeezing labels into the frame.

---

## Non-negotiables (merged constraints)

- **Persist only** already-presented cues (plus policy-eligible retention); **no future cues** by default.  
- **Preserve video geometry**; ads and native playback boundaries stay intact.  
- **Caption region** stays within layout (`CaptionTheaterLayoutGeometry/captionReadingRect`); respect caption text size as the renderer matures.  
- **Accessibility:** speaker distinction requires **name or initials (text)**, not color alone; sane contrast; VoiceOver should expose **who** then **what** when we own the accessible hierarchy; respect **Reduce Motion** (avoid ornamental lane/bubble motion).  
- **Fail closed:** when speaker identity is unknown or low-confidence, use **neutral** styling.  
- **Do not** reposition the product as a full **transcript viewer** or **future subtitle preview**.

---

## Visual patterns: what to take from each approach

| Idea | Source | Role in synthesis |
|------|--------|-------------------|
| **Transcript rail** (narrow column: icon / initials / chip + wrapped body) | MS1 | **Core of MVP-shaped UI**; maps to optional `speaker` on internal cue model; degrades to plain text. |
| **Speaker color stripes / hash hue** | MS1, MS2 | **Secondary signal** only; chip + label remain primary. |
| **Conversation bubbles + L/R alignment** | MS1, MS2 | **Demo / research** variant; two primary speakers only; risk of “chat app” feel and false spatial implications. |
| **Speaker lanes** | MS2 | **Experimental**; watch vertical cost and transcript-like appearance; not default. |
| **Spatial anchoring** | MS2 | **Defer** without trusted annotations; no face-inferred positions for MVP. |
| **SDH / bracket labels in source** | MS1 | **Trust when authored**; parser lifts display name; high trust, not flashy. |
| **Hybrid MVP** | MS2 | **Adopt as default direction**: stacked text + chip + optional accent + optional conditional L/R when data allows. |

**Best composite:** **Hybrid (MS2) + transcript rail terminology (MS1)** = same thing stated two ways; implementation should lead with **rail + chip**, emphasize **current cue** vs **dimmed retained**, and collapse repeated labels within a **run** of the same speaker (MS2).

---

## Data model and confidence (from MS2, aligned with MS1 Phase 4)

Canonical cues should eventually carry optional structured speaker data, not presentation baked into VTT files (MS1 medium-term).

Minimum useful fields:

- **Cue:** id, timing, text payload, optional **speaker** attachment.  
- **Speaker:** stable `id`, `displayName`, `shortLabel`; optional **accent** hint for UI; **confidence** tier.

**Confidence tiers (apply styling only for safe tiers):**

| Tier | Meaning | Default UI |
|------|---------|------------|
| `authored` | WebVTT `<v>`, provider metadata, explicit SDH label | Full speaker chrome |
| `fixtureAnnotated` | Reviewed sidecar (e.g. `speaker-map.json`) | Full speaker chrome for demos |
| `inferredWeak` | Heuristics only | **Neutral** (no speaker chrome) |
| `unknown` | No attribution | **Neutral** |

For Tears of Steel today, target **`fixtureAnnotated`** via sidecar until/adunless voice tags are added in a controlled fixture.

**Sidecar shape (MS2):** JSON with `speakers[]` and `cues[]` entries using **`start` / `end`** times (seconds) matching WebVTT windows; validate `speakerID` references. Prefer time-based matching because **segment-local cue ids conflict across files**.

Alternative **short term (MS1):** small synthetic VTT with voice tags or prefixes for **unit tests** (`speaker extraction`, renderer snapshots), without committing to editing shipped mock subtitles.

---

## Renderer behavior (merged rules)

- Apply speaker styling only when confidence is **`authored`** or **`fixtureAnnotated`**.  
- **Current cue:** strongest contrast, caption size preset applied; speaker chip visible; optionally stronger accent.  
- **Retained cues:** readable but visually **historical** (dimmer / lighter secondary); same speaker identity treatment; bounded by existing scroll/history policy.  
- **Runs:** show speaker label on **first cue of a run**; suppress duplicate labels for consecutive same-speaker lines (exact thresholds open; see open questions).  
- **Never** change authored timing or leak future text.  
- **Color:** never sole differentiator; pair with label, weight, or rail position.

---

## Testing and acceptance (merged)

**From MS1 (milestone-level):**

- Fixture encodes **≥2 speakers** and **≥10 alternating lines** in ultrawide/letterboxed context.  
- UI proves **≥1 non-color-only** differentiator.  
- **Reduce Motion:** avoid ornamental motion.  
- No pre-start cues; retention policy unchanged.

**From MS2 (concrete tests):**

- Decode and validate sidecar; reject bad `speakerID`; time-range match to cues; unknown fallback; no future cues in retained list; label run-collapse behavior.  
- Snapshots: two-speaker exchange, three-speaker brief, unknown fallback, long wrapped line + chip, high contrast/largest text if applicable.  
- Manual: undistorted top video; lower band clarifies **who**; fast exchange easier than native-only; retained block does not read as an endless transcript wall.

---

## Implementation slices (consolidated)

1. **Fixture + parser:** `speaker-map.json` (or synthetic VTT + voice tags) + Swift types + unit tests.  
2. **Cue enrichment:** join annotations by time range into scrolling cue entries / internal model; plain path unchanged.  
3. **Renderer prototype:** rail + chip + optional accent; hybrid as default; bubbles/lanes behind flags.  
4. **Demo compare:** native subtitles vs Caption Theater flat vs speaker-aware (short script).

Later: align fields with **CT-0401** internal cue model so VTT-specific details do not leak into renderer decisions.

---

## Open questions (deduplicated)

- Label **every** cue vs **only on speaker change** vs run-collapsed (recommend: run-collapsed with clear rule when gap exceeds N seconds).  
- Left/right alignment: require **explicit** two-speaker metadata flag vs automatic for exactly two `fixtureAnnotated` ids?  
- **Cap** distinct accent colors (e.g. max 4 prominent) before falling back to neutral + text only.  
- Trust **authored** SDH brackets automatically when present? (Likely yes for `authored`, with normalization.)  
- Speaker styling: **user toggle** vs automatic when metadata exists?

---

## Recommendation (one paragraph)

Use **Tears of Steel** plus a **reviewed time-keyed sidecar** (or parallel **synthetic VTT** for tests) so speaker identity is **honest and stable**. Ship a **hybrid renderer**: **transcript rail / speaker chip**, **optional accent** with **textual labels**, **run-collapsed names**, and **current vs retained** emphasis—while reserving **bubbles, lanes, and spatial anchoring** for experiments. This matches both documents: maximal comprehension benefit from the **lower band**, minimal betrayal of trust (no fake inference), and strict alignment with **persistence, geometry, and accessibility** commitments.
