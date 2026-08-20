#!/usr/bin/env python3
"""Hub ground builder (HUB_ART_SPEC 1c): plaza/deck/cliff overlay textures in
the MEASURED vanilla ground language - flat base + sparse extracted vanilla
decals + wobbly torn edges. Deterministic (seeded); zero PixelLab credits.
Outputs land in game-src/ui/lobby/art/ and the live tree."""
import numpy as np, random, os
from PIL import Image, ImageDraw
from collections import deque

V = os.path.expanduser("~/brotato-vanilla-reference/resources/tiles/")
OUT1 = os.path.join(os.path.dirname(os.path.abspath(__file__)), "../../game-src/ui/lobby/art/")
OUT2 = os.path.expanduser("~/brotato-decompiled/ui/lobby/art/")
random.seed(408)

def extract_decals(path, base_rgb, tol=18):
    im = Image.open(path).convert("RGBA")
    a = np.array(im); H, W = a.shape[:2]
    base = np.array(base_rgb)
    diff = np.abs(a[..., :3].astype(int) - base).sum(axis=2)
    mask = (diff > tol) & (a[..., 3] > 100)
    lab = np.zeros((H, W), int); cur = 0; decals = []
    for y in range(H):
        for x in range(W):
            if mask[y, x] and lab[y, x] == 0:
                cur += 1; q = deque([(y, x)]); lab[y, x] = cur; px = [(y, x)]
                while q:
                    cy, cx = q.popleft()
                    for ny, nx in ((cy-1,cx),(cy+1,cx),(cy,cx-1),(cy,cx+1),
                                   (cy-1,cx-1),(cy-1,cx+1),(cy+1,cx-1),(cy+1,cx+1)):
                        if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = cur; q.append((ny, nx)); px.append((ny, nx))
                if 40 <= len(px) <= 3000:
                    ys = [p[0] for p in px]; xs = [p[1] for p in px]
                    y0, y1, x0, x1 = min(ys), max(ys), min(xs), max(xs)
                    crop = np.zeros((y1-y0+3, x1-x0+3, 4), np.uint8)
                    for (yy, xx) in px:
                        crop[yy-y0+1, xx-x0+1] = a[yy, xx]
                    decals.append(Image.fromarray(crop))
    return decals

rocks = extract_decals(V + "tiles_1.png", (120, 103, 88))
tufts = extract_decals(V + "tiles_2.png", (78, 92, 91))

def is_greenish(im):
    # PLANT detector: fraction of the decal's own pixels that are green-
    # dominant (the mean is useless - dark outlines dilute it). A gray-tinted
    # cactus still has a plant silhouette, so the source decal must go.
    a = np.array(im).astype(int)
    m = a[..., 3] > 100
    if m.sum() == 0:
        return True
    g_frac = ((a[..., 1] > a[..., 0] + 4) & (a[..., 1] > a[..., 2] + 4) & m).sum() / m.sum()
    return g_frac > 0.12

# PURE rocks only for the cliff (user 2026-08-19: no grass on the face) -
# the dirt-tile extraction includes cacti/tufts, filter them out by hue
pure_rocks = [d for d in rocks if not is_greenish(d)]
print("extracted:", len(rocks), "dirt decals,", len(tufts), "forest decals,",
      len(pure_rocks), "pure rocks")
assert len(pure_rocks) >= 6, "rock filter too aggressive"
assert len(rocks) >= 8, "too few decals extracted"

def tint(im, mul):
    a = np.array(im).astype(float)
    a[..., :3] *= np.array(mul)
    return Image.fromarray(np.clip(a, 0, 255).astype(np.uint8))

def scatter(canvas, decals, count, mul, margin=24, scale=1.0):
    W, H = canvas.size; placed = []
    for _ in range(count * 8):
        if len(placed) >= count: break
        d = random.choice(decals)
        d2 = tint(d, mul)
        if scale != 1.0:
            d2 = d2.resize((max(2,int(d2.width*scale)), max(2,int(d2.height*scale))), Image.NEAREST)
        x = random.randint(margin, W - d2.width - margin)
        y = random.randint(margin, H - d2.height - margin)
        if any(abs(x-px) < 70 and abs(y-py) < 70 for px, py in placed): continue
        canvas.paste(d2, (x, y), d2); placed.append((x, y))
    return len(placed)

def wobble_edge(draw, x0, x1, y, amp, color, thickness, seed):
    rnd = random.Random(seed); pts = []
    x = x0
    while x <= x1:
        pts.append((x, y + rnd.randint(-amp, amp)))
        x += rnd.randint(18, 34)
    pts.append((x1, y))
    for i in range(len(pts) - 1):
        draw.line([pts[i], pts[i+1]], fill=color, width=thickness)

# PLAZA overlay 2752x1344: transparent, sparse decals (rocks + muted tufts)
plaza = Image.new("RGBA", (2752, 1344), (0, 0, 0, 0))
n1 = scatter(plaza, rocks, 68, (0.62, 0.62, 0.60))
n2 = scatter(plaza, tufts, 34, (0.55, 0.60, 0.52))
plaza.save(OUT1 + "ground_plaza.png"); plaza.save(OUT2 + "ground_plaza.png")
print("plaza decals:", n1 + n2)

# DECK overlay 2752x560: plate seams (soft wobbly lines) + few gray rocks
deck = Image.new("RGBA", (2752, 560), (0, 0, 0, 0))
dd = ImageDraw.Draw(deck)
seam = (22, 24, 28, 110)
for i, sx in enumerate(range(-1376+344, 1376, 344)):
    px = sx + 1376
    rnd = random.Random(900 + i)
    yy = 8
    while yy < 552:
        seg = rnd.randint(60, 140)
        if rnd.random() > 0.25:
            dd.line([(px + rnd.randint(-3, 3), yy), (px + rnd.randint(-3, 3), min(552, yy + seg))],
                    fill=seam, width=4)
        yy += seg + rnd.randint(10, 30)
for j, sy in enumerate(range(140, 560, 140)):
    rnd = random.Random(950 + j)
    xx = 8
    while xx < 2744:
        seg = rnd.randint(120, 260)
        if rnd.random() > 0.3:
            dd.line([(xx, sy + rnd.randint(-3, 3)), (min(2744, xx + seg), sy + rnd.randint(-3, 3))],
                    fill=seam, width=4)
        xx += seg + rnd.randint(20, 50)
n3 = scatter(deck, rocks, 16, (0.5, 0.52, 0.56), margin=30, scale=0.8)
deck.save(OUT1 + "ground_deck.png"); deck.save(OUT2 + "ground_deck.png")
print("deck seams drawn, rocks:", n3)

# CLIFF band 2752x384 v4 - DESIGN STORY: "the deck is a scrap platform built
# over the natural rock rise". Clean straight deck-trim edge (no torn lip),
# evenly spaced support girders holding the deck up (stair openings framed by
# posts), natural rock face between beams. Patch plates removed (reused on
# the pad later).
cliff = Image.new("RGBA", (2752, 384), (34, 29, 26, 255))
cd = ImageDraw.Draw(cliff)
# natural face: strata + blotches + cracks + boulders
strata_y = 30
band = 0
rndS = random.Random(510)
while strata_y < 344:
    h = rndS.randint(52, 96)
    tone = (30, 26, 23, 255) if band % 2 == 0 else (37, 32, 28, 255)
    cd.rectangle([0, strata_y, 2752, min(344, strata_y + h)], fill=tone)
    wobble_edge(cd, 0, 2752, strata_y, 4, (26, 22, 20, 255), 3, seed=520 + band)
    strata_y += h
    band += 1
rndB = random.Random(560)
for i in range(10):
    bw = rndB.randint(180, 420); bh = rndB.randint(60, 140)
    bx = rndB.randint(-60, 2700); by = rndB.randint(50, 320 - bh)
    blotch = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blotch)
    col = (46, 40, 35, 38) if rndB.random() < 0.5 else (24, 20, 18, 42)
    bd.ellipse([0, 0, bw, bh], fill=col)
    cliff.paste(blotch, (bx, by), blotch)
rndC = random.Random(620)
crack_xs = []
for i in range(24):
    x = rndC.randint(40, 2710)
    if any(abs(x - px) < 240 for px in crack_xs):
        continue
    crack_xs.append(x)
    if len(crack_xs) >= 8:
        break
for x in crack_xs:
    y = rndC.randint(50, 170)
    ln = rndC.randint(80, 190)
    yy = y; wdt = 4
    while yy < y + ln and yy < 348:
        nx = x + rndC.randint(-6, 6)
        cd.line([(x, yy), (nx, yy + 14)], fill=(20, 17, 15, 220), width=max(2, wdt))
        if rndC.random() < 0.4:
            wdt -= 1
        x = nx; yy += 14
n4 = scatter(cliff, pure_rocks, 30, (0.46, 0.44, 0.42), margin=44, scale=1.2)
n4 += scatter(cliff, pure_rocks, 10, (0.40, 0.38, 0.36), margin=44, scale=0.8)
# occlusion shadow under the deck edge (flat 2-step, no gradient)
ov = Image.new("RGBA", (2752, 26), (0, 0, 0, 60)); cliff.paste(ov, (0, 22), ov)
ov2 = Image.new("RGBA", (2752, 12), (0, 0, 0, 50)); cliff.paste(ov2, (0, 22), ov2)
# SUPPORT GIRDERS: evenly spaced columns + posts framing the stair openings.
# world x -> texture x: tx = wx + 1376
beam_wxs = [-1226, -926, -150, 150, 926, 1226]
post_wxs = [-694, -394, 394, 694]
def draw_beam(wx, wide):
    bw = 30 if wide else 24
    x = wx + 1376 - bw // 2
    cd.rectangle([x, 18, x + bw, 372], fill=(46, 48, 52, 255))
    cd.rectangle([x, 18, x + 3, 372], fill=(28, 29, 32, 255))
    cd.rectangle([x + bw - 3, 18, x + bw, 372], fill=(24, 25, 28, 255))
    cd.rectangle([x + 5, 18, x + 8, 372], fill=(58, 60, 64, 255))
    rndR2 = random.Random(1000 + wx)
    for ry in range(40, 350, 46):
        for rx in (x + 6, x + bw - 10):
            cd.ellipse([rx, ry + rndR2.randint(-2, 2), rx + 4, ry + 4 + rndR2.randint(-2, 2)],
                       fill=(24, 24, 26, 255))
    # foot plate
    cd.rectangle([x - 6, 352, x + bw + 6, 372], fill=(40, 42, 46, 255))
    cd.rectangle([x - 6, 352, x + bw + 6, 355], fill=(56, 58, 62, 255))
for wx in beam_wxs:
    draw_beam(wx, False)
for wx in post_wxs:
    draw_beam(wx, True)
plates = 0
# CLEAN DECK-TRIM EDGE (straight, crisp - the platform's edge, no wobble)
cd.rectangle([0, 0, 2752, 22], fill=(52, 55, 62, 255))
cd.rectangle([0, 0, 2752, 3], fill=(34, 36, 41, 255))
cd.rectangle([0, 6, 2752, 9], fill=(66, 69, 76, 255))
cd.rectangle([0, 18, 2752, 22], fill=(28, 29, 33, 255))
# base contact: straight soft band (no scribble)
cd.rectangle([0, 360, 2752, 372], fill=(20, 16, 14, 255))
cd.rectangle([0, 372, 2752, 384], fill=(13, 11, 10, 255))
cliff.save(OUT1 + "ground_cliff.png"); cliff.save(OUT2 + "ground_cliff.png")
print("cliff v4 built: beams=%d posts=%d boulders=%d" % (len(beam_wxs), len(post_wxs), n4))

# plaza near-wall rubble: hugs the cliff base, avoids stair aprons and booth
# (plaza-local coords: x = world_x + 1376, wall base at plaza y 0..)
rndR = random.Random(800)
rubble = 0
tries = 0
while rubble < 26 and tries < 300:
    tries += 1
    wx = rndR.randint(-1340, 1340)
    if -700 < wx < -390 or 390 < wx < 700 or -180 < wx < 180:
        continue
    d = tint(random.choice(pure_rocks), (0.5, 0.48, 0.46))
    px = wx + 1376; py = rndR.randint(4, 44)
    plaza.paste(d, (px, py), d)
    rubble += 1
plaza.save(OUT1 + "ground_plaza.png"); plaza.save(OUT2 + "ground_plaza.png")
print("plaza rubble at wall base:", rubble)

print("DONE - bases: plaza RGB(66,61,57) deck RGB(52,55,62) set in lobby.gd")

# STAIRS 256x576 (G/FOUNDATION, procedural - walkable ground gets NO outline):
# 96 landing + 384 run of steps + 96 apron. Steps = tread band + darker riser
# shadow, soft wobbly seams, dark side rails.
def build_stairs():
    W, H = 256, 576
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    tread = (58, 61, 68, 255); riser = (30, 31, 36, 255)
    rail = (24, 22, 22, 255); rail_hi = (44, 45, 50, 255)
    dr.rectangle([0, 0, W, 96], fill=(52, 55, 62, 255))          # landing
    y = 96
    step_h = 48
    for i in range(8):                                            # 384px run
        dr.rectangle([0, y, W, y + step_h - 14], fill=tread)
        dr.rectangle([0, y + step_h - 14, W, y + step_h], fill=riser)
        wobble_edge(dr, 0, W, y + step_h - 14, 2, (20, 20, 24, 255), 3, seed=300 + i)
        y += step_h
    dr.rectangle([0, 480, W, 576], fill=(60, 55, 50, 255))        # apron: dirt
    n = scatter(im.crop((0, 480, 256, 576)), rocks, 2, (0.5, 0.5, 0.5))
    for rx in (0, W - 20):                                        # side rails
        dr.rectangle([rx, 0, rx + 20, 480], fill=rail)
        dr.rectangle([rx + 6, 0, rx + 9, 480], fill=rail_hi)
    im.save(OUT1 + "stairs.png")
    im.save(OUT2 + "stairs.png")
    mirror = im.transpose(Image.FLIP_LEFT_RIGHT)
    mirror.save(OUT1 + "stairs_e.png")
    mirror.save(OUT2 + "stairs_e.png")
    print("stairs built (west + mirrored east)")

build_stairs()
