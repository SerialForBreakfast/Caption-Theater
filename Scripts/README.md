# Scripts

Repo-local automation for media fixtures. All writes stay inside this repository (see `AGENTS.md`).

## Offline HLS fixtures

| Script | Purpose |
| --- | --- |
| [`download_mux_offline_hls_mock.py`](download_mux_offline_hls_mock.py) | Downloads ~five minutes from the **public Mux** multivariant *Tears of Steel* demo, one **1920×800** rendition + English WebVTT segments, rewrites playlists to **relative paths**. Output: `CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`. **Requires:** Python 3, network. |
| [`build_ct0005_cinematic_open_hls.py`](build_ct0005_cinematic_open_hls.py) | Builds an offline HLS package from **Blender.org** picture masters + official `TOS-en.srt`: cinematic center crop/scaled **1920×800**, default trim (~22s / 120s) for rooftop dialogue. Output default: `CaptionTheater/CaptionTheater/Media/OfflineHLS/BlenderToSCinematicClip/`. **Requires:** Python 3, **ffmpeg**/**ffprobe**, network unless `--reuse-downloads` with cached files under `Fixtures/SourceDownloads/`. |

## Optional third offline demo (tvOS)

After `BlenderToSCinematicClip/` exists and you intend to ship it, add a `CaptionTheaterPlaybackDemoSource` case and duplicate the ``OfflineHLS`` folder-reference pattern used for `TearsOfSteelFiveMinuteMock` (large binaries — confirm Blender Foundation licensing before publication).
