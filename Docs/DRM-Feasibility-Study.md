# DRM Feasibility Study

Status: `IN PROGRESS` for metadata-first validation using approved in-repo fixtures (see **CT-0204 Approval Checklist**). Status remains `BLOCKED` for live FairPlay or other private protected-stream URLs until those rows in `TASKS.md` (CT-0204 stream inventory) move to `approved`.

## Purpose

Caption Theater must understand what protected playback can safely expose without depending on raw frame access. This study defines the evidence we need, the questions to answer, and the approval gates before testing real DRM/FairPlay streams.

## CT-0204 Approval Checklist

Complete one checklist row per sanitized stream alias before expanding scope. Do not commit credentials, keys, tokens, or unsanitized manifests.

| Field | Description | Record |
| --- | --- | --- |
| **Sanitized stream alias** | Internal codename only; never a raw URL or entitlement label | `ct0204-metadata-first-fixtures-bundle` (fixture phase; see `TASKS.md`) |
| **Approval owner** | Named person or role accountable for this alias | Project maintainers / in-repo fixture policy (`AGENTS.md` privacy rules) |
| **Allowed test scope** | What may be exercised: manifest parsing, AVFoundation surfaces, media selection, timed metadata, provider metadata, frame sampling | Manifest tags and static fixture inspection only until live stream approval |
| **Frame sampling allowed** | Explicit yes / no / not yet | **No** for this alias (fixtures are text/JSON; no `AVPlayerItemVideoOutput` on protected frames) |
| **Sanitized metadata logging allowed** | Whether findings may be logged or committed; must exclude secrets | **Yes**, only redacted summaries and structure (tag names, counts, classification enums)—no raw keys, cookies, or full production playlists |

For each additional alias (for example a representative FairPlay test stream), copy the row template into `TASKS.md` stream inventory and fill **Approval owner** and **Allowed test scope** from the relevant owners before changing status from `pending-approval` to `approved` or `metadata-only`.

## Owner Questions (Prepare Before Live Streams)

Ask playback, security, provider-metadata, and legal owners explicitly; capture answers in the result template.

### Playback owner

- Which representative FairPlay/HLS test streams may we use, under what naming alias?
- Which AVFoundation surfaces should we treat as authoritative for protected assets (asset metadata, tracks, media selection, timed metadata)?
- Are there streams where subtitle renditions or discontinuities are known-good for exercising inspection?

### Security / DRM owner

- May `AVPlayerItemVideoOutput` frame sampling be attempted in any controlled environment for this project?
- What must never be logged, stored, or committed (keys, SKD responses, license URLs, raw frames)?
- If frame sampling is forbidden, what classification should we record (`not-allowed` vs `metadata-only`)?

### Content / provider metadata owner

- Can QC or entitlement metadata be supplied to exercise `trusted-metadata-eligible` paths on protected content?
- Which fields are contractually safe to reflect in sanitized fixtures?

### Legal / content owner

- May sanitized stream aliases and non-secret findings from approved tests be committed to this repository?
- Any constraints on describing studio or distributor feeds in docs?

## Minimum Metadata-First Test Matrix (Before Private Streams)

Run these checks **before** using any private or production-like stream URL. Use checked-in `.m3u8` and JSON fixtures where noted; assert decisions via `CaptionTheaterDecisionEngine`, `HLSManifestInspector`, `ProviderMetadataInspector`, and related tests.

| # | Scenario | Expected classification / behavior |
| --- | --- | --- |
| 1 | Protected stream **without** trusted provider metadata | Stay **native** / `native-fallback-required`; decision engine uncertain or ineligible per policy |
| 2 | Protected stream **with** trusted provider metadata (fixture-backed) | Classify as **`trusted-metadata-eligible`** when QC inputs satisfy inspector rules |
| 3 | Protected stream with **only** manifest + AVFoundation-style metadata (no trusted provider package) | **`metadata-only`** or **`native-fallback-required`** depending on evidence; never assume pixel analysis |
| 4 | Frame sampling (only if approval checklist allows it) | Must **not** persist raw frames; if disallowed, record **`not-allowed`** or **`metadata-only`** and keep native playback unless trusted metadata exists |

Order of operations:

1. Manifest tags (variants, `EXT-X-MEDIA`, discontinuities, date ranges, encryption signals).
2. AVFoundation metadata surfaces (when a live asset exists and is approved).
3. Media-selection and subtitle track metadata.
4. Timed metadata if present.
5. Provider metadata availability and trust rules.
6. Frame sampling **only** if the checklist explicitly allows it; otherwise skip and document.

## Current Finding

The current implementation already supports the safe fallback policy:

- protected content without trusted metadata fails closed;
- trusted provider/QC metadata can authorize a DRM-like fixture;
- HLS encryption markers are detected as metadata evidence;
- no implementation stores raw frames, keys, credentials, or private stream URLs.

Real protected-stream testing is blocked until representative FairPlay/DRM test streams and usage approval are provided.

## Required Test Inputs

- Approved representative FairPlay/HLS test streams.
- Confirmation that the streams are safe to reference in local documentation.
- Expected metadata surfaces for each stream: manifest metadata, AVFoundation asset metadata, timed metadata, provider QC metadata, or none.
- A clear answer from playback/security owners about whether attempting `AVPlayerItemVideoOutput` frame sampling is allowed in the controlled test environment.

## Feasibility Questions

1. Can HLS manifest metadata be inspected for the protected stream?
2. Can AVFoundation expose useful asset, track, media-selection, or timed metadata?
3. Is raw frame access unavailable, blocked, or explicitly disallowed?
4. Can trusted provider metadata or allowlisting authorize safe Caption Theater regions?
5. Does the feature correctly fall back to native playback when evidence is incomplete?

## Classification Outcomes

- `metadata-only`: manifest, AVFoundation, or provider metadata is available, but raw frame access is unavailable or not allowed.
- `trusted-metadata-eligible`: provider/QC metadata safely authorizes Caption Theater eligibility.
- `native-fallback-required`: protected content lacks trusted metadata or allowlisting.
- `not-allowed`: security, legal, or platform policy forbids a test path.
- `not-available-in-stream`: the specific stream does not expose the needed metadata.
- `test-content-only`: a behavior is possible in controlled fixtures but not suitable for production assumptions.

## Test Procedure

1. Record approved stream identifier using a sanitized alias only.
2. Inspect manifest-level metadata for variants, subtitle declarations, discontinuities, date ranges, and encryption markers.
3. Inspect AVFoundation metadata surfaces without logging private values.
4. If approved, test whether frame sampling is technically available; do not store raw frames.
5. Evaluate whether provider metadata can authorize a safe region.
6. Record the final classification and fallback reason.

## Result Template

```text
Stream alias:
Approval owner:
Allowed test scope:
Manifest metadata available:
AVFoundation metadata available:
Timed metadata available:
Frame sampling allowed:
Frame sampling available:
Provider metadata available:
Caption Theater outcome:
Classification:
Notes:
```

## Safety Rules

- Do not store credentials, tokens, cookies, certificates, FairPlay keys, private stream URLs, raw protected frames, private media, or unsanitized production manifests.
- Do not bypass protected playback constraints.
- Do not require raw frame access for protected production playback.
- Fall back to native playback when protected content cannot be verified with trusted metadata or allowlisting.
