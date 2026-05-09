# CT-0303 layout follow-through (2026-05-08)

## Summary

- Added `CaptionTheaterLayoutContentInsets` and threaded it through `CaptionTheaterLayoutInputs` / `CaptionTheaterLayoutEngine` so aspect-fit math runs inside an inset region; output rects stay in container coordinates.
- tvOS `GeometryReader` passes SwiftUI `safeAreaInsets` (leading/trailing) into `CaptionTheaterPlaybackShellViewModel.layoutGeometry(container:contentInsets:)`.
- Top-pinned playback column uses horizontal gutters from `captionReadingRect` so video + caption band align when width is inset.
- Unit tests: overscan simulation (uniform insets), asymmetric safe-area style insets, inner-region validation, reference container sizes for hero top-pin aspect preservation.
- SwiftUI: `easeInOut` animation on layout identity when switching standard vs top-pinned / bounds changes.

## Verification

- `xcodebuild test -scheme CaptionTheater -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)'` — pass (layout + full suite).

## Remaining (from TASKS / product notes)

- Centeredcaptions-to-top-pinned **hero transition** remains deferred (TASKS Phase 5 exit / CT-0303 note).
