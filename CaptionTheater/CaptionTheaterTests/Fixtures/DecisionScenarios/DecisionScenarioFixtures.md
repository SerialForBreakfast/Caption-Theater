# Decision Scenario Fixtures

These fixtures exercise `CaptionTheaterDecisionEngine` with sanitized, deterministic eligibility snapshots.

## Ownership

- The unit test target owns these fixtures.
- Each scenario declares one input snapshot and the expected decision summary.
- Fixture evidence must remain diagnostic only. Do not store credentials, private stream URLs, FairPlay keys, raw protected frames, private media, or unsanitized production manifests.

## Expected Results

- `eligible-cinematic-webvtt-clear`: activates Caption Theater for user-enabled content playback, WebVTT subtitles, safe cinematic letterbox space, and clear content.
- `disabled-by-user`: remains native because user control wins over otherwise eligible evidence.
- `linear-ad`: remains native because linear ads must play normally.
- `unknown-ad-state`: fails closed because ad state is unknown.
- `unsupported-subtitle`: remains native because the selected subtitle format is not eligible for persistence.
- `unsafe-viewport`: remains native because inactive-looking regions are not safe to repurpose.
- `variable-aspect-ratio`: remains native for the MVP because variable aspect ratio needs segment-aware metadata.
- `protected-without-trusted-metadata`: fails closed because DRM-like content needs trusted metadata or allowlisting.
- `protected-with-trusted-metadata`: activates when trusted provider metadata authorizes protected-content eligibility.
