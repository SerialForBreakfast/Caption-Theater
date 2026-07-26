# Caption Theater

Normal Playback (Green Border represents playback view)

<img width="2505" height="1420" alt="Screenshot 2026-07-26 at 10 28 04 AM" src="https://github.com/user-attachments/assets/e7c495c1-c40c-4541-8d60-201f83168fc7" />

Caption Theater Mode (Blue Border represents Unobstructed Caption/Controls View)

<img width="2560" height="1440" alt="Screenshot 2026-07-26 at 10 28 36 AM (2)" src="https://github.com/user-attachments/assets/f9f9c80e-88bb-4991-b46c-91b1bf2ee673" />

Caption Theater transforms the unused space around cinema-aspect-ratio video into a premium, unobstructed reading area for captions.

Many ultra-widescreen films and shows are presented on 16:9 screens with black letterbox space above and below the active picture. Caption Theater uses that otherwise empty space to give subtitles and captions more room, more dwell time, and more context without covering the image. Instead of forcing viewers to choose between watching the scene and racing to read dense text, the active picture can shift into a theater-style layout while recent caption cues persist in the open lower region.

The project explores this as a modular playback add-on for native iOS, tvOS, and macOS players using AVFoundation, AVKit-adjacent integrations, HLS metadata, timed-text analysis, active-picture layout, and runtime safety guardrails.

**Platforms today:** The Xcode project ships native **tvOS** and **macOS** targets. tvOS is the primary living-room prototype; macOS is a demo/QA surface for offline HLS playback, layout review, and window aspect-ratio presets. **iOS** remains a roadmap target.

---

## Product Thesis

> Caption Theater helps viewers keep up with captions by preserving recent subtitle context in verified safe screen space, while maintaining native playback whenever visual safety, subtitle semantics, ad state, or platform compatibility is uncertain.

Three product values drive the design:

1. **Readable dwell time** — captions that have already appeared can remain visible briefly so viewers have more time to scan them.
2. **Context preservation** — the active picture stays visible and undistorted while recent caption context stays available in a stable reading region.
3. **Trustworthy fallback** — if the system cannot prove the experience is safe, it returns to native playback and native caption behavior.

Core rules:

1. Persist already-presented cues; never reveal future cues by default.
2. Treat subtitle and caption text as meaningful content, not decoration.
3. Use verified inactive screen space only when it is safe.
4. Keep the active picture visible, undistorted, and aligned with authored playback timing.
5. Separate viewport eligibility from subtitle-format eligibility.
6. Return to native playback for unsafe, unsupported, ad, or uncertain states; resume or revalidate once content resumes.
7. Keep the feature opt-in, reversible, measurable, and explainable.
8. Prove the user value with controlled fixtures before attempting production integration.

Caption Theater **does**: detect active-picture boundaries in non-DRM test content, use provider/QC metadata where pixel analysis is unavailable, prompt before activating on eligible ultra-widescreen content, render current cues plus briefly-retained recent cues, and explain every activation/fallback decision in debug tooling.

Caption Theater **avoids**: revealing future dialogue, stretching or cropping the picture, moving/OCR-ing burned-in subtitles, altering ad or legal overlays, depending on raw frame access for DRM content, and persisting legal/ad/lyric/forced/unknown-intent cues by default.

---

## Documentation

This README stays intentionally short. Deeper roadmap, architecture, and process documentation lives alongside it:

| Doc | Covers |
|---|---|
| [`TASKS.md`](TASKS.md) | Current, git-status-groomed task list and execution plan — the source of truth for "what's done vs. next." |
| [`Caption-Theater-POC-Roadmap.md`](Caption-Theater-POC-Roadmap.md) | Full product roadmap and phased proof-of-concept plan. |
| [`Caption-Theater-Showcase-and-Execution-Plan.md`](Caption-Theater-Showcase-and-Execution-Plan.md) | Demo/showcase script, execution sequencing, and production-readiness criteria. |
| [`Docs/TechnicalArchitecture.md`](Docs/TechnicalArchitecture.md) | Component sketches, eligibility/evidence model, aspect-ratio and subtitle-format policy, state machine, testing strategy, platform goals, known risks. |
| [`ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md`](ADR-0001-Letterbox-Aware-Top-Justified-Video-Viewport.md) | Architecture decision record for viewport detection and layout. |
| [`ADR-0002-Multi-Speaker-Caption-Presentation.md`](ADR-0002-Multi-Speaker-Caption-Presentation.md) | Architecture decision record for multi-speaker caption presentation. |
| [`Caption-Theater-Metadata-Feasibility-Deep-Dive.md`](Caption-Theater-Metadata-Feasibility-Deep-Dive.md) | Deep dive on manifest/metadata feasibility. |
| [`Docs/DRM-Feasibility-Study.md`](Docs/DRM-Feasibility-Study.md) | DRM/FairPlay feasibility findings and safety gates. |
| [`Docs/Fixture-Inventory.md`](Docs/Fixture-Inventory.md) | Canonical map of test fixtures and their expected decisions. |
| [`Docs/Sources.md`](Docs/Sources.md) | Source media candidates, licensing notes, and offline-mock provenance. |
| [`Docs/OpenSourceReleaseChecklist.md`](Docs/OpenSourceReleaseChecklist.md) | What must be true before this repository goes public. |
| [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) | Third-party and separately-licensed media notices. |

---

## Developer Demo Controls

Launch arguments can preselect demo and engineering settings:

```text
--caption-theater-offline-hls
--caption-theater-generated-hls
-CaptionTheater.playbackDemoSource bundledGeneratedWidescreenFixture
--caption-theater-playback-demo-source=bundledGeneratedWidescreenFixture
--caption-theater-playback-debug-hud=yes
-CaptionTheater.playbackDebugHUD YES
--caption-theater-playback-layout-border=yes
--caption-theater-mac-startup-aspect=twentyOneByNine
```

Available demo media raw values:

- `bundledGeneratedWidescreenFixture`
- `muxTearsOfSteelHLS`
- `bundledOfflineHLSMock`
- `bundledSyntheticSample`

`bundledGeneratedWidescreenFixture` uses the repo-owned no-audio HLS package under `CaptionTheater/CaptionTheater/Media/OfflineHLS/CaptionTheaterGeneratedWidescreenFixture/`. It contains 1920x800 generated video plus timed WebVTT captions for offline layout and caption QA — the safe default demo source.

`bundledOfflineHLSMock` pointed at a private, Mux-derived five-minute HLS package under `CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`. That media has been removed from the public repository (redistribution rights were never cleared); the demo source still exists in code and fails closed with a missing-resource placeholder. Regenerate it locally with `Scripts/download_mux_offline_hls_mock.py` if you need it for private testing — see `Docs/Sources.md` and `THIRD_PARTY_NOTICES.md`.

---

## License

Caption Theater source code is licensed under the **Apache License, Version 2.0**. See [`LICENSE`](LICENSE) and [`NOTICE`](NOTICE).

Third-party media and sample assets are not automatically covered by the source license — see [`THIRD_PARTY_NOTICES.md`](THIRD_PARTY_NOTICES.md) and [`Docs/OpenSourceReleaseChecklist.md`](Docs/OpenSourceReleaseChecklist.md) before publishing, redistributing, or packaging demo media. The generated widescreen fixture is project-owned and is the safe default demo asset.
