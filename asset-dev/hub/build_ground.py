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
print("extracted:", len(rocks), "dirt decals,", len(tufts), "forest decals")
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

# CLIFF band 2752x384 v3 - NATURAL rock face first (user 2026-08-19), scrap
# demoted to sparse repair patches: strata + tone blotches + vertical cracks +
# protruding boulders + hanging flora from the lip + 4-5 mixed plates.
cliff = Image.new("RGBA", (2752, 384), (34, 29, 26, 255))
cd = ImageDraw.Draw(cliff)
strata_y = 26
band = 0
rndS = random.Random(510)
while strata_y < 340:
    h = rndS.randint(44, 96)
    tone = (30, 26, 23, 255) if band % 2 == 0 else (38, 33, 29, 255)
    cd.rectangle([0, strata_y, 2752, min(340, strata_y + h)], fill=tone)
    wobble_edge(cd, 0, 2752, strata_y, rndS.randint(4, 8), (26, 22, 20, 255), 3, seed=520 + band)
    strata_y += h
    band += 1
# large soft tone blotches (organic patchiness)
rndB = random.Random(560)
for i in range(10):
    bw = rndB.randint(180, 420); bh = rndB.randint(60, 140)
    bx = rndB.randint(-60, 2700); by = rndB.randint(40, 320 - bh)
    blotch = Image.new("RGBA", (bw, bh), (0, 0, 0, 0))
    bd = ImageDraw.Draw(blotch)
    lighter = rndB.random() < 0.5
    col = (46, 40, 35, 38) if lighter else (24, 20, 18, 42)
    bd.ellipse([0, 0, bw, bh], fill=col)
    cliff.paste(blotch, (bx, by), blotch)
# vertical cracks: sparse, spread, tapered toward the bottom
rndC = random.Random(620)
crack_xs = []
for i in range(24):
    x = rndC.randint(30, 2720)
    if any(abs(x - px) < 220 for px in crack_xs):
        continue
    crack_xs.append(x)
    if len(crack_xs) >= 8:
        break
for x in crack_xs:
    y = rndC.randint(30, 160)
    ln = rndC.randint(80, 200)
    yy = y
    wdt = 4
    while yy < y + ln and yy < 350:
        nx = x + rndC.randint(-6, 6)
        cd.line([(x, yy), (nx, yy + 14)], fill=(20, 17, 15, 220), width=max(2, wdt))
        if rndC.random() < 0.4:
            wdt -= 1
        x = nx; yy += 14
# drip stains under the lip
for i in range(40):
    rndD = random.Random(600 + i)
    x = rndD.randint(10, 2740)
    ln = rndD.randint(28, 84)
    st = Image.new("RGBA", (10, ln), (0, 0, 0, 0))
    sd = ImageDraw.Draw(st)
    sd.rectangle([2, 0, 7, ln], fill=(22, 18, 16, 55))
    cliff.paste(st, (x, 26), st)
# protruding boulders: more, bigger, brighter than v2
n4 = scatter(cliff, rocks, 34, (0.46, 0.44, 0.42), margin=40, scale=1.25)
n4 += scatter(cliff, rocks, 12, (0.40, 0.38, 0.36), margin=40, scale=0.8)
# hanging flora from the lip (flipped tufts, olive-tinted)
rndF = random.Random(660)
flora = 0
for i in range(11):
    d = tint(random.choice(tufts), (0.5, 0.55, 0.45)).transpose(Image.FLIP_TOP_BOTTOM)
    x = rndF.randint(20, 2700)
    cliff.paste(d, (x, 24 + rndF.randint(0, 6)), d)
    flora += 1
# repair plates: probe decals only (flips for variety); the girder strip is
# lip reinforcement, pinned just under the overhang
probe_plates = []
for i in (0, 2):
    try:
        probe_plates.append(Image.open("plate_decal_%d.png" % i).convert("RGBA"))
    except Exception:
        pass
girder = None
try:
    girder = Image.open("plate_decal_3.png").convert("RGBA")
except Exception:
    pass
rndP = random.Random(700)
plates = 0
for cx in (380, 1120, 1760, 2420):
    if not probe_plates:
        break
    src = probe_plates[plates % len(probe_plates)]
    pp = tint(src, (0.72, 0.72, 0.72))
    if rndP.random() < 0.5:
        pp = pp.transpose(Image.FLIP_LEFT_RIGHT)
    sc = rndP.uniform(1.25, 1.75)
    pp = pp.resize((int(pp.width * sc), int(pp.height * sc)), Image.NEAREST)
    x = cx + rndP.randint(-70, 70)
    y = rndP.randint(84, 330 - pp.height)
    cliff.paste(pp, (x, y), pp)
    plates += 1
if girder is not None:
    for gx in (700, 1980):
        gg = tint(girder, (0.56, 0.57, 0.58))
        if rndP.random() < 0.5:
            gg = gg.transpose(Image.FLIP_LEFT_RIGHT)
        gg = gg.resize((int(gg.width * 1.9), int(gg.height * 1.9)), Image.NEAREST)
        cliff.paste(gg, (gx + rndP.randint(-50, 50), 30), gg)
        plates += 1
# torn overhang lip ON TOP
for tlayer, (tone, yy, th) in enumerate([((58,52,46,255), 4, 8), ((48,42,38,255), 12, 7), ((38,33,29,255), 20, 6)]):
    wobble_edge(cd, 0, 2752, yy, 9 - tlayer * 2, tone, th, seed=70 + tlayer)
# contact shadow
cd.rectangle([0, 356, 2752, 370], fill=(20, 16, 14, 255))
cd.rectangle([0, 370, 2752, 384], fill=(13, 11, 10, 255))
wobble_edge(cd, 0, 2752, 356, 5, (20, 16, 14, 255), 8, seed=140)
cliff.save(OUT1 + "ground_cliff.png"); cliff.save(OUT2 + "ground_cliff.png")
print("cliff v3 built: plates=%d boulders=%d flora=%d" % (plates, n4, flora))

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
    d = tint(random.choice(rocks), (0.5, 0.48, 0.46))
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
