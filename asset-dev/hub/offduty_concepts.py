# OFF DUTY corner LAYOUT concepts (2026-08-20, planning). Three scattered
# arrangements of the west deck corner (world x -1350..-730, y -1160..-660
# mapped to 620x500 panels). Schematic, not art: white potato blobs = mode
# guys, "z z" = the sleeper seat, dashed rings = future-guy spots.
from PIL import Image, ImageDraw

PW, PH = 620, 500
DECK = (52, 55, 62, 255)
WALL = (30, 30, 34, 255)
B = (16, 14, 12, 255)
CRATE = (110, 84, 52, 255)
CRATE_H = (128, 100, 64, 255)
DRUM = (60, 62, 66, 255)
FIRE = (238, 150, 40, 255)
FIRE_C = (252, 220, 120, 255)
POT = (235, 232, 226, 255)
CHALK = (40, 44, 40, 255)
DASH = (180, 180, 170, 255)


def panel():
    im = Image.new("RGBA", (PW, PH), DECK)
    d = ImageDraw.Draw(im)
    d.rectangle([0, 0, PW, 26], fill=WALL)          # north perimeter wall
    d.rectangle([0, 0, 26, PH], fill=WALL)          # west perimeter wall
    d.rectangle([0, 26, PW, 30], fill=B)
    d.rectangle([26, 0, 30, PH], fill=B)
    for gx in range(30, PW, 148):                    # plate seams
        d.line([gx, 30, gx, PH], fill=(46, 49, 56, 255), width=2)
    for gy in range(30, PH, 148):
        d.line([30, gy, PW, gy], fill=(46, 49, 56, 255), width=2)
    return im, d


def firedrum(d, x, y):
    d.ellipse([x-26, y-18, x+26, y+18], fill=B)
    d.ellipse([x-22, y-15, x+22, y+15], fill=DRUM)
    d.polygon([(x-12, y-2), (x-4, y-26), (x+2, y-8), (x+10, y-22), (x+14, y-2)], fill=FIRE)
    d.polygon([(x-6, y-3), (x-1, y-16), (x+6, y-4)], fill=FIRE_C)


def crate(d, x, y, w=40, h=30):
    d.rectangle([x-w//2-2, y-h//2-2, x+w//2+2, y+h//2+2], fill=B)
    d.rectangle([x-w//2, y-h//2, x+w//2, y+h//2], fill=CRATE)
    d.line([x-w//2, y-h//2, x+w//2, y+h//2], fill=CRATE_H, width=3)


def guy(d, x, y, label=""):
    d.ellipse([x-16, y-16, x+16, y+16], fill=B)
    d.ellipse([x-13, y-13, x+13, y+13], fill=POT)
    d.ellipse([x-6, y-5, x-2, y-1], fill=B)
    d.ellipse([x+2, y-5, x+6, y-1], fill=B)
    if label:
        d.text((x-len(label)*3, y+18), label, fill=(225, 222, 214, 255))


def sleeper(d, x, y):
    d.ellipse([x-16, y-10, x+16, y+14], fill=B)
    d.ellipse([x-13, y-7, x+13, y+11], fill=POT)
    d.line([x-8, y+2, x+8, y+2], fill=B, width=2)
    d.text((x+14, y-24), "z z", fill=(225, 222, 214, 255))


def empty_spot(d, x, y):
    for ang in range(0, 360, 45):
        import math
        a0, a1 = ang, ang + 24
        d.arc([x-17, y-17, x+17, y+17], a0, a1, fill=DASH, width=3)
    d.text((x-4, y-7), "+", fill=DASH)


def chalkboard(d, x, y):
    d.rectangle([x-30, y-22, x+30, y+22], fill=B)
    d.rectangle([x-26, y-18, x+26, y+18], fill=CHALK)
    d.text((x-22, y-14), "MODES", fill=(200, 205, 200, 255))
    d.line([x-20, y+6, x+12, y+6], fill=(150, 155, 150, 255), width=2)


def lightstring(d, x0, x1, y, sag=26):
    import math
    for i in range(41):
        t = i / 40.0
        px = x0 + (x1 - x0) * t
        py = y + math.sin(t * 3.14159) * sag
        if i % 5 == 0:
            d.ellipse([px-4, py-4, px+4, py+4], fill=(238, 196, 66, 255))
        else:
            d.point((px, py), fill=B)
    d.rectangle([x0-4, y-34, x0+4, y+4], fill=DRUM)
    d.rectangle([x1-4, y-34, x1+4, y+4], fill=DRUM)


# ---- Concept A: FIRE RING (uneven circle, classic campfire) ----
imA, dA = panel()
lightstring(dA, 120, 470, 80)
chalkboard(dA, 545, 70)
firedrum(dA, 300, 250)
crate(dA, 190, 180); guy(dA, 190, 158, "P2W")
crate(dA, 415, 205, 34, 34); guy(dA, 415, 182, "SMITH")
crate(dA, 235, 355); guy(dA, 235, 332, "GOURMET")
guy(dA, 390, 340, "MOLE")                       # sits on the floor, no seat
crate(dA, 120, 270, 30, 26); guy(dA, 120, 248, "WILD")
crate(dA, 505, 300, 56, 26); sleeper(dA, 505, 282)
guy(dA, 330, 130, "DEMON")                      # leaning on nothing, hovering near fire
empty_spot(dA, 150, 410)
empty_spot(dA, 470, 415)

# ---- Concept B: WALL LOUNGE (couch against the wall, fire offset) ----
imB, dB = panel()
lightstring(dB, 60, 400, 68)
dB.rectangle([88, 44, 366, 96], fill=B)          # salvaged shuttle couch
dB.rectangle([92, 48, 362, 92], fill=(84, 60, 46, 255))
for cx in (130, 218, 306):
    dB.line([cx+44, 48, cx+44, 92], fill=B, width=3)
guy(dB, 130, 70, "WILD"); guy(dB, 218, 70, "MOLE"); sleeper(dB, 306, 70)
chalkboard(dB, 430, 66)
firedrum(dB, 250, 250)
crate(dB, 150, 300); guy(dB, 150, 278, "GOURMET")
guy(dB, 350, 300, "DEMON")
crate(dB, 470, 200, 46, 36)                      # card table
crate(dB, 420, 258, 26, 22); guy(dB, 420, 236, "P2W")
crate(dB, 520, 258, 26, 22); guy(dB, 520, 236, "SMITH")
empty_spot(dB, 100, 420)
empty_spot(dB, 300, 420)
empty_spot(dB, 560, 350)

# ---- Concept C: SCATTER CAMP (micro-spots, most spread out) ----
imC, dC = panel()
lightstring(dC, 200, 560, 62)
firedrum(dC, 170, 350)
crate(dC, 100, 300); guy(dC, 100, 278, "WILD")
guy(dC, 245, 320, "MOLE")
crate(dC, 430, 150, 46, 36)                      # card game NE
crate(dC, 380, 205, 26, 22); guy(dC, 380, 183, "P2W")
crate(dC, 480, 205, 26, 22); guy(dC, 480, 183, "SMITH")
guy(dC, 90, 110, "DEMON")                        # wall-leaner NW
chalkboard(dC, 250, 120)
crate(dC, 330, 430, 40, 30); guy(dC, 330, 408, "GOURMET")
# hammock between two posts, east
dC.rectangle([540, 250, 548, 330], fill=DRUM)
dC.rectangle([600, 250, 608, 330], fill=DRUM)
dC.arc([544, 258, 604, 320], 0, 180, fill=B, width=5)
sleeper(dC, 574, 296)
empty_spot(dC, 120, 440)
empty_spot(dC, 480, 330)
empty_spot(dC, 560, 110)

board = Image.new("RGBA", (PW * 3 + 80, PH + 90), (24, 22, 20, 255))
dd = ImageDraw.Draw(board)
labels = ["A  FIRE RING - uneven circle round the drum",
          "B  WALL LOUNGE - couch on the wall, fire offset",
          "C  SCATTER CAMP - micro-spots, most spread out"]
for i, (im, lab) in enumerate(zip([imA, imB, imC], labels)):
    x = 20 + i * (PW + 20)
    board.alpha_composite(im, (x, 60))
    dd.text((x + 4, 24), lab, fill=(230, 225, 215, 255))
dd.text((20, PH + 68), "white blob = mode guy   z z = sleeper seat   dashed ring = future-guy spot   MODES board = active-mode chalkboard", fill=(180, 176, 168, 255))
board.save("offduty_concept_board.png")
print("board written")
