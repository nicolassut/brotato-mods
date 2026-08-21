# Bake the OFF DUTY corner props to in-game sizes (2026-08-21).
# Sources: raw/prop_*.png (PixelLab) + offduty/*.png (procedural/vanilla).
# Installs flat-named textures to ui/lobby/art/ in BOTH trees.
from PIL import Image
import numpy as np
import os

HERE = os.path.dirname(os.path.abspath(__file__))
DST1 = os.path.join(HERE, "../../game-src/ui/lobby/art/")
DST2 = os.path.expanduser("~/brotato-decompiled/ui/lobby/art/")

# name -> (source, target world width)
PROPS = {
    "od_dartboard": ("raw/prop_dartboard.png", 64),
    "od_cooler":    ("raw/prop_cooler.png", 60),
    "od_lantern":   ("raw/prop_lantern.png", 40),
    "od_radio":     ("raw/prop_radio.png", 56),
    "od_dice":      ("raw/prop_dice.png", 48),
    "od_bottles":   ("raw/prop_bottles.png", 52),
    "od_cookpot":   ("raw/prop_cookpot.png", 90),
    "od_plant":     ("raw/prop_plant.png", 52),
    "od_skewers":   ("raw/prop_skewers.png", 80),
    "od_hammock":   ("raw/prop_hammock.png", 190),
    "od_crate":     ("raw/prop_crate3.png", 70),
    "od_rug":       ("offduty/rug.png", 260),
    "od_scorch":    ("offduty/scorch.png", 96),
    "od_tally":     ("offduty/tally.png", 120),
    "od_sign":      ("raw/prop_sign2.png", 130),
    "od_crate2":    ("raw/prop_crate_tall.png", 62),
    "od_barrel":    ("raw/prop_barrel.png", 56),
    "od_cards":     ("offduty/cards.png", 64),
    "od_chips":     ("offduty/chips.png", 40),
}


def recolor_plant(im):
    # tie the plant to the palette: terracotta -> clay brown, leaves ->
    # deck-moss olive (user note 2026-08-21)
    a = np.array(im).astype(float)
    r, g, b = a[..., 0], a[..., 1], a[..., 2]
    vis = a[..., 3] > 50
    potm = vis & (r > g + 20) & (r > 90)          # terracotta
    a[..., 0] = np.where(potm, r * 0.62, a[..., 0])
    a[..., 1] = np.where(potm, g * 0.72, a[..., 1])
    a[..., 2] = np.where(potm, b * 0.75, a[..., 2])
    leafm = vis & (g > r) & (g > 70)              # leaves
    a[..., 0] = np.where(leafm, r * 0.95, a[..., 0])
    a[..., 1] = np.where(leafm, g * 0.82, a[..., 1])
    a[..., 2] = np.where(leafm, b * 0.55, a[..., 2])
    np.clip(a, 0, 255, out=a)
    return Image.fromarray(a.astype(np.uint8))


for name, (src, tw) in PROPS.items():
    im = Image.open(os.path.join(HERE, src)).convert("RGBA")
    im = im.crop(im.getbbox())
    if name == "od_plant":
        im = recolor_plant(im)
    if im.width != tw:
        th = round(im.height * tw / im.width)
        im = im.resize((tw, th), Image.LANCZOS)
    for dst in (DST1, DST2):
        im.save(os.path.join(dst, name + ".png"))
    print("%-14s %dx%d" % (name, im.width, im.height))
print("off duty props baked:", len(PROPS))
