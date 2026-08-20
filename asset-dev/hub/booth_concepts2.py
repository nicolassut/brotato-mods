# Changing-booth CONCEPT BOARD round 2 (2026-08-20) - GW2-inspired: carnival
# marquee flash + deliberately shitty curtain on rings. Rough mockups, not
# final art. Chosen one goes to PixelLab probes.
from PIL import Image, ImageDraw

B = (16, 14, 12, 255)
METAL = (46, 48, 52, 255)
HI = (58, 60, 64, 255)
DK = (34, 36, 40, 255)
CAP = (56, 58, 62, 255)
BAND = (128, 52, 46, 255)       # marquee band red-brown
BAND_H = (150, 66, 56, 255)
BULB = (238, 196, 66, 255)
BULB_C = (252, 232, 150, 255)
GLOW = (140, 92, 40, 255)       # warm interior
GLOW_D = (108, 66, 30, 255)
CURT = (128, 142, 66, 255)      # trashy green curtain
CURT_D = (104, 116, 52, 255)
CURT_H = (148, 162, 82, 255)
STAR = (208, 196, 90, 255)
PANEL = (86, 150, 170, 255)     # glowing sign panel
PANEL_H = (130, 196, 214, 255)
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


def bulbs(d, xs, y):
    for x in xs:
        d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=BULB)
        d.ellipse([x - 3, y - 5, x + 2, y], fill=BULB_C)


def curtain(d, x0, x1, y0, y1, sag=True, gap=None, patch=None):
    # rail + rings
    d.rectangle([x0 - 6, y0, x1 + 6, y0 + 5], fill=CAP)
    for rx in range(x0 + 6, x1 - 4, 22):
        d.ellipse([rx - 5, y0 + 2, rx + 5, y0 + 14], outline=RING, width=3)
    # cloth (optionally with an open gap showing the warm interior)
    cx1 = gap if gap else x1
    d.rectangle([x0, y0 + 10, cx1, y1], fill=CURT_D)
    for i, x in enumerate(range(x0, cx1 - 8, 16)):
        hem = y1 - (6 if (i % 2) else 0) - (8 if sag and i in (2, 3) else 0)
        d.rectangle([x, y0 + 10, x + 8, hem], fill=CURT)
    d.rectangle([x0 + 2, y0 + 10, x0 + 8, y1 - 4], fill=CURT_H)
    # stars
    for (sx, sy) in ((x0 + 22, y0 + 46), (x0 + 58, y0 + 88), (x0 + 30, y0 + 132),
                     (x0 + 70, y0 + 40), (x0 + 82, y0 + 120)):
        if sx < cx1 - 10:
            d.polygon([(sx, sy - 7), (sx + 2, sy - 2), (sx + 7, sy - 2), (sx + 3, sy + 2),
                       (sx + 5, sy + 7), (sx, sy + 4), (sx - 5, sy + 7), (sx - 3, sy + 2),
                       (sx - 7, sy - 2), (sx - 2, sy - 2)], fill=STAR)
    if patch:
        d.rectangle(patch, fill=(88, 92, 76, 255))
        d.line([patch[0], patch[1], patch[2], patch[3]], fill=DK, width=2)


def concept_e():  # MARQUEE DRUM - closest to GW2: panel ring + bulbs + curtain
    def f(d, im):
        d.rectangle([30, 86, 220, 296], fill=METAL)                   # drum
        d.rectangle([34, 86, 52, 296], fill=HI)
        d.rectangle([202, 86, 220, 296], fill=DK)
        d.rectangle([18, 30, 232, 72], fill=BAND)                     # marquee band
        d.rectangle([18, 30, 232, 38], fill=BAND_H)
        for px in (34, 104, 174):                                     # sign panels
            d.rectangle([px, 38, px + 56, 66], fill=PANEL)
            d.rectangle([px + 4, 42, px + 22, 54], fill=PANEL_H)
        d.rectangle([18, 72, 232, 86], fill=BAND)                     # bulb ledge
        bulbs(d, range(34, 226, 38), 79)
        d.rectangle([62, 100, 188, 268], fill=GLOW)                   # opening
        d.rectangle([62, 100, 188, 118], fill=GLOW_D)
        curtain(d, 66, 184, 108, 258, gap=156)
        d.rectangle([42, 268, 208, 288], fill=CAP)                    # step
        d.rectangle([54, 288, 196, 302], fill=DK)
    return outlined(f)


def concept_f():  # SCRAP MARQUEE - boxy patched scrap, one tilted goggle sign
    def f(d, im):
        d.rectangle([34, 78, 216, 300], fill=METAL)
        d.rectangle([38, 78, 56, 300], fill=HI)
        d.rectangle([198, 78, 216, 300], fill=DK)
        for y in (150, 226):                                          # plate seams
            d.rectangle([34, y, 216, y + 4], fill=DK)
        for (rx, ry) in ((44, 90), (206, 90), (44, 288), (206, 288)):
            d.ellipse([rx - 4, ry - 4, rx + 4, ry + 4], fill=DK)
        d.polygon([(52, 22), (198, 34), (194, 74), (48, 62)], fill=BAND)   # tilted sign
        d.polygon([(60, 30), (140, 36), (138, 52), (58, 46)], fill=PANEL)
        d.ellipse([148, 40, 168, 60], fill=PANEL_H)                   # goggle doodle
        d.ellipse([166, 42, 186, 62], fill=PANEL_H)
        bulbs(d, (60, 100, 140, 180), 70)
        d.rectangle([66, 96, 184, 272], fill=GLOW)
        curtain(d, 70, 180, 104, 262, patch=(120, 170, 156, 206))
        d.rectangle([48, 276, 202, 292], fill=CAP)
    return outlined(f)


def concept_g():  # BIG TOP JANK - crooked cone cap + pennant + hat shelf
    def f(d, im):
        d.rectangle([36, 96, 204, 298], fill=METAL)
        d.rectangle([40, 96, 58, 298], fill=HI)
        d.rectangle([186, 96, 204, 298], fill=DK)
        d.polygon([(28, 96), (212, 96), (150, 30), (74, 38)], fill=BAND)   # crooked cone
        d.polygon([(74, 38), (110, 34), (120, 96), (76, 96)], fill=BAND_H)
        d.line([148, 30, 146, 8], fill=DK, width=4)                   # pennant
        d.polygon([(146, 8), (178, 14), (146, 24)], fill=STAR)
        bulbs(d, (48, 88, 128, 168, 200), 96)
        d.rectangle([64, 116, 176, 272], fill=GLOW)
        curtain(d, 68, 172, 124, 262, gap=148)
        d.rectangle([204, 170, 244, 182], fill=CAP)                   # hat shelf
        d.polygon([(212, 168), (236, 168), (224, 148)], fill=(96, 66, 130, 255))
        d.rectangle([206, 162, 242, 170], fill=(96, 66, 130, 255))
        d.rectangle([48, 272, 192, 290], fill=CAP)                    # step
    return outlined(f)


board = Image.new("RGBA", (W * 3 + 80, H + 80), (24, 22, 20, 255))
dd = ImageDraw.Draw(board)
labels = ["E  MARQUEE DRUM (closest to GW2)", "F  SCRAP MARQUEE", "G  BIG TOP JANK"]
for i, (c, lab) in enumerate(zip([concept_e(), concept_f(), concept_g()], labels)):
    x = 20 + i * (W + 20)
    board.alpha_composite(c, (x, 50))
    dd.text((x + 6, 20), lab, fill=(230, 225, 215, 255))
board.save("booth_concept_board2.png")
print("board 2 written")
