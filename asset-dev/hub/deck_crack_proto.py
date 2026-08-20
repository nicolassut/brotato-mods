# Deck slab CRACK prototype (2026-08-20). Vanilla-language irregularities:
# tapered branching cracks with a lit left rim (light-from-left), spall pits,
# chipped slab corners. Cracks may cross seams (the STRUCTURE cracked, not
# the tiles). Style B slabs underneath.
from PIL import Image, ImageDraw
import random, math

B = (16, 14, 12, 255)
BASE = (52, 55, 62, 255)
SEAM = (38, 40, 46, 255)
LIT = (62, 66, 74, 255)
SHD = (44, 46, 53, 255)
CRACK = (27, 29, 34, 255)
CRACK_DEEP = (21, 22, 26, 255)
RIM = (63, 67, 76, 255)
MOSS = (110, 130, 66, 255)
MOSS_D = (88, 106, 52, 255)


def slabs(d, w, h, seed):
    rnd = random.Random(seed)
    y = 0
    row = 0
    while y < h:
        x = -(60 if row % 2 else 0)
        while x < w:
            cw = 120 + rnd.randint(-14, 14)
            tone = rnd.choice([BASE, (54, 57, 65, 255), (50, 53, 60, 255)])
            d.rectangle([x, y, x + cw, y + 74], fill=tone)
            d.rectangle([x, y, x + cw, y + 3], fill=LIT)
            d.rectangle([x, y, x + 3, y + 74], fill=LIT)
            d.rectangle([x + cw - 3, y, x + cw, y + 74], fill=SHD)
            d.rectangle([x, y + 71, x + cw, y + 74], fill=SHD)
            d.rectangle([x + cw, y, x + cw + 4, y + 74], fill=SEAM)
            x += cw + 4
        d.rectangle([0, y + 74, w, y + 78], fill=SEAM)
        y += 78
        row += 1


def crack_path(rnd, x, y, ang, steps, step_len):
    # heading-constrained walk: jitters and kinks, but never doubles back
    # (cumulative deviation clamped to +-1.0 rad of the initial heading)
    base_ang = ang
    pts = [(x, y)]
    for i in range(steps):
        ang += rnd.uniform(-0.45, 0.45)
        if rnd.random() < 0.22:                       # sharp kink
            ang += rnd.choice([-0.9, 0.9])
        ang = max(base_ang - 1.0, min(base_ang + 1.0, ang))
        x += math.cos(ang) * step_len * rnd.uniform(0.7, 1.3)
        y += math.sin(ang) * step_len * rnd.uniform(0.7, 1.3)
        pts.append((x, y))
    return pts


def draw_crack(d, pts, w_max):
    n = len(pts)
    # width profile: taper in, bulge mid, taper to a point
    for i in range(n - 1):
        t = i / max(1, n - 2)
        w = max(1.0, w_max * math.sin(t * math.pi) ** 0.7)
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        ang = math.atan2(y1 - y0, x1 - x0)
        px, py = -math.sin(ang) * w / 2, math.cos(ang) * w / 2
        poly = [(x0 + px, y0 + py), (x1 + px, y1 + py), (x1 - px, y1 - py), (x0 - px, y0 - py)]
        d.polygon(poly, fill=CRACK if w < 3 else CRACK_DEEP)
        # lit rim on the LEFT side of the crack (light-from-left); skip the
        # hairline ends so they taper clean
        if w >= 2.0:
            d.line([(x0 - px - 1, y0 - py), (x1 - px - 1, y1 - py)], fill=RIM, width=1)


def spall(d, rnd, x, y):
    r = rnd.randint(2, 4)
    pts = []
    for k in range(7):
        a = k / 7.0 * 2 * math.pi
        rr = r * rnd.uniform(0.6, 1.25)
        pts.append((x + math.cos(a) * rr, y + math.sin(a) * rr))
    d.polygon(pts, fill=CRACK)
    d.line([pts[3], pts[4]], fill=RIM, width=1)


def chip_corner(d, rnd, x, y):
    s = rnd.randint(8, 15)
    d.polygon([(x, y), (x + s, y), (x, y + s)], fill=CRACK)
    d.line([(x + s, y), (x, y + s)], fill=RIM, width=1)


import glob
MOSS_SET = [Image.open(p).convert("RGBA") for p in sorted(glob.glob(
    __file__.rsplit("/", 1)[0] + "/deck_moss_set/moss_*.png"))]


def moss_tuft(im, rnd, x, y, big=False):
    # vanilla-drawn tuft from the recolored deck moss set (user 2026-08-20:
    # use Brotato's own grass pieces, recolored - not hand triangles)
    p = MOSS_SET[rnd.randint(0, len(MOSS_SET) - 1)]
    if not big and (p.width > 30 or rnd.random() < 0.5):
        p = p.resize((max(6, int(p.width * 0.7)), max(6, int(p.height * 0.7))), Image.NEAREST)
    im.alpha_composite(p, (int(x - p.width / 2), int(y - p.height) + 2))


def make_swatch(seed, n_cracks, n_spall, n_moss):
    W, H = 760, 460
    im = Image.new("RGBA", (W, H), BASE)
    d = ImageDraw.Draw(im)
    rnd = random.Random(seed)
    slabs(d, W, H, seed)
    for _ in range(n_cracks):
        x, y = rnd.randint(40, W - 40), rnd.randint(30, H - 30)
        ang = rnd.uniform(0, 2 * math.pi)
        pts = crack_path(rnd, x, y, ang, rnd.randint(7, 13), rnd.randint(9, 16))
        draw_crack(d, pts, rnd.uniform(4.0, 6.0))
        for _ in range(rnd.randint(1, 2)):            # branches
            bi = rnd.randint(2, len(pts) - 3)
            bang = math.atan2(pts[bi+1][1]-pts[bi][1], pts[bi+1][0]-pts[bi][0]) + rnd.choice([-1.4, 1.4])
            bpts = crack_path(rnd, pts[bi][0], pts[bi][1], bang, rnd.randint(3, 6), rnd.randint(7, 12))
            draw_crack(d, bpts, rnd.uniform(1.6, 2.6))
        # pits hug the crack line only (never float free), 1-2 max
        for _ in range(rnd.randint(1, 2)):
            p = pts[rnd.randint(1, len(pts) - 2)]
            spall(d, rnd, p[0] + rnd.randint(-7, 7), p[1] + rnd.randint(-7, 7))
        # moss grows IN the crack (vegetation reclaims the seams)
        if rnd.random() < 0.7:
            p = pts[rnd.randint(1, len(pts) - 2)]
            moss_tuft(im, rnd, p[0], p[1] + 3, big=True)

    # moss only where there is a GAP to grow from: along slab seams
    for _ in range(n_moss):
        row_y = rnd.randint(1, H // 78) * 78
        moss_tuft(im, rnd, rnd.randint(30, W - 30), row_y + 2)
    # chipped slab corners at seam intersections
    for _ in range(5):
        row_y = rnd.randint(1, H // 78) * 78
        chip_corner(d, rnd, rnd.randint(40, W - 40), row_y - 74)
    return im


if __name__ == "__main__":
    import sys
    seed = int(sys.argv[1]) if len(sys.argv) > 1 else 11
    cracks = int(sys.argv[2]) if len(sys.argv) > 2 else 5
    im = make_swatch(seed, cracks, 6, 5)
    im.save("/tmp/deck_crack_proto.png")
    print("proto written")
