# Deterministic booth bake: booth_vector_master.png -> in-game booth.png +
# static frames. Prints the lobby.gd constants (screen offset/size, base
# band) so a size change is one edit here + consts paste there.
# History: 333 tall (1.3x, 2026-08-20) -> 300 tall (user: 10% smaller).
from PIL import Image
import numpy as np

TARGET_H = 300

vm = Image.open("booth_vector_master.png").convert("RGBA")
W = round(vm.width * TARGET_H / vm.height)
baked = vm.resize((W, TARGET_H), Image.LANCZOS)
a = np.array(baked)
r, g, b = a[..., 0].astype(int), a[..., 1].astype(int), a[..., 2].astype(int)
blue = (a[..., 3] > 128) & (b > 120) & (b > r + 40) & (b > g + 20)
ys, xs = np.where(blue)
sx0, sx1, sy0, sy1 = int(xs.min()), int(xs.max()), int(ys.min()), int(ys.max())
a[blue] = (28, 32, 36, 255)
out = Image.fromarray(a)
for dst in ("../../game-src/ui/lobby/art/booth.png",
            "/Users/nicolassutcliffe/brotato-decompiled/ui/lobby/art/booth.png",
            "booth_baked.png"):
    out.save(dst)

# body width at the base (bottom 8 rows) for an ACCURATE base-band hitbox
alpha = a[..., 3] > 128
base_cols = np.where(alpha[TARGET_H - 8:TARGET_H].any(axis=0))[0]
bx0, bx1 = int(base_cols.min()), int(base_cols.max())
body_w = bx1 - bx0 + 1

sw, sh = sx1 - sx0 + 1, sy1 - sy0 + 1
rng = np.random.RandomState(7)
for i in range(2):
    n = rng.randint(0, 2, (sh, sw)).astype(np.uint8)
    fr = np.zeros((sh, sw, 4), np.uint8)
    fr[..., 0] = fr[..., 1] = fr[..., 2] = 60 + n * 150
    fr[..., 3] = 255
    st = Image.fromarray(fr)
    st.save("booth_static_%d.png" % i)
    st.save("../../game-src/ui/lobby/art/booth_static_%d.png" % i)
    st.save("/Users/nicolassutcliffe/brotato-decompiled/ui/lobby/art/booth_static_%d.png" % i)

# object shadows (user 2026-08-20): booth casts a SUBTLE shadow to its
# right matching its shape (silhouette at alpha 55, offset applied in
# lobby.gd); the shuttle gets a decent ground ellipse under the ship.
sil = a[..., 3] > 128
shadow_img = np.zeros((TARGET_H, W, 4), np.uint8)
shadow_img[sil] = (0, 0, 0, 55)
for dst in ("../../game-src/ui/lobby/art/booth_shadow.png",
            "/Users/nicolassutcliffe/brotato-decompiled/ui/lobby/art/booth_shadow.png",
            "booth_shadow.png"):
    Image.fromarray(shadow_img).save(dst)
from PIL import ImageDraw
ell = Image.new("RGBA", (160, 44), (0, 0, 0, 0))
ImageDraw.Draw(ell).ellipse([0, 0, 159, 43], fill=(0, 0, 0, 70))
for dst in ("../../game-src/ui/lobby/art/shuttle_shadow.png",
            "/Users/nicolassutcliffe/brotato-decompiled/ui/lobby/art/shuttle_shadow.png",
            "shuttle_shadow.png"):
    ell.save(dst)

# MARQUEE CHASE LIGHTS (user 2026-08-20): two overlay frames - frame A has
# every odd bulb off, frame B every even bulb off; lobby flips them twice a
# second. Bulbs = small bright-yellow components on the marquee (y<115).
from collections import deque
bulbmask = (a[..., 3] > 128) & (a[..., 0] > 235) & (a[..., 1] > 235) & (a[..., 2] > 170)
bulbmask[115:, :] = False
seen = np.zeros_like(bulbmask, dtype=bool)
comps = []
for yy in range(115):
    for xx in range(W):
        if bulbmask[yy, xx] and not seen[yy, xx]:
            q = deque([(yy, xx)]); seen[yy, xx] = True; comp = [(yy, xx)]
            while q:
                cy2, cx2 = q.popleft()
                for ny, nx in ((cy2-1, cx2), (cy2+1, cx2), (cy2, cx2-1), (cy2, cx2+1)):
                    if 0 <= ny < 115 and 0 <= nx < W and bulbmask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx)); comp.append((ny, nx))
            if 3 <= len(comp) <= 80:
                comps.append(comp)
# order bulbs ALONG THE STRING (nearest-neighbor chain from the leftmost
# bulb) so on/off truly alternates one-by-one along the trim - a plain
# x-sort interleaves the crown edges with the bottom row and clumps states
cents = [(sum(p[1] for p in c) / len(c), sum(p[0] for p in c) / len(c)) for c in comps]
used = [False] * len(comps)
cur = min(range(len(comps)), key=lambda i: (cents[i][0], cents[i][1]))
order = []
for _ in range(len(comps)):
    order.append(cur); used[cur] = True
    nxt, best = None, None
    for j in range(len(comps)):
        if not used[j]:
            d = (cents[j][0] - cents[cur][0]) ** 2 + (cents[j][1] - cents[cur][1]) ** 2
            if best is None or d < best:
                best, nxt = d, j
    if nxt is None:
        break
    cur = nxt
comps = [comps[i] for i in order]
assert len(comps) >= 12, "found only %d bulbs" % len(comps)
frames = [np.zeros((TARGET_H, W, 4), np.uint8), np.zeros((TARGET_H, W, 4), np.uint8)]
for i, comp in enumerate(comps):
    fr = frames[i % 2]
    for (py, px) in comp:
        r0, g0, b0 = a[py, px, 0], a[py, px, 1], a[py, px, 2]
        fr[py, px] = (int(r0 * 0.30), int(g0 * 0.28), int(b0 * 0.25), 255)
for i, name in enumerate(("booth_bulbs_a.png", "booth_bulbs_b.png")):
    img = Image.fromarray(frames[i])
    img.save(name)
    img.save("../../game-src/ui/lobby/art/" + name)
    img.save("/Users/nicolassutcliffe/brotato-decompiled/ui/lobby/art/" + name)
print("bulbs found: %d (chase frames written)" % len(comps))

cx = (sx0 + sx1 + 1) / 2.0 - W / 2.0
cy = (sy0 + sy1 + 1) / 2.0 - TARGET_H
print("baked %dx%d" % (W, TARGET_H))
print("BOOTH_SCREEN_OFFSET = Vector2(%d, %d)" % (round(cx), round(cy)))
print("BOOTH_SCREEN_SIZE = Vector2(%d, %d)" % (sw, sh))
print("body base: x %d..%d (width %d) -> wall Rect2(base_x %+d, w %d)" % (bx0, bx1, body_w, bx0 - W // 2, body_w))
print("half_h = %.1f" % (TARGET_H / 2.0))
