# Deterministic statue bake: statue_relief_cutout.png -> in-game statue.png.
# The MONUMENT PLAQUE (user's PlatformStatue render: relief carving on a
# stone platform, white surround cropped off) is the plaza centerpiece.
from PIL import Image

TARGET_W = 340

src = Image.open("statue_plaque_cutout.png").convert("RGBA")
src = src.crop(src.getbbox())
H = round(src.height * TARGET_W / src.width)
baked = src.resize((TARGET_W, H), Image.LANCZOS)
for dst in ("../../game-src/ui/lobby/art/statue.png",
            "/Users/nicolassutcliffe/brotato-decompiled/ui/lobby/art/statue.png",
            "statue_baked.png"):
    baked.save(dst)
print("statue baked %dx%d, half_h %.1f" % (TARGET_W, H, H / 2.0))
