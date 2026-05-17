# Multi-speaker proposal: asset gate, backups, and task list

Date: 2026-05-09  
Status: Proposal (asset-gated; not yet approved for UI implementation)  
Related: [ADR-0002 Multi-Speaker Caption Presentation](../ADR-0002-Multi-Speaker-Caption-Presentation.md) (architecture + task framing), [memlog/MultiSpeakerSupport4.md](../memlog/MultiSpeakerSupport4.md) (ruthless asset gate), [memlog/MultiSpeakerSupport3.md](../memlog/MultiSpeakerSupport3.md) (feasibility audit), [Docs/Fixture-Inventory.md](Fixture-Inventory.md)

This document is intentionally stricter than the earlier PoC notes. A text-balloon / SMS-style demo is only worth building if we can point at a real, backed-up asset whose subtitle data already supports speaker identity. If we cannot, the right product work is caption readability, wrapping, retention, and opportunistic speaker chips for authored labels.

---

## Proposal assessment

### What is good in the earlier plan

- It correctly identifies the existing offline Tears of Steel package as the best **layout and backup** asset: local HLS, `1920x800`, segmented WebVTT, and no network requirement.
- It gives useful engineering pieces: launch source, bundle tests, sidecar validation, time-range matching, and a demo runbook.
- It keeps inference out of the renderer, which is the correct trust boundary.
- It separates the baseline demo from network fallback and smoke-only fallback.

### What is weak or unsafe

- It treats `speaker-map.json` as enough to justify a “multi-speaker” demo. That is acceptable for an internal PoC, but it does **not** prove the product idea is viable because the speaker identity would be invented by us.
- It does not start with asset qualification. The first task should be proving we have a usable source-authored asset, not authoring sidecar metadata.
- It risks building SMS/balloon UI for a rare or nonexistent asset class.
- It does not clearly distinguish three different outcomes:
  - production-safe caption improvements;
  - internal fixture-only speaker demo;
  - real hero demo backed by source-authored speaker attribution.

### Decision from this review

Do **not** proceed directly to sidecar + SMS UI. Keep the practical pieces, but move them behind a gate:

1. **Always pursue:** wrapping, text size, retention, baseline caption band, visible SDH label preservation.
2. **Allow for internal PoC:** `speaker-map.json` plus transcript rail only, clearly labeled fixture-driven.
3. **Require real asset before building:** SMS balloons, left/right chat alignment, speaker lanes, or any hero claim that Caption Theater can transform dialogue into a conversation UI.

---

## Demo asset contract

A candidate must satisfy all of these before it can justify SMS/balloon UI work:

- playable offline or backuppable locally;
- license/provenance documented before packaging;
- HLS VOD or source media convertible to local HLS;
- ultra-wide or letterboxed enough to visibly showcase Caption Theater space;
- timed text with **source-authored** speaker identity, not an invented sidecar;
- at least 2 named speakers;
- at least 10 alternating speaker-attributed cues in a short scene;
- cue-level timing, not paragraph-level transcript timing;
- no DRM, private credentials, cookies, or protected frames.

If any requirement fails, the asset can still be useful for parser tests or layout tests, but it cannot be the “perfect demo.”

---

## Current asset scorecard

| Candidate | What it proves | What it fails | Current decision |
|-----------|----------------|---------------|------------------|
| Bundled Tears of Steel offline HLS | Offline playback, `1920x800`, segmented WebVTT, backup chain | No source-authored speaker ids | Use for baseline layout and internal sidecar PoC only. |
| Mux Tears of Steel network HLS | Public HLS + ultrawide + subtitles | Network dependency; live VTT sampled as plain dialogue; no speaker ids | Layout fallback only; do not claim speaker metadata. |
| Blender Tears of Steel source + official subtitles | Potentially clearer license path and source-media rebuild | Official subtitles likely plain text; must be inspected | Candidate for backup/license cleanup, not yet speaker demo. |
| American Archive speaker-tagged transcripts | Real `<v Speaker>` transcript text and many named speakers | Not proven as HLS subtitle track; paragraph timing; access/backup constraints; not ultrawide | Parser research only unless media + timed subtitle path qualifies. |
| Bitmovin Sintel HLS | Known HLS/WebVTT test candidate | CDN access denied from recent fetch; speaker markup unverified | Inconclusive; recheck only as asset discovery. |
| Wholly owned short clip | Full control over media, license, captions, and backup | Requires creating or sourcing content | Best route if no public asset qualifies. |

**Current gate status:** no known asset qualifies for SMS/balloon hero UI.

---

## Backup chain

1. **Primary baseline demo:** offline mock via `CaptionTheaterPlaybackDemoSource.bundledOfflineHLSMock`; verify bundle integrity with `CaptionTheaterOfflineHLSBundleTests`.
2. **If offline bundle breaks:** fix resource packaging until tests pass. Do not fall back to network for the primary offline claim.
3. **Network fallback:** `muxTearsOfSteelHLS` may show layout only; do not claim speaker attribution without raw subtitle proof.
4. **Smoke fallback:** bundled sample MP4 may prove app launch/playback only; it is not a multi-speaker demo.
5. **Future qualifying asset:** if one passes the asset contract, create a local HLS backup with provenance and checksum manifest before renderer work starts.

---

## Actionable tasks

Use these as issue/PR bullets. Stop at the first failed gate unless the task says it is still useful for baseline caption work.

| ID | Task | Acceptance criteria |
|----|------|---------------------|
| **MS-GATE-01** | Build an asset scorecard. Include Tears offline, Mux Tears, Blender Tears source, American Archive candidates, Bitmovin Sintel, and at least 5 additional public HLS/WebVTT/IMSC candidates. | Each row records URL/source, license posture, video aspect ratio, subtitle format, speaker attribution type, timing granularity, and backup feasibility. |
| **MS-GATE-02** | Inspect raw subtitle files for each candidate. Search for WebVTT `<v Speaker>`, `Speaker:`, `>> Speaker:`, `[Speaker]`, and TTML/IMSC `ttm:agent`. | At least one candidate either passes the speaker requirement or is explicitly rejected with evidence. |
| **MS-GATE-03** | Verify backup feasibility for any candidate that passes subtitle inspection. | Candidate has downloadable source/HLS, local subtitle preservation, playlist rewrite path, provenance note, and checksum plan. |
| **MS-GATE-04** | Make a go/no-go decision. | If no asset passes, mark SMS/balloon UI as parked and proceed only with baseline caption readability and authored-label chips. |
| **MS-BASE-01** | Preserve baseline offline demo path. | `bundledOfflineHLSMock` launches local `master.m3u8` with no network; bundle tests remain green. |
| **MS-BASE-02** | Add authored-label parser tests using synthetic text fixtures, not demo claims. | Visible SDH labels parse into speaker chips; false positives fall back to neutral captions. |
| **MS-POC-01** | Optional internal-only `speaker-map.json` for Tears of Steel. | Clearly labeled fixture annotation; transcript rail only; not used to justify SMS/balloon UI or product claims. |
| **MS-POC-02** | Optional PoC transcript rail renderer. | Shows speaker chip + text for `fixtureAnnotated`; neutral fallback unchanged; no chat alignment. |
| **MS-HERO-01** | Only after gates pass: implement SMS/balloon prototype behind code-level feature toggle. | Uses source-authored speaker identity from the qualifying asset; no sidecar-only proof; no inferred identity. |
| **MS-DOC-01** | Add demo runbook after either PoC or hero path is selected. | Runbook names exact source, launch args, offline backup, fallback caveats, and test command. |

---

## Pros and cons by path

### Path A: Baseline caption readability

**Pros**

- Works for almost every eligible text subtitle asset.
- Directly supports Caption Theater's core promise.
- Does not depend on rare speaker metadata.

**Cons**

- Less visually novel than SMS-style UI.
- Does not solve speaker attribution when captions omit it.

**Verdict:** highest-confidence product work.

### Path B: Authored-label speaker chips

**Pros**

- Practical because SDH labels and visible `Speaker:` conventions exist.
- Keeps attribution textual and accessible.
- Degrades cleanly to plain captions.

**Cons**

- Intermittent: many tracks identify speakers only when needed.
- Parser false positives require careful tests.

**Verdict:** reasonable progressive enhancement.

### Path C: Tears sidecar PoC

**Pros**

- Fastest way to demonstrate UI mechanics offline.
- Uses our strongest existing layout fixture.
- Good for tests of time-range matching and fallback behavior.

**Cons**

- Speaker identity is invented by us.
- Does not prove broad product viability.
- Must be labeled PoC to avoid misleading ourselves.

**Verdict:** useful engineering sandbox, weak product evidence.

### Path D: SMS / balloon hero UI

**Pros**

- Could be visually memorable if the asset naturally supports it.
- Could clarify rapid two-person exchanges better than ordinary captions.

**Cons**

- Requires a rare combination of source-authored speaker identity, cue-level timing, usable media, backup rights, and good scene composition.
- Left/right or bubble UI can imply speaker position or certainty the data does not contain.
- If no real asset qualifies, implementation is theater rather than product work.

**Verdict:** parked until the asset gate passes.

---

## Explicit non-goals

- Do not build SMS/balloon UI from invented sidecar data.
- Do not infer speakers from dialogue text, names mentioned in lines, voice, face detection, or scene position.
- Do not treat HLS subtitle presence as speaker metadata.
- Do not broaden into TTML/IMSC agent parsing without a real asset and ingestion path.
- Do not make a product claim that retail streams expose stable per-cue speaker ids.

---

## Recommended next step

Run **MS-GATE-01** through **MS-GATE-04** before any speaker-specific renderer work. If the gate fails, close the SMS/balloon idea for now and move implementation effort to baseline readability plus authored-label chips.
