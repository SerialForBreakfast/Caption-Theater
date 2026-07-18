#!/usr/bin/env python3
"""Generate the project-owned Caption Theater widescreen HLS fixture.

The fixture intentionally has no audio in v1. It uses deterministic generated
video plus timed WebVTT captions so public redistribution does not depend on
third-party media, voice models, or platform TTS output.
"""

from __future__ import annotations

import hashlib
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "CaptionTheater" / "CaptionTheater" / "Media" / "OfflineHLS" / "CaptionTheaterGeneratedWidescreenFixture"
VIDEO_DIR = OUT / "video"
VIDEO_SEGMENTS_DIR = VIDEO_DIR / "segments"
SUBTITLE_DIR = OUT / "subtitles"
SUBTITLE_SEGMENTS_DIR = SUBTITLE_DIR / "segments"
MASTER_PLAYLIST_NAME = "caption-theater-generated-master.m3u8"
VIDEO_PLAYLIST_NAME = "caption-theater-generated-video.m3u8"
SUBTITLE_PLAYLIST_NAME = "caption-theater-generated-english.m3u8"
VIDEO_SEGMENT_TEMPLATE = "caption-theater-generated-video-%03d.ts"
SUBTITLE_SEGMENT_TEMPLATE = "caption-theater-generated-subtitle-%03d.vtt"
PROVENANCE_NAME = "CAPTION_THEATER_GENERATED_PROVENANCE.md"
BACKUP_MANIFEST_NAME = "CAPTION_THEATER_GENERATED_MEDIA_BACKUP_MANIFEST.txt"

WIDTH = 1920
HEIGHT = 800
FPS = 30
DURATION_SECONDS = 60
SEGMENT_SECONDS = 6
TOTAL_FRAMES = FPS * DURATION_SECONDS


@dataclass(frozen=True)
class Cue:
    identifier: str
    start: float
    end: float
    text: str


CUES = [
    Cue("CT-001", 1.0, 5.0, "Caption Theater generated fixture: true 1920 by 800 widescreen video."),
    Cue("CT-002", 5.2, 9.2, "This v1 asset has timed captions and no audio, so every media right is project-owned."),
    Cue("CT-003", 10.0, 15.5, "Alignment grid: the moving scan line should stay straight, sharp, and undistorted."),
    Cue("CT-004", 16.0, 21.5, "Long wrapping cue: this deliberately verbose sentence should fill the caption reading band without covering the active picture."),
    Cue("CT-005", 22.0, 27.5, "LED panel scene: numbered tiles make crop, scale, and top-pinned layout errors easy to see."),
    Cue("CT-006", 28.0, 33.0, "Short cue."),
    Cue("CT-007", 34.0, 39.5, "[silent visual pulse] The screen flashes without audio in v1."),
    Cue("CT-008", 40.0, 45.5, "Cue CT-008 is also burned into the picture for rendered-caption comparison."),
    Cue("CT-009", 46.0, 53.5, "Retention check: already-presented cues may remain visible, but future cues must not appear early."),
    Cue("CT-010", 54.0, 59.5, "Reset boundary: seeking or restarting should clear retained caption history before new cues arrive."),
]


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/System/Library/Fonts/Supplemental/Helvetica Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Helvetica.ttf",
        "/Library/Fonts/Arial Bold.ttf" if bold else "/Library/Fonts/Arial.ttf",
    ]
    for candidate in candidates:
        if Path(candidate).exists():
            return ImageFont.truetype(candidate, size=size)
    return ImageFont.load_default()


F18 = font(18)
F24 = font(24)
F32 = font(32)
F44 = font(44, bold=True)
F64 = font(64, bold=True)


def prepare_output() -> None:
    if OUT.exists():
        shutil.rmtree(OUT)
    VIDEO_SEGMENTS_DIR.mkdir(parents=True)
    SUBTITLE_SEGMENTS_DIR.mkdir(parents=True)


def timestamp(seconds: float) -> str:
    milliseconds = int(round(seconds * 1000))
    hours, remainder = divmod(milliseconds, 3_600_000)
    minutes, remainder = divmod(remainder, 60_000)
    secs, millis = divmod(remainder, 1000)
    return f"{hours:02d}:{minutes:02d}:{secs:02d}.{millis:03d}"


def draw_guides(draw: ImageDraw.ImageDraw) -> None:
    draw.rectangle((0, 0, WIDTH - 1, HEIGHT - 1), outline=(255, 255, 255), width=6)
    draw.rectangle((32, 32, WIDTH - 33, HEIGHT - 33), outline=(0, 220, 120), width=3)
    draw.line((WIDTH // 2, 0, WIDTH // 2, HEIGHT), fill=(255, 255, 255), width=2)
    draw.line((0, HEIGHT // 2, WIDTH, HEIGHT // 2), fill=(255, 255, 255), width=2)
    draw.text((42, 42), "TL", fill=(255, 255, 255), font=F32)
    draw.text((WIDTH - 42, 42), "TR", fill=(255, 255, 255), font=F32, anchor="ra")
    draw.text((42, HEIGHT - 42), "BL", fill=(255, 255, 255), font=F32, anchor="ld")
    draw.text((WIDTH - 42, HEIGHT - 42), "BR", fill=(255, 255, 255), font=F32, anchor="rd")


def active_cue_id(time_seconds: float) -> str:
    for cue in CUES:
        if cue.start <= time_seconds < cue.end:
            return cue.identifier
    return "none"


def draw_footer(draw: ImageDraw.ImageDraw, frame_index: int, time_seconds: float) -> None:
    draw.rectangle((0, HEIGHT - 52, WIDTH, HEIGHT), fill=(4, 5, 8))
    draw.text(
        (42, HEIGHT - 26),
        f"Frame {frame_index:04d}   Time {time_seconds:06.3f}s   Active cue {active_cue_id(time_seconds)}",
        fill=(230, 236, 245),
        font=F24,
        anchor="lm",
    )
    draw.text((WIDTH - 42, HEIGHT - 26), "Generated no-audio v1", fill=(150, 170, 190), font=F24, anchor="rm")


def draw_opening(draw: ImageDraw.ImageDraw, frame_index: int, time_seconds: float) -> None:
    for x in range(0, WIDTH, 120):
        draw.rectangle((x, 0, x + 60, HEIGHT), fill=(18, 30, 48) if (x // 120) % 2 == 0 else (8, 12, 22))
    draw.rectangle((250, 160, WIDTH - 250, 610), fill=(8, 13, 23), outline=(90, 180, 255), width=4)
    draw.text((WIDTH // 2, 242), "Caption Theater", fill=(250, 252, 255), font=F64, anchor="mm")
    draw.text((WIDTH // 2, 315), "Generated Widescreen Fixture", fill=(125, 230, 255), font=F44, anchor="mm")
    draw.text((WIDTH // 2, 390), "1920 x 800 | 2.40:1 | 30 fps | No audio", fill=(222, 232, 244), font=F32, anchor="mm")
    draw.text((WIDTH // 2, 465), "Timed WebVTT captions are authored from this script.", fill=(180, 195, 216), font=F24, anchor="mm")
    draw_guides(draw)
    draw_footer(draw, frame_index, time_seconds)


def draw_grid(draw: ImageDraw.ImageDraw, frame_index: int, time_seconds: float) -> None:
    draw.rectangle((0, 0, WIDTH, HEIGHT), fill=(4, 6, 10))
    for x in range(0, WIDTH + 1, 80):
        major = x % 320 == 0
        draw.line((x, 0, x, HEIGHT), fill=(75, 105, 130) if major else (28, 42, 55), width=3 if major else 1)
        if major and x:
            draw.text((x + 8, 24), f"x{x}", fill=(135, 170, 200), font=F18)
    for y in range(0, HEIGHT + 1, 80):
        major = y % 320 == 0
        draw.line((0, y, WIDTH, y), fill=(75, 105, 130) if major else (28, 42, 55), width=3 if major else 1)
        if major and y:
            draw.text((24, y + 8), f"y{y}", fill=(135, 170, 200), font=F18)
    scan_x = int((time_seconds - 10) / 12 * WIDTH) % WIDTH
    scan_y = 160 + int(((time_seconds - 10) * 70) % 480)
    draw.rectangle((scan_x - 8, 0, scan_x + 8, HEIGHT), fill=(255, 214, 70))
    draw.rectangle((0, scan_y - 5, WIDTH, scan_y + 5), fill=(0, 210, 255))
    draw.ellipse((WIDTH // 2 - 44, HEIGHT // 2 - 44, WIDTH // 2 + 44, HEIGHT // 2 + 44), outline=(255, 80, 120), width=6)
    draw.text((WIDTH // 2, 90), "Alignment grid + moving scanline", fill=(255, 255, 255), font=F44, anchor="mm")
    draw_guides(draw)
    draw_footer(draw, frame_index, time_seconds)


def draw_led(draw: ImageDraw.ImageDraw, frame_index: int, time_seconds: float) -> None:
    cols = 8
    rows = 4
    panel_w = WIDTH // cols
    panel_h = HEIGHT // rows
    palette = [(18, 42, 62), (42, 28, 58), (35, 58, 35), (68, 48, 22)]
    for row in range(rows):
        for col in range(cols):
            x0 = col * panel_w
            y0 = row * panel_h
            x1 = x0 + panel_w
            y1 = y0 + panel_h
            draw.rectangle((x0, y0, x1, y1), fill=palette[(row + col) % len(palette)])
            draw.rectangle((x0 + 5, y0 + 5, x1 - 5, y1 - 5), outline=(220, 235, 255), width=2)
            draw.text(((x0 + x1) // 2, (y0 + y1) // 2), f"{chr(65 + row)}{col + 1}", fill=(255, 255, 255), font=F44, anchor="mm")
            draw.text((x0 + 16, y0 + 18), f"{panel_w}x{panel_h}", fill=(170, 190, 210), font=F18)
    highlight = int((time_seconds - 22) * 2) % cols
    draw.rectangle((highlight * panel_w, 0, (highlight + 1) * panel_w, HEIGHT), outline=(255, 226, 0), width=10)
    draw.text((WIDTH // 2, 54), "LED-style alignment: numbered tiles and sweep column", fill=(255, 255, 255), font=F32, anchor="mm")
    draw_footer(draw, frame_index, time_seconds)


def draw_pulse(draw: ImageDraw.ImageDraw, frame_index: int, time_seconds: float) -> None:
    pulse = int((time_seconds - 34) * 2) % 2 == 0
    draw.rectangle((0, 0, WIDTH, HEIGHT), fill=(245, 245, 245) if pulse else (5, 5, 7))
    center_x = WIDTH // 2
    draw.line((center_x, 120, center_x, HEIGHT - 120), fill=(0, 255, 140), width=8)
    for offset in range(-300, 301, 50):
        x = center_x + int(offset * 2.2)
        draw.line((x, 220, x, 520), fill=(90, 100, 112), width=2)
        if offset % 100 == 0:
            draw.text((x, 552), f"{offset:+d}ms", fill=(20, 24, 32) if pulse else (220, 230, 242), font=F18, anchor="mm")
    draw.rectangle((center_x - 170, 170, center_x + 170, 510), fill=(255, 255, 255), outline=(255, 60, 80), width=12)
    draw.text((center_x, 338), "VISUAL PULSE", fill=(8, 8, 10), font=F64, anchor="mm")
    draw.text((center_x, 650), "No audio in v1: this scene reserves visual timing markers for a future beep track.", fill=(255, 255, 255) if not pulse else (8, 8, 10), font=F32, anchor="mm")
    draw_footer(draw, frame_index, time_seconds)


def draw_caption_stress(draw: ImageDraw.ImageDraw, frame_index: int, time_seconds: float) -> None:
    picture_h = 500
    draw.rectangle((0, 0, WIDTH, picture_h), fill=(9, 14, 25))
    for x in range(0, WIDTH, 120):
        draw.rectangle((x, 0, x + 58, picture_h), fill=(18, 28, 44) if (x // 120) % 2 == 0 else (12, 20, 34))
    draw.rectangle((0, 0, WIDTH - 1, picture_h - 1), outline=(0, 230, 120), width=6)
    draw.text((70, 70), "Caption stress scene", fill=(235, 242, 255), font=F44)
    draw.text((70, 132), "Burned-in active cue id helps compare AVFoundation legible output.", fill=(128, 230, 255), font=F24)
    draw.text((WIDTH - 70, 70), timestamp(time_seconds), fill=(255, 226, 90), font=F32, anchor="ra")

    draw.rectangle((0, picture_h, WIDTH, HEIGHT), fill=(13, 13, 18))
    draw.rectangle((0, picture_h, WIDTH - 1, HEIGHT - 1), outline=(70, 130, 255), width=6)
    draw.text((WIDTH // 2, picture_h + 52), f"Rendered caption band mockup | active cue {active_cue_id(time_seconds)}", fill=(245, 248, 255), font=F32, anchor="mm")
    draw.text((WIDTH // 2, picture_h + 112), "Long cues should wrap here without covering the active picture.", fill=(190, 204, 224), font=F24, anchor="mm")
    draw.text((WIDTH // 2, picture_h + 172), "Retained cues stay bounded; future cues stay hidden.", fill=(190, 204, 224), font=F24, anchor="mm")
    draw_footer(draw, frame_index, time_seconds)


def frame(frame_index: int) -> Image.Image:
    time_seconds = frame_index / FPS
    image = Image.new("RGB", (WIDTH, HEIGHT), (5, 8, 14))
    draw = ImageDraw.Draw(image)
    if time_seconds < 10:
        draw_opening(draw, frame_index, time_seconds)
    elif time_seconds < 22:
        draw_grid(draw, frame_index, time_seconds)
    elif time_seconds < 34:
        draw_led(draw, frame_index, time_seconds)
    elif time_seconds < 40:
        draw_pulse(draw, frame_index, time_seconds)
    else:
        draw_caption_stress(draw, frame_index, time_seconds)
    return image


def run_ffmpeg() -> None:
    command = [
        "ffmpeg",
        "-y",
        "-f",
        "rawvideo",
        "-pix_fmt",
        "rgb24",
        "-s",
        f"{WIDTH}x{HEIGHT}",
        "-r",
        str(FPS),
        "-i",
        "-",
        "-an",
        "-c:v",
        "libx264",
        "-preset",
        "veryfast",
        "-crf",
        "20",
        "-pix_fmt",
        "yuv420p",
        "-profile:v",
        "high",
        "-level",
        "4.0",
        "-g",
        str(FPS * SEGMENT_SECONDS),
        "-keyint_min",
        str(FPS * SEGMENT_SECONDS),
        "-sc_threshold",
        "0",
        "-hls_time",
        str(SEGMENT_SECONDS),
        "-hls_playlist_type",
        "vod",
        "-hls_segment_filename",
        str(VIDEO_SEGMENTS_DIR / VIDEO_SEGMENT_TEMPLATE),
        str(VIDEO_DIR / VIDEO_PLAYLIST_NAME),
    ]

    with subprocess.Popen(command, stdin=subprocess.PIPE, cwd=ROOT) as process:
        assert process.stdin is not None
        for index in range(TOTAL_FRAMES):
            process.stdin.write(frame(index).tobytes())
        process.stdin.close()
        return_code = process.wait()
    if return_code != 0:
        raise RuntimeError(f"ffmpeg failed with exit code {return_code}")


def cues_for_segment(segment_index: int) -> list[Cue]:
    start = segment_index * SEGMENT_SECONDS
    end = start + SEGMENT_SECONDS
    return [cue for cue in CUES if cue.start < end and cue.end > start]


def write_subtitles() -> None:
    segment_count = DURATION_SECONDS // SEGMENT_SECONDS
    playlist_lines = [
        "#EXTM3U",
        "#EXT-X-VERSION:3",
        f"#EXT-X-TARGETDURATION:{SEGMENT_SECONDS}",
        "#EXT-X-PLAYLIST-TYPE:VOD",
        "#EXT-X-MEDIA-SEQUENCE:0",
    ]

    for segment_index in range(segment_count):
        segment_name = SUBTITLE_SEGMENT_TEMPLATE % segment_index
        segment_path = SUBTITLE_SEGMENTS_DIR / segment_name
        lines = [
            "WEBVTT",
            "X-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:0",
            "",
        ]
        for cue in cues_for_segment(segment_index):
            lines.extend([cue.identifier, f"{timestamp(cue.start)} --> {timestamp(cue.end)}", cue.text, ""])
        segment_path.write_text("\n".join(lines), encoding="utf-8")
        playlist_lines.extend([f"#EXTINF:{SEGMENT_SECONDS},", f"segments/{segment_name}"])

    playlist_lines.append("#EXT-X-ENDLIST")
    (SUBTITLE_DIR / SUBTITLE_PLAYLIST_NAME).write_text("\n".join(playlist_lines) + "\n", encoding="utf-8")


def write_master_playlist() -> None:
    master = """#EXTM3U
#EXT-X-VERSION:5
#EXT-X-INDEPENDENT-SEGMENTS
#EXT-X-MEDIA:TYPE=SUBTITLES,GROUP-ID="sub1",CHARACTERISTICS="public.accessibility.transcribes-spoken-dialog",NAME="English",AUTOSELECT=YES,DEFAULT=YES,FORCED=NO,LANGUAGE="en",URI="subtitles/caption-theater-generated-english.m3u8"
#EXT-X-STREAM-INF:BANDWIDTH=2400000,AVERAGE-BANDWIDTH=1800000,CODECS="avc1.640028",RESOLUTION=1920x800,FRAME-RATE=30.000,CLOSED-CAPTIONS=NONE,SUBTITLES="sub1"
video/caption-theater-generated-video.m3u8
"""
    (OUT / MASTER_PLAYLIST_NAME).write_text(master, encoding="utf-8")


def relative_files() -> list[Path]:
    return sorted(path for path in OUT.rglob("*") if path.is_file() and path.name != BACKUP_MANIFEST_NAME)


def write_provenance() -> None:
    text = f"""# Caption Theater Generated Widescreen Fixture

Generated by:

```text
Scripts/generate_widescreen_fixture.py
```

Rights posture:

- Project-owned generated video pattern.
- Project-authored timed WebVTT captions.
- No audio in v1.
- No third-party media, footage, speech synthesis, voice model, music, or captured stream content.
- Intended for public repository distribution under the project source license unless superseded by a future notice.

Technical shape:

- Video: {WIDTH}x{HEIGHT}, {FPS} fps, H.264, no audio.
- Duration: {DURATION_SECONDS} seconds.
- HLS segment duration: {SEGMENT_SECONDS} seconds.
- Captions: segmented WebVTT, English.

Purpose:

- Demonstrate true ultrawide geometry.
- Exercise Caption Theater top-pinned layout.
- Exercise timed caption rendering, wrapping, and retention behavior.
- Provide deterministic visual markers for screenshot and layout QA.
"""
    (OUT / PROVENANCE_NAME).write_text(text, encoding="utf-8")


def write_manifest() -> None:
    lines = ["Caption Theater generated widescreen fixture", "", "File hashes:"]
    for path in relative_files():
        digest = hashlib.sha256(path.read_bytes()).hexdigest()
        lines.append(f"{digest}  {path.relative_to(OUT)}")
    (OUT / BACKUP_MANIFEST_NAME).write_text("\n".join(lines) + "\n", encoding="utf-8")


def main() -> None:
    prepare_output()
    run_ffmpeg()
    write_subtitles()
    write_master_playlist()
    write_provenance()
    write_manifest()
    print(f"Generated {OUT.relative_to(ROOT)}")


if __name__ == "__main__":
    main()
