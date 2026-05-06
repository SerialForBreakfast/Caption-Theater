#!/usr/bin/env python3
"""Download a private POC-only offline HLS mock for Caption Theater.

The script writes only repo-local files and rewrites playlists to relative paths
so signed source URLs are not stored in the fixture.
"""

from __future__ import annotations

import hashlib
import re
import shutil
import sys
import urllib.parse
import urllib.request
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path


SOURCE_MASTER_URL = "https://stream.mux.com/4XYzhPXzqArkFI8d1vDsScBLD69Gh1b2.m3u8"
OFFLINE_DURATION_SECONDS = 300.0
OUTPUT_ROOT = Path("CaptionTheater/CaptionTheater/Media/OfflineHLS/TearsOfSteelFiveMinuteMock")


@dataclass
class Rendition:
    resolution: tuple[int, int]
    bandwidth: int
    uri: str


@dataclass
class Segment:
    duration: float
    uri: str
    local_name: str


def fetch_text(url: str) -> str:
    with urllib.request.urlopen(url, timeout=30) as response:
        return response.read().decode("utf-8")


def fetch_bytes(url: str) -> bytes:
    with urllib.request.urlopen(url, timeout=60) as response:
        return response.read()


def parse_attribute_list(line: str) -> dict[str, str]:
    _, raw_attributes = line.split(":", 1)
    attributes: dict[str, str] = {}
    for match in re.finditer(r'([A-Z0-9-]+)=("[^"]*"|[^,]*)', raw_attributes):
        key = match.group(1)
        value = match.group(2)
        if value.startswith('"') and value.endswith('"'):
            value = value[1:-1]
        attributes[key] = value
    return attributes


def parse_master(master_text: str) -> tuple[Rendition, str]:
    lines = [line.strip() for line in master_text.splitlines() if line.strip()]
    subtitle_uri: str | None = None
    renditions: list[Rendition] = []

    for index, line in enumerate(lines):
        if line.startswith("#EXT-X-MEDIA:") and 'TYPE=SUBTITLES' in line and 'LANGUAGE="en"' in line:
            attributes = parse_attribute_list(line)
            subtitle_uri = attributes.get("URI")
        if line.startswith("#EXT-X-STREAM-INF:"):
            attributes = parse_attribute_list(line)
            resolution_raw = attributes.get("RESOLUTION")
            bandwidth_raw = attributes.get("BANDWIDTH", "0")
            if not resolution_raw or index + 1 >= len(lines):
                continue
            width_raw, height_raw = resolution_raw.split("x", 1)
            renditions.append(
                Rendition(
                    resolution=(int(width_raw), int(height_raw)),
                    bandwidth=int(bandwidth_raw),
                    uri=lines[index + 1],
                )
            )

    if subtitle_uri is None:
        raise RuntimeError("English subtitle playlist URI not found in source master playlist.")
    if not renditions:
        raise RuntimeError("No video renditions found in source master playlist.")

    preferred = next((rendition for rendition in renditions if rendition.resolution == (1920, 800)), None)
    if preferred is None:
        preferred = max(renditions, key=lambda rendition: (rendition.resolution[0] / rendition.resolution[1], rendition.bandwidth))
    return preferred, subtitle_uri


def selected_segments(playlist_text: str, extension: str) -> list[Segment]:
    segments: list[Segment] = []
    pending_duration: float | None = None
    total_duration = 0.0

    for raw_line in playlist_text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#EXTINF:"):
            duration_raw = line.removeprefix("#EXTINF:").split(",", 1)[0]
            pending_duration = float(duration_raw)
            continue
        if line.startswith("#"):
            continue
        if pending_duration is None:
            continue

        local_name = f"seg{len(segments):03d}.{extension}"
        segments.append(Segment(duration=pending_duration, uri=line, local_name=local_name))
        total_duration += pending_duration
        pending_duration = None
        if total_duration >= OFFLINE_DURATION_SECONDS:
            break

    if not segments:
        raise RuntimeError("No segments found in source playlist.")
    return segments


def playlist_header(source_text: str, playlist_type: str) -> list[str]:
    target_duration = "6"
    version = "3"
    independent_segments = False

    for line in source_text.splitlines():
        if line.startswith("#EXT-X-VERSION:"):
            version = line.split(":", 1)[1]
        if line.startswith("#EXT-X-TARGETDURATION:"):
            target_duration = line.split(":", 1)[1]
        if line.startswith("#EXT-X-INDEPENDENT-SEGMENTS"):
            independent_segments = True

    lines = [
        "#EXTM3U",
        f"#EXT-X-VERSION:{version}",
        f"#EXT-X-TARGETDURATION:{target_duration}",
        f"#EXT-X-PLAYLIST-TYPE:{playlist_type}",
        "#EXT-X-MEDIA-SEQUENCE:0",
    ]
    if independent_segments:
        lines.append("#EXT-X-INDEPENDENT-SEGMENTS")
    return lines


def write_media_playlist(path: Path, source_text: str, segments: list[Segment], segment_dir_name: str) -> None:
    lines = playlist_header(source_text, "VOD")
    for segment in segments:
        lines.append(f"#EXTINF:{format_duration(segment.duration)},")
        lines.append(f"{segment_dir_name}/{segment.local_name}")
    lines.append("#EXT-X-ENDLIST")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def write_master_playlist(path: Path, bandwidth: int, resolution: tuple[int, int]) -> None:
    width, height = resolution
    lines = [
        "#EXTM3U",
        "#EXT-X-VERSION:5",
        "#EXT-X-INDEPENDENT-SEGMENTS",
        '#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="sub1",CHARACTERISTICS="public.accessibility.transcribes-spoken-dialog",NAME="English",AUTOSELECT=YES,DEFAULT=YES,FORCED=NO,LANGUAGE="en",URI="subtitles/english.m3u8"',
        f'#EXT-X-STREAM-INF:BANDWIDTH={bandwidth},AVERAGE-BANDWIDTH={bandwidth},CODECS="mp4a.40.2,avc1.64002a",RESOLUTION={width}x{height},CLOSED-CAPTIONS=NONE,SUBTITLES="sub1"',
        "video/video.m3u8",
    ]
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def format_duration(duration: float) -> str:
    if duration.is_integer():
        return str(int(duration))
    return f"{duration:.3f}".rstrip("0").rstrip(".")


def download_segments(base_url: str, segments: list[Segment], directory: Path) -> None:
    directory.mkdir(parents=True, exist_ok=True)
    for index, segment in enumerate(segments, start=1):
        absolute_url = urllib.parse.urljoin(base_url, segment.uri)
        data = fetch_bytes(absolute_url)
        (directory / segment.local_name).write_bytes(data)
        print(f"Downloaded {index:03d}/{len(segments):03d} {directory.name}/{segment.local_name}")


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_provenance(
    root: Path,
    rendition: Rendition,
    video_segments: list[Segment],
    subtitle_segments: list[Segment],
) -> None:
    total_video_duration = sum(segment.duration for segment in video_segments)
    total_subtitle_duration = sum(segment.duration for segment in subtitle_segments)
    content = f"""# Tears of Steel Five-Minute Offline Mock

Created UTC: {datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")}

Source master playlist:

```text
{SOURCE_MASTER_URL}
```

Intended use:

- Private Caption Theater proof-of-concept and development fixture.
- Not release media.
- Re-check source license, attribution terms, and redistribution rights before making this repository public.

Captured rendition:

- Resolution: {rendition.resolution[0]}x{rendition.resolution[1]}
- Bandwidth: {rendition.bandwidth}
- Video/audio segment count: {len(video_segments)}
- Video/audio duration: {format_duration(total_video_duration)} seconds
- Subtitle segment count: {len(subtitle_segments)}
- Subtitle playlist duration: {format_duration(total_subtitle_duration)} seconds

Stored playlists use local relative paths only. Signed child playlist and segment URLs are intentionally not stored in this fixture.
"""
    (root / "PROVENANCE.md").write_text(content, encoding="utf-8")


def write_manifest(root: Path) -> None:
    lines = [
        "Caption Theater offline HLS media backup",
        f"Created UTC: {datetime.now(timezone.utc).strftime('%Y-%m-%dT%H:%M:%SZ')}",
        "",
        "File hashes:",
    ]
    for path in sorted(root.rglob("*")):
        if path.is_file() and path.name != "MEDIA_BACKUP_MANIFEST.txt":
            lines.append(f"{sha256(path)}  {path.relative_to(root)}")
    (root / "MEDIA_BACKUP_MANIFEST.txt").write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> int:
    repo_root = Path.cwd()
    output_root = repo_root / OUTPUT_ROOT

    if output_root.exists():
        shutil.rmtree(output_root)
    (output_root / "video").mkdir(parents=True)
    (output_root / "subtitles").mkdir(parents=True)

    master_text = fetch_text(SOURCE_MASTER_URL)
    rendition, subtitle_uri = parse_master(master_text)

    video_playlist_text = fetch_text(rendition.uri)
    subtitle_playlist_text = fetch_text(subtitle_uri)

    video_segments = selected_segments(video_playlist_text, "ts")
    subtitle_segments = selected_segments(subtitle_playlist_text, "vtt")

    download_segments(rendition.uri, video_segments, output_root / "video" / "segments")
    download_segments(subtitle_uri, subtitle_segments, output_root / "subtitles" / "segments")

    write_master_playlist(output_root / "master.m3u8", rendition.bandwidth, rendition.resolution)
    write_media_playlist(output_root / "video" / "video.m3u8", video_playlist_text, video_segments, "segments")
    write_media_playlist(output_root / "subtitles" / "english.m3u8", subtitle_playlist_text, subtitle_segments, "segments")
    write_provenance(output_root, rendition, video_segments, subtitle_segments)
    write_manifest(output_root)

    print(output_root)
    return 0


if __name__ == "__main__":
    sys.exit(main())
