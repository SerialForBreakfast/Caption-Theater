#!/usr/bin/env python3
"""Build CT-0005 offline HLS demo media from open-licensed source masters.

Turns Blender Foundation *Tears of Steel* (official blender.org mirrors plus bundled
English ``.srt``) into a repo-local VOD package:

- True cinematic raster ``1920x800`` (center crop toward ~2.4:1 active picture, then scale)
- AAC + H.264 MPEG-TS segments playable offline
- Sidecar English WebVTT segmented playlists compatible with ``AVPlayer``

Requirements:

- ``ffmpeg`` and ``ffprobe`` on ``PATH``
- Network access unless sources already exist under ``Fixtures/SourceDownloads/``

Writes **only** under the repository (see ``AGENTS.md``): cache downloads and output HLS tree.

License note:
The Blender Foundation distributes this film for reuse with attribution. Re-verify film,
subtitle, and soundtrack license terms before publishing this repository or redistributing
derived fixtures. The accompanying ``copyright.txt`` on blender.org covers the soundtrack;
confirm ``tearsofsteel.org`` / Blender Foundation terms for the picture master you select.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import subprocess
import sys
import urllib.request
from dataclasses import dataclass
from datetime import timedelta
from pathlib import Path


DEFAULT_VIDEO_URL = (
    "https://download.blender.org/demo/movies/ToS/tears_of_steel_720p.mov"
)
DEFAULT_SUBTITLE_URL = (
    "https://download.blender.org/demo/movies/ToS/subtitles/TOS-en.srt"
)

DOWNLOAD_CACHE_ROOT = Path("Fixtures/SourceDownloads/ct0005-open-masters")
DEFAULT_OUTPUT_ROOT = Path(
    "CaptionTheater/CaptionTheater/Media/OfflineHLS/BlenderToSCinematicClip"
)

TARGET_WIDTH = 1920
TARGET_HEIGHT = 800


@dataclass(frozen=True)
class VideoSegmentRef:
    duration_seconds: float
    relative_path: str


@dataclass(frozen=True)
class Cue:
    start: timedelta
    end: timedelta
    text: str


def fetch_bytes(url: str, destination: Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    request = urllib.request.Request(url, headers={"User-Agent": "CaptionTheater-CT0005/1.0"})
    with urllib.request.urlopen(request, timeout=120) as response:
        destination.write_bytes(response.read())


def run_checked(argv: list[str], *, cwd: Path | None = None) -> None:
    proc = subprocess.run(argv, capture_output=True, text=True, cwd=str(cwd) if cwd else None)
    if proc.returncode != 0:
        sys.stderr.write(proc.stderr or proc.stdout or "")
        raise RuntimeError(f"Command failed ({proc.returncode}): {' '.join(argv)}")


def ffprobe_video_size(source: Path) -> tuple[int, int]:
    argv = [
        "ffprobe",
        "-v",
        "error",
        "-select_streams",
        "v:0",
        "-show_entries",
        "stream=width,height",
        "-of",
        "json",
        str(source),
    ]
    proc = subprocess.run(argv, capture_output=True, text=True, check=True)
    payload = json.loads(proc.stdout)
    streams = payload.get("streams") or []
    if not streams:
        raise RuntimeError(f"No video stream in {source}")
    width = int(streams[0]["width"])
    height = int(streams[0]["height"])
    return width, height


def ffprobe_bit_rate_bits_per_second(media: Path) -> int:
    argv = [
        "ffprobe",
        "-v",
        "error",
        "-show_entries",
        "format=bit_rate",
        "-of",
        "default=noprint_wrappers=1:nokey=1",
        str(media),
    ]
    proc = subprocess.run(argv, capture_output=True, text=True, check=True)
    raw = proc.stdout.strip()
    if not raw or raw == "N/A":
        return 4_000_000
    return max(int(raw), 256_000)


def cinematic_crop_then_scale_filter(width: int, height: int) -> str:
    """Center-crop toward TARGET aspect (``1920x800``), then scale."""
    target_ar = TARGET_WIDTH / TARGET_HEIGHT
    source_ar = width / height
    if source_ar > target_ar:
        crop_w = int(round(height * target_ar))
        crop_h = height
        crop_x = max((width - crop_w) // 2, 0)
        crop_y = 0
    else:
        crop_w = width
        crop_h = int(round(width / target_ar))
        crop_x = 0
        crop_y = max((height - crop_h) // 2, 0)

    return (
        f"crop={crop_w}:{crop_h}:{crop_x}:{crop_y},"
        f"scale={TARGET_WIDTH}:{TARGET_HEIGHT}:flags=lanczos"
    )


def parse_srt(content: str) -> list[Cue]:
    """Parse a minimal SubRip subset sufficient for Blender ``TOS-en.srt``."""
    cues: list[Cue] = []
    normalized = content.replace("\r\n", "\n").strip()
    if not normalized:
        return cues

    blocks = re.split(r"\n\s*\n", normalized)
    timestamp_line = re.compile(
        r"^(?P<start>\d{2}:\d{2}:\d{2},\d{3})\s*-->\s*(?P<end>\d{2}:\d{2}:\d{2},\d{3})"
    )

    for block in blocks:
        lines = [line.strip() for line in block.split("\n") if line.strip()]
        if len(lines) < 2:
            continue
        ts_match = None
        body_start = 0
        for idx, line in enumerate(lines):
            ts_match = timestamp_line.match(line)
            if ts_match:
                body_start = idx + 1
                break
        if ts_match is None:
            continue
        text_lines = lines[body_start:]
        if not text_lines:
            continue
        start = parse_srt_timestamp(ts_match.group("start"))
        end = parse_srt_timestamp(ts_match.group("end"))
        cues.append(Cue(start=start, end=end, text="\n".join(text_lines)))
    cues.sort(key=lambda cue: cue.start)
    return cues


def parse_srt_timestamp(raw: str) -> timedelta:
    hours, minutes, rest = raw.split(":")
    seconds, millis = rest.split(",")
    return timedelta(
        hours=int(hours),
        minutes=int(minutes),
        seconds=int(seconds),
        milliseconds=int(millis),
    )


def format_vtt_timestamp(delta: timedelta) -> str:
    total_ms = int(delta.total_seconds() * 1000)
    if total_ms < 0:
        total_ms = 0
    ms = total_ms % 1000
    total_seconds = total_ms // 1000
    s = total_seconds % 60
    total_minutes = total_seconds // 60
    m = total_minutes % 60
    h = total_minutes // 60
    return f"{h:02d}:{m:02d}:{s:02d}.{ms:03d}"


def cues_to_webvtt(cues: list[Cue]) -> str:
    lines = ["WEBVTT", ""]
    for index, cue in enumerate(cues, start=1):
        lines.append(str(index))
        lines.append(
            f"{format_vtt_timestamp(cue.start)} --> {format_vtt_timestamp(cue.end)}"
        )
        lines.append(cue.text)
        lines.append("")
    return "\n".join(lines) + "\n"


def shift_clip_cues(cues: list[Cue], trim_start: timedelta, clip_duration: timedelta) -> list[Cue]:
    clip_end = trim_start + clip_duration
    shifted: list[Cue] = []
    for cue in cues:
        if cue.end <= trim_start or cue.start >= clip_end:
            continue
        start = cue.start - trim_start
        end = cue.end - trim_start
        if start.total_seconds() < 0:
            start = timedelta(0)
        if end > clip_duration:
            end = clip_duration
        if end <= start:
            continue
        shifted.append(Cue(start=start, end=end, text=cue.text))
    return shifted


def normalize_video_media_playlist(segment_dir_name: str, playlist_path: Path) -> None:
    """Rewrite bare ``*.ts`` lines so URIs match on-disk layout (for example ``segments/seg000.ts``)."""

    lines_out: list[str] = []
    for raw_line in playlist_path.read_text(encoding="utf-8").splitlines():
        stripped = raw_line.strip()
        if stripped.endswith(".ts") and not stripped.startswith("#") and "/" not in stripped:
            lines_out.append(f"{segment_dir_name}/{stripped}")
        else:
            lines_out.append(raw_line)
    playlist_path.write_text("\n".join(lines_out) + "\n", encoding="utf-8")


def parse_hls_media_playlist_segments(playlist_path: Path) -> list[VideoSegmentRef]:
    text = playlist_path.read_text(encoding="utf-8")
    segments: list[VideoSegmentRef] = []
    pending_duration: float | None = None
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if line.startswith("#EXTINF:"):
            pending_duration = float(line.split(":", 1)[1].split(",", 1)[0])
            continue
        if not line or line.startswith("#"):
            continue
        if pending_duration is None:
            continue
        segments.append(
            VideoSegmentRef(duration_seconds=pending_duration, relative_path=line)
        )
        pending_duration = None
    if not segments:
        raise RuntimeError(f"No segments parsed from {playlist_path}")
    return segments


def cues_for_segment_window(
    cues: list[Cue], window_start: timedelta, window_end: timedelta
) -> list[Cue]:
    selected: list[Cue] = []
    for cue in cues:
        if cue.end <= window_start or cue.start >= window_end:
            continue
        selected.append(cue)
    return selected


def write_subtitle_segments(
    cues: list[Cue],
    video_segments: list[VideoSegmentRef],
    subtitles_root: Path,
) -> None:
    segments_dir = subtitles_root / "segments"
    segments_dir.mkdir(parents=True, exist_ok=True)

    elapsed = timedelta(0)
    target_duration = max(int(round(seg.duration_seconds)) for seg in video_segments)
    playlist_lines = [
        "#EXTM3U",
        "#EXT-X-VERSION:3",
        f"#EXT-X-TARGETDURATION:{target_duration}",
        "#EXT-X-PLAYLIST-TYPE:VOD",
        "#EXT-X-MEDIA-SEQUENCE:0",
    ]

    for index, seg in enumerate(video_segments):
        window_start = elapsed
        window_end = elapsed + timedelta(seconds=seg.duration_seconds)
        seg_cues = cues_for_segment_window(cues, window_start, window_end)
        local_name = f"seg{index:03d}.vtt"
        (segments_dir / local_name).write_text(cues_to_webvtt(seg_cues), encoding="utf-8")

        dur = seg.duration_seconds
        playlist_lines.append(f"#EXTINF:{format_hls_duration(dur)},")
        playlist_lines.append(f"segments/{local_name}")
        elapsed = window_end

    playlist_lines.append("#EXT-X-ENDLIST")
    (subtitles_root / "english.m3u8").write_text("\n".join(playlist_lines) + "\n", encoding="utf-8")


def format_hls_duration(seconds: float) -> str:
    if seconds.is_integer():
        return str(int(seconds))
    return f"{seconds:.3f}".rstrip("0").rstrip(".")


def write_master_playlist(path: Path, bandwidth: int, resolution: tuple[int, int]) -> None:
    width, height = resolution
    lines = [
        "#EXTM3U",
        "#EXT-X-VERSION:5",
        "#EXT-X-INDEPENDENT-SEGMENTS",
        '#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="sub1",'
        'CHARACTERISTICS="public.accessibility.transcribes-spoken-dialog",'
        'NAME="English",AUTOSELECT=YES,DEFAULT=YES,FORCED=NO,LANGUAGE="en",'
        'URI="subtitles/english.m3u8"',
        f'#EXT-X-STREAM-INF:BANDWIDTH={bandwidth},AVERAGE-BANDWIDTH={bandwidth},'
        f'CODECS="mp4a.40.2,avc1.640028",RESOLUTION={width}x{height},'
        f'CLOSED-CAPTIONS=NONE,SUBTITLES="sub1"',
        "video/video.m3u8",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_provenance(
    root: Path,
    *,
    video_url: str,
    subtitle_url: str,
    trim_start_seconds: float,
    clip_seconds: float,
    source_video_name: str,
    bandwidth: int,
    crop_note: str,
) -> None:
    content = f"""# Blender-derived cinematic offline clip (CT-0005 pipeline)

This package was produced by ``Scripts/build_ct0005_cinematic_open_hls.py``.

## Sources

- Video master: `{video_url}` (cached as `{source_video_name}`)
- English subtitles: `{subtitle_url}`

## Trim

- ``ffmpeg`` trim start: {trim_start_seconds:.3f}s
- Clip duration: {clip_seconds:.3f}s

## Processing

- Center cinematic crop toward {TARGET_WIDTH}×{TARGET_HEIGHT} active picture, then Lanczos scale.
- Filter chain note: {crop_note}

## Manifest

- Estimated presentation bitrate (``ffprobe`` on intermediate encode): {bandwidth} bits/s
- Codec strings in ``master.m3u8`` are representative H.264/AAC tags for AVFoundation.

## Licensing

Confirm current Blender Foundation / *Tears of Steel* terms before **public** redistribution.
Official mirrors live under ``download.blender.org``; see project pages at
https://www.tearsofsteel.org/ and https://studio.blender.org/projects/tears-of-steel/

This fixture is intended for **private development**, Caption Theater demos, and offline QA—same
posture as other fixtures in ``Media/OfflineHLS/``.
"""
    (root / "PROVENANCE.md").write_text(content, encoding="utf-8")


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_manifest(root: Path) -> None:
    lines = [
        "Caption Theater CT-0005 open-source cinematic clip manifest",
        "",
        "SHA256:",
    ]
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.name != "MEDIA_BACKUP_MANIFEST.txt":
            rel = path.relative_to(root)
            lines.append(f"{sha256_file(path)}  {rel}")
    (root / "MEDIA_BACKUP_MANIFEST.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def ensure_tools() -> None:
    for binary in ("ffmpeg", "ffprobe"):
        if shutil.which(binary) is None:
            raise RuntimeError(f"Missing `{binary}` on PATH (install FFmpeg).")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Build offline cinematic HLS + WebVTT from open *Tears of Steel* masters."
    )
    parser.add_argument(
        "--video-url",
        default=DEFAULT_VIDEO_URL,
        help="HTTPS URL for the Blender picture master (default: 720p MOV mirror).",
    )
    parser.add_argument(
        "--subtitle-url",
        default=DEFAULT_SUBTITLE_URL,
        help="HTTPS URL for English SubRip subtitles.",
    )
    parser.add_argument(
        "--trim-start",
        type=float,
        default=22.0,
        help=(
            "Seconds to skip from the source timeline before encoding "
            "(default ~22s lands on the Amsterdam rooftop dialogue for *Tears of Steel*)."
        ),
    )
    parser.add_argument(
        "--duration",
        type=float,
        default=120.0,
        help="Seconds of content to include after the trim point.",
    )
    parser.add_argument(
        "--output-root",
        type=Path,
        default=DEFAULT_OUTPUT_ROOT,
        help="Repository-relative output folder for HLS output.",
    )
    parser.add_argument(
        "--download-cache",
        type=Path,
        default=DOWNLOAD_CACHE_ROOT,
        help="Repository-relative folder for cached MOV/SRT downloads.",
    )
    parser.add_argument(
        "--reuse-downloads",
        action="store_true",
        help="Skip HTTP when cached files already exist.",
    )
    args = parser.parse_args()

    ensure_tools()

    repo_root = Path.cwd()
    cache_root = repo_root / args.download_cache
    output_root = repo_root / args.output_root

    cache_root.mkdir(parents=True, exist_ok=True)

    video_local = cache_root / Path(args.video_url).name
    subtitle_local = cache_root / Path(args.subtitle_url).name

    meta_path = cache_root / "last_urls.json"
    if not (args.reuse_downloads and video_local.is_file()):
        print(f"Downloading video master → {video_local}")
        fetch_bytes(args.video_url, video_local)
    else:
        print(f"Reusing cached video {video_local}")

    if not (args.reuse_downloads and subtitle_local.is_file()):
        print(f"Downloading subtitles → {subtitle_local}")
        fetch_bytes(args.subtitle_url, subtitle_local)
    else:
        print(f"Reusing cached subtitles {subtitle_local}")

    meta_path.write_text(
        json.dumps({"video_url": args.video_url, "subtitle_url": args.subtitle_url}, indent=2),
        encoding="utf-8",
    )

    width, height = ffprobe_video_size(video_local)
    vf = cinematic_crop_then_scale_filter(width, height)
    crop_note = f"source {width}×{height}, filter `{vf}`"

    clip_duration = timedelta(seconds=args.duration)
    trim_start = timedelta(seconds=args.trim_start)

    intermediate = cache_root / "intermediate_cinematic_clip.mp4"
    trim_args: list[str] = []
    if args.trim_start > 0:
        trim_args.extend(["-ss", str(args.trim_start)])

    encode_argv = [
        "ffmpeg",
        "-y",
        *trim_args,
        "-i",
        str(video_local),
        "-t",
        str(args.duration),
        "-vf",
        vf,
        "-c:v",
        "libx264",
        "-preset",
        "fast",
        "-crf",
        "21",
        "-pix_fmt",
        "yuv420p",
        "-c:a",
        "aac",
        "-b:a",
        "160k",
        "-movflags",
        "+faststart",
        str(intermediate),
    ]
    print("Encoding intermediate cinematic clip…")
    run_checked(encode_argv)

    bandwidth = ffprobe_bit_rate_bits_per_second(intermediate)

    if output_root.exists():
        shutil.rmtree(output_root)

    video_dir = output_root / "video" / "segments"
    video_dir.mkdir(parents=True, exist_ok=True)

    video_pkg_dir = output_root / "video"
    hls_argv = [
        "ffmpeg",
        "-y",
        "-i",
        str(intermediate.resolve()),
        "-c",
        "copy",
        "-f",
        "hls",
        "-hls_time",
        "6",
        "-hls_playlist_type",
        "vod",
        "-hls_segment_filename",
        "segments/seg%03d.ts",
        "video.m3u8",
    ]
    print("Muxing HLS video segments…")
    run_checked(hls_argv, cwd=video_pkg_dir)

    video_playlist_path = video_pkg_dir / "video.m3u8"
    normalize_video_media_playlist("segments", video_playlist_path)

    raw_srt = subtitle_local.read_text(encoding="utf-8", errors="replace")
    shifted_cues = shift_clip_cues(parse_srt(raw_srt), trim_start, clip_duration)

    video_segments = parse_hls_media_playlist_segments(video_playlist_path)

    subtitles_root = output_root / "subtitles"
    write_subtitle_segments(shifted_cues, video_segments, subtitles_root)

    write_master_playlist(
        output_root / "master.m3u8",
        bandwidth=bandwidth,
        resolution=(TARGET_WIDTH, TARGET_HEIGHT),
    )

    write_provenance(
        output_root,
        video_url=args.video_url,
        subtitle_url=args.subtitle_url,
        trim_start_seconds=args.trim_start,
        clip_seconds=args.duration,
        source_video_name=video_local.name,
        bandwidth=bandwidth,
        crop_note=crop_note,
    )
    write_manifest(output_root)

    print(f"Done. Offline package: {output_root}")
    print(f"Cues in clip window: {len(shifted_cues)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
