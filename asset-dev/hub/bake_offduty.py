# Bake the OFF DUTY corner props to in-game sizes (2026-08-21).
# Sources: raw/prop_*.png (PixelLab) + offduty/*.png (procedural/vanilla).
# Installs flat-named textures to ui/lobby/art/ in BOTH trees.
from PIL import Image, ImageFilter
import numpy as np
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DST1 = os.path.join(HERE, "../../game-src/ui/lobby/art/")
DST2 = os.path.expanduser("~/brotato-decompiled/ui/lobby/art/")

# name -> (source, target world width)
PROPS = {
    "od_dartboard": ("raw/prop_dartboard.png", 64),
    "od_cooler":    ("raw/prop_cooler.png", 60),
    "od_dice":      ("raw/prop_dice.png", 48),
    "od_plant":     ("raw/prop_plant.png", 52),
    "od_skewers":   ("raw/prop_skewers.png", 80),
    "od_hammock":   ("raw/prop_hammock.png", 190),
    "od_crate":     ("raw/prop_crate3.png", 70),
    "od_rug":       ("offduty/rug.png", 260),
    "od_scorch":    ("offduty/scorch.png", 96),
    "od_tally":     ("offduty/tally.png", 120),
    "od_sign":      ("raw/prop_sign2.png", 130),
    "od_crate2":    ("raw/prop_crate_tall.png", 62),
    "od_barrel":    ("raw/prop_barrel.png", 56),
    "od_cards":     ("offduty/cards.png", 64),
    "od_chips":     ("offduty/chips.png", 40),
}


# decals that are soot/scratches by design - no outline, no thickening
NO_OUTLINE = {"od_scorch", "od_tally"}


def thicken_outline(im, px=2):
    # downscaling thins the masters' outlines to ~1px; grow a black ring
    # around the outer silhouette AFTER resize so every prop lands at a
    # consistent border weight (outer-ring only, like the statue - growing
    # interior lines fuses detail into webs)
    mask = im.split()[3].point(lambda v: 255 if v > 60 else 0)
    sil = mask.filter(ImageFilter.MaxFilter(2 * px + 1))
    pad = px + 1
    out = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
    ring = Image.new("RGBA", im.size, (16, 14, 12, 255))
    out.paste(ring, (pad, pad), sil)
    out.alpha_composite(im, (pad, pad))
    return out.crop(out.getbbox())


def extend_sign_ropes(im, ext):
    # the hanging sign's rope strands stop mid-air; continue each strand
    # straight up by `ext` px so the ropes reach the top of the wall when
    # the decal's top edge is placed at the wall top (user 2026-08-21)
    px = im.load()
    w, h = im.size
    cols = []
    for x in range(w):
        for y in range(0, 6):
            if px[x, y][3] > 60:
                cols.append(x)
                break
    clusters = []
    for x in cols:
        if clusters and x - clusters[-1][-1] <= 3:
            clusters[-1].append(x)
        else:
            clusters.append([x])
    from PIL import ImageDraw
    out = Image.new("RGBA", (w, h + ext), (0, 0, 0, 0))
    out.alpha_composite(im, (0, ext))
    d = ImageDraw.Draw(out)
    for cl in clusters:
        cx = sum(cl) // len(cl)
        core = (188, 152, 104, 255)
        for yy in range(3, 16):        # sample the strand's own color
            c = px[cx, yy]
            if c[3] > 60 and (c[0] + c[1] + c[2]) > 150:
                core = c
                break
        d.rectangle([cx - 4, 0, cx + 4, ext + 3], fill=(16, 14, 12, 255))
        d.rectangle([cx - 2, 0, cx + 2, ext + 2], fill=core)
    return out


def recolor_plant(im):
    # tie the plant to the palette: terracotta -> clay brown, leaves ->
    # deck-moss olive (user note 2026-08-21)
    a = np.array(im).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    vis = a[..., 3] > 50
    potm = vis & (r > g + 20) & (r > 90)          # terracotta
    a[..., 0] = np.where(potm, r * 0.62, a[..., 0])
    a[..., 1] = np.where(potm, g * 0.72, a[..., 1])
    a[..., 2] = np.where(potm, b * 0.75, a[..., 2])
    leafm = vis & (g > r) & (g > 70)              # leaves
    a[..., 0] = np.where(leafm, r * 0.95, a[..., 0])
    a[..., 1] = np.where(leafm, g * 0.82, a[..., 1])
    a[..., 2] = np.where(leafm, b * 0.55, a[..., 2])
    np.clip(a, 0, 255, out=a)
    return Image.fromarray(a.astype(np.uint8))


for name, (src, tw) in PROPS.items():
    im = Image.open(os.path.join(HERE, src)).convert("RGBA")
    im = im.crop(im.getbbox())
    if name == "od_plant":
        im = recolor_plant(im)
    if im.width != tw:
        th = round(im.height * tw / im.width)
        im = im.resize((tw, th), Image.LANCZOS)
    if name not in NO_OUTLINE:
        im = thicken_outline(im, 2)
    if name == "od_sign":
        im = extend_sign_ropes(im, 49)
    for dst in (DST1, DST2):
        im.save(os.path.join(dst, name + ".png"))
    print("%-14s %dx%d" % (name, im.width, im.height))
print("off duty props baked:", len(PROPS))
