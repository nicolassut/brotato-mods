# DECK RETEXTURE + BACK WALL concepts (2026-08-20, planning). The deck is a
# stone platform held by stone pillars - floor becomes smooth rock slabs and
# the north edge gets a visible WALL FACE to hang props on.
# Light-from-left law: slab chamfers lit on the left, shaded on the right.
from PIL import Image, ImageDraw
import random

TXT = (225, 222, 214, 255)
DIM = (150, 148, 142, 255)
B = (16, 14, 12, 255)
BASE = (52, 55, 62, 255)          # current deck base - palette anchor
SEAM = (38, 40, 46, 255)
LIT = (62, 66, 74, 255)
SHD = (44, 46, 53, 255)
MOSS = (110, 130, 66, 255)

SW, SH = 380, 240


def slab_field(d, w, h, sw, shh, jitter, seed, cracked=False, moss=False, inlay=False):
    rnd = random.Random(seed)
    y = 0
    row = 0
    while y < h:
        x = -(sw // 2 if row % 2 else 0)
        while x < w:
            cw = sw + rnd.randint(-jitter, jitter)
            tone = rnd.choice([BASE, (54, 57, 65, 255), (50, 53, 60, 255)])
            d.rectangle([x, y, x + cw, y + shh], fill=tone)
            d.rectangle([x, y, x + cw, y + 3], fill=LIT)               # top chamfer
            d.rectangle([x, y, x + 3, y + shh], fill=LIT)              # left chamfer (light)
            d.rectangle([x + cw - 3, y, x + cw, y + shh], fill=SHD)    # right shade
            d.rectangle([x, y + shh - 3, x + cw, y + shh], fill=SHD)
            d.rectangle([x + cw, y, x + cw + 4, y + shh], fill=SEAM)   # vertical seam
            if inlay and row % 2 == 0 and rnd.random() < 0.5:
                d.rectangle([x + 10, y + shh - 8, x + cw - 10, y + shh - 5], fill=(70, 74, 82, 255))
            if cracked and rnd.random() < 0.18:
                cx0 = x + rnd.randint(10, max(11, cw - 20))
                pts = [(cx0, y + 6)]
                for k in range(4):
                    pts.append((pts[-1][0] + rnd.randint(-8, 8), y + 10 + (k + 1) * (shh // 6)))
                d.line(pts, fill=(30, 32, 37, 255), width=2)
            if moss and rnd.random() < 0.10:
                mx, my = x + rnd.randint(8, max(9, cw - 16)), y + rnd.randint(6, shh - 12)
                d.polygon([(mx, my + 8), (mx + 5, my), (mx + 8, my + 6), (mx + 12, my + 2), (mx + 14, my + 8)], fill=MOSS)
            x += cw + 4
        d.rectangle([0, y + shh, w, y + shh + 4], fill=SEAM)
        y += shh + 4
        row += 1


def swatch(kind, seed=7):
    im = Image.new("RGBA", (SW, SH), BASE)
    d = ImageDraw.Draw(im)
    if kind == "A":
        slab_field(d, SW, SH, 120, 74, 14, seed)
    elif kind == "B":
        slab_field(d, SW, SH, 120, 74, 14, seed, cracked=True, moss=True)
    else:
        slab_field(d, SW, SH, 150, 90, 8, seed, inlay=True)
    return im


# ---- back wall faces (vertical surface, ~130px tall, props mountable) ----
def wall_face(kind):
    W, H = 560, 190
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    top = 26
    face = (40, 42, 49, 255)
    face_d = (34, 36, 42, 255)
    d.rectangle([0, 0, W, top], fill=(58, 61, 69, 255))       # cap lip (walkable edge)
    d.rectangle([0, top, W, top + 4], fill=B)
    d.rectangle([0, top + 4, W, H - 26], fill=face)
    if kind == "W1":  # dressed stone courses
        y = top + 4
        row = 0
        while y < H - 30:
            x = -(60 if row % 2 else 0)
            while x < W:
                d.rectangle([x, y, x + 116, y + 36], fill=face if (x // 116 + row) % 2 else face_d)
                d.rectangle([x, y, x + 2, y + 36], fill=(50, 53, 60, 255))
                d.rectangle([x + 114, y, x + 116, y + 36], fill=(28, 30, 35, 255))
                d.rectangle([x + 116, y, x + 119, y + 36], fill=(24, 26, 30, 255))
                x += 119
            d.rectangle([0, y + 36, W, y + 39], fill=(24, 26, 30, 255))
            y += 39
            row += 1
    elif kind == "W2":  # rock face + metal reinforcement ribs (pillar recipe)
        rnd = random.Random(3)
        for i in range(26):
            lx = rnd.randint(0, W)
            d.line([lx, top + 8, lx + rnd.randint(-14, 14), H - 32], fill=face_d, width=2)
        for rx in (70, 250, 430):
            d.rectangle([rx - 3, top + 4, rx + 17, H - 26], fill=B)
            d.rectangle([rx, top + 6, rx + 14, H - 28], fill=(46, 48, 52, 255))
            d.rectangle([rx + 2, top + 6, rx + 5, H - 28], fill=(58, 60, 64, 255))
            for ry in range(top + 18, H - 34, 26):
                d.ellipse([rx + 5, ry, rx + 9, ry + 4], fill=(26, 26, 28, 255))
    else:  # W3: stone courses + mounting plates + hazard cap
        y = top + 4
        while y < H - 30:
            d.rectangle([0, y + 33, W, y + 36], fill=(24, 26, 30, 255))
            y += 36
        for x in range(0, W, 40):
            d.polygon([(x, 0), (x + 20, 0), (x + 8, top), (x - 12, top)], fill=(198, 168, 44, 255))
        d.rectangle([0, top, W, top + 4], fill=B)
        for (px, py) in ((120, 70), (330, 60), (470, 84)):
            d.rectangle([px, py, px + 74, py + 52], fill=(48, 50, 56, 255), outline=B, width=3)
            for (ex, ey) in ((px + 5, py + 5), (px + 66, py + 5), (px + 5, py + 44), (px + 66, py + 44)):
                d.ellipse([ex, ey, ex + 4, ey + 4], fill=(26, 26, 28, 255))
    d.rectangle([0, H - 26, W, H - 22], fill=B)               # base line where wall meets floor
    d.rectangle([0, H - 22, W, H], fill=BASE)                  # floor in front
    # a hung dartboard to prove mountability
    d.ellipse([W - 120, top + 18, W - 70, top + 68], fill=(150, 60, 50, 255), outline=B, width=3)
    d.ellipse([W - 106, top + 32, W - 84, top + 54], fill=(206, 192, 164, 255))
    return im


board = Image.new("RGBA", (SW * 3 + 100, SH + 190 + 190), (24, 22, 20, 255))
dd = ImageDraw.Draw(board)
labels = ["A  clean slabs (smooth, staggered)", "B  worn slabs (cracks + moss ties)", "C  big slabs + metal inlay strips"]
for i, k in enumerate(["A", "B", "C"]):
    x = 25 + i * (SW + 25)
    board.alpha_composite(swatch(k), (x, 40))
    dd.text((x, 14), labels[i], fill=TXT)
wl = ["W1  dressed stone courses", "W2  rock + metal ribs (pillar recipe)", "W3  courses + mount plates + hazard cap"]
for i, k in enumerate(["W1", "W2", "W3"]):
    x = 25 + i * (SW + 25)
    face = wall_face(k).resize((SW, 130))
    board.alpha_composite(face, (x, SH + 90))
    dd.text((x, SH + 64), wl[i], fill=TXT)
dd.text((25, SH + 240), "top row: DECK FLOOR as smooth rock slabs (replaces metal plates; palette stays on the current deck base)", fill=DIM)
dd.text((25, SH + 262), "bottom row: BACK WALL face along the deck's north edge - a real surface to hang the Off Duty props on (dartboard shown)", fill=DIM)
board.save("deck_wall_concept_board.png")
print("board written")
