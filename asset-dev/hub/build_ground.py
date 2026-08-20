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

def outline_paste(dst, layer, pos, r=4, color=(14, 12, 11, 255)):
    """Paste layer with a true BLACK BORDER around its silhouette (vanilla
    thick-outline law - structures are objects, not ground)."""
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

# DECK overlay 2752x560 v2 - riveted plate decking (the platform's top):
# full plate grid, per-plate FLAT tone variation, soft continuous seams with
# jittered joints, rivets along edges, sparse scuffs + debris.
deck = Image.new("RGBA", (2752, 560), (0, 0, 0, 0))
dd = ImageDraw.Draw(deck)
seam = (26, 27, 31, 150)
rivet = (30, 31, 35, 210)
rndDk = random.Random(880)
PW, PH = 344, 187
cols = 2752 // PW
rows = 3
# per-plate tone variation (flat overlays)
for r in range(rows):
    for cix in range(cols):
        tone = rndDk.randint(-4, 5)
        if tone == 0:
            continue
        col = (255, 255, 255, tone * 3) if tone > 0 else (0, 0, 0, -tone * 4)
        px, py = cix * PW, r * PH
        plate = Image.new("RGBA", (PW, PH), col)
        deck.paste(plate, (px, py), plate)
# seams: continuous, slightly jittered at joints
for cix in range(1, cols):
    x = cix * PW
    yy = 0
    while yy < 560:
        seg = rndDk.randint(120, 220)
        jx = x + rndDk.randint(-2, 2)
        dd.line([(jx, yy), (jx, min(560, yy + seg))], fill=seam, width=4)
        yy += seg
for r in range(1, rows):
    y = r * PH
    xx = 0
    while xx < 2752:
        seg = rndDk.randint(220, 420)
        jy = y + rndDk.randint(-2, 2)
        dd.line([(xx, jy), (min(2752, xx + seg), jy)], fill=seam, width=4)
        xx += seg
# rivets along plate edges (corners + midpoints, jittered)
for r in range(rows + 1):
    for cix in range(cols + 1):
        for (ox, oy) in ((10, 10), (PW - 14, 10), (10, PH - 14), (PW // 2, 12)):
            if rndDk.random() < 0.35:
                continue
            x = cix * PW + ox + rndDk.randint(-2, 2)
            y = r * PH + oy + rndDk.randint(-2, 2)
            if 4 < x < 2746 and 4 < y < 554:
                dd.ellipse([x, y, x + 5, y + 5], fill=rivet)
# scuffs: soft darker ellipses, sparse
for i in range(9):
    sw = rndDk.randint(60, 160); sh = rndDk.randint(24, 60)
    sx = rndDk.randint(30, 2700 - sw); sy = rndDk.randint(30, 520 - sh)
    sc = Image.new("RGBA", (sw, sh), (0, 0, 0, 0))
    sd2 = ImageDraw.Draw(sc)
    sd2.ellipse([0, 0, sw, sh], fill=(0, 0, 0, 22))
    deck.paste(sc, (sx, sy), sc)
# top-wall junction line
dd.rectangle([0, 0, 2752, 4], fill=(30, 31, 35, 200))
n3 = scatter(deck, pure_rocks, 12, (0.36, 0.40, 0.48), margin=30, scale=0.8)
deck.save(OUT1 + "ground_deck.png"); deck.save(OUT2 + "ground_deck.png")
print("deck v2 plated: %dx%d grid, rocks=%d" % (2752 // 344, 3, n3))

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
    ld.rectangle([bx + 4, 4, bx + 7, 368], fill=(58, 60, 64, 255))
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
    outline_paste(cliff, layer, (wx + 1376 - LW // 2, 14))
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
outline_paste(cliff, edge_layer, (0, 0))
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
    # v4 (2026-08-19 zoom review): no rivets on rails; rails WIDER and
    # OVERHANGING the 256 footprint (canvas 288, sprite centered on the rect);
    # treads drawn only BETWEEN the rails (no slivers outside); tread color =
    # exact deck base; riser-only variation.
    W, H = 320, 576
    FIELD_L, FIELD_R = 46, 278          # tread field between rail inner edges
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    dr = ImageDraw.Draw(im)
    DECK = (52, 55, 62, 255)
    riser = (33, 34, 39, 255)
    PLAZA = (66, 61, 57, 255)
    y = 96
    step_h = 48
    rndT = random.Random(360)
    for i in range(8):
        dr.rectangle([FIELD_L, y, FIELD_R, y + step_h - 10], fill=DECK)
        dr.rectangle([FIELD_L, y + step_h - 10, FIELD_R, y + step_h], fill=riser)
        wobble_edge(dr, FIELD_L, FIELD_R, y + step_h - 10, 2, (26, 27, 31, 255), 3, seed=300 + i)
        y += step_h
    dr.rectangle([FIELD_L, 480, FIELD_R, 576], fill=PLAZA)
    dr.rectangle([FIELD_L, 480, FIELD_R, 486], fill=(46, 42, 39, 255))
    n = scatter(im.crop((FIELD_L, 480, FIELD_R, 576)), pure_rocks, 2, (0.5, 0.5, 0.5))
    def rail(x):
        # RAILING ANATOMY (user 2026-08-19): a thick NEWEL POST at each end -
        # the top one protrudes ABOVE the deck edge, the bottom one protrudes
        # PAST the stair bottom onto the plaza - with the thinner FENCE RUN
        # spanning between them, elevated above the steps.
        B = (16, 14, 12, 255)
        post_w = 34
        run_w = 18
        cx = x + post_w // 2          # shared axis
        # fence run between the posts (thinner band)
        run = Image.new("RGBA", (run_w + 8, 340), (0, 0, 0, 0))
        rd = ImageDraw.Draw(run)
        rd.rectangle([4, 0, 4 + run_w, 340], fill=(46, 48, 52, 255))
        rd.rectangle([7, 0, 10, 340], fill=(58, 60, 64, 255))
        outline_paste(im, run, (cx - run_w // 2 - 4, 128))
        # TOP newel post: cap above the deck edge, body past the deck line
        top = Image.new("RGBA", (post_w + 20, 130), (0, 0, 0, 0))
        td = ImageDraw.Draw(top)
        bx = 10
        td.rectangle([bx, 14, bx + post_w, 130], fill=(46, 48, 52, 255))
        td.rectangle([bx + 5, 14, bx + 9, 130], fill=(58, 60, 64, 255))
        td.rectangle([bx - 9, 0, bx + post_w + 9, 20], fill=(52, 54, 58, 255))
        td.rectangle([bx - 9, 0, bx + post_w + 9, 6], fill=(62, 64, 68, 255))
        td.rectangle([bx - 9, 18, bx + post_w + 9, 21], fill=B)
        outline_paste(im, top, (cx - post_w // 2 - 10, 36))
        # BOTTOM newel post: protrudes past the stair bottom onto the plaza
        bot = Image.new("RGBA", (post_w + 20, 120), (0, 0, 0, 0))
        bd3 = ImageDraw.Draw(bot)
        bd3.rectangle([bx, 14, bx + post_w, 100], fill=(46, 48, 52, 255))
        bd3.rectangle([bx + 5, 14, bx + 9, 100], fill=(58, 60, 64, 255))
        bd3.rectangle([bx - 9, 0, bx + post_w + 9, 20], fill=(52, 54, 58, 255))
        bd3.rectangle([bx - 9, 0, bx + post_w + 9, 6], fill=(62, 64, 68, 255))
        bd3.rectangle([bx - 9, 18, bx + post_w + 9, 21], fill=B)
        # foot plate on the plaza
        bd3.rectangle([bx - 7, 98, bx + post_w + 7, 118], fill=(40, 42, 46, 255))
        bd3.rectangle([bx - 7, 98, bx + post_w + 7, 101], fill=B)
        outline_paste(im, bot, (cx - post_w // 2 - 10, 436))
    # ONE black edge line where the platform ends and the steps begin
    dr.rectangle([FIELD_L, 92, FIELD_R, 96], fill=(16, 14, 12, 255))
    # the staircase slab's OWN outer borders (rails now ride ON the slab)
    dr.rectangle([FIELD_L, 92, FIELD_L + 4, 480], fill=(16, 14, 12, 255))
    dr.rectangle([FIELD_R - 4, 92, FIELD_R, 480], fill=(16, 14, 12, 255))
    rail(43)
    rail(W - 77)
    # BORDER COMPLETENESS CHECK (machine-enforced black border law): every
    # opaque pixel that touches transparency must have near-black within 2px.
    # Ground-class rows (dirt apron, y>=470) are exempt.
    arr = np.array(im)
    alpha = arr[..., 3] > 60
    lum = arr[..., :3].astype(int).sum(axis=2)
    bad = []
    for yy in range(0, 470):
        for xx in range(W):
            if not alpha[yy, xx]:
                continue
            edge = False
            for ny, nx in ((yy-1,xx),(yy+1,xx),(yy,xx-1),(yy,xx+1)):
                if 0 <= ny < H and 0 <= nx < W and not alpha[ny, nx]:
                    edge = True; break
            if not edge:
                continue
            ok = False
            for dy2 in range(-2, 3):
                for dx2 in range(-2, 3):
                    ny, nx = yy+dy2, xx+dx2
                    if 0 <= ny < H and 0 <= nx < W and alpha[ny, nx] and lum[ny, nx] <= 130:
                        ok = True
            if not ok:
                bad.append((xx, yy))
    assert not bad, "BORDER LAW VIOLATION at %d px, first: %s" % (len(bad), bad[:8])
    im.save(OUT1 + "stairs.png")
    im.save(OUT2 + "stairs.png")
    mirror = im.transpose(Image.FLIP_LEFT_RIGHT)
    mirror.save(OUT1 + "stairs_e.png")
    mirror.save(OUT2 + "stairs_e.png")
    print("stairs v4 built (clean rails, overhang, exact deck tread)")



build_stairs()
