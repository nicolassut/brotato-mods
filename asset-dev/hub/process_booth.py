# Deterministic booth post-process: raw/booth_gen_c.png -> booth_master.png
# (2026-08-20). Recipe (v4, user-approved direction: thicken ALL lines):
#   1. pad 24px (grow-before-crop law)
#   2. interior lines: dark mask (lum<=70) -> DROP components <30px (kills
#      checker-dither cells so they don't fuse) -> MaxFilter(3) -> paint
#      black only inside the silhouette and never over highlights (lum>=200,
#      protects marquee bulbs + screen glare)
#   3. outer border: silhouette MaxFilter(7) black under-layer
# Hard asserts: median edge outline >= 5px, zero interior alpha holes.
from PIL import Image, ImageFilter
import numpy as np
import statistics
from collections import deque

src = Image.open("raw/booth_gen_c.png").convert("RGBA")
pad = 24
im = Image.new("RGBA", (src.width + pad * 2, src.height + pad * 2), (0, 0, 0, 0))
im.alpha_composite(src, (pad, pad))
a = np.array(im)
alpha = a[..., 3] > 40
lum = a[..., :3].astype(int).max(axis=2)
dark = alpha & (lum <= 70)

H, W = dark.shape
seen = np.zeros_like(dark, dtype=bool)
linemask = np.zeros_like(dark, dtype=bool)
for y in range(H):
    for x in range(W):
        if dark[y, x] and not seen[y, x]:
            q = deque([(y, x)]); seen[y, x] = True; comp = [(y, x)]
            while q:
                cy, cx = q.popleft()
                for ny, nx in ((cy - 1, cx), (cy + 1, cx), (cy, cx - 1), (cy, cx + 1)):
                    if 0 <= ny < H and 0 <= nx < W and dark[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx)); comp.append((ny, nx))
            if len(comp) >= 30:
                for (cy, cx) in comp:
                    linemask[cy, cx] = True

lm = Image.fromarray(linemask.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(3))
paint = (np.array(lm) > 0) & alpha & (lum < 200)
out = im.copy()
black = Image.new("RGBA", im.size, (16, 14, 12, 255))
out.paste(black, (0, 0), Image.fromarray(paint.astype(np.uint8) * 255))
sil = Image.fromarray(alpha.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(7))
final = Image.new("RGBA", im.size, (0, 0, 0, 0))
final.paste(black, (0, 0), sil)
final.alpha_composite(out)

# --- verification gates ---
fa = np.array(final)
falpha = fa[..., 3] > 40
flum = fa[..., :3].astype(int).max(axis=2)
fdark = falpha & (flum <= 70)
runs = []
for y in range(0, final.height, 5):
    xs = np.where(falpha[y])[0]
    if len(xs) == 0:
        continue
    x = xs[0]; run = 0
    while x < final.width and fdark[y, x]:
        run += 1; x += 1
    if run:
        runs.append(run)
med = statistics.median(runs)
assert med >= 5, "edge outline too thin: median %s" % med
outside = np.zeros_like(falpha, dtype=bool)
q = deque([(0, 0)]); outside[0, 0] = True
while q:
    y, x = q.popleft()
    for ny, nx in ((y - 1, x), (y + 1, x), (y, x - 1), (y, x + 1)):
        if 0 <= ny < final.height and 0 <= nx < final.width and not falpha[ny, nx] and not outside[ny, nx]:
            outside[ny, nx] = True; q.append((ny, nx))
holes = ((~falpha) & (~outside)).sum()
assert holes == 0, "interior alpha holes: %d" % holes

final = final.crop(final.getbbox())
final.save("booth_master.png")
print("booth_master.png %dx%d, edge median %dpx, holes 0 - OK" % (final.width, final.height, med))
