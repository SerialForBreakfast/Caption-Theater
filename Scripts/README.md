# Scripts

Repo-local automation for media fixtures. All writes stay inside this repository (see `AGENTS.md`).

## Offline HLS fixtures

| Script | Purpose |
| --- | --- |
| [`generate_widescreen_fixture.py`](generate_widescreen_fixture.py) | Generates the project-owned default offline HLS fixture: **1920x800** video-only media, segmented WebVTT captions, provenance, and backup manifest. Output: `CaptionTheater/CaptionTheater/Media/OfflineHLS/CaptionTheaterGeneratedWidescreenFixture/`. **Requires:** Python 3, Pillow, **ffmpeg**. |
| [`download_mux_offline_hls_mock.py`](download_mux_offline_hls_mock.py) | Downloads ~five minutes from the **public Mux** multivariant *Tears of Steel* demo, one **1920×800** rendition + English WebVTT segments, rewrites playlists to **relative paths**. Output: `CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock/`. **Requires:** Python 3, network. |
| [`build_ct0005_cinematic_open_hls.py`](build_ct0005_cinematic_open_hls.py) | Builds an offline HLS package from **Blender.org** picture masters + official `TOS-en.srt`: cinematic center crop/scaled **1920×800**, default trim (~22s / 120s) for rooftop dialogue. Output default: `CaptionTheater/CaptionTheater/Media/OfflineHLS/BlenderToSCinematicClip/`. **Requires:** Python 3, **ffmpeg**/**ffprobe**, network unless `--reuse-downloads` with cached files under `Fixtures/SourceDownloads/`. |

## Optional third offline demo (tvOS)

After `BlenderToSCinematicClip/` exists and you intend to ship it, add a `CaptionTheaterPlaybackDemoSource` case and duplicate the ``OfflineHLS`` folder-reference pattern used for `TearsOfSteelFiveMinuteMock` (large binaries — confirm Blender Foundation licensing before publication).

## Mac visual QA

| Script | Purpose |
| --- | --- |
| [`capture_mac_demo_screenshots.sh`](capture_mac_demo_screenshots.sh) | Builds `CaptionTheaterMac` with repo-local DerivedData, launches the bundled generated HLS fixture with debug HUD and layout borders enabled, sizes the window to an ultrawide review shape, and writes `Screenshots/MacQA/caption-theater-mac-ultrawide.png`. **Requires:** macOS GUI access, Screen Recording permission for Terminal/Codex, and Xcode command-line tools. |
