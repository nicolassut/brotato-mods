# Deterministic statue bake: statue_relief_cutout.png -> in-game statue.png.
# The MONUMENT PLAQUE (user's Statuemoss render: degraded mossy relief on
# its stone platform, white surround cropped off) is the plaza centerpiece.
from PIL import Image

TARGET_W = 340

src = Image.open("statue_plaque_cutout.png").convert("RGBA")
src = src.crop(src.getbbox())
H = round(src.height * TARGET_W / src.width)
baked = src.resize((TARGET_W, H), Image.LANCZOS)
# BORDER THICKENING (user 2026-08-20: a couple px thicker): OUTER rim only
# - a 2px black dilate-under ring around the silhouette. Interior cracks and
# moss detail stay untouched (growing every dark line fused the cracks into
# black webs).
import numpy as np
from PIL import ImageFilter
a = np.array(baked)
alpha = a[..., 3] > 128
sil = np.array(Image.fromarray(alpha.astype(np.uint8) * 255).filter(ImageFilter.MaxFilter(5))) > 0
ring = sil & ~alpha
a[ring] = (16, 14, 12, 255)
baked = Image.fromarray(a)
for dst in ("../../game-src/ui/lobby/art/statue.png",
            "/Users/nicolassutcliffe/brotato-decompiled/ui/lobby/art/statue.png",
            "statue_baked.png"):
    baked.save(dst)
print("statue baked %dx%d, half_h %.1f" % (TARGET_W, H, H / 2.0))
