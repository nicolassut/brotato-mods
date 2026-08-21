# BACK WALL faces, high-quality concepts (2026-08-21). Three treatments of
# the deck's north wall, built with the shipped systems (slab courses, crack
# kit, dimmed vanilla moss set, cliff-pillar metal recipe), rendered on top
# of the real deck v3 slabs so the junction reads.
from PIL import Image, ImageDraw
import random, math
import deck_crack_proto as dcp

B = (16, 14, 12, 255)
W, FACE_H, CAP_H = 1400, 150, 30

FACE = (42, 44, 51, 255)
FACE_D = (36, 38, 44, 255)
FACE_DD = (31, 33, 38, 255)
CAP = (58, 61, 69, 255)
CAP_LIT = (66, 70, 78, 255)


def base_strip(kind):
    H = CAP_H + FACE_H + 160
    im = Image.new("RGBA", (W, H), (52, 55, 62, 255))
    d = ImageDraw.Draw(im)
    # real deck slabs at the bottom (junction context)
    dcp.slabs(d, W, H, 42)
    d.rectangle([0, 0, W, CAP_H + FACE_H], fill=FACE)
    # cap lip (walkable top edge, lit)
    d.rectangle([0, 0, W, CAP_H], fill=CAP)
    d.rectangle([0, 0, W, 5], fill=CAP_LIT)
    d.rectangle([0, CAP_H - 4, W, CAP_H], fill=B)
    rnd = random.Random(hash(kind) & 0xffff)

    if kind == "W1":       # dressed stone courses
        y = CAP_H
        row = 0
        while y < CAP_H + FACE_H - 20:
            x = -(64 if row % 2 else 0)
            while x < W:
                bw = 118 + rnd.randint(-10, 10)
                tone = rnd.choice([FACE, FACE_D, (45, 47, 54, 255)])
                d.rectangle([x, y, x + bw, y + 34], fill=tone)
                d.rectangle([x, y, x + 3, y + 34], fill=(52, 55, 63, 255))
                d.rectangle([x + bw - 3, y, x + bw, y + 34], fill=FACE_DD)
                d.rectangle([x + bw, y, x + bw + 4, y + 34], fill=(26, 28, 33, 255))
                x += bw + 4
            d.rectangle([0, y + 34, W, y + 38], fill=(26, 28, 33, 255))
            y += 38
            row += 1
        for _ in range(6):   # cracks down the face
            pts = dcp.crack_path(rnd, rnd.randint(60, W - 60), CAP_H + rnd.randint(6, 30),
                                 math.pi / 2 + rnd.uniform(-0.5, 0.5), rnd.randint(4, 8), rnd.randint(8, 13))
            dcp.draw_crack(d, pts, rnd.uniform(2.5, 4.0))
        for _ in range(10):  # moss hanging from course lines
            dcp.moss_tuft(im, rnd, rnd.randint(20, W - 20), CAP_H + rnd.choice([38, 76, 114]) + 2)

    elif kind == "W2":     # rock face + riveted metal ribs (pillar recipe)
        # rock face: soft tone blotches (the cliff's language, not hatching)
        for _ in range(90):
            bw2, bh2 = rnd.randint(40, 130), rnd.randint(14, 34)
            bx2 = rnd.randint(-20, W - 20)
            by2 = CAP_H + rnd.randint(2, FACE_H - 30)
            blot = Image.new("RGBA", (bw2, bh2), (0, 0, 0, 0))
            ImageDraw.Draw(blot).ellipse([0, 0, bw2, bh2],
                fill=rnd.choice([(38, 40, 46, 60), (34, 36, 42, 55), (47, 49, 56, 45)]))
            im.alpha_composite(blot, (bx2, by2))
        for yy in (CAP_H + 46, CAP_H + 96):   # strata
            xx = 0
            while xx < W:
                seg = rnd.randint(120, 260)
                jy = yy + rnd.randint(-4, 4)
                d.line([(xx, jy), (min(W, xx + seg), jy)], fill=FACE_DD, width=3)
                xx += seg
        for _ in range(5):
            pts = dcp.crack_path(rnd, rnd.randint(60, W - 60), CAP_H + rnd.randint(8, 40),
                                 math.pi / 2 + rnd.uniform(-0.6, 0.6), rnd.randint(4, 7), rnd.randint(8, 12))
            dcp.draw_crack(d, pts, rnd.uniform(2.0, 3.5))
        for rx in range(90, W, 200):          # riveted ribs, pillar recipe
            rxj = rx + rnd.randint(-14, 14)
            d.rectangle([rxj - 13, CAP_H - 4, rxj + 13, CAP_H + FACE_H], fill=B)
            d.rectangle([rxj - 10, CAP_H - 2, rxj + 10, CAP_H + FACE_H], fill=(46, 48, 52, 255))
            d.rectangle([rxj - 8, CAP_H - 2, rxj - 4, CAP_H + FACE_H], fill=(58, 60, 64, 255))
            d.rectangle([rxj + 5, CAP_H - 2, rxj + 10, CAP_H + FACE_H], fill=(34, 36, 40, 255))
            for ry in range(CAP_H + 14, CAP_H + FACE_H - 8, 34):
                d.ellipse([rxj - 2, ry, rxj + 3, ry + 5], fill=(26, 26, 28, 255))
        for _ in range(8):
            dcp.moss_tuft(im, rnd, rnd.randint(20, W - 20), CAP_H + rnd.choice([48, 98]) + 2)

    else:                   # W3: courses + mount plates + hazard cap
        y = CAP_H
        row = 0
        while y < CAP_H + FACE_H - 20:
            x = -(64 if row % 2 else 0)
            while x < W:
                bw = 118 + rnd.randint(-10, 10)
                d.rectangle([x, y, x + bw, y + 34], fill=rnd.choice([FACE, FACE_D]))
                d.rectangle([x + bw, y, x + bw + 4, y + 34], fill=(26, 28, 33, 255))
                x += bw + 4
            d.rectangle([0, y + 34, W, y + 38], fill=(26, 28, 33, 255))
            y += 38
            row += 1
        # hazard cap stripes on the lip
        for x in range(-40, W, 46):
            d.polygon([(x, 4), (x + 22, 4), (x + 10, CAP_H - 4), (x - 12, CAP_H - 4)],
                      fill=(198, 168, 44, 255))
        d.rectangle([0, 0, W, 5], fill=CAP_LIT)
        d.rectangle([0, CAP_H - 4, W, CAP_H], fill=B)
        # bolted mounting plates (prop anchors)
        for px in (170, 520, 880, 1200):
            pw, ph = rnd.randint(80, 120), rnd.randint(56, 72)
            py = CAP_H + rnd.randint(14, FACE_H - ph - 18)
            d.rectangle([px - 3, py - 3, px + pw + 3, py + ph + 3], fill=B)
            d.rectangle([px, py, px + pw, py + ph], fill=(48, 50, 56, 255))
            d.rectangle([px, py, px + 4, py + ph], fill=(58, 60, 66, 255))
            for (ex, ey) in ((px + 5, py + 5), (px + pw - 9, py + 5),
                             (px + 5, py + ph - 9), (px + pw - 9, py + ph - 9)):
                d.ellipse([ex, ey, ex + 5, ey + 5], fill=(26, 26, 28, 255))
        for _ in range(6):
            dcp.moss_tuft(im, rnd, rnd.randint(20, W - 20), CAP_H + rnd.choice([38, 76, 114]) + 2)

    # wall->floor junction: black base line + contact shadow on the slabs
    jy = CAP_H + FACE_H
    d.rectangle([0, jy - 4, W, jy], fill=B)
    sh = Image.new("RGBA", (W, 14), (0, 0, 0, 60))
    im.alpha_composite(sh, (0, jy))
    # a dartboard + the OFF DUTY sign hung on every option (mount proof)
    d.ellipse([W - 190, CAP_H + 22, W - 120, CAP_H + 92], fill=(150, 60, 50, 255), outline=B, width=4)
    d.ellipse([W - 172, CAP_H + 40, W - 138, CAP_H + 74], fill=(206, 192, 164, 255))
    d.ellipse([W - 160, CAP_H + 52, W - 150, CAP_H + 62], fill=B)
    d.polygon([(70, CAP_H + 26), (240, CAP_H + 18), (244, CAP_H + 66), (74, CAP_H + 76)], fill=(94, 68, 50, 255))
    d.polygon([(70, CAP_H + 26), (240, CAP_H + 18), (242, CAP_H + 22), (72, CAP_H + 30)], fill=(110, 82, 60, 255))
    d.text((104, CAP_H + 38), "OFF DUTY", fill=(214, 192, 148, 255))
    return im


strips = [("W1  dressed stone courses", base_strip("W1")),
          ("W2  rock face + riveted ribs (pillar recipe)", base_strip("W2")),
          ("W3  courses + mount plates + hazard cap", base_strip("W3"))]
H1 = strips[0][1].height
board = Image.new("RGBA", (W + 40, (H1 + 56) * 3 + 30), (24, 22, 20, 255))
dd = ImageDraw.Draw(board)
for i, (lab, s) in enumerate(strips):
    y = 20 + i * (H1 + 56)
    dd.text((20, y), lab, fill=(225, 222, 214, 255))
    board.alpha_composite(s, (20, y + 24))
board.save("wall_concept_hq_board.png")
print("hq wall board written")
