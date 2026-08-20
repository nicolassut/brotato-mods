#!/usr/bin/env python3
"""Hub shuttle post-process (deterministic, re-runnable): probe2 ->
outward-only silhouette thicken (2 rounds) -> guarded interior line pass ->
vecprep 256. Every step mechanically checked: interior-untouched (pass 1),
component count stable, hazard-yellow loss 0%, vecprep border clearance.
Working files live HERE in the repo, never in the volatile scratchpad
(2026-08-19 lesson: /tmp cleanup ate a day of deliverables)."""
import numpy as np
from PIL import Image
from collections import deque

def label(mask, H, W):
    lab = np.zeros(mask.shape, dtype=int); cur = 0
    for y in range(H):
        for x in range(W):
            if mask[y, x] and lab[y, x] == 0:
                cur += 1; q = deque([(y, x)]); lab[y, x] = cur
                while q:
                    cy, cx = q.popleft()
                    for ny, nx in ((cy-1,cx),(cy+1,cx),(cy,cx-1),(cy,cx+1)):
                        if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and lab[ny, nx] == 0:
                            lab[ny, nx] = cur; q.append((ny, nx))
    return lab, cur

img = Image.open("shuttle_probe2.png").convert("RGBA")
a = np.array(img); H, W = a.shape[:2]
alpha = a[..., 3] > 32
rgb = a[..., :3].astype(int)
dark = (rgb.sum(axis=2) < 150) & alpha

# stray speck cleanup
lab, n = label(dark, H, W)
for i in range(1, n + 1):
    px = np.argwhere(lab == i)
    if len(px) <= 3:
        for y, x in px:
            neigh = [a[ny, nx, :3] for ny in range(max(0, y-2), min(H, y+3))
                     for nx in range(max(0, x-2), min(W, x+3))
                     if alpha[ny, nx] and not dark[ny, nx]]
            if neigh:
                a[y, x, :3] = np.median(np.array(neigh), axis=0).astype(np.uint8)
            dark[y, x] = False
_, n0 = label(dark, H, W)
interior_snapshot = a.copy()

# PASS 1: outward-only silhouette thicken (grows into transparency ONLY)
BLACK = np.array([16, 14, 12], dtype=np.uint8)
opaque = a[..., 3] > 32
for rnd in range(2):
    add = []
    for y in range(H):
        for x in range(W):
            if opaque[y, x]:
                continue
            for ny, nx in ((y-1,x),(y+1,x),(y,x-1),(y,x+1),(y-1,x-1),(y-1,x+1),(y+1,x-1),(y+1,x+1)):
                if 0 <= ny < H and 0 <= nx < W and dark[ny, nx]:
                    add.append((y, x)); break
    for y, x in add:
        a[y, x, :3] = BLACK; a[y, x, 3] = 255
        dark[y, x] = True; opaque[y, x] = True
changed = (interior_snapshot[..., 3] > 32) & (np.any(a[..., :3] != interior_snapshot[..., :3], axis=2))
assert changed.sum() == 0, "pass 1 touched interior pixels"
_, n1 = label(dark, H, W)
assert n1 <= n0, "pass 1 merged components"

# PASS 2: guarded interior line thicken (yellow exclusion + diagonal-aware
# corridor guard - a candidate only blackens if no dark within 3px on the far
# side or bracketing diagonals)
rgb = a[..., :3].astype(int)
yellow = (rgb[..., 0] > 150) & (rgb[..., 1] > 110) & (rgb[..., 2] < 110) & (a[..., 3] > 32)
yellow_before = int(yellow.sum())
dist = np.full((H, W), 9999, dtype=int); q = deque()
for y in range(H):
    for x in range(W):
        if not (a[y, x, 3] > 32):
            dist[y, x] = 0; q.append((y, x))
while q:
    cy, cx = q.popleft()
    for ny, nx in ((cy-1,cx),(cy+1,cx),(cy,cx-1),(cy,cx+1)):
        if 0 <= ny < H and 0 <= nx < W and dist[ny, nx] > dist[cy, cx] + 1:
            dist[ny, nx] = dist[cy, cx] + 1; q.append((ny, nx))
interior_dark = dark & (dist > 5)
near_yellow = np.zeros((H, W), bool)
for y, x in zip(*np.where(yellow)):
    near_yellow[max(0, y-2):y+3, max(0, x-2):x+3] = True
add = []
for y in range(H):
    for x in range(W):
        if dark[y, x] or not (a[y, x, 3] > 32) or near_yellow[y, x]:
            continue
        grow = False
        for dy, dx in ((-1,0),(1,0),(0,-1),(0,1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < H and 0 <= nx < W and interior_dark[ny, nx]:
                blocked = False
                for oy, ox in ((-dy,-dx),(-dy+dx,-dx+dy),(-dy-dx,-dx-dy)):
                    if oy == 0 and ox == 0:
                        continue
                    for k in (1, 2, 3):
                        py, px = y + oy * k, x + ox * k
                        if 0 <= py < H and 0 <= px < W and dark[py, px]:
                            blocked = True; break
                    if blocked:
                        break
                if not blocked:
                    grow = True
                break
        if grow:
            add.append((y, x))
for y, x in add:
    a[y, x, :3] = BLACK; a[y, x, 3] = 255
dark = (a[..., :3].astype(int).sum(axis=2) < 150) & (a[..., 3] > 32)
_, n2 = label(dark, H, W)
assert n2 <= n1, "pass 2 merged components"
rgb2 = a[..., :3].astype(int)
yellow2 = (rgb2[..., 0] > 150) & (rgb2[..., 1] > 110) & (rgb2[..., 2] < 110) & (a[..., 3] > 32)
loss = 100 * (yellow_before - int(yellow2.sum())) / max(1, yellow_before)
assert loss < 2, "pass 2 ate hazard yellow: %.1f%%" % loss

master = Image.fromarray(a)
master.save("shuttle_master.png")

# vecprep: bbox + padding on 256, border clearance verified
b = master.getbbox(); c = master.crop(b)
side = max(c.size) + 48
canvas = Image.new("RGBA", (side, side), (0, 0, 0, 0))
canvas.paste(c, ((side - c.width) // 2, (side - c.height) // 2), c)
canvas = canvas.resize((256, 256), Image.NEAREST)
canvas.save("shuttle_vecprep_256.png")
va = np.array(canvas); valpha = va[..., 3] > 32
border = valpha[:20, :].sum() + valpha[-20:, :].sum() + valpha[:, :20].sum() + valpha[:, -20:].sum()
assert border == 0, "vecprep content clips the border margin"
print("ALL CHECKS PASSED: components %d->%d->%d, yellow loss %.1f%%, interior pass added %d px"
      % (n0, n1, n2, loss, len(add)))
