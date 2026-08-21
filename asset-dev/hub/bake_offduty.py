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
    # PAD FIRST: dilating the un-padded sprite clips the ring flat wherever
    # the silhouette touches its bounding box (user 2026-08-21: "cut off
    # edges, not consistent all around")
    pad = px + 2
    big = Image.new("RGBA", (im.width + 2 * pad, im.height + 2 * pad), (0, 0, 0, 0))
    big.alpha_composite(im, (pad, pad))
    mask = big.split()[3].point(lambda v: 255 if v > 60 else 0)
    sil = mask.filter(ImageFilter.MaxFilter(2 * px + 1))
    out = Image.new("RGBA", big.size, (0, 0, 0, 0))
    out.paste(Image.new("RGBA", big.size, (16, 14, 12, 255)), (0, 0), sil)
    out.alpha_composite(big)
    return out.crop(out.getbbox())


def extend_sign_ropes(im, ext):
    # replace the master's decorative crossed strands (which stop mid-air)
    # with TWO straight ropes from the board's bolts running past the top of
    # the camera view, clipped naturally by the screen edge (user
    # 2026-08-21: "cut off by the top of the view, naturally, not with
    # these weird ass lines")
    from PIL import ImageDraw
    px = im.load()
    w, h = im.size
    # the board = the wide rows at the bottom; everything above is strands
    widths = []
    for y in range(h):
        row = [x for x in range(w) if px[x, y][3] > 60]
        widths.append((row[0], row[-1]) if row else None)
    board_top = 0
    for y in range(h):
        if widths[y] and widths[y][1] - widths[y][0] > 0.75 * w:
            board_top = y
            break
    bl, br = widths[board_top + 6][0], widths[board_top + 6][1]
    # board-only image: per column, clear everything above the board's own
    # black top outline (a flat row-clear leaves stubs of the old strands
    # where the board is tilted)
    board = im.copy()
    dd = ImageDraw.Draw(board)
    dd.rectangle([0, 0, w, board_top - 1], fill=(0, 0, 0, 0))
    bpx = board.load()

    def is_black(c):
        return c[3] > 60 and (c[0] + c[1] + c[2]) < 90

    # stubs of the old strands survive the flat clear only inside the tilt
    # zone (rows board_top..surface); walk each column up from the board
    # interior and clear everything above its true top outline
    reliable = []           # (x, top) where the outline ended in air
    for x in range(w):
        y = board_top + 14
        if bpx[x, y][3] <= 60:
            top = board_top + 14    # column outside the board: clear it all
        else:
            while y < h - 1 and is_black(bpx[x, y]):
                y += 1              # start in wood, below any seam line
            top = 0
            while y >= 0:
                hit_air = False
                while y >= 0 and not is_black(bpx[x, y]):
                    if bpx[x, y][3] <= 60:
                        top = y     # air mid-wood: a floating stub core -
                        hit_air = True      # the surface is right here
                        break
                    y -= 1
                if hit_air or y < 0:
                    break
                y_start = y
                while y >= 0 and is_black(bpx[x, y]):
                    y -= 1          # walk through the black run
                run = y_start - y
                if run > 8:
                    top = y_start - 7   # outline merged with a strand stub:
                    break               # keep 7px of outline, clear the rest
                if y < 0 or bpx[x, y][3] <= 60:
                    top = y         # run ends in air: the true top outline
                    reliable.append((x, y))
                    break
                # run ends in wood again: a plank seam - keep climbing
        for yy in range(0, max(0, top + 1)):
            bpx[x, yy] = (0, 0, 0, 0)
    # the board's top edge is a straight (tilted) line: fit it through the
    # reliable columns and clear the leftover nubs above it everywhere
    if len(reliable) > 10:
        n = float(len(reliable))
        sx = sum(p[0] for p in reliable); sy = sum(p[1] for p in reliable)
        sxx = sum(p[0] * p[0] for p in reliable); sxy = sum(p[0] * p[1] for p in reliable)
        slope = (n * sxy - sx * sy) / (n * sxx - sx * sx)
        icpt = (sy - slope * sx) / n
        for x in range(w):
            edge = int(round(slope * x + icpt))
            for yy in range(0, max(0, edge)):
                bpx[x, yy] = (0, 0, 0, 0)
    # the BOLTS (gray, low-saturation discs near the board's upper corners)
    # are the exact hanging points: each rope runs down OVER the board to
    # its bolt center, and the bolt is redrawn on top of the rope end
    bolts = []
    for half in ((0, w // 2), (w // 2, w)):
        pts = []
        for yy in range(board_top, min(h, board_top + 40)):
            for xx in range(half[0], half[1]):
                c = bpx[xx, yy]
                if c[3] > 60 and max(c[:3]) - min(c[:3]) < 22 and 70 < sum(c[:3]) / 3 < 175:
                    pts.append((xx, yy))
        bx = sum(p[0] for p in pts) / float(len(pts))
        by = sum(p[1] for p in pts) / float(len(pts))
        bolts.append((int(round(bx)), int(round(by))))
    out = Image.new("RGBA", (w, ext + h), (0, 0, 0, 0))
    out.alpha_composite(board, (0, ext))
    d = ImageDraw.Draw(out)
    rope_core = (188, 152, 104, 255)
    rope_dark = (150, 118, 78, 255)
    for (cx, by) in bolts:
        bot = ext + by
        d.rectangle([cx - 4, 0, cx + 4, bot], fill=(16, 14, 12, 255))
        d.rectangle([cx - 2, 0, cx + 2, bot], fill=rope_core)
        d.rectangle([cx + 1, 0, cx + 2, bot], fill=rope_dark)  # light-left
        r = 8
        disc = im.crop((cx - r, by - r, cx + r + 1, by + r + 1))
        m = Image.new("L", disc.size, 0)
        ImageDraw.Draw(m).ellipse([0, 0, 2 * r, 2 * r], fill=255)
        out.paste(disc, (cx - r, ext + by - r), m)
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
        im = extend_sign_ropes(im, 165)
    for dst in (DST1, DST2):
        im.save(os.path.join(dst, name + ".png"))
    print("%-14s %dx%d" % (name, im.width, im.height))
    if name == "od_hammock":
        # FRONT FOLD layer (user 2026-08-21: the sleeper must be wedged INTO
        # the cloth, between the back and front folds): per cloth column,
        # the lower half of the sag plus its bottom outline, same canvas so
        # it base-anchors identically and draws over the sleeper
        px = im.load()
        front = Image.new("RGBA", im.size, (0, 0, 0, 0))
        fpx = front.load()
        # cloth = saturated opaque pixels (orange AND cream), not posts/outline
        def is_cloth(c):
            return c[3] > 60 and (max(c[:3]) - min(c[:3])) > 25 and c[0] > 120
        splits = {}
        for x in range(im.width):
            ys = [y for y in range(im.height) if is_cloth(px[x, y])]
            if len(ys) >= 6:
                splits[x] = (ys[0] + (ys[-1] - ys[0]) * 0.5, ys[-1])
        xs = sorted(splits)
        for x in xs:
            # smooth the split line over +-6 columns so the fold edge is clean
            nb = [splits[k][0] for k in range(x - 6, x + 7) if k in splits]
            split = int(round(sum(nb) / float(len(nb))))
            yb = splits[x][1]
            y = split
            while y < im.height and (px[x, y][3] > 60 or y <= yb):
                if px[x, y][3] > 60:
                    c = px[x, y]
                    if y < split + 2 and is_cloth(c):   # rim shade on the fold edge
                        c = (int(c[0] * 0.78), int(c[1] * 0.78), int(c[2] * 0.78), c[3])
                    fpx[x, y] = c
                y += 1
        for dst in (DST1, DST2):
            front.save(os.path.join(dst, "od_hammock_front.png"))
        print("od_hammock_front baked")
print("off duty props baked:", len(PROPS))
