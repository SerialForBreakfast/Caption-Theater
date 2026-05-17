# CT-0504 — tvOS playback transport drawer (2026-05-08)

## Delivered

- `tvOSPlaybackTransportDrawer.swift`: collapsed lower-trailing control; expanded panel with play/pause, ±15s skip (`gobackward.15` / `goforward.15`), custom UIKit scrub bar (`TVPlaybackTimelineScrubControl` — `UISlider` / SwiftUI `Slider` unavailable on tvOS), and “Scrolling captions” `@AppStorage` toggle.
- `CaptionTheaterPlaybackShellViewModel`: `timeControlStatus` for play/pause glyph; `playbackTransportSkipSeconds` = 15; initial `timeControlStatus` sync after player creation.
- `tvOSPlaybackShellView`: ZStack integration; caption column branches on scrolling vs latest-cue-only; Play/Pause command unchanged.

## Verification

- `xcodebuild` build (tvOS Simulator, scheme CaptionTheater): succeeded.
- `xcodebuild test` `-only-testing:CaptionTheaterTests`: succeeded.

## Follow-up

- Manual QA on device: focus order, scrub gesture with Siri Remote, toggle persistence, picture unobscured.
- Optional: pass expanded drawer width into `CaptionTheaterLayoutContentInsets` to widen caption band when panel is open.
