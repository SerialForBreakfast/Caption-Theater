

# Caption Theater Tasks

Status: Draft Product Execution Plan  
Role: Product Lead  
Scope: Proof of concept through production-readiness assessment  
Platforms: **tvOS-first in this repository** (current Xcode targets); **iOS** and **macOS** remain planned product expansions using the same modular core.

---

## Repository platform note

The Caption Theater Xcode project currently ships **tvOS-only** targets (`CaptionTheater`, `CaptionTheaterTests`, `CaptionTheaterUITests`). Tasks that describe an **iOS** playback shell or showcase should be read as **roadmap** until an iOS target exists; **Phase 5** showcase work should land on **tvOS** first to match the repo. Cross-platform feasibility (including macOS) stays in later phases.

---

## Task Status Key

- `TODO`: Not started.
- `IN PROGRESS`: Started, with remaining acceptance criteria or integration work.
- `DONE`: Completed for the current documented scope.
- `BLOCKED`: Cannot proceed without a decision, dependency, fixture, credential, or external input.

---

## Execution snapshot (groomed)

**Shipped in repo today**

- **Phase 1 core:** Stateless `CaptionTheaterDecisionEngine`, eligibility snapshot + evidence types (`CaptionTheaterEvidence`, sources, polarities), JSON decision fixtures, broad unit coverage.
- **Phase 2 foundations:** `HLSManifestInspector`, `ProviderMetadataInspector`, `SubtitleMetadataClassifier` with sanitized fixtures and tests.
- **DRM study:** `Docs/DRM-Feasibility-Study.md` + CT-0204 metadata-first stream inventory (live streams still gated).
- **Phase 5 shell (partial):** Bundled sample MP4 + **`PlaybackScenarios/`** inspector fusion + **`CaptionTheaterLayoutEngine`** / **`CaptionTheaterLayoutInputs`** (presentation aspect from `AVAssetTrack`, not pixels) + Playback tab **`tvOSCaptionTheaterPlayerContainer`** locked to **`resizeAspect`** with optional **top-pin MVP** + caption placeholder band + **caption text size menu** (`CaptionTheaterCaptionTextPreferences`). Safe-area/overscan refinement and cross-platform layout matrices remain **CT-0303** follow-through.

**Formal gaps**

- **Phase 1 exit:** Satisfied for fixture-driven explainability (**CT-0103** Debug tab). Coordinator-driven “live” transitions on device remain future work.
- **Phase 2 → playback:** **Partial:** bundled playback scenarios now fuse `HLSManifestInspector`, `ProviderMetadataInspector`, and `SubtitleMetadataClassifier` via `CaptionTheaterPlaybackEvidenceAssembler` on device (`PlaybackScenarios` resources). **Remaining CT-0502:** live `AVPlayerItem`/selection observers, timeline segments (native-only ranges), and ad-state hooks—not static fixtures alone.

**Reasonable next forks (pick one driving sequence)**

1. **CT-0303 / cinematic MVP** — Harden layout (safe area, overscan, animations) and ship readable captions into the computed caption band (Phase 4 slice).
2. **CT-0502 (finish)** — `AVPlayerItem` track selection + periodic snapshot refresh.
3. **CT-0301** — viewport preclassification feeding evidence before pixels return.
4. **CT-0001 / CT-0002** — hero narrative + broaden fixture inventory when demo readiness matters.

**Phase 0:** **CT-0002** is **partial** (`Docs/Fixture-Inventory.md` + manifest/subtitle/provider/decision JSON + bundled sample MP4 for the playback shell); synthetic frames and full demo matrix still TODO.

---

## 1. Product Goal

Caption Theater is a persistent timed-text readability mode for Apple-platform playback.

It gives viewers more readable dwell time for subtitle and caption text that has already appeared. The feature preserves recent caption context in verified safe screen space so viewers can finish reading dense, translated, SDH, or fast-moving captions without rewinding or losing picture context.

The goal of this task plan is to break the project into buildable phases that prove value, validate safety, expose production risks, and avoid premature investment in a full custom player.

---

## 2. Guiding Product Principles

1. **Readable dwell time is the primary value.**  
   The product should be judged by whether viewers can better read and retain already-presented captions.

2. **No future cue display by default.**  
   Caption Theater persists prior/current cue context. It should not preview upcoming dialogue.

3. **Native fallback is a feature, not a failure.**  
   If visual safety, subtitle semantics, ad state, DRM state, or platform compatibility is uncertain, the player should remain native.

4. **Evidence beats assumptions.**  
   The system should make decisions from manifest metadata, provider metadata, subtitle data, runtime state, and pixel analysis where available.

5. **Modular before polished.**  
   The proof of concept should validate pure modules before building a polished player UI.

6. **Ads, promos, legal disclosures, and burned-in text are hard safety boundaries.**  
   The feature must never alter or obscure required ad/legal/creative surfaces.

---

## 3. High-Level Timeline

These timeline estimates assume one small product/engineering team and can be compressed if workstreams run concurrently.

| Phase | Duration | Outcome |
|---|---:|---|
| Phase 0: Product Alignment and Fixtures | 1 week | Project scope, fixtures, expected results, and demo criteria are defined. |
| Phase 1: Evidence and State Foundation | 1–2 weeks | Eligibility decisions are deterministic, testable, and explainable without AVPlayer. |
| Phase 2: Metadata and Manifest Feasibility | 1–2 weeks | `.m3u8`, provider metadata, subtitle declarations, DRM risk, and ad markers are parsed into evidence. |
| Phase 3: Viewport Detection and Layout | 2–3 weeks | Safe inactive regions can be detected in fixtures and converted into stable layout geometry. |
| Phase 4: Caption Persistence Renderer | 2–3 weeks | WebVTT fixture cues render first, using an extensible cue model designed for the main subtitle/caption formats. |
| Phase 5: End-to-End Showcase | 2–3 weeks | A playable **tvOS** demo (this repo) proves native vs. Caption Theater value and fallback behavior; an **iOS** stakeholder demo remains roadmap-compatible. |
| Phase 6: Ads, Promos, and Boundary Safety | 1–2 weeks | Ads play normally fullscreen/native while Caption Theater suspends, then resumes or revalidates when content returns. |
| Phase 7: Additional platform feasibility | 2–3 weeks | **macOS** wrapper and any **iOS** target viability; tvOS-specific polish, focus, remote, resize (macOS), and accessibility risks are documented. |
| Phase 8: Production Readiness Assessment | 1 week | Team decides whether to proceed, narrow scope, or stop. |

Total expected POC window: approximately 10–17 weeks depending on staffing, fixture availability, and platform scope.

---

## 4. Workstreams

### Product and UX

Responsibilities:

- define user value;
- define settings and user-facing copy;
- define demo script;
- define the ultra-widescreen entry prompt and opt-in transition behavior;
- define readability success metrics;
- decide when persistent cues are helpful or distracting;
- coordinate stakeholder review.

### Playback Engineering

Responsibilities:

- build player sample harness;
- integrate `AVPlayerLayer` container;
- manage playback state;
- validate seek, pause, resume, route, and lifecycle behavior;
- evaluate AVKit/native player constraints.

### Caption and Subtitle Engineering

Responsibilities:

- define cue model;
- parse/adapt WebVTT fixtures first while designing the cue model for the main subtitle/caption formats;
- implement persistence policy;
- preserve cue semantics;
- prevent duplicate native/custom caption rendering.

### Video Analysis and Metadata

Responsibilities:

- parse HLS manifests;
- parse provider metadata stubs;
- classify viewport metadata;
- implement frame-analysis fixtures;
- identify unsafe visual-region evidence.

### Ads and Monetization

Responsibilities:

- define ad-state contract;
- simulate ad pods;
- simulate pause promos;
- define suppression rules;
- ensure ad/legal surfaces are not altered.

### QA and Accessibility

Responsibilities:

- define fixture matrix;
- define acceptance test matrix;
- validate VoiceOver, large captions, high contrast, and tvOS focus;
- validate fallback states;
- document known failures.

---

## 5. Phase 0: Product Alignment and Fixtures

### Goal

Define the controlled world where Caption Theater can be tested before real-stream complexity is introduced.

### Requirements

- Define the product value in terms of readable dwell time.
- Define the first hero demo scenario: ultra-widescreen content on a 16:9 screen with an opt-in Caption Theater prompt.
- Create fixture categories for video, frames, subtitles, manifests, and provider metadata.
- Document the expected result for every fixture.
- Define baseline vs. Caption Theater demo criteria.

### Key Tasks

#### CT-0001 [DONE]: Define Hero Demo Narrative

User Story:
As a stakeholder, I want to see the Caption Theater benefit in under five minutes so I can understand why the POC is worth building.

Implementation Status:

- Baseline hero narrative, first-demo scenario, opt-in framing, ads behavior, and demo controls are documented in `README.md` (product thesis, first demo scenario, developer demo controls). Formal scripted run-of-show for recordings remains with **CT-0503**.

Tasks:

- Define the ultra-widescreen-on-16:9 hero scenario.
- Define the eligibility prompt copy: “Would you like to enter Caption Theater mode?”
- Define native centered baseline behavior.
- Define the accepted state where content transitions from centered to top-aligned presentation.
- Define the lower caption reading region behavior.
- Define persistent caption behavior during fast dialogue.
- Define one unsafe fallback scenario.
- Define normal fullscreen ad behavior and content-resume behavior.

Acceptance Criteria:

- Demo script is written.
- Hero clip requirements are documented.
- Hero clip uses ultra-widescreen content on a 16:9 screen.
- Demo includes the Caption Theater opt-in prompt.
- Demo shows the video transition from centered to top-aligned presentation.
- Demo shows captions using the larger lower reading region.
- Demo does not depend on production streams.
- Demo explicitly states that future cues are not shown.
- Demo shows ads playing normally fullscreen/native and Caption Theater resuming or revalidating after content returns.

#### CT-0002 [IN PROGRESS]: Create Fixture Inventory

User Story:
As an engineer, I need deterministic fixtures so every module can be tested without relying on external services.

Tasks:

- Create video fixture list.
- Create synthetic frame fixture list.
- Create WebVTT fixture list.
- Create HLS manifest fixture list.
- Create provider metadata fixture list.
- Create real-world source candidate list with URLs, license notes, attribution requirements, and expected use.
- Create generated-content fixture list for deterministic detector and renderer tests.
- Document expected classification for each fixture.

Acceptance Criteria:

- Fixture inventory includes eligible and ineligible cases.
- Every fixture has an expected decision.
- Fixture matrix includes eligible ultra-widescreen content, burned-in text, dark scene, ad marker, DRM marker, 4:3 pillarbox, variable aspect ratio, and unsupported subtitle examples.
- Fixture inventory separates real-world demo candidates, Apple HLS control references, and generated known-answer fixtures.

Implementation Status:

- Canonical map for **sanitized** JSON / `.m3u8` fixtures lives in `Docs/Fixture-Inventory.md` (decision scenarios, manifests, provider metadata, subtitle metadata, bundled offline HLS demo).
- Still TODO per tasks above: broader bundled **video** taxonomy, **synthetic frame** catalog, dense **WebVTT cue** fixtures for renderer tests, full **generation scripts** for raster/detector known-answers (**CT-0005** backlog).

#### CT-0003 [DONE]: Define Readability Metrics

User Story:
As a Product Lead, I need measurable success criteria so we can evaluate whether Caption Theater is actually useful.

Implementation Status:

- **Objective placeholders:** caption dwell time vs native baseline; percentage of cues still visible N seconds after end; rewind/replay counts during dense dialogue segments (lab + field instrumentation TBD).
- **Subjective placeholders:** post-demo Likert on readability and distraction; failure signals (confusion, timing unease).
- Full instrumentation and evaluation protocol land with **CT-0801** (POC evaluation).

Tasks:

- Define measurable dwell-time improvement.
- Define cue retention bounds.
- Define rewind/pause reduction metrics for demo testing.
- Define subjective user questions.
- Define failure metrics.


Acceptance Criteria:

- Metrics distinguish readability value from layout novelty.
- Metrics include both objective and subjective measures.
- Metrics include negative outcomes such as distraction, confusion, or perceived timing issues.

#### CT-0004 [DONE]: Source Real-World Widescreen Test Content

User Story:
As a product and playback team, we need legitimate real-world ultra-widescreen test content so the hero demo proves Caption Theater value without licensing ambiguity.

Implementation Status:

- Hero candidate (**Mux *Tears of Steel*** multivariant), secondary candidates, Apple HLS **control reference** URLs, offline mock posture, and CT-0005 cinematic pipeline sources are consolidated in `Docs/Sources.md` with validation notes.
- Bundled offline mock (`TearsOfSteelFiveMinuteMock`) and regeneration script (`Scripts/download_mux_offline_hls_mock.py`) support private offline demos.
- Per-asset license verification remains the publisher’s responsibility before **public** redistribution.

Candidate Sources:

- Tears of Steel download page: https://mango.blender.org/download/
- Tears of Steel project page: https://studio.blender.org/projects/tears-of-steel/
- Tears of Steel original video asset: https://studio.blender.org/projects/tears-of-steel/55f344892beb3300251b0172/?asset=5910
- Tears of Steel timed text example: https://commons.wikimedia.org/wiki/TimedText:Tears_of_Steel_in_4k_-_Official_Blender_Foundation_release.webm.en.srt
- Apple HLS example streams: https://developer.apple.com/streaming/examples/
- Apple HLS authoring specification: https://developer.apple.com/documentation/http-live-streaming/hls-authoring-specification-for-apple-devices

Tasks:

- Evaluate Tears of Steel as the primary real-world hero fixture.
- Verify the exact source file license, attribution requirements, and allowed local test usage.
- Select a 15–30 second segment with useful caption density.
- Convert or adapt available subtitles to WebVTT if needed.
- Document the source URL, license, attribution, original dimensions, expected aspect ratio, expected active-picture rect, and expected Caption Theater decision.
- Add Apple HLS sample streams as control references for HLS/WebVTT behavior, 16:9 fallback, and 4:3 classification.
- Avoid random trailers, streaming-service captures, or copyrighted production content unless explicitly approved.

Acceptance Criteria:

- At least one real ultra-widescreen candidate is documented for hero-demo testing.
- License and attribution notes are captured before committing local media.
- The selected segment has expected aspect ratio and active-picture bounds.
- At least one Apple HLS sample stream is documented as a control reference.
- The fixture inventory distinguishes real-world demo media from generated detector fixtures.

#### CT-0005 [IN PROGRESS]: Generate Purpose-Built Test Content

User Story:
As a detector and caption-rendering engineer, I need generated known-answer content so edge cases can be tested without relying on real media.

**Delivered (open masters + tooling)**

- **Cinematic open-content offline HLS pipeline** — `Scripts/build_ct0005_cinematic_open_hls.py` builds a **1920×800** HLS + English WebVTT package from Blender Foundation *Tears of Steel* mirrors plus official `TOS-en.srt`, with a default trim that favors iconic rooftop dialogue. Output default: `CaptionTheater/CaptionTheater/Media/OfflineHLS/BlenderToSCinematicClip/`. Documented in `Docs/Sources.md` (CT-0005 section). Downloads cache under `Fixtures/SourceDownloads/` (Git-ignored). See `Scripts/README.md` for when to use this script vs `download_mux_offline_hls_mock.py`.

**Backlog (fully synthetic / detector suite)**

- Generate an ultra-widescreen 2.39:1 active-picture fixture inside a 16:9 raster (fully synthetic raster, no third-party footage).
- Generate a matching WebVTT fixture with dense dialogue and SDH-style cues for synthetic visuals.
- Generate a full-frame 16:9 control fixture.
- Generate a 4:3 pillarbox stretch-goal fixture.
- Generate a variable-aspect stretch-goal fixture.
- Generate unsafe-region fixtures with burned-in subtitles, logo/watermark, legal-text-like content, and dark-scene false positives.
- Keep all generated fixtures inside the project directory.
- Document generation scripts and expected active-picture rects.

Acceptance Criteria:

- Generated fixtures are deterministic and project-local.
- Every generated fixture has an expected Caption Theater decision.
- Unsafe fixtures are suitable for automated detector tests.
- Open-derived bundles comply with source licensing before **public** redistribution (private dev/PoC use matches other offline HLS fixtures).
- Fully synthetic detector variants do not require external media licensing.
- Generation scripts do not write to `/tmp`, `/private/tmp`, `/var/tmp`, or any path outside the repository.

#### CT-0006 [DONE]: Create Five-Minute Offline HLS Mock of the Hero Stream

User Story:
As a demo owner, I need a repo-local offline version of the current hero stream so the Caption Theater proof of concept can be demonstrated without relying on internet connectivity or public-stream availability.

Context:

- Current hero candidate: Mux-hosted Tears of Steel HLS VOD documented in `Docs/Sources.md`.
- Intended use: private proof-of-concept and development fixture only, not release media.
- Public-repo risk: before making the repository public, re-check licensing, attribution, and redistribution rights for any downloaded third-party video, audio, subtitle, or playlist content.
- Scope preference: capture approximately the first five minutes of the exact stream path used by the app today, but keep the implementation narrow to one rendition plus subtitles rather than mirroring the whole adaptive ladder.

Tasks:

- Re-verify the Mux master playlist is reachable and still contains a true ultra-widescreen encoded variant, preferably `1920x800` or the nearest available cinematic aspect ratio.
- Re-verify the stream still declares sidecar WebVTT subtitles and identify the English subtitle playlist URI.
- Inspect the selected video variant, audio rendition, and subtitle playlists to determine segment duration, media sequence, discontinuity tags, and whether URLs are signed or time-limited.
- Select one video rendition for the offline fixture; do not download the entire adaptive ladder unless explicitly needed.
- Capture enough video, audio, and subtitle segments to cover at least the first five minutes of playback.
- Preserve a self-contained HLS structure under `CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`.
- Rewrite master, variant, audio, and subtitle playlists to use repo-local relative paths only.
- Trim playlists so they represent only the captured five-minute window and include correct `#EXT-X-TARGETDURATION`, `#EXT-X-MEDIA-SEQUENCE`, `#EXTINF`, and `#EXT-X-ENDLIST` behavior.
- Preserve WebVTT cue timing relative to the offline playback window; if subtitle playlists use segmented WebVTT, keep segment timing coherent with the media slice.
- Add a provenance file in the offline fixture folder documenting source URL, capture date, selected rendition, selected subtitle language, intended private POC use, and public-repo review requirement.
- Add an entry to `Docs/Sources.md` recording that the offline mock exists only as a development fixture and must be removed, replaced, or explicitly cleared before the repo becomes public.
- Add a `CaptionTheaterPlaybackDemoSource` case for the bundled offline HLS mock, separate from the live Mux stream and the bundled synthetic MP4.
- Ensure `playbackURL()` resolves the local master playlist from the app bundle and fails with a clear missing-resource placeholder if the offline fixture is absent.
- Update Xcode project resources so the offline HLS folder is included in the app target without flattening paths that HLS relative URIs depend on.
- Add smoke coverage that the offline fixture resources exist in the test bundle or app bundle with the expected master playlist, selected media playlist, subtitle playlist, and at least one media/subtitle segment.
- Add fixture inventory coverage documenting expected eligibility: ultra-widescreen video, WebVTT subtitles, clear content, Caption Theater eligible unless other runtime evidence blocks it.
- Verify on Apple TV Simulator or device with network disabled, using the offline source, that playback starts and Caption Theater can receive subtitle text.
- Record any failure modes, especially AVFoundation bundle URL restrictions, relative HLS path issues, signed URL expiration, subtitle selection failures, or missing audio/video segment references.

Acceptance Criteria:

- A single repo-local offline HLS package plays at least five minutes without internet access.
- The offline package includes local video/audio media segments and local WebVTT subtitle content, not just manifest stubs.
- The app has a selectable bundled offline HLS demo source.
- Caption Theater eligibility and subtitle extraction work against the offline source.
- The fixture is documented as private POC media and explicitly flagged for licensing review before public repository publication.
- All generated/downloaded files stay inside the repository.
- No private credentials, cookies, signed private URLs, DRM keys, raw protected frames, or unsanitized production manifests are stored.
- Tests or smoke checks fail clearly if the offline fixture is incomplete.

Non-Goals:

- Do not implement a full HLS downloader product feature.
- Do not mirror every Mux rendition.
- Do not ship the offline mock as release content.
- Do not use protected, paid, DRM, or streaming-service content.

Implementation Status:

- Offline media package at `CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/` (single `1920×800` ladder slice: MPEG-TS + segmented English WebVTT, playlists rewritten to repo-relative URIs, `PROVENANCE.md`, manifest checksum file).
- Regeneration path documented alongside Sources (`Scripts/download_mux_offline_hls_mock.py`).
- **App integration:** `CaptionTheaterPlaybackDemoSource.bundledOfflineHLSMock`, `CaptionTheaterPlaybackFixture.offlineHLSMockMasterPlaylistURL(bundle:)`, `OfflineHLS` folder reference on the tvOS app target (preserves subdirectory layout), `--caption-theater-offline-hls` / `-CaptionTheater.playbackDemoSource` launch shortcuts (`CaptionTheaterLaunchConfiguration`).
- **Automated coverage:** `CaptionTheaterOfflineHLSBundleTests` asserts bundled master/variant/subtitle playlists, sample `.ts` / `.vtt`, and key `#EXT-X-*` markers (`TASKS` acceptance: smoke checks fail when the fixture tree is incomplete).
- **Manual QA (each milestone / release candidate):** on tvOS Simulator or device, disable network, select **Offline HLS mock**, confirm playback starts and Caption Theater receives subtitle text; record regressions in `memlog/` or issue tracker.

### Phase 0 Exit Criteria

- Product thesis is agreed.
- Fixture inventory supports **current** metadata/decision modules (`Docs/Fixture-Inventory.md`); video, synthetic-frame, and full demo matrices may still be **in progress** (**CT-0002**).
- Demo narrative baseline documented (**CT-0001**; see `README.md`).
- Success metrics placeholders documented (**CT-0003**).
- Real-world widescreen candidate URLs and control streams documented (**CT-0004**; see `Docs/Sources.md`).
- Generated fixture strategy documented and open-master cinematic pipeline scripted (**CT-0005**; see `Docs/Sources.md`, `Scripts/README.md`).
- Offline hero-stream mock implemented with automated bundle smoke tests (**CT-0006**).

---

## 6. Phase 1: Evidence and State Foundation

### Goal

Build the decision engine before building playback UI.

### Requirements

- Every activation or fallback decision must be explainable.
- Eligibility evaluation **fails closed** for uncertainty.
- Core eligibility logic must be testable without AVPlayer.
- The system must separate viewport eligibility from subtitle eligibility.

### Key Tasks

#### CT-0101 [DONE]: Define Evidence Model

User Story:
As a playback engineer, I need eligibility decisions to carry evidence so unsafe activations can be diagnosed.

Tasks:

- Define `CaptionTheaterEvidenceSource`.
- Define evidence polarity (`CaptionTheaterEvidencePolarity`: positive / negative / uncertain).
- Define structured evidence payloads (`CaptionTheaterEvidence` with sanitized messages).
- Define confidence model _(deferred: future scoring on evidence or viewport confidence)_.
- Define time range support _(deferred: attach `CMTimeRange` when coordinator emits timed evidence)_.
- Surface ineligibility and uncertainty via typed reasons on `CaptionTheaterDecision`.

Acceptance Criteria:

- Evidence models conform to `Sendable`.
- Evidence can be logged without storing raw frames.
- Evidence can be displayed in debug UI _(model-ready; **CT-0103** provides the UI)_.
- Evidence distinguishes positive, negative, and uncertain signals.

Implementation Status:

- Shipped in `CaptionTheaterDecisionEngine.swift`: `CaptionTheaterEvidence`, `CaptionTheaterEvidenceSource`, `CaptionTheaterEvidencePolarity`, plus decision enums carrying evidence arrays.
- Explicit numeric confidence and timed evidence attachments remain future work.

#### CT-0102 [DONE]: Define Decision Engine and Lifecycle State Model

User Story:
As a QA engineer, I need deterministic eligibility decisions so edge cases can be tested reliably.

Tasks:

- Define `CaptionTheaterDecision`.
- Define playback state inputs (represented in `CaptionTheaterEligibilitySnapshot`).
- Define ad state inputs.
- Define subtitle state inputs.
- Define viewport state inputs.
- Define user setting inputs.
- Implement a **stateless** decision engine before adding playback lifecycle coordination.

Acceptance Criteria:

- User disable wins over all states.
- Ad pod start forces native presentation.
- Unknown ad state fails closed.
- Unsupported subtitle format fails closed.
- Unsafe region evidence suspends the feature.
- Seek, track change, audio change, discontinuity, and asset transition reset cue history _(owned by future **playback coordinator** + cue persistence — **Phase 4–5**; not part of the pure eligibility function)_.

Implementation Status:

- Completed stateless `CaptionTheaterDecisionEngine` + `CaptionTheaterEligibilitySnapshot` and related enums.
- Deterministic tests + JSON scenario fixtures cover eligible, user-disabled, ad, unknown-ad, unsupported-subtitle, unsafe-viewport, protected-content uncertainty, and fixture-matrix cases.
- Playback lifecycle, cancellation, and cue-history resets remain coordinator/renderer work.

#### CT-0103 [DONE]: Build Debug Decision Inspector

User Story:
As a Product Lead, I need to see why the feature is active or inactive so I can evaluate the product and safety tradeoffs.

Tasks:

- Display current mode.
- Display positive evidence.
- Display negative evidence.
- Display uncertainty reasons.
- Display last state transition _(placeholder copy until a playback coordinator emits real transitions)_.
- Display selected subtitle state.
- Display ad state.

Acceptance Criteria:

- Debug inspector works with fixture/fake data.
- Every state has a human-readable explanation.
- Unsafe states are obvious.
- Inspector is separate from production user UI.

Implementation Status:

- Added **Debug** tab on tvOS hosting ``CaptionTheaterDebugDecisionInspectorView`` with `NavigationSplitView`, scenario catalog (`CaptionTheaterDebugScenarioCatalog`), and grouped evidence panels (tvOS-safe section styling; no `GroupBox`).
- Added ``CaptionTheaterDebugDecisionInspection`` for mapping decisions into UI strings without touching AVFoundation.
- Added ``CaptionTheaterDebugInspectionTests`` for headline wiring on baseline / linear-ad / unknown-ad scenarios.

### Phase 1 Exit Criteria

- Decision engine has unit coverage.
- Evidence-bearing eligibility decisions run without AVPlayer.
- Debug inspector can explain fixture decisions (**CT-0103**: Debug tab + scenario catalog).
- No AVPlayer dependency is required for core decision tests.

---

## 7. Phase 2: Metadata and Manifest Feasibility

### Goal

Determine what `.m3u8`, AVFoundation metadata, provider metadata, and subtitle metadata can and cannot prove.

### Requirements

- Manifest parsing must never claim visual-region safety by itself.
- Provider metadata must be able to authorize DRM-like safe regions in fixtures.
- Missing trusted metadata for protected content must return native fallback.
- Subtitle transport must be classified.

### Key Tasks

#### CT-0201 [IN PROGRESS]: Parse HLS Manifest Fixtures

User Story:
As an engineer, I need to inspect `.m3u8` metadata so we can identify subtitle, ad, discontinuity, and DRM evidence.

Tasks:

- Parse `EXT-X-STREAM-INF`.
- Parse `RESOLUTION`, `CODECS`, `FRAME-RATE`, `AUDIO`, `SUBTITLES`, and `CLOSED-CAPTIONS` attributes.
- Parse `EXT-X-MEDIA`.
- Parse `TYPE`, `GROUP-ID`, `LANGUAGE`, `ASSOC-LANGUAGE`, `NAME`, `DEFAULT`, `AUTOSELECT`, `FORCED`, `CHARACTERISTICS`, and `URI`.
- Parse `EXT-X-DISCONTINUITY`.
- Parse `EXT-X-DATERANGE`.
- Parse `EXT-X-KEY` and `EXT-X-SESSION-KEY` markers.
- Convert findings to evidence.

Acceptance Criteria:

- Sidecar subtitles are distinguished from embedded closed captions.
- Forced subtitle tracks are identified.
- Discontinuities create revalidation evidence.
- Date ranges can create ad-risk evidence.
- Encryption creates DRM-risk evidence.
- Encoded resolution is not treated as active-picture evidence.

Implementation Status:

- Completed initial sanitized `HLSManifestInspector`.
- Added fixtures for sidecar WebVTT subtitles, embedded closed captions, ad date ranges, discontinuities, encryption markers, and no-subtitle controls.
- Added unit tests for manifest fact extraction.
- Conversion from manifest findings to decision evidence remains future work.

#### CT-0202 [IN PROGRESS]: Implement Provider Metadata Stub

User Story:
As a production architect, I need to simulate trusted QC metadata because DRM content may not allow pixel analysis.

Tasks:

- Define local JSON schema.
- Parse active picture rect.
- Parse safe caption regions.
- Parse eligibility policy.
- Parse blocklist policy.
- Parse variable-aspect timeline.
- Parse burned-in subtitle warnings.

Acceptance Criteria:

- Trusted metadata can make a DRM-like fixture eligible.
- Missing metadata keeps DRM-like fixture native.
- Blocklist metadata overrides pixel analysis.
- Metadata can define segment-level native-only regions.
- Metadata can define a declared active aspect ratio for the ultra-widescreen hero fixture.

Implementation Status:

- Completed initial sanitized provider metadata JSON schema and `ProviderMetadataInspector`.
- Added fixtures for trusted eligible metadata, blocklisted burned-in subtitle risk, native-only timeline segments, and incomplete metadata.
- Added unit tests showing trusted metadata can authorize a protected-content decision path, missing/incomplete metadata fails closed, and blocklist metadata forces native presentation.
- Runtime segment enforcement remains future playback coordination work.

#### CT-0203 [IN PROGRESS]: Classify Subtitle Transport and Format

User Story:
As a caption engineer, I need to know whether the selected captions can be rendered and persisted safely.

Tasks:

- Classify sidecar WebVTT.
- Classify embedded closed captions.
- Classify IMSC/TTML fixture metadata if available.
- Classify image-based subtitle fixtures.
- Classify native-only caption cases.

Acceptance Criteria:

- WebVTT fixtures are marked MVP-compatible.
- Embedded closed captions are marked native-only until a semantic extraction path exists.
- Image-based subtitles are not reflowed.
- Burned-in subtitles are not treated as caption data.

Implementation Status:

- Completed initial sanitized `SubtitleMetadataClassifier`.
- Added fixtures for sidecar WebVTT dialogue, sidecar WebVTT SDH, sidecar WebVTT forced narrative, embedded CEA-608 captions, image-based subtitles, burned-in subtitles, missing selected tracks, and unknown subtitle formats.
- Added unit tests for subtitle state and presentation policy classification.
- IMSC/TTML-specific fixture metadata remains future work.

#### CT-0204 [IN PROGRESS]: Run DRM Feasibility Study

User Story:
As a playback architect, I need to know whether representative protected streams allow any useful client-side Caption Theater analysis.

Tasks:

- Identify representative DRM/FairPlay test streams.
- Test whether raw frame access is available in controlled environments.
- Test whether manifest and AVFoundation metadata remain available.
- Test whether provider metadata can authorize a safe region when pixel analysis is unavailable.
- Document whether each stream is possible, blocked, unsupported, or metadata-only.

Acceptance Criteria:

- DRM feasibility findings are documented.
- The project distinguishes “not possible,” “not allowed,” “not available in this stream,” and “possible only in test content.”
- The system never requires raw frame access for protected production playback.
- Protected content without trusted metadata falls back to native presentation.

Implementation Status:

- Added `Docs/DRM-Feasibility-Study.md` with required inputs, test procedure, classification outcomes, result template, safety rules, **CT-0204 approval checklist**, **owner question lists**, and **minimum metadata-first test matrix** before private streams.
- Current code already covers protected-content fallback without trusted metadata and trusted provider metadata for DRM-like fixtures.
- **Sanitized stream inventory** (status key: `pending-approval`, `approved`, `not-allowed`, `metadata-only`):

| Sanitized alias | Status | Allowed scope | Notes |
| --- | --- | --- | --- |
| `ct0204-metadata-first-fixtures-bundle` | `approved` | Manifest/static fixture inspection only (`CaptionTheaterTests/Fixtures/Manifests`, provider/subtitle JSON); no live playback URLs | Approval owner recorded in `Docs/DRM-Feasibility-Study.md` checklist; satisfies metadata-first phase |
| `ct0204-live-fairplay-representative` | `pending-approval` | TBD after playback/security sign-off | Requires checklist row completion and DRM owner answers before `approved` or `metadata-only` |

- Live FairPlay stream validation remains gated until at least one live-stream row is `approved` or explicitly `metadata-only` with written scope; frame sampling remains **not allowed** unless the DRM checklist marks it **yes** for that alias.

### Phase 2 Exit Criteria

- Manifest, provider, and subtitle metadata facts are extractable from sanitized fixtures with unit coverage.
- Wiring those facts into runtime `CaptionTheaterEvidence` + snapshots during playback remains **CT-0502** / coordinator work.
- Debug inspector surfaces eligibility outcomes and evidence strings (**CT-0103**); wiring live manifest/subtitle rows into snapshots remains **CT-0502**.
- DRM safety policy is represented in code and tests (protected content without trusted metadata fails closed).
- DRM feasibility documentation and metadata-first gates exist (**CT-0204**); live-stream validation follows approved inventory rows.

---

## 8. Phase 3: Viewport Detection and Layout

### Goal

Detect safe inactive regions in non-DRM fixtures and compute stable video/caption layout.

### Requirements

- Detector must reject false positives such as dark scenes and burned-in subtitles.
- Layout must preserve aspect ratio.
- Layout must not crop or stretch active picture.
- Layout must return native geometry for full-frame 16:9.

### Key Tasks

#### CT-0301 [TODO]: Implement Viewport Preclassification

User Story:
As a detector developer, I need cheap preclassification before pixel analysis.

Tasks:

- Normalize presentation size.
- Classify full-frame 16:9.
- Classify eligible ultra-widescreen candidate.
- Classify 4:3 pillarbox.
- Classify windowboxed content.
- Classify square/vertical content.
- Classify unknown content.
- Preserve 4:3, variable-aspect, and burned-in subtitle cases as stretch-goal classifications rather than removing them from the model.

Acceptance Criteria:

- Known fixture dimensions classify correctly.
- Preclassification never activates Caption Theater by itself.
- Classification is represented as evidence.

#### CT-0302 [TODO]: Implement Pixel Region Detector

**Milestone sequencing (native ultra-wide MVP):** Ship **presentation-aspect + layout math** (`CaptionTheaterLayoutEngine`) and **`resizeAspect`-only** presentation first. **Defer CT-0302** until that MVP is demonstrated; pixel sampling then validates encoded-letterbox ambiguity, burned-in risk in bars, and logos—not the first proof of top-aligned scope on a 16:9 panel.

User Story:
As a playback engineer, I need a bounded detector that can identify safe inactive regions where pixel analysis is allowed.

Tasks:

- Extract luminance metrics.
- Detect top/bottom/side inactive bands.
- Compute active picture rect.
- Detect edge density in inactive regions.
- Detect text-like patterns in inactive regions.
- Detect motion/change in inactive regions for sequences.
- Detect inconsistent boundaries.
- Score confidence.

Acceptance Criteria:

- Detects known letterbox active rects.
- Rejects full-frame 16:9.
- Rejects dark-scene false positives.
- Rejects burned-in subtitles in bars.
- Rejects logos/watermarks in proposed reading region.
- Rejects variable-boundary fixture.
- Does not persist raw frames.

#### CT-0303 [IN PROGRESS]: Implement Layout Engine

**Partially shipped:** `CaptionTheaterLayoutInputs`, `CaptionTheaterLayoutGeometry`, `CaptionTheaterLayoutEngine`, and `CaptionTheaterLayoutEngineTests` implement native-centered vs **top-pinned** aspect-fit rects from **container size + picture aspect (w÷h)**; Playback tab integrates via `CaptionTheaterPlaybackShellViewModel.layoutGeometry` and `tvOSCaptionTheaterPlayerContainer` ( **`AVLayerVideoGravity.resizeAspect` only**). **Caption text size** presets persist via `@AppStorage` (`CaptionTheaterCaptionTextPreferences.textSizePresetStorageKey`) for MVP overlay + future Phase 4 renderer.

User Story:
As a UI engineer, I need deterministic geometry for native and Caption Theater presentation modes.

Tasks:

- Define layout input and output models.
- Implement native layout.
- Implement expanded bottom reading-region layout.
- Implement centered-to-top-aligned ultra-widescreen layout for the hero demo.
- Preserve aspect ratio.
- Respect safe area.
- Simulate tvOS overscan.
- Recompute on bounds change.

Acceptance Criteria:

- Active picture is not stretched.
- Active picture is not cropped.
- Caption region is non-negative.
- Full-frame 16:9 returns native layout.
- Layout tests cover common iOS, tvOS, and macOS container sizes.
- Hero layout test verifies top-aligned ultra-widescreen active picture with a larger lower caption region on a 16:9 screen.

### Phase 3 Exit Criteria

- Detector works against synthetic fixture corpus _(CT-0302; deferred until after native ultra-wide layout MVP per milestone sequencing note)._
- Layout engine has unit coverage _(partial: ultra-wide / full-frame regression tests landed)._
- Debug overlay can show active picture, inactive region, caption region, confidence, and fallback reason _(partial: debug HUD shows presentation aspect; caption band placeholder when top-pin enabled)._

---

## 9. Phase 4: Caption Persistence Renderer

### Goal

Render already-presented text cues with bounded persistence and no future cue display.

### Requirements

- WebVTT is the first implementation source, but the cue model must support the main subtitle/caption families over time.
- Respect **caption text size** preference (`CaptionTheaterCaptionTextSizePreset`, persisted under `CaptionTheaterCaptionTextPreferences.textSizePresetStorageKey`) when drawing into ``CaptionTheaterLayoutGeometry/captionReadingRect`` so expanded bands translate into larger readable captions without overlapping picture.
- Current cue appears during authored timing.
- Recently expired cue can persist briefly when safe.
- Retained cues must look historical, not current.
- Future cues must not appear by default.
- Cue history must clear at playback boundaries.

### Key Tasks

#### CT-0401 [TODO]: Define Internal Cue Model

User Story:
As a caption engineer, I need a normalized cue model so persistence logic is not tied directly to one parser.

Tasks:

- Define cue ID.
- Define start/end time.
- Define text payload.
- Define style payload.
- Define cue intent.
- Define authored positioning hints.
- Define persistence eligibility.

Acceptance Criteria:

- Cue model conforms to `Sendable`.
- Cue model can represent dialogue, SDH, forced, lyrics, legal, ad, and unknown cue types.
- Cue model preserves authored time.
- Cue model is not WebVTT-specific and can support future IMSC/TTML, CEA-608/708, and app-owned cue adapters.

#### CT-0402 [TODO]: Implement WebVTT Fixture Adapter

#### CT-0402A [TODO]: Define Main Subtitle Format Adapter Requirements

User Story:
As a caption engineer, I need the first implementation to avoid WebVTT-only assumptions so the product can support the main subtitle and caption formats later.

Tasks:

- Document adapter requirements for IMSC/TTML.
- Document adapter requirements for CEA-608/708.
- Document adapter requirements for app-owned cue models.
- Identify native-only or unsupported format cases.
- Identify semantic risks for roll-up captions, forced cues, lyrics, signs, and legal disclosures.

Acceptance Criteria:

- Format adapter requirements are documented.
- WebVTT implementation uses the shared internal cue model.
- Unsupported formats have explicit fallback behavior.
- The architecture does not require WebVTT-specific cue assumptions in the renderer.

User Story:
As a developer, I need WebVTT fixture cues converted into the internal cue model.

Tasks:

- Parse cue start/end times.
- Parse cue text.
- Preserve line breaks.
- Preserve basic italics or span hints if feasible.
- Parse cue settings where available.
- Apply fixture metadata for cue intent.

Acceptance Criteria:

- WebVTT fixtures convert deterministically.
- Dense dialogue fixture renders correctly.
- SDH fixture preserves speaker and sound-effect text.
- Forced/lyrics/legal fixtures are marked authored-timing-only by default.

#### CT-0403 [TODO]: Implement Persistence Window

User Story:
As a viewer, I want recent captions to remain visible briefly after they appeared so I can finish reading them.

Tasks:

- Select current cue from playback time.
- Retain expired eligible cues.
- Enforce maximum cue age.
- Enforce maximum visible cue count.
- Prevent future cue display.
- Clear history on seek.
- Clear history on subtitle track change.
- Clear history on audio track change.
- Clear history on ad boundary.
- Clear history on discontinuity.

Acceptance Criteria:

- No cue with future start time is displayed.
- Current cue appears during authored timing.
- Expired eligible cue can persist within configured bounds.
- Ineligible cue types do not persist by default.
- Boundary events clear retained history.

#### CT-0404 [TODO]: Implement Caption Renderer View

User Story:
As a viewer, I need current and retained captions to be readable and visually distinct.

Tasks:

- Render current cue prominently.
- Render retained cues in a de-emphasized style.
- Enforce reading-region bounds.
- Handle large text mode strategy.
- Avoid transcript-wall behavior.
- Add snapshot tests.

Acceptance Criteria:

- Retained text is visually distinct from current speech.
- Text stays inside reading region.
- Renderer handles empty state.
- Renderer handles pause state.
- Snapshot tests cover current-only, retained, large-text, and cleared-history states.

### Phase 4 Exit Criteria

- Caption persistence works with fixture cues.
- No future cue display is possible in default policy.
- Renderer can operate without AVPlayer.

---

## 10. Phase 5: End-to-End Showcase (tvOS-first)

### Goal

Prove the user value in a playable demo on **tvOS**, matching the current Xcode project. An **iOS** showcase remains a valid parallel stakeholder goal once an iOS target exists.

### Requirements

- Use local fixtures first.
- Include native and Caption Theater modes.
- Include an opt-in Caption Theater prompt for eligible ultra-widescreen content.
- Include a centered-to-top-aligned transition in the accepted state.
- Include safe and unsafe examples.
- Include debug overlay and fallback reasons.
- Include pause, resume, and seek behavior.

### Key Tasks

#### CT-0501 [DONE]: Build tvOS Playback Shell

User Story:
As a stakeholder, I need a playable sample to evaluate the experience.

Tasks:

- Extend the existing **tvOS** app target (or add a dedicated tvOS sample scene) for fixture-driven playback.
- Host playback with `AVPlayer` / `AVPlayerViewController` or an `AVPlayerLayer`-backed view hierarchy appropriate for tvOS.
- Load local fixture video.
- Add play/pause/seek controls.
- Add Caption Theater toggle.
- Add Caption Theater eligibility prompt for the hero flow.
- Add debug overlay toggle.

Acceptance Criteria:

- Fixture video plays locally (bundled `CaptionTheaterSamplePlayback.mp4`; generated synthetic letterboxed H.264, no audio).
- User can toggle native vs. Caption Theater mode (`Caption Theater session` confirms via dialog; demo toggles exercise eligibility paths until CT-0502 replaces stubs).
- Basic playback controls work (`VideoPlayer` scrubbing plus explicit transport buttons; SwiftUI `Slider` not used on tvOS).
- Debug overlay can be shown/hidden.

Deferred beyond this task (Phase 5 exit / CT-0303): centered-to-top-aligned hero transition, unsafe fixture swaps without rebuilding video.

#### CT-0502 [IN PROGRESS]: Wire Caption Theater Modules

User Story:
As an engineer, I need the sample app to exercise the real decision modules.

Tasks:

- Map outputs from `HLSManifestInspector`, `ProviderMetadataInspector`, and `SubtitleMetadataClassifier` (plus playback hooks) into `CaptionTheaterEligibilitySnapshot` and optional `CaptionTheaterEvidence` attachments.
- Connect viewport/detector results to layout engine when Phase 3 ships.
- Connect subtitle fixtures / track selection to persistence renderer when Phase 4 ships.
- Connect eligibility snapshots / decision-engine outputs to UI presentation.
- Connect fallback reason to debug UI.

**Done in repo for static bundled scenarios**

- `CaptionTheaterPlaybackEvidenceAssembler` merges manifest + provider + subtitle classifications into one snapshot (with explicit precedence comments).
- `CaptionTheater/Media/PlaybackScenarios/*` ships sanitized copies of existing JSON/M3U8 fixtures plus the Playback tab scenario picker.
- `CaptionTheaterPlaybackScenarioKind` covers encrypted-vs-clear manifests, full-frame manifest hints, burned-in subtitles, and variable-aspect provider warnings.
- `ProviderMetadataInspector` maps `variableAspectRatio` warnings to ``CaptionTheaterViewportState/variableAspectRatio`` before other policy branches.
- Unit coverage: `CaptionTheaterPlaybackEvidenceAssemblerTests` + `variable-aspect-warning` provider fixture test.

**Still open**

- Live `AVPlayer`/`AVPlayerItem` legible-track selection + timed metadata feeding the assembler (replace static scenario bundles incrementally).
- Provider timeline segments (`nativeOnly` ranges) tied to `CMTime`/playback hooks.
- Ad / promo lifecycle inputs into snapshots.

Acceptance Criteria:

- Eligible ultra-widescreen fixture prompts the viewer before activating Caption Theater. _(Prompt exists globally; still TODO: gate on live eligibility.)_
- Full-frame 16:9 fixture remains native. _(Covered by `fullFrame16x9WebVTT` scenario + manifest hint tests.)_
- Burned-in subtitle fixture remains native. _(Covered by `burnedInSubtitlesWithTrustedProvider` scenario + classifier.)_
- Variable-aspect fixture remains native. _(Covered by `variableAspectProviderWarning` scenario + inspector/tests.)_
- 4:3, variable-aspect, and burned-in subtitle fixtures are retained as stretch-goal classifications with explicit debug reasons. _(4:3 explicit scenario not yet added; variable-aspect + burned-in covered.)_
- Debug UI explains all outcomes. _(Playback eligibility summary + existing Debug tab.)_

#### CT-0503 [TODO]: Build Showcase Recording Flow

User Story:
As a Product Lead, I need a repeatable demo that shows the feature value quickly.

Tasks:

- Define recording steps.
- Record native baseline clip.
- Record Caption Theater clip.
- Record unsafe fallback clip.
- Record ad/promo fallback clip when Phase 6 is available.
- Capture before/after metrics.

Acceptance Criteria:

- Demo is under five minutes.
- Demo clearly shows increased readable dwell time.
- Demo states that future captions are not shown.
- Demo shows at least one fail-closed case.

### Phase 5 Exit Criteria

- tvOS showcase is repeatable (this repository).
- Product value is visible without explaining implementation details first.
- Unsafe fallback behavior is visible.

---

## 11. Phase 6: Ads, Promos, and Boundary Safety

### Goal

Prove that ads continue to play normally fullscreen/native while Caption Theater suspends during ad playback and resumes or revalidates when content returns.

### Requirements

- Linear ads play normally fullscreen/native.
- Caption Theater suspends during ad playback.
- DAI/SSAI-like markers force revalidation or suspension.
- Unknown ad state fails closed.
- Caption Theater resumes or revalidates when content playback returns.
- Pause promo behavior follows explicit product/ad policy rather than blanket caption-based suppression.

### Key Tasks

#### CT-0601 [TODO]: Implement Ad State Simulator

User Story:
As an ads stakeholder, I need proof that Caption Theater will not alter ad presentation.

Tasks:

- Simulate ad pod start.
- Simulate ad pod end.
- Simulate unknown ad state.
- Simulate DAI/SSAI marker event.
- Connect ad state to eligibility snapshots / decision engine inputs.
- Add transition tests.

Acceptance Criteria:

- Ad start immediately returns to normal fullscreen/native ad presentation.
- Unknown ad state returns to native presentation.
- Ad end triggers content revalidation.
- Caption Theater does not carry eligibility across ad boundaries.
- Caption Theater can resume after ads only after content returns and the mode is still valid.

#### CT-0602 [TODO]: Implement Pause Promo Simulator

User Story:
As a Product Lead, I need pause promos to coexist with caption accessibility.

Tasks:

- Simulate pause promo request.
- Detect whether Caption Theater is active.
- Apply an explicit product/ad policy for pause promo placement or presentation.
- Dismiss promo on resume.
- Dismiss promo on seek/scrub/back/subtitle-menu open.
- Log any caption/control conflict and the selected policy outcome.

Acceptance Criteria:

- Pause promo behavior follows the selected product/ad policy.
- Resume dismisses pause promo.
- Seek clears cue history and promo state.
- Any caption/control conflict is visible in debug UI.
- The POC does not assume automatic suppression merely because captions are visible.

### Phase 6 Exit Criteria

- Ads and promos safely override Caption Theater.
- Ad/promo state is represented in tests and debug UI.
- Demo can show monetization safety.

---

## 12. Phase 7: Additional Platform Feasibility

### Goal

Validate **macOS** (and optional future **iOS** target) viability while hardening the existing **tvOS** integration path.

### Requirements

- Shared core modules must compile for target platforms.
- Platform adapters must be thin.
- **tvOS** focus must remain stable on the primary shipping target.
- macOS resize/full-screen must remain stable when pursued.

### Key Tasks

#### CT-0701 [TODO]: tvOS Hardening Pass

User Story:
As a tvOS viewer, I need Caption Theater to work without breaking remote navigation, focus, or VoiceOver.

Tasks:

- Audit the existing **tvOS** host shell once Caption Theater modules attach.
- Add overscan-safe layout mode.
- Validate Siri Remote play/pause.
- Validate scrubbing.
- Validate focus does not enter passive caption overlay.
- Validate VoiceOver smoke behavior.
- Validate pause promo simulation.

Acceptance Criteria:

- Caption overlay is passive by default.
- Remote controls remain functional.
- Focus remains stable.
- Overscan-safe reading region is available.
- Platform blockers are documented.

#### CT-0702 [TODO]: macOS Feasibility Pass

User Story:
As a macOS viewer, I need Caption Theater to survive resize, full screen, and keyboard controls.

Tasks:

- Add macOS wrapper.
- Validate window resize.
- Validate full-screen transition.
- Validate keyboard controls.
- Validate backing scale changes.
- Validate caption overlay stability.

Acceptance Criteria:

- Shared core code works on macOS.
- Layout recomputes on resize.
- Full-screen behavior is stable.
- Keyboard controls remain functional.
- Platform blockers are documented.

### Phase 7 Exit Criteria

- Cross-platform feasibility report is written.
- iOS/tvOS/macOS blockers are identified.
- Production path is narrowed or confirmed.

---

## 13. Phase 8: Production Readiness Assessment

### Goal

Decide whether to proceed, narrow scope, keep as an experiment, or stop.

### Requirements

- Evaluate value, safety, complexity, and platform risk.
- Identify production dependencies.
- Identify stakeholder approvals.
- Define next-phase work if the project continues.

### Key Tasks

#### CT-0801 [TODO]: Run POC Evaluation

User Story:
As a Product Lead, I need a clear go/no-go recommendation based on evidence.

Tasks:

- Review showcase results.
- Review detector accuracy.
- Review subtitle persistence quality.
- Review ad/promo behavior.
- Review DRM strategy.
- Review platform feasibility.
- Review accessibility findings.
- Review legal/content/ad risks.

Acceptance Criteria:

- Recommendation is documented.
- Production blockers are explicit.
- Required stakeholder decisions are listed.
- Next-phase roadmap is written if proceeding.

#### CT-0802 [TODO]: Define Production Candidate Requirements

User Story:
As an engineering lead, I need clear production gates before this can be shipped.

Tasks:

- Define real HLS/TS validation plan.
- Define DRM metadata requirements.
- Define real ad lifecycle contract.
- Define subtitle pipeline contract.
- Define analytics requirements.
- Define kill-switch requirements.
- Define accessibility QA requirements.
- Define content/legal sign-off requirements.

Acceptance Criteria:

- Production candidate checklist is complete.
- Required dependencies are assigned to owners.
- Unknowns are tracked as risks or follow-up research.

### Phase 8 Exit Criteria

- Go/no-go/narrow-scope decision is complete.
- Production dependencies are documented.
- Updated roadmap exists if the project continues.

---

## 14. Concurrent Work Plan

The following work can proceed concurrently:

- Product can define demo script and readability metrics while engineering builds fixtures.
- Metadata parsing can proceed while decision-engine integration is being built.
- Layout engine can proceed using fake analysis input.
- Caption persistence can proceed using fixture cues without playback.
- Ad simulation can proceed against eligibility snapshots before real ad SDK integration.
- tvOS/macOS wrappers should wait until the core model stabilizes, but platform risk review can start early.

Dependencies:

- End-to-end showcase depends on decision-engine wiring, layout engine, and caption renderer.
- Real-stream validation depends on manifest parser, provider metadata strategy, and playback shell.
- DRM support depends on trusted provider metadata or allowlisting.
- Production ad support depends on real ad lifecycle contract.

---

## 15. Definition of Done

### POC Done

- tvOS showcase demonstrates the prompted ultra-widescreen Caption Theater hero flow (this repo); iOS parity follows when an iOS target exists.
- Persistent cue model works with no future cue display.
- WebVTT renders first through an internal cue model designed for the main subtitle/caption formats.
- Detector accepts at least one eligible fixture.
- Detector rejects at least five unsafe fixtures.
- Manifest inspector identifies subtitle/ad/DRM risk evidence.
- Provider metadata stub can authorize DRM-like safe-region behavior.
- Ad/promo simulation proves ads play normally fullscreen/native while Caption Theater suspends and resumes or revalidates around content return.
- Debug UI explains every active/inactive decision.
- Unit tests cover evidence, state, detection, layout, and persistence.
- tvOS and macOS feasibility are documented.

### Production Candidate Done

- Representative HLS/TS streams are tested.
- DRM path uses trusted metadata or allowlisting.
- Real ad lifecycle integration exists.
- Real subtitle pipeline integration exists.
- Native/custom caption duplication is prevented.
- Accessibility settings are honored as much as technically possible.
- Platform QA passes for iOS, tvOS, and macOS targets.
- Analytics and remote kill switch exist.
- Content, legal, ads, accessibility, and product stakeholders approve rollout constraints.

---

## 16. First Decision Set

These product decisions define the first build direction.

### 16.1 Hero User Scenario

The first demo focuses on a viewer entering playback of ultra-widescreen content on a 16:9 screen.

Flow:

1. Playback begins in normal centered presentation.
2. The system detects eligible ultra-widescreen content with a safe lower reading region.
3. The viewer is prompted:

   > Would you like to enter Caption Theater mode?

4. If accepted, the active picture transitions from centered to top-aligned presentation.
5. The active picture remains correctly scaled and undistorted.
6. The lower region becomes a larger caption reading area.
7. Current captions render in that region.
8. Recently presented captions can persist longer, giving the viewer more context and longer read time during fast dialogue.
9. The viewer can exit Caption Theater and return to native presentation.

Technical assumption for the first demo:

- Prefer ultra-widescreen content delivered with a detectable aspect ratio or trusted metadata.
- The video should be sized according to the detected or declared active aspect ratio.
- The first fixture should be controlled enough that the expected active picture rect is known.

### 16.2 Subtitle Format Direction

The product goal is to support the main subtitle and caption formats, not only WebVTT.

Implementation direction:

1. Start with WebVTT because it is text-based and easiest to adapt into the persistence renderer.
2. Define the internal cue model broadly enough to support WebVTT, IMSC/TTML, CEA-608/708, and app-owned cue models.
3. Add format-specific adapters incrementally.
4. Treat semantic fidelity as the requirement, not just text extraction.

### 16.3 DRM Feasibility Direction

DRM content should receive a feasibility study rather than being categorically excluded.

Direction:

- Identify representative DRM/FairPlay test streams.
- Test whether useful client-side analysis is possible.
- Do not assume raw frame access will be available.
- Keep trusted metadata and provider-side QC as the expected production-safe path if frame access is unavailable.
- Fall back to native presentation when protected content cannot be verified.

### 16.4 4:3, Variable-Aspect, and Burned-In Subtitle Direction

These cases are stretch goals and should remain in the fixture matrix.

Direction:

- MVP focuses on ultra-widescreen content first.
- 4:3, variable-aspect, and burned-in subtitle cases should be studied and classified.
- Automatic activation can remain conservative.
- Debug tooling should explain why each case activates, suspends, or falls back.

Stretch-goal exploration:

- 4:3 pillarbox: investigate whether side or lower reading regions can be useful without creating an awkward reading experience.
- Variable aspect ratio: investigate segment-aware or timeline-aware Caption Theater if trusted metadata exists.
- Burned-in subtitles: investigate detection and fallback behavior; do not attempt OCR/reflow in the first implementation.

### 16.5 Ads and Pause Promo Direction

Ads should be delivered normally as expected fullscreen/native playback.

Direction:

- During ads, the player returns to normal fullscreen/native ad presentation.
- Caption Theater suspends during ad playback.
- Caption Theater resumes after ads only through normal content-resume flow and revalidation.
- The caption view and playback presentation resume after ads like normal playback.
- Pause promos are not automatically suppressed just because captions are visible; promo behavior should match explicit product/ad policy unless it creates a direct accessibility or control conflict.

---

## 17. Updated Critical Questions

### Hero Demo and UX

1. What exact prompt copy should be used for Caption Theater entry?
2. Should the prompt appear automatically, or should the player expose a subtle button/badge when eligible?
3. Should the top-align transition animate, snap, or wait until playback is paused?
4. How do we avoid the transition feeling like a bug or unexpected aspect-ratio shift?
5. Should the user preference persist per title, per profile, per device, or per session?

### Ultra-Widescreen Detection

6. What aspect-ratio threshold should make content eligible for the first prompt?
7. Should eligibility be based on encoded resolution, active-picture detection, provider metadata, or a combination?
8. What active-picture rect is required for the hero fixture?
9. How much lower reading-region height is required before prompting the user?
10. What confidence threshold is required before an automatic prompt appears?

### Caption Format Support

11. Which subtitle/caption formats are considered “main ones” for the first architecture: WebVTT, IMSC/TTML, CEA-608, CEA-708, or app-owned cues?
12. Which format must actually render in the first demo?
13. Do we have a reliable way to access CEA-608/708 cue semantics outside native rendering?
14. How should the renderer preserve roll-up/pop-on semantics for CEA captions?
15. What is the fallback if the selected format is supported by native playback but not by Caption Theater persistence?

### DRM Feasibility

16. Which DRM/FairPlay test streams can be used for feasibility testing?
17. What does success mean for DRM: frame access, metadata access, trusted provider metadata, or safe fallback?
18. Who can confirm whether frame extraction from protected content is allowed or expected to fail?
19. What provider-side metadata would be acceptable if client pixel analysis is unavailable?
20. How will DRM feasibility findings be documented for future production decisions?

### Complex Aspect and Burned-In Cases

21. What should the first 4:3 experiment attempt: native-only classification, side-region reading, or lower-region reading after resizing?
22. What variable-aspect examples should be included in the fixture matrix?
23. Should variable-aspect content ever prompt the user, or only activate with trusted timeline metadata?
24. How will burned-in subtitles be detected and explained in debug UI?
25. Should burned-in subtitle content ever coexist with Caption Theater if external captions are also available?

### Ads and Promos

26. What is the authoritative ad-state source for the POC?
27. What should happen if ad-state callbacks are delayed or missing?
28. Should Caption Theater resume automatically after ads, or should the user remain in the selected mode and the system revalidates silently?
29. What pause promo placements are allowed while Caption Theater is active?
30. What product policy applies if a pause promo competes with retained captions?

### Platform Integration

31. Is the first player shell a custom `AVPlayerLayer` view, an AVKit-adjacent wrapper, or both?
32. Which native controls must be present in the first demo?
33. Should PiP and AirPlay force native presentation in the POC?
34. How should tvOS focus handle the entry prompt and exit control?
35. How should macOS window resize affect the reading region and retained cue count?

---

## 18. Revised Immediate Sprint Decisions

Before implementation begins, lock these decisions:

1. Hero demo uses ultra-widescreen content on a 16:9 screen.
2. User is prompted before Caption Theater mode activates.
3. Caption Theater top-aligns eligible ultra-widescreen active picture and uses lower safe space for persistent captions.
4. WebVTT renders first, but the internal cue model is designed for the main subtitle/caption formats.
5. DRM receives a feasibility study rather than being excluded.
6. 4:3, variable-aspect, and burned-in subtitle cases remain stretch-goal fixtures.
7. Ads render normally fullscreen/native, Caption Theater suspends during ads, and content resumes/revalidates after ads.

These decisions keep the first sprint focused while preserving the larger product ambition.
