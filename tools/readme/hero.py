#!/usr/bin/env python3
"""The title image of the README (scripts/readme-images): five looks of the
example invoice fanned out, rising from the bottom edge of a rounded card.

Usage: hero.py <pages dir> <out.webp>   (pages: <preset>-1.png at 150 ppi)
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter

W, H = 2400, 1100
PAGE_H = 1500  # the pages overflow the card at the bottom
TOP, BOTTOM = (238, 246, 244), (226, 233, 240)
# preset, rotation (degrees), centre x, top y; the outer pages first
LOOKS = [
    ("classic", -10, 430, 290),
    ("corporate", 10, 1970, 290),
    ("elegant", -5, 805, 175),
    ("soft", 5, 1595, 175),
    ("bold", 0, 1200, 90),
]


def gradient(size, top, bottom):
    w, h = size
    column = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / max(1, h - 1)
        column.putpixel((0, y), tuple(round(a + (b - a) * t) for a, b in zip(top, bottom)))
    return column.resize((w, h))


def paste_with_shadow(canvas, im, xy, blur=28, offset=(0, 22), alpha=70):
    shadow = Image.new("RGBA", (im.width + 4 * blur, im.height + 4 * blur), (0, 0, 0, 0))
    mask = im.split()[3].point(lambda a: alpha if a > 0 else 0)
    shadow.paste((15, 23, 42, 255), (2 * blur, 2 * blur), mask)
    shadow = shadow.filter(ImageFilter.GaussianBlur(blur))
    canvas.alpha_composite(shadow, (xy[0] - 2 * blur + offset[0], xy[1] - 2 * blur + offset[1]))
    canvas.alpha_composite(im, xy)


def main(pages, out):
    canvas = gradient((W, H), TOP, BOTTOM).convert("RGBA")
    for name, angle, cx, top in LOOKS:
        page = Image.open(pages / f"{name}-1.png").convert("RGBA")
        height = PAGE_H * (1.06 if name == "bold" else 1.0)
        page = page.resize((round(page.width * height / page.height), round(height)), Image.LANCZOS)
        page = page.rotate(-angle, resample=Image.BICUBIC, expand=True)
        paste_with_shadow(canvas, page, (round(cx - page.width / 2), top))
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, W - 1, H - 1), 40, fill=255)
    card = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    card.paste(canvas, (0, 0), mask)
    # WebP at quality 92: no visible loss, a quarter of the PNG
    card.save(out, quality=92, method=6)


if __name__ == "__main__":
    main(Path(sys.argv[1]), Path(sys.argv[2]))
