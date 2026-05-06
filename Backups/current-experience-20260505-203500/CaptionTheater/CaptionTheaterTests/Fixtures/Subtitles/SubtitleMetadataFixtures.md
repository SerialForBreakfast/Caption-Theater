# Subtitle Metadata Fixtures

These sanitized JSON fixtures exercise `SubtitleMetadataClassifier`. They describe selected subtitle-track metadata only; they do not contain real subtitle cue payloads, production manifests, private stream URLs, or media.

## Expected Results

- `sidecar-webvtt-dialogue.json`: sidecar WebVTT dialogue is MVP-compatible and eligible for previous-cue retention.
- `sidecar-webvtt-sdh.json`: sidecar WebVTT SDH is MVP-compatible and eligible for previous-cue retention.
- `sidecar-webvtt-forced.json`: sidecar WebVTT forced narrative is parseable but authored-timing-only.
- `embedded-cea608.json`: embedded CEA-608 captions remain native-only until semantic extraction exists.
- `image-based-subtitle.json`: image-based subtitles are native-only and are not reflowed.
- `burned-in-subtitles.json`: burned-in subtitles are visual content, not caption data.
- `missing-selected-track.json`: missing selected track remains native.
- `unknown-format.json`: unknown format fails closed.
