# Changing-booth CONCEPT BOARD round 3 (2026-08-20). GW2 gives the CONCEPT
# only (marquee flash + janky half-drawn curtain on rings) - the curtain
# cloth itself is OURS, three crash-site identities. Bodies and curtains are
# mixable. Rough mockups, not final art.
from PIL import Image, ImageDraw

B = (16, 14, 12, 255)
METAL = (46, 48, 52, 255)
HI = (58, 60, 64, 255)
DK = (34, 36, 40, 255)
CAP = (56, 58, 62, 255)
BAND = (128, 52, 46, 255)
BAND_H = (150, 66, 56, 255)
BULB = (238, 196, 66, 255)
BULB_C = (252, 232, 150, 255)
GLOW = (140, 92, 40, 255)
GLOW_D = (108, 66, 30, 255)
PANEL = (226, 168, 62, 255)      # warm amber sign glow (not GW2 blue)
PANEL_H = (248, 210, 120, 255)
RING = (170, 172, 176, 255)
W, H = 250, 330


def outlined(draw_fn):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    draw_fn(d, im)
    mask = im.split()[3].point(lambda v: 255 if v > 60 else 0)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    black = Image.new("RGBA", (W, H), B)
    for dx in range(-4, 5):
        for dy in range(-4, 5):
            if dx * dx + dy * dy <= 16:
                out.paste(black, (dx, dy), mask)
    out.paste(im, (0, 0), im)
    return out


def rail(d, x0, x1, y0):
    d.rectangle([x0 - 6, y0, x1 + 6, y0 + 5], fill=CAP)
    for rx in range(x0 + 6, x1 - 4, 22):
        d.ellipse([rx - 5, y0 + 2, rx + 5, y0 + 14], outline=RING, width=3)


def curtain_parachute(d, x0, x1, y0, y1, gap):
    # SALVAGED SHUTTLE PARACHUTE: alternating orange/cream gores, frayed
    # hem, shroud cord dangling - canon: the crash survivors reused it
    rail(d, x0, x1, y0)
    cols = [(196, 120, 60, 255), (206, 192, 164, 255)]
    i = 0
    x = x0
    while x < gap - 6:
        w = 18
        hem = y1 - (10 if i % 3 == 0 else 0) - (6 if i % 2 else 0)
        d.polygon([(x, y0 + 10), (x + w, y0 + 10), (x + w - 2, hem), (x + 2, hem + 6)],
                  fill=cols[i % 2])
        x += w
        i += 1
    # fray: little triangular nicks in the hem
    for fx in range(x0 + 10, gap - 14, 26):
        d.polygon([(fx, y1 - 2), (fx + 8, y1 - 2), (fx + 4, y1 + 8)], fill=cols[0])
    d.line([gap - 14, y1 - 4, gap - 6, y1 + 22], fill=(206, 192, 164, 255), width=3)  # cord


def curtain_sacks(d, x0, x1, y0, y1, gap):
    # STITCHED POTATO SACKS: burlap panels, cross-stitch seams, crude
    # potato stamp - peak Brotato
    rail(d, x0, x1, y0)
    d.rectangle([x0, y0 + 10, gap, y1], fill=(136, 108, 68, 255))
    for i, x in enumerate(range(x0, gap - 8, 34)):
        d.rectangle([x, y0 + 10, x + 17, y1 - (8 if i % 2 else 0)], fill=(150, 122, 78, 255))
    for sx in range(x0 + 30, gap - 10, 34):        # stitch seams
        for sy in range(y0 + 22, y1 - 8, 16):
            d.line([sx - 5, sy - 5, sx + 5, sy + 5], fill=(92, 70, 42, 255), width=3)
            d.line([sx - 5, sy + 5, sx + 5, sy - 5], fill=(92, 70, 42, 255), width=3)
    # crude potato stamp with eyes
    px, py = x0 + 34, (y0 + y1) // 2
    d.ellipse([px, py - 22, px + 40, py + 22], fill=(112, 84, 52, 255))
    for (ex, ey) in ((px + 10, py - 8), (px + 26, py + 4), (px + 16, py + 12)):
        d.ellipse([ex, ey, ex + 5, ey + 5], fill=(84, 60, 36, 255))


def curtain_tarp(d, x0, x1, y0, y1, gap):
    # CARGO TARP: grey-blue shuttle tarp, hazard-tape patches, grommet
    # tie-down corner - like they cut up the cargo cover
    rail(d, x0, x1, y0)
    d.rectangle([x0, y0 + 10, gap, y1], fill=(88, 100, 112, 255))
    d.rectangle([x0 + 4, y0 + 10, x0 + 12, y1 - 4], fill=(108, 122, 134, 255))
    d.polygon([(x0, y1 - 26), (gap, y1 - 46), (gap, y1), (x0, y1)], fill=(74, 86, 98, 255))
    for (hx, hy) in ((x0 + 52, y0 + 44), (gap - 44, y1 - 78)):    # hazard patches
        d.rectangle([hx, hy, hx + 34, hy + 22], fill=(206, 178, 60, 255))
        for k in range(3):
            d.line([hx + 6 + k * 12, hy, hx - 4 + k * 12, hy + 22], fill=(40, 40, 40, 255), width=4)
    for gx in range(x0 + 14, gap - 8, 30):          # grommets along hem
        d.ellipse([gx, y1 - 12, gx + 8, y1 - 4], outline=(160, 164, 168, 255), width=2)


def body_drum(d, curt):
    d.rectangle([30, 86, 220, 296], fill=METAL)
    d.rectangle([34, 86, 52, 296], fill=HI)
    d.rectangle([202, 86, 220, 296], fill=DK)
    d.rectangle([18, 30, 232, 72], fill=BAND)
    d.rectangle([18, 30, 232, 38], fill=BAND_H)
    for px in (34, 104, 174):
        d.rectangle([px, 38, px + 56, 66], fill=PANEL)
        d.rectangle([px + 4, 42, px + 22, 54], fill=PANEL_H)
    d.rectangle([18, 72, 232, 86], fill=BAND)
    for x in range(34, 226, 38):
        d.ellipse([x - 7, 72, x + 7, 86], fill=BULB)
        d.ellipse([x - 3, 74, x + 2, 79], fill=BULB_C)
    d.rectangle([62, 100, 188, 268], fill=GLOW)
    d.rectangle([62, 100, 188, 118], fill=GLOW_D)
    curt(d, 66, 184, 108, 258, 160)
    d.rectangle([42, 268, 208, 288], fill=CAP)
    d.rectangle([54, 288, 196, 302], fill=DK)


def make(curt):
    def f(d, im):
        body_drum(d, curt)
    return outlined(f)


board = Image.new("RGBA", (W * 3 + 80, H + 80), (24, 22, 20, 255))
dd = ImageDraw.Draw(board)
labels = ["1  SALVAGED PARACHUTE", "2  STITCHED POTATO SACKS", "3  CARGO TARP + HAZARD PATCH"]
for i, (curt, lab) in enumerate(zip([curtain_parachute, curtain_sacks, curtain_tarp], labels)):
    x = 20 + i * (W + 20)
    board.alpha_composite(make(curt), (x, 50))
    dd.text((x + 6, 20), lab, fill=(230, 225, 215, 255))
board.save("booth_concept_board3.png")
print("board 3 written")
