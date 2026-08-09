#!/usr/bin/env python3
"""Install the Appetite "Stomach" level-up icon from the user's design source.

The 4 appetite upgrade tres shipped pointing at items/custom_stats/appetite.png - the fork &
knife STAT glyph - so the Stomach card showed the stat icon instead of its own art. Vanilla
level-up icons are their own 96x96 organs (heart, lungs, skull, teeth), and the user drew a
matching green stomach; this installs it in that format.

Idempotent: re-running rewrites the same PNG from the same source.
"""
from PIL import Image
import os

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
REPO = "/Users/nicolassutcliffe/brotato-mods"

SRC = os.path.join(REPO, "Brotato Icons",
                   "For brotato, appetite needs its own upgrade icon, its very important that "
                   "this looks very accurate to what it needs to be. So basically in the game "
                   "for every type of main stat theres an upgrade ic (7) (1).png")

OUT_DIR = os.path.join(DEC, "items", "upgrades", "appetite")
OUT = os.path.join(OUT_DIR, "stomach.png")

# vanilla upgrade icons sit inside a 96x96 canvas with ~10px of breathing room
CANVAS = 96
MAX_CONTENT = 80


def main() -> None:
    im = Image.open(SRC).convert("RGBA")

    # crop to the drawn pixels, so the source's whitespace does not shrink the icon
    bbox = im.getchannel("A").getbbox()
    if bbox is None:
        raise SystemExit("source image is fully transparent")
    im = im.crop(bbox)

    # scale the long edge to MAX_CONTENT, preserving aspect
    scale = MAX_CONTENT / max(im.size)
    new_size = (max(1, round(im.width * scale)), max(1, round(im.height * scale)))
    im = im.resize(new_size, Image.LANCZOS)

    out = Image.new("RGBA", (CANVAS, CANVAS), (0, 0, 0, 0))
    out.paste(im, ((CANVAS - im.width) // 2, (CANVAS - im.height) // 2), im)

    os.makedirs(OUT_DIR, exist_ok=True)
    out.save(OUT)
    print(f"wrote {OUT} ({out.size[0]}x{out.size[1]}, content {new_size[0]}x{new_size[1]})")


main()
