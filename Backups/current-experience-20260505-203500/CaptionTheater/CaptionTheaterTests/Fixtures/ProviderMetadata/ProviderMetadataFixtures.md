# Provider Metadata Fixtures

These sanitized JSON fixtures exercise `ProviderMetadataInspector`. They simulate provider-side QC metadata without referencing private streams, credentials, FairPlay keys, protected frames, or private media.

## Expected Results

- `trusted-eligible-letterbox.json`: trusted provider QC metadata authorizes a protected-content Caption Theater path.
- `blocklisted-burned-in-subtitles.json`: trusted metadata blocks Caption Theater because burned-in subtitle risk is known.
- `native-only-timeline.json`: trusted metadata authorizes the asset generally but declares a segment that must remain native-only.
- `incomplete-eligible-metadata.json`: positive-looking metadata is incomplete and must fail closed.

Missing metadata is tested without a JSON file and must fail closed for protected content.
