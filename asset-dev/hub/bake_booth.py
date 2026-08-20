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

cx = (sx0 + sx1 + 1) / 2.0 - W / 2.0
cy = (sy0 + sy1 + 1) / 2.0 - TARGET_H
print("baked %dx%d" % (W, TARGET_H))
print("BOOTH_SCREEN_OFFSET = Vector2(%d, %d)" % (round(cx), round(cy)))
print("BOOTH_SCREEN_SIZE = Vector2(%d, %d)" % (sw, sh))
print("body base: x %d..%d (width %d) -> wall Rect2(base_x %+d, w %d)" % (bx0, bx1, body_w, bx0 - W // 2, body_w))
print("half_h = %.1f" % (TARGET_H / 2.0))
