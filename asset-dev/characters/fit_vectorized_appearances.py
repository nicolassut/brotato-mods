#!/usr/bin/env python3
"""Fit the hi-res vectorized characters (Brotato Icons/New_Vectorized_Icons/
character__<slug>.png) onto the 150x150 in-game appearance-piece canvas as
full-body overlays (vanilla Golem/Cyborg pattern: one skin-depth sprite that
covers the potato and carries the whole look; worn items draw on top).

Canvas law (measured from potato.png and all three existing skins):
  potato body bbox on the 150 canvas = (45, 38, 104, 107)  => 59w x 69h
  sprite anchor = canvas center, so on any canvas C:
  body center x = C/2 - 0.5, body bottom = C/2 + 32

Body detection in the 640 source: max opaque row width in the lower band of
the silhouette (hats/horns/eyestalks/props live in the upper half).
Per-slug overrides available where the heuristic misreads.

Outputs to final/appearances_vector/<slug>_face.png + a verification sheet.
Does NOT touch the live game dirs; installation is a separate manual step.
"""
import os
from PIL import Image, ImageDraw

HOME = os.path.expanduser("~")
SRC = f"{HOME}/brotato-mods/Brotato Icons/New_Vectorized_Icons"
OUT = f"{HOME}/brotato-mods/asset-dev/characters/final/appearances_vector"
LIVE = f"{HOME}/brotato-decompiled/items/custom_characters"
POTATO = f"{HOME}/brotato-decompiled/entities/units/player/potato.png"
SHEET = f"{HOME}/brotato-mods/asset-dev/characters/final/appearances_vector/_verify_sheet.png"

BODY_W, BODY_BOTTOM_OFF, BODY_CX_OFF = 59, 32, -0.5  # vs canvas center
ALPHA_T = 10

SLUGS = ["blacksmith", "butcher", "comp_eater", "dishwasher", "gourmet",
         "juggler", "mime", "mole", "picky_eater", "ruminant", "snail",
         "tourist", "zombie"]

# band = (lo, hi) fractions of silhouette height measured up from the bottom;
# widest row inside the band is taken as the body width.
BAND = {"default": (0.05, 0.40)}
# manual body-width override in source px: slug -> (width, cx)
# blacksmith: the beard flares wider than the egg, contaminating the band
# measurement (272 vs the roster-consistent ~248) and shrinking him ~9%.
# 248 matches the shared framing of the other vectorizer exports; cx from
# the frame center of his 640 export.
OVERRIDE = {"blacksmith": (250, 320)}


def measure_body(im):
    a = im.split()[3].point(lambda v: 255 if v > ALPHA_T else 0)
    bbox = a.getbbox()
    x0, y0, x1, y1 = bbox
    h = y1 - y0
    lo, hi = BAND["default"]
    rows = []
    px = a.load()
    for y in range(int(y1 - hi * h), int(y1 - lo * h)):
        xs = [x for x in range(x0, x1) if px[x, y]]
        if xs:
            rows.append((xs[-1] - xs[0] + 1, (xs[0] + xs[-1]) / 2, y))
    wmax = max(r[0] for r in rows)
    good = [r for r in rows if r[0] >= 0.98 * wmax]
    cx = sum(r[1] for r in good) / len(good)
    return wmax, cx, y1


def compose(im, w, cx, bottom, f, dx, dy):
    """Scale source so body width = BODY_W * f, anchor body-ish bottom to the
    potato bottom line (+dy, +dx tweaks). Returns canvas or None if > 200px."""
    scale = BODY_W * f / w
    nw, nh = round(im.width * scale), round(im.height * scale)
    im2 = im.resize((nw, nh), Image.LANCZOS)
    scx, sbot = cx * scale, bottom * scale
    for C in (150, 160, 170, 180, 190, 200, 210, 220):
        c = C / 2
        ox = c + BODY_CX_OFF + dx - scx
        oy = c + BODY_BOTTOM_OFF + dy - sbot
        if ox >= 0 and oy >= 0 and ox + nw <= C and oy + nh <= C:
            out = Image.new("RGBA", (C, C), (0, 0, 0, 0))
            out.paste(im2, (round(ox), round(oy)), im2)
            return out, C
    return None, None


def potato_interior_mask(potato):
    """Solid, non-outline potato pixels: the beige fill that must never peek."""
    px = potato.load()
    mask = []
    for y in range(potato.height):
        for x in range(potato.width):
            r, g, b, a = px[x, y]
            if a >= 250 and (r + g + b) > 180:
                mask.append((x, y))
    return mask


def uncovered(piece, C, interior):
    """Count interior potato pixels not covered by the overlay (both centered
    on the same anchor)."""
    off = (C - 150) // 2
    pa = piece.split()[3].load()
    n = 0
    for (x, y) in interior:
        if pa[x + off, y + off] < 150:
            n += 1
    return n


def fit(slug, interior):
    im = Image.open(f"{SRC}/character__{slug}.png").convert("RGBA")
    if slug in OVERRIDE:
        w, cx = OVERRIDE[slug]
        bottom = im.split()[3].point(lambda v: 255 if v > ALPHA_T else 0).getbbox()[3]
    else:
        w, cx, bottom = measure_body(im)
    # search the smallest upscale / shift that fully hides the potato fill
    for f in (1.0, 1.02, 1.04, 1.06, 1.08, 1.10, 1.12, 1.15):
        for dy in (0, -1, 1, -2, 2, -3, 3, -4, 4, -5, 5, -6, 6, -7, 7,
                   -8, 8, -9, 9, -10, 10, 11, 12, 13, 14):
            for dx in (0, -1, 1, -2, 2, -3, 3):
                piece, C = compose(im, w, cx, bottom, f, dx, dy)
                if piece is None:
                    continue
                if uncovered(piece, C, interior) == 0:
                    return piece, w, C, f, dx, dy
    # fallback: no upscale, pushed down as far as the canvas allows
    for dy in range(14, -15, -1):
        piece, C = compose(im, w, cx, bottom, 1.0, 0, dy)
        if piece is not None:
            return piece, w, C, 1.0, 0, dy
    raise RuntimeError(f"{slug}: cannot fit on any canvas")


def main():
    os.makedirs(OUT, exist_ok=True)
    potato = Image.open(POTATO).convert("RGBA")
    cell = 170
    sheet = Image.new("RGBA", (3 * cell + 120, len(SLUGS) * cell + 30), (58, 58, 58, 255))
    d = ImageDraw.Draw(sheet)
    for j, h in enumerate(["icon LIVE", "overlay alone", "potato+overlay"]):
        d.text((120 + j * cell, 8), h, fill=(255, 255, 0, 255))
    interior = potato_interior_mask(potato)
    for i, slug in enumerate(SLUGS):
        piece, srcw, C, f, dx, dy = fit(slug, interior)
        left = uncovered(piece, C, interior)
        piece.save(f"{OUT}/{slug}_face.png")
        y = 30 + i * cell
        d.text((5, y + 60), f"{slug}\nsrc_bw={srcw} canvas={C}\nf={f} dx={dx} dy={dy}\nuncovered={left}",
               fill=(255, 255, 255, 255) if left == 0 else (255, 80, 80, 255))
        icon = Image.open(f"{LIVE}/{slug}/{slug}_icon.png").convert("RGBA")
        icon = icon.resize((150, 150), Image.NEAREST)
        sheet.paste(icon, (120, y + 10), icon)
        pv = piece.resize((150, 150), Image.LANCZOS) if C != 150 else piece
        sheet.paste(pv, (120 + cell, y + 10), pv)
        comp = Image.new("RGBA", (C, C), (0, 0, 0, 0))
        pot_off = (C - 150) // 2  # potato canvas centered on same anchor
        comp.paste(potato, (pot_off, pot_off), potato)
        comp.alpha_composite(piece)
        if C != 150:
            comp = comp.resize((150, 150), Image.LANCZOS)
        sheet.paste(comp, (120 + 2 * cell, y + 10), comp)
        print(f"{slug}: src body_w={srcw} canvas={C} f={f} dx={dx} dy={dy} uncovered={left}")
    sheet.save(SHEET)
    print("sheet ->", SHEET)


if __name__ == "__main__":
    main()
