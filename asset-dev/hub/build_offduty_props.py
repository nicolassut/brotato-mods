# OFF DUTY corner - procedural props + vanilla reuse (2026-08-21).
# Free pieces per HUB_PLAN 4c art sources: seat crate (vanilla item_box,
# gem painted out), parachute-scrap rug, scorch mark, tally graffiti,
# OFF DUTY sign, playing cards, material chips, the Mole's dirt mound.
# Outputs: offduty/ *.png (masters, committed; baked/installed later with
# the corner build).
from PIL import Image, ImageDraw, ImageFilter
import random, math, os

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "offduty")
os.makedirs(OUT, exist_ok=True)
B = (16, 14, 12, 255)
CHUTE_O = (196, 120, 60, 255)
CHUTE_O_D = (168, 100, 50, 255)
CHUTE_C = (206, 192, 164, 255)
CHUTE_C_D = (182, 168, 140, 255)
rnd = random.Random(4242)

# ---- 1. seat crate: vanilla item_box, green gem painted out ----
box = Image.open(os.path.expanduser(
    "~/brotato-vanilla-reference/items/consumables/item_box/item_box.png")).convert("RGBA")
import numpy as np
a = np.array(box)
# the gem glow tints the whole front - remap every green-dominant pixel
# onto a wood ramp by its brightness (keeps shading, kills the green)
r = a[..., 0].astype(int); g = a[..., 1].astype(int); b2 = a[..., 2].astype(int)
green = (g > r + 12) & (g > b2 + 12) & (a[..., 3] > 50)
lum = (r + g + b2) / 3.0
wr, wg, wb = 132, 100, 62
scale = np.clip(lum / 150.0, 0.35, 1.35)
a[..., 0] = np.where(green, np.clip(wr * scale, 0, 255), a[..., 0])
a[..., 1] = np.where(green, np.clip(wg * scale, 0, 255), a[..., 1])
a[..., 2] = np.where(green, np.clip(wb * scale, 0, 255), a[..., 2])
crate = Image.fromarray(a)
crate.save(OUT + "/seat_crate.png")

# ---- 2. parachute-scrap rug (~180x120, tattered) ----
rug = Image.new("RGBA", (260, 176), (0, 0, 0, 0))
d = ImageDraw.Draw(rug)
corners = [(10, 14), (250, 6), (256, 164), (6, 170)]
d.polygon(corners, fill=CHUTE_O_D)
for i in range(8):
    x0 = 12 + i * 31
    if i % 2 == 0:
        d.polygon([(x0, 14), (x0 + 26, 11), (x0 + 31, 162), (x0 + 5, 166)], fill=CHUTE_C_D)
    else:
        d.polygon([(x0, 14), (x0 + 26, 11), (x0 + 31, 162), (x0 + 5, 166)], fill=CHUTE_O)
# tattered nicks along the hem
for _ in range(11):
    ex = rnd.randint(12, 244)
    d.polygon([(ex, 166), (ex + 10, 169), (ex + 5, 156)], fill=(0, 0, 0, 0))
# black outline via dilate-under
mask = rug.split()[3].point(lambda v: 255 if v > 60 else 0)
sil = mask.filter(ImageFilter.MaxFilter(5))
outl = Image.new("RGBA", rug.size, (0, 0, 0, 0))
outl.paste(Image.new("RGBA", rug.size, B), (0, 0), sil)
outl.alpha_composite(rug)
outl.save(OUT + "/rug.png")

# ---- 3. scorch mark (wall decal, alpha soot) ----
sc = Image.new("RGBA", (96, 70), (0, 0, 0, 0))
d = ImageDraw.Draw(sc)
for _ in range(14):
    w2, h2 = rnd.randint(18, 52), rnd.randint(12, 30)
    x2, y2 = rnd.randint(0, 96 - w2), rnd.randint(0, 70 - h2)
    blob = Image.new("RGBA", (w2, h2), (0, 0, 0, 0))
    ImageDraw.Draw(blob).ellipse([0, 0, w2, h2], fill=(18, 14, 12, rnd.randint(60, 120)))
    sc.alpha_composite(blob, (x2, y2))
d.ellipse([28, 18, 66, 48], fill=(24, 18, 14, 200))
sc.save(OUT + "/scorch.png")

# ---- 4. tally graffiti (wall decal, scratched) ----
ta = Image.new("RGBA", (120, 44), (0, 0, 0, 0))
d = ImageDraw.Draw(ta)
gx = 4
for grp in range(4):
    for i in range(4):
        x = gx + i * 7
        d.line([(x + rnd.randint(-1, 1), 6 + rnd.randint(-2, 2)),
                (x + rnd.randint(-1, 1), 36 + rnd.randint(-2, 2))], fill=(178, 174, 166, 235), width=3)
    d.line([(gx - 3, 30 + rnd.randint(-2, 2)), (gx + 24, 10 + rnd.randint(-2, 2))],
           fill=(178, 174, 166, 235), width=3)
    gx += 32
ta.save(OUT + "/tally.png")

# ---- 5. OFF DUTY sign (crooked planks + painted letters) ----
sg = Image.new("RGBA", (170, 64), (0, 0, 0, 0))
d = ImageDraw.Draw(sg)
d.polygon([(4, 10), (162, 2), (166, 50), (8, 60)], fill=(104, 76, 52, 255))
d.polygon([(4, 10), (162, 2), (163, 8), (5, 16)], fill=(122, 92, 62, 255))
d.line([(58, 6), (60, 58)], fill=(84, 60, 40, 255), width=3)
d.line([(112, 4), (114, 55)], fill=(84, 60, 40, 255), width=3)
# painted letters, chunky: draw small then upscale-nearest onto the board
txt = Image.new("RGBA", (85, 16), (0, 0, 0, 0))
ImageDraw.Draw(txt).text((1, 2), "OFF DUTY", fill=(226, 204, 158, 255))
txt = txt.resize((85 * 2, 16 * 2), Image.NEAREST).rotate(-2, expand=True)
sg.alpha_composite(txt, (10, 12))
mask = sg.split()[3].point(lambda v: 255 if v > 60 else 0)
sil = mask.filter(ImageFilter.MaxFilter(5))
outl = Image.new("RGBA", sg.size, (0, 0, 0, 0))
outl.paste(Image.new("RGBA", sg.size, B), (0, 0), sil)
outl.alpha_composite(sg)
outl.save(OUT + "/sign_offduty.png")

# ---- 6. playing cards (table decal) ----
ca = Image.new("RGBA", (64, 48), (0, 0, 0, 0))
d = ImageDraw.Draw(ca)
for (cx2, cy2, rot) in ((4, 8, -8), (24, 4, 5), (42, 12, 14)):
    card = Image.new("RGBA", (18, 26), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle([0, 0, 17, 25], 3, fill=(232, 228, 218, 255), outline=B, width=2)
    cd.ellipse([6, 9, 12, 15], fill=(150, 60, 50, 255))
    card = card.rotate(rot, expand=True)
    ca.alpha_composite(card, (cx2, cy2))
ca.save(OUT + "/cards.png")

# ---- 7. material chips (stack of green material orbs) ----
ch = Image.new("RGBA", (40, 34), (0, 0, 0, 0))
d = ImageDraw.Draw(ch)
for (x2, y2) in ((4, 14), (18, 16), (11, 4)):
    d.ellipse([x2, y2, x2 + 16, y2 + 16], fill=(96, 180, 96, 255), outline=B, width=2)
    d.ellipse([x2 + 3, y2 + 3, x2 + 8, y2 + 8], fill=(150, 220, 150, 255))
ch.save(OUT + "/chips.png")

# (mound retired 2026-08-21 - user cut it)

# contact sheet
names = ["seat_crate", "rug", "scorch", "tally", "sign_offduty", "cards", "chips"]
imgs = [Image.open(OUT + "/%s.png" % n) for n in names]
cw = max(i.width for i in imgs) + 16
chh = max(i.height for i in imgs) + 30
sheet = Image.new("RGBA", (cw * 4, chh * 2), (40, 42, 48, 255))
sd = ImageDraw.Draw(sheet)
for i, (n, img) in enumerate(zip(names, imgs)):
    x, y = (i % 4) * cw, (i // 4) * chh
    sheet.alpha_composite(img, (x + 8, y + 24))
    sd.text((x + 8, y + 4), n, fill=(225, 222, 214, 255))
sheet = sheet.resize((sheet.width * 2, sheet.height * 2), Image.NEAREST)
sheet.save(OUT + "/procedural_sheet.png")
print("procedural props written:", ", ".join(names))
