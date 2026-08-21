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
                    break
                # run ends in wood again: a plank seam - keep climbing
        for yy in range(0, max(0, top + 1)):
            bpx[x, yy] = (0, 0, 0, 0)
    out = Image.new("RGBA", (w, ext + h), (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    rope_core = (188, 152, 104, 255)
    rope_dark = (150, 118, 78, 255)
    for cx in (bl + 14, br - 14):       # at the bolts, behind the board top
        bot = ext + board_top + 10
        d.rectangle([cx - 4, 0, cx + 4, bot], fill=(16, 14, 12, 255))
        d.rectangle([cx - 2, 0, cx + 2, bot], fill=rope_core)
        d.rectangle([cx + 1, 0, cx + 2, bot], fill=rope_dark)  # light-left
    out.alpha_composite(board, (0, ext))
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
print("off duty props baked:", len(PROPS))
