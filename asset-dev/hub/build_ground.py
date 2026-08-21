#!/usr/bin/env python3
"""Hub ground builder (HUB_ART_SPEC 1c): plaza/deck/cliff overlay textures in
the MEASURED vanilla ground language - flat base + sparse extracted vanilla
decals + wobbly torn edges. Deterministic (seeded); zero PixelLab credits.
Outputs land in game-src/ui/lobby/art/ and the live tree."""
import numpy as np, random, os, math
from PIL import Image, ImageDraw, ImageChops, ImageFilter
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

def outline_paste(dst, layer, pos, r=4, color=(14, 12, 11, 255), allow_clip=False):
    """Paste layer with a true BLACK BORDER around its silhouette (vanilla
    thick-outline law - structures are objects, not ground). Asserts the
    outlined result fits inside dst: edge clipping was the root cause of
    every missing-border bug, so it fails loudly instead of shipping."""
    assert allow_clip or (pos[0] - r >= 0 and pos[1] - r >= 0
            and pos[0] + layer.width + r <= dst.width
            and pos[1] + layer.height + r <= dst.height), \
        "outline CLIPS at dst edge: pos=%s layer=%s dst=%s" % (pos, layer.size, dst.size)
    mask = layer.split()[3].point(lambda v: 255 if v > 60 else 0)
    black = Image.new("RGBA", layer.size, color)
    for dx in range(-r, r + 1):
        for dy in range(-r, r + 1):
            if dx * dx + dy * dy <= r * r:
                dst.paste(black, (pos[0] + dx, pos[1] + dy), mask)
    dst.paste(layer, pos, layer)


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

# DECK overlay 2752x560 v3 - SMOOTH ROCK SLABS (user 2026-08-21: the deck
# is a stone platform held by stone pillars; metal plates retired). Dressed
# slab courses + the approved crack/moss system from deck_crack_proto.py
# (tapered branching cracks with lit left rim, pits hugging cracks, vanilla
# moss-set tufts growing from cracks/seams, chipped corners). The shuttle
# pad zone stays a flat recessed placeholder for the future launch-pad art.
import sys as _sys
_sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import deck_crack_proto as dcp

deck = Image.new("RGBA", (2752, 560), (52, 55, 62, 255))
dd = ImageDraw.Draw(deck)
rndDk = random.Random(880)
dcp.slabs(dd, 2752, 560, 880)
PAD = (1096, 0, 1656, 384)   # SHUTTLE_PAD_RECT in deck coords
def in_pad(x, y, m=30):
    return PAD[0]-m < x < PAD[2]+m and PAD[1]-m < y < PAD[3]+m
n_cracks = 0
tries = 0
while n_cracks < 16 and tries < 200:
    tries += 1
    x, y = rndDk.randint(40, 2712), rndDk.randint(30, 530)
    if in_pad(x, y, 70):
        continue
    ang = rndDk.uniform(0, 2 * math.pi)
    pts = dcp.crack_path(rndDk, x, y, ang, rndDk.randint(7, 13), rndDk.randint(9, 16))
    if any(in_pad(px, py) for (px, py) in pts):
        continue
    dcp.draw_crack(dd, pts, rndDk.uniform(4.0, 6.0))
    for _ in range(rndDk.randint(1, 2)):
        bi = rndDk.randint(2, len(pts) - 3)
        bang = math.atan2(pts[bi+1][1]-pts[bi][1], pts[bi+1][0]-pts[bi][0]) + rndDk.choice([-1.4, 1.4])
        bpts = dcp.crack_path(rndDk, pts[bi][0], pts[bi][1], bang, rndDk.randint(3, 6), rndDk.randint(7, 12))
        dcp.draw_crack(dd, bpts, rndDk.uniform(1.6, 2.6))
    for _ in range(rndDk.randint(1, 2)):
        p = pts[rndDk.randint(1, len(pts) - 2)]
        dcp.spall(dd, rndDk, p[0] + rndDk.randint(-7, 7), p[1] + rndDk.randint(-7, 7))
    if rndDk.random() < 0.7:
        p = pts[rndDk.randint(1, len(pts) - 2)]
        dcp.moss_tuft(deck, rndDk, p[0], p[1] + 3, big=True)
    n_cracks += 1
for _ in range(22):
    row_y = rndDk.randint(1, 560 // 78) * 78
    mx = rndDk.randint(30, 2722)
    if not in_pad(mx, row_y):
        dcp.moss_tuft(deck, rndDk, mx, row_y + 2)
for _ in range(12):
    row_y = rndDk.randint(1, 560 // 78) * 78
    cx2 = rndDk.randint(40, 2712)
    if not in_pad(cx2, row_y - 74):
        dcp.chip_corner(dd, rndDk, cx2, row_y - 74)
# shuttle pad: flat recessed placeholder (future launch-pad art drops here)
dd.rectangle([PAD[0]-4, PAD[1], PAD[2]+4, PAD[3]+4], fill=(16, 14, 12, 255))
dd.rectangle([PAD[0], PAD[1], PAD[2], PAD[3]], fill=(48, 48, 41, 255))
dd.rectangle([PAD[0], PAD[3]-6, PAD[2], PAD[3]], fill=(40, 40, 34, 255))
# top-wall junction line
dd.rectangle([0, 0, 2752, 4], fill=(30, 31, 35, 200))
deck.save(OUT1 + "ground_deck.png"); deck.save(OUT2 + "ground_deck.png")
print("deck v3 stone slabs: cracks=%d" % n_cracks)

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
# base contact: thin darker-rock band UNDER the beams (not a black bar -
# 2026-08-19 user: the old full-width band boxed the whole texture)
cd.rectangle([0, 372, 2752, 384], fill=(24, 20, 18, 255))
cd.rectangle([0, 380, 2752, 384], fill=(18, 15, 13, 255))
# SUPPORT GIRDERS: evenly spaced columns + posts framing the stair openings.
# world x -> texture x: tx = wx + 1376
beam_wxs = [-1226, -926, -150, 150, 926, 1226]
post_wxs = [-742, -346, 346, 742]
def draw_beam(wx, wide):
    bw = 30 if wide else 24
    LW = bw + 20
    layer = Image.new("RGBA", (LW, 372), (0, 0, 0, 0))
    ld = ImageDraw.Draw(layer)
    bx = 10
    ld.rectangle([bx, 4, bx + bw, 368], fill=(46, 48, 52, 255))
    ld.rectangle([bx + 3, 4, bx + 8, 368], fill=(58, 60, 64, 255))
    # cylindrical shading (the pillars are ROUND): dark band on the right
    ld.rectangle([bx + bw - 6, 4, bx + bw, 368], fill=(34, 36, 40, 255))
    # rivet holes (the PILLARS keep them - user 2026-08-19)
    rndR2 = random.Random(1000 + wx)
    for ry in range(44, 336, 46):
        for rx in (bx + 5, bx + bw - 9):
            ld.ellipse([rx, ry + rndR2.randint(-2, 2), rx + 4, ry + 4 + rndR2.randint(-2, 2)],
                       fill=(26, 26, 28, 255))
    ld.rectangle([bx - 7, 4, bx + bw + 7, 26], fill=(40, 42, 46, 255))
    ld.rectangle([bx - 7, 4, bx + bw + 7, 8], fill=(56, 58, 62, 255))
    ld.rectangle([bx - 7, 24, bx + bw + 7, 27], fill=(16, 14, 12, 255))
    ld.rectangle([bx - 7, 346, bx + bw + 7, 368], fill=(40, 42, 46, 255))
    ld.rectangle([bx - 7, 346, bx + bw + 7, 350], fill=(56, 58, 62, 255))
    ld.rectangle([bx - 7, 343, bx + bw + 7, 346], fill=(16, 14, 12, 255))
    outline_paste(cliff, layer, (wx + 1376 - LW // 2, 14), allow_clip=True)
    # connected cast shadow (v11, user-approved for the cliff pillars):
    # the pillar SILHOUETTE shifted right 14px minus itself
    m = layer.split()[3].point(lambda v: 255 if v > 0 else 0)
    base_m = Image.new("L", (LW + 14, 372), 0); base_m.paste(m, (0, 0))
    shift_m = Image.new("L", (LW + 14, 372), 0); shift_m.paste(m, (14, 0))
    shm = ImageChops.subtract(shift_m, base_m)
    sh_layer = Image.new("RGBA", (LW + 14, 372), (0, 0, 0, 0))
    sh_layer.paste(Image.new("RGBA", (LW + 14, 372), (0, 0, 0, 70)), (0, 0), shm)
    sh_layer = sh_layer.crop((0, 0, LW + 14, 370))
    cliff.alpha_composite(sh_layer, (wx + 1376 - LW // 2, 14))
for wx in beam_wxs:
    draw_beam(wx, False)
for wx in post_wxs:
    draw_beam(wx, True)
plates = 0
# DECK-EDGE BAR: outlined horizontal member in the SAME metal recipe as the
# pillars (body 46,48,52 + highlight + uniform black border) - it is the top
# chord the pillars bolt to
edge_layer = Image.new("RGBA", (2752, 20), (0, 0, 0, 0))
eld = ImageDraw.Draw(edge_layer)
eld.rectangle([0, 3, 2752, 17], fill=(46, 48, 52, 255))
eld.rectangle([0, 5, 2752, 8], fill=(58, 60, 64, 255))
outline_paste(cliff, edge_layer, (0, 0), allow_clip=True)
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

# NORTH WALL 2752x194 (W2, user pick 2026-08-21): natural rock face framed
# into panels by riveted metal ribs (the pillar recipe) - the deck's back
# wall. Cap lip on top (walkable edge), black base line + 14px contact
# shadow that overhangs onto the deck slabs below.
WALL_W, FACE_H, CAP_H, SH_H = 2752, 150, 30, 14
wall = Image.new("RGBA", (WALL_W, FACE_H + CAP_H + SH_H), (0, 0, 0, 0))
wd = ImageDraw.Draw(wall)
rndW = random.Random(777)
W_FACE = (42, 44, 51, 255)
W_FACE_D = (36, 38, 44, 255)
W_FACE_DD = (31, 33, 38, 255)
wd.rectangle([0, 0, WALL_W, CAP_H + FACE_H], fill=W_FACE)
wd.rectangle([0, 0, WALL_W, CAP_H], fill=(58, 61, 69, 255))
wd.rectangle([0, 0, WALL_W, 5], fill=(66, 70, 78, 255))
wd.rectangle([0, CAP_H - 4, WALL_W, CAP_H], fill=(16, 14, 12, 255))
# rock blotches (cliff language)
for _ in range(180):
    bw2, bh2 = rndW.randint(40, 130), rndW.randint(14, 34)
    bx2 = rndW.randint(-20, WALL_W - 20)
    by2 = CAP_H + rndW.randint(2, FACE_H - 30)
    blot = Image.new("RGBA", (bw2, bh2), (0, 0, 0, 0))
    ImageDraw.Draw(blot).ellipse([0, 0, bw2, bh2],
        fill=rndW.choice([(38, 40, 46, 60), (34, 36, 42, 55), (47, 49, 56, 45)]))
    wall.alpha_composite(blot, (bx2, by2))
for yy in (CAP_H + 46, CAP_H + 96):
    xx = 0
    while xx < WALL_W:
        seg = rndW.randint(120, 260)
        jy = yy + rndW.randint(-4, 4)
        wd.line([(xx, jy), (min(WALL_W, xx + seg), jy)], fill=W_FACE_DD, width=3)
        xx += seg
for _ in range(10):
    pts = dcp.crack_path(rndW, rndW.randint(60, WALL_W - 60), CAP_H + rndW.randint(8, 40),
                         math.pi / 2 + rndW.uniform(-0.6, 0.6), rndW.randint(4, 7), rndW.randint(8, 12))
    dcp.draw_crack(wd, pts, rndW.uniform(2.0, 3.5))
for rx in range(90, WALL_W, 200):
    rxj = rx + rndW.randint(-14, 14)
    wd.rectangle([rxj - 13, CAP_H - 4, rxj + 13, CAP_H + FACE_H], fill=(16, 14, 12, 255))
    wd.rectangle([rxj - 10, CAP_H - 2, rxj + 10, CAP_H + FACE_H], fill=(46, 48, 52, 255))
    wd.rectangle([rxj - 8, CAP_H - 2, rxj - 4, CAP_H + FACE_H], fill=(58, 60, 64, 255))
    wd.rectangle([rxj + 5, CAP_H - 2, rxj + 10, CAP_H + FACE_H], fill=(34, 36, 40, 255))
    for ry in range(CAP_H + 14, CAP_H + FACE_H - 8, 34):
        wd.ellipse([rxj - 2, ry, rxj + 3, ry + 5], fill=(26, 26, 28, 255))
for _ in range(16):
    dcp.moss_tuft(wall, rndW, rndW.randint(20, WALL_W - 20), CAP_H + rndW.choice([48, 98]) + 2)
wd.rectangle([0, CAP_H + FACE_H - 4, WALL_W, CAP_H + FACE_H], fill=(16, 14, 12, 255))
wall.alpha_composite(Image.new("RGBA", (WALL_W, SH_H), (0, 0, 0, 60)), (0, CAP_H + FACE_H))
wall.save(OUT1 + "wall_north.png"); wall.save(OUT2 + "wall_north.png")
print("north wall W2 built: %dx%d" % (WALL_W, FACE_H + CAP_H + SH_H))

# STAIRS 256x576 (G/FOUNDATION, procedural - walkable ground gets NO outline):
# 96 landing + 384 run of steps + 96 apron. Steps = tread band + darker riser
# shadow, soft wobbly seams, dark side rails.
def build_stairs():
    # v4 (2026-08-19 zoom review): no rivets on rails; rails WIDER and
    # OVERHANGING the 256 footprint (canvas 288, sprite centered on the rect);
    # treads drawn only BETWEEN the rails (no slivers outside); tread color =
    # exact deck base; riser-only variation.
    W, H = 320, 720   # canvas hangs 144px past the 576 rect (lobby top-aligns it)
    FIELD_L, FIELD_R = 46, 274          # tread field between rail inner edges
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    DECK = (52, 55, 62, 255)
    riser = (33, 34, 39, 255)
    PLAZA = (66, 61, 57, 255)
    y = 96
    step_h = 48
    rndT = random.Random(360)
    # STEP DEPTH + BORDER LAW ON STEPS (2026-08-20): every color
    # separation gets a black line, so each step is nose / tread / BLACK /
    # riser / BLACK. The value ramp STARTS AT EXACTLY THE DECK COLOR
    # (f=1.0) and the first tread has no nose line - the deck flows
    # seamlessly onto the staircase, the first separation is the first
    # riser. Straight lines: this is constructed metal, not dirt.
    B3 = (16, 14, 12, 255)
    # 12 steps: the last FOUR land past the cliff base onto the plaza -
    # the staircase visibly protrudes from the cliff face (a stair cannot
    # occupy the plane of a vertical wall)
    for i in range(12):
        f = 1.0 - i * 0.02
        tread_c = (int(52 * f), int(55 * f), int(62 * f), 255)
        nose_c = (int(52 * f * 1.22), int(55 * f * 1.22), int(62 * f * 1.18), 255)
        rf = 1.0 - i * 0.010
        riser_c = (int(33 * rf), int(34 * rf), int(39 * rf), 255)
        if i > 0:
            dr.rectangle([FIELD_L, y, FIELD_R, y + 3], fill=nose_c)
            dr.rectangle([FIELD_L, y + 3, FIELD_R, y + step_h - 16], fill=tread_c)
        else:
            dr.rectangle([FIELD_L, y, FIELD_R, y + step_h - 16], fill=tread_c)
        dr.rectangle([FIELD_L, y + step_h - 16, FIELD_R, y + step_h - 13], fill=B3)
        dr.rectangle([FIELD_L, y + step_h - 13, FIELD_R, y + step_h - 3], fill=riser_c)
        dr.rectangle([FIELD_L, y + step_h - 3, FIELD_R, y + step_h], fill=B3)
        y += step_h

    def rail(cx):
        # RAILING v11: members assemble on their own layer; the cast shadow
        # is the assembly SILHOUETTE shifted right 14px minus itself, so the
        # post/pole steps CONNECT seamlessly (light-from-left law). Members
        # are shaded as CYLINDERS: left highlight band, dark right band.
        B = (16, 14, 12, 255)
        asm = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        def block(by, tall):
            blk = Image.new("RGBA", (46, tall), (0, 0, 0, 0))
            bd4 = ImageDraw.Draw(blk)
            bd4.rectangle([0, 10, 45, tall - 1], fill=(46, 48, 52, 255))
            bd4.rectangle([4, 10, 11, tall - 1], fill=(58, 60, 64, 255))
            bd4.rectangle([34, 10, 45, tall - 1], fill=(34, 36, 40, 255))
            bd4.rectangle([0, 0, 45, 14], fill=(56, 58, 62, 255))
            bd4.rectangle([0, 12, 45, 15], fill=B)
            outline_paste(asm, blk, (cx - 23, by))
        # top newel: base flush with the stair top edge (96)
        block(8, 88)
        # ONE solid pole, a touch darker than the pillar metal, cylindrical
        run_w, run_h = 28, 560
        run = Image.new("RGBA", (run_w, run_h), (42, 44, 48, 255))
        rd = ImageDraw.Draw(run)
        rd.rectangle([2, 0, 7, run_h], fill=(52, 54, 58, 255))
        rd.rectangle([21, 0, 27, run_h], fill=(30, 32, 36, 255))
        outline_paste(asm, run, (cx - run_w // 2, 26), r=3)
        # bottom newel: base at the stair FOOT, two steps out on the plaza
        block(572, 96)
        # shadows (user 2026-08-20, take 3): the POLE keeps its cast strip
        # on the treads (that read was fine) - but the CORNER POSTS are
        # STANDING pillars, so their shadow POOLS AT THE FOOT only, same
        # language as the cliff pillars. A full-height post shadow reads as
        # the post lying on its side.
        run_m = Image.new("L", (W, H), 0)
        run_m.paste(run.split()[3].point(lambda v: 255 if v > 0 else 0),
                    (cx - run_w // 2, 26))
        # the pole's shadow continues to the stair FOOT - the pole itself
        # tucks behind the bottom post, but its shadow must not gap there
        ImageDraw.Draw(run_m).rectangle(
            [cx - run_w // 2, 548, cx - run_w // 2 + run_w - 1, 662], fill=255)
        run_m = run_m.filter(ImageFilter.MaxFilter(7))   # include the outline
        asm_m = asm.split()[3].point(lambda v: 255 if v > 0 else 0)
        shifted = Image.new("L", (W, H), 0)
        shifted.paste(run_m, (14, 0))
        shm = ImageChops.subtract(shifted, asm_m)
        sh_layer = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        sh_layer.paste(Image.new("RGBA", (W, H), (0, 0, 0, 90)), (0, 0), shm)
        im.alpha_composite(sh_layer)
        # post shadows: lower half of each post, ROUNDED, grounded a touch
        # past the base (user 2026-08-20)
        for (py0, pbase) in ((8, 96), (572, 668)):
            sy = py0 + (pbase - py0) // 2
            ph = pbase - sy + 6
            # flush edge where the shadow meets the post (it emanates from
            # it) - rounding only on the OUTER corners, drawn off-canvas on
            # the post side
            psh = Image.new("RGBA", (22, ph), (0, 0, 0, 0))
            ImageDraw.Draw(psh).rounded_rectangle([-12, 0, 21, ph - 1], 9, fill=(0, 0, 0, 90))
            im.alpha_composite(psh, (cx + 26, sy))
        im.alpha_composite(asm)
    rail(60)
    rail(W - 60)
    im.save(OUT1 + "stairs.png")
    im.save(OUT2 + "stairs.png")
    im.save(OUT1 + "stairs_e.png")
    im.save(OUT2 + "stairs_e.png")
    print("stairs v4 built (clean rails, overhang, exact deck tread)")



build_stairs()
