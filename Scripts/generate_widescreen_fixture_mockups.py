#!/usr/bin/env python3
"""Generate static PNG mockups for the Caption Theater widescreen fixture."""

from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw, ImageFont


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "Docs" / "Mockups" / "WidescreenFixture"
WIDTH = 1920
HEIGHT = 800


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


F12 = font(12)
F18 = font(18)
F24 = font(24)
F32 = font(32)
F44 = font(44, bold=True)
F64 = font(64, bold=True)


def text_box(draw: ImageDraw.ImageDraw, xy: tuple[int, int], text: str, *, fill: tuple[int, int, int] = (245, 248, 255), anchor: str = "la", font_obj=F24) -> None:
    draw.text(xy, text, fill=fill, font=font_obj, anchor=anchor)


def save(image: Image.Image, name: str) -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    image.save(OUT / name)


def base(bg=(8, 10, 16)) -> tuple[Image.Image, ImageDraw.ImageDraw]:
    image = Image.new("RGB", (WIDTH, HEIGHT), bg)
    return image, ImageDraw.Draw(image)


def draw_outer_guides(draw: ImageDraw.ImageDraw) -> None:
    draw.rectangle((0, 0, WIDTH - 1, HEIGHT - 1), outline=(255, 255, 255), width=6)
    draw.rectangle((32, 32, WIDTH - 33, HEIGHT - 33), outline=(0, 220, 120), width=3)
    draw.line((WIDTH // 2, 0, WIDTH // 2, HEIGHT), fill=(255, 255, 255), width=2)
    draw.line((0, HEIGHT // 2, WIDTH, HEIGHT // 2), fill=(255, 255, 255), width=2)
    marker = 32
    for x, y, label, anchor in [
        (marker, marker, "TL", "la"),
        (WIDTH - marker, marker, "TR", "ra"),
        (marker, HEIGHT - marker, "BL", "ld"),
        (WIDTH - marker, HEIGHT - marker, "BR", "rd"),
    ]:
        draw.text((x, y), label, fill=(255, 255, 255), font=F32, anchor=anchor)


def opening_slate() -> None:
    image, draw = base((5, 8, 15))
    draw_outer_guides(draw)
    for i in range(0, WIDTH, 120):
        color = (20 + (i // 120) % 2 * 15, 32, 48)
        draw.rectangle((i, 0, i + 60, HEIGHT), fill=color)

    draw.rectangle((260, 170, WIDTH - 260, 620), fill=(9, 14, 25), outline=(90, 180, 255), width=4)
    draw.text((WIDTH // 2, 250), "Caption Theater", fill=(250, 252, 255), font=F64, anchor="mm")
    draw.text((WIDTH // 2, 322), "Generated Widescreen Fixture", fill=(125, 230, 255), font=F44, anchor="mm")
    draw.text((WIDTH // 2, 392), "1920 x 800  |  2.40:1  |  30 fps  |  Project-owned media", fill=(222, 232, 244), font=F32, anchor="mm")
    draw.text((WIDTH // 2, 468), "Use this slate to verify true ultrawide geometry, not letterboxed 16:9.", fill=(180, 195, 216), font=F24, anchor="mm")

    for x in range(400, WIDTH - 399, 160):
        draw.line((x, 585, x, 615), fill=(255, 255, 255), width=2)
        draw.text((x, 642), str(x), fill=(150, 170, 190), font=F18, anchor="mm")
    save(image, "01-opening-slate.png")


def alignment_grid() -> None:
    image, draw = base((4, 6, 10))
    for x in range(0, WIDTH + 1, 80):
        major = x % 320 == 0
        draw.line((x, 0, x, HEIGHT), fill=(75, 105, 130) if major else (28, 42, 55), width=3 if major else 1)
        if major and x > 0:
            draw.text((x + 8, 24), f"x{x}", fill=(135, 170, 200), font=F18)
    for y in range(0, HEIGHT + 1, 80):
        major = y % 320 == 0
        draw.line((0, y, WIDTH, y), fill=(75, 105, 130) if major else (28, 42, 55), width=3 if major else 1)
        if major and y > 0:
            draw.text((24, y + 8), f"y{y}", fill=(135, 170, 200), font=F18)

    draw_outer_guides(draw)
    scan_x = 1280
    scan_y = 320
    draw.rectangle((scan_x - 10, 0, scan_x + 10, HEIGHT), fill=(255, 214, 70))
    draw.rectangle((0, scan_y - 6, WIDTH, scan_y + 6), fill=(0, 210, 255))
    draw.ellipse((WIDTH // 2 - 44, HEIGHT // 2 - 44, WIDTH // 2 + 44, HEIGHT // 2 + 44), outline=(255, 80, 120), width=6)
    draw.text((WIDTH // 2, 720), "Alignment grid + moving scanline mockup", fill=(255, 255, 255), font=F32, anchor="mm")
    save(image, "02-alignment-grid.png")


def led_panel() -> None:
    image, draw = base((6, 6, 9))
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
            label = f"{chr(65 + row)}{col + 1}"
            draw.text(((x0 + x1) // 2, (y0 + y1) // 2), label, fill=(255, 255, 255), font=F44, anchor="mm")
            draw.text((x0 + 16, y0 + 18), f"{panel_w}x{panel_h}", fill=(170, 190, 210), font=F18)

    highlight_col = 5
    draw.rectangle((highlight_col * panel_w, 0, (highlight_col + 1) * panel_w, HEIGHT), outline=(255, 226, 0), width=10)
    draw.line((0, HEIGHT // 2, WIDTH, HEIGHT // 2), fill=(255, 226, 0), width=4)
    draw.text((WIDTH // 2, 54), "LED-style panel alignment: numbered tiles, sweep column, center seam", fill=(255, 255, 255), font=F32, anchor="mm")
    save(image, "03-led-panel-alignment.png")


def av_sync() -> None:
    image, draw = base((3, 3, 4))
    draw.rectangle((0, 0, WIDTH, HEIGHT), fill=(250, 250, 250))
    draw.rectangle((70, 70, WIDTH - 70, HEIGHT - 70), fill=(10, 10, 12), outline=(255, 255, 255), width=4)
    center_x = WIDTH // 2
    draw.line((center_x, 120, center_x, HEIGHT - 120), fill=(0, 255, 140), width=8)
    for offset in range(-300, 301, 50):
        x = center_x + int(offset * 2.2)
        draw.line((x, 220, x, 520), fill=(90, 100, 112), width=2)
        if offset % 100 == 0:
            draw.text((x, 552), f"{offset:+d}ms", fill=(220, 230, 242), font=F18, anchor="mm")

    flash_rect = (center_x - 170, 170, center_x + 170, 510)
    draw.rectangle(flash_rect, fill=(255, 255, 255), outline=(255, 60, 80), width=12)
    draw.text((center_x, 338), "BEEP NOW", fill=(8, 8, 10), font=F64, anchor="mm")
    draw.text((center_x, 630), "Frame 120  |  00:04.000  |  1 kHz tone starts on this flash frame", fill=(255, 255, 255), font=F32, anchor="mm")
    draw.text((center_x, 705), "Mockup for phone-camera A/V sync inspection and player drift checks", fill=(180, 196, 218), font=F24, anchor="mm")
    save(image, "04-av-sync-flash-beep.png")


def caption_stress() -> None:
    image, draw = base((5, 8, 14))
    picture_h = 480
    caption_y = picture_h
    draw.rectangle((0, 0, WIDTH, picture_h), fill=(9, 14, 25))
    for x in range(0, WIDTH, 120):
        draw.rectangle((x, 0, x + 58, picture_h), fill=(18, 28, 44) if (x // 120) % 2 == 0 else (12, 20, 34))
    draw.rectangle((0, 0, WIDTH - 1, picture_h - 1), outline=(0, 230, 120), width=6)
    draw.line((0, picture_h, WIDTH, picture_h), fill=(255, 255, 255), width=4)
    draw.text((70, 70), "Active picture area: true 1920x800 source top-pinned inside app layout", fill=(235, 242, 255), font=F32)
    draw.text((70, 132), "Cue ID VTT-017 burns into video for rendered-caption comparison", fill=(128, 230, 255), font=F24)
    draw.text((WIDTH - 70, 70), "00:01:07.500", fill=(255, 226, 90), font=F32, anchor="ra")
    draw.rectangle((0, caption_y, WIDTH, HEIGHT), fill=(13, 13, 18))
    draw.rectangle((0, caption_y, WIDTH - 1, HEIGHT - 1), outline=(70, 130, 255), width=6)

    lines = [
        ("ALEX", "This is a deliberately long caption that should wrap cleanly across the full reading band."),
        ("MIRA", "Short reply."),
        ("SDH", "[low rumble builds under the dialogue]"),
        ("ALEX", "Already-presented cues remain visible, but future cues never appear early."),
    ]
    y = caption_y + 42
    colors = {"ALEX": (120, 220, 255), "MIRA": (255, 190, 100), "SDH": (180, 190, 205)}
    for speaker, text in lines:
        draw.rounded_rectangle((210, y - 8, WIDTH - 210, y + 44), radius=10, fill=(25, 28, 38), outline=(58, 66, 85), width=2)
        draw.text((240, y + 16), speaker, fill=colors[speaker], font=F24, anchor="lm")
        draw.text((340, y + 16), text, fill=(245, 248, 255), font=F24, anchor="lm")
        y += 62

    draw.text((WIDTH // 2, HEIGHT - 26), "Caption stress mockup: wrapping, speaker labels, retained cues, SDH cue", fill=(155, 170, 190), font=F18, anchor="mm")
    save(image, "05-caption-stress-band.png")


def main() -> None:
    opening_slate()
    alignment_grid()
    led_panel()
    av_sync()
    caption_stress()


if __name__ == "__main__":
    main()
