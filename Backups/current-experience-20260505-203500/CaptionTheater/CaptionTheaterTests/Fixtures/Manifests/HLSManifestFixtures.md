# HLS Manifest Fixtures

These sanitized fixtures exercise the first `HLSManifestInspector` behavior. They are not production manifests and must not contain credentials, cookies, private stream URLs, FairPlay keys, or protected media references.

## Expected Results

- `sidecar-webvtt-master.m3u8`: multivariant playlist with two variants and a sidecar text subtitle rendition.
- `embedded-closed-captions-master.m3u8`: multivariant playlist that declares embedded closed captions through `EXT-X-MEDIA`.
- `ad-daterange-discontinuity-media.m3u8`: media playlist with `EXT-X-DATERANGE` timed metadata and a discontinuity boundary.
- `encrypted-session-key-master.m3u8`: multivariant playlist with a sanitized session-key encryption marker.
- `full-frame-no-subtitles-master.m3u8`: multivariant playlist with no declared subtitle or caption transport.

Manifest inspection is evidence only. These fixtures must never be used to prove that visual letterbox regions are safe.
