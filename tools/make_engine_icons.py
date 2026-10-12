#!/usr/bin/env python3
"""Draws the engine type icons of nj_event_calendar_1 in the format of the vanilla GUI icons: 36 x 36 TGA,
one 8-bit gray channel used as alpha (white glyph), file name with @2x (the game picks @2x for "<name>.tga").
Drawn at 8x and downsampled for anti-aliasing.
Usage: python3 tools/make_engine_icons.py [preview.png]"""
import math
import os
import sys

from PIL import Image, ImageDraw

SIZE = 36
SS = 8
S = SIZE * SS
OUT = os.path.join(os.path.dirname(__file__), "..", "mod", "nj_event_calendar_1", "content", "gui", "release_calendar", "icons")


def p(x, y):
    """36-grid coordinates -> supersampled pixels"""
    return (x * SS, y * SS)


def horse(d):
    # horse head in profile facing left (like a chess knight): ear, forehead, muzzle, jaw, neck; eye cut out
    d.polygon([
        p(28, 34), p(29.5, 24), p(28.5, 15), p(25.5, 8.5), p(23, 5.5), p(22, 1.5), p(19.5, 5.5),
        p(15, 7.5), p(10, 12), p(5.5, 18.5), p(4.5, 22), p(6, 24.5), p(9, 25), p(12.5, 22.5),
        p(16, 22), p(15, 27), p(12.5, 34),
    ], fill=255)
    # mane: a few notches along the back of the neck
    for y in (11, 16, 21, 26):
        d.polygon([p(27.5, y), p(32, y + 1.6), p(28, y + 3.6)], fill=255)
    d.ellipse([p(15, 11.2), p(17.6, 13.8)], fill=0)


def steam(d):
    # chimney (funnel widening to the top) with three puffs of steam
    d.polygon([p(11, 33), p(19, 33), p(19, 23), p(21, 18), p(9, 18), p(11, 23)], fill=255)
    d.rectangle([p(8, 16), p(22, 18.5)], fill=255)
    d.ellipse([p(13, 7), p(23, 15)], fill=255)
    d.ellipse([p(19, 2), p(29, 10)], fill=255)
    d.ellipse([p(24, 8), p(33, 15)], fill=255)


def diesel(d):
    # fuel drop
    cx, cy, r = 18, 22, 10
    d.ellipse([p(cx - r, cy - r), p(cx + r, cy + r)], fill=255)
    d.polygon([p(18, 2), p(cx - r * math.cos(math.radians(35)), cy - r * math.sin(math.radians(35))),
               p(cx + r * math.cos(math.radians(35)), cy - r * math.sin(math.radians(35)))], fill=255)
    # highlight cut-out
    d.arc([p(cx - 6, cy - 6), p(cx + 6, cy + 6)], start=110, end=170, fill=0, width=int(2 * SS))


def electric(d):
    # lightning bolt
    d.polygon([p(21, 2), p(8, 20), p(16.5, 20), p(13, 34), p(28, 14), p(19.5, 14), p(24, 2)], fill=255)


ICONS = {"engine_horse": horse, "engine_steam": steam, "engine_diesel": diesel, "engine_electric": electric}


def render(fn):
    big = Image.new("L", (S, S), 0)
    fn(ImageDraw.Draw(big))
    return big.resize((SIZE, SIZE), Image.LANCZOS)


def main():
    os.makedirs(OUT, exist_ok=True)
    images = []
    for name, fn in ICONS.items():
        im = render(fn)
        # uncompressed gray TGA with bottom-left origin, like the vanilla icons
        im.save(os.path.join(OUT, name + "@2x.tga"), rle=False, orientation=-1)
        images.append(im)
    if len(sys.argv) > 1:
        scale = 4
        sheet = Image.new("RGB", (len(images) * (SIZE + 4) * scale, (SIZE + 4) * scale), (40, 52, 66))
        for i, im in enumerate(images):
            white = Image.new("RGB", im.size, (255, 255, 255))
            tile = Image.new("RGB", im.size, (40, 52, 66))
            tile.paste(white, (0, 0), im)
            sheet.paste(tile.resize((SIZE * scale, SIZE * scale), Image.NEAREST), ((i * (SIZE + 4) + 2) * scale, 2 * scale))
        sheet.save(sys.argv[1])


if __name__ == "__main__":
    main()
