# OFF DUTY corner DECORATION pass (2026-08-20, planning). Layout C dressed
# with numbered props; legend maps numbers to prop + art source.
from PIL import Image, ImageDraw

PW, PH = 780, 640
DECK = (52, 55, 62, 255)
WALL = (30, 30, 34, 255)
B = (16, 14, 12, 255)
CRATE = (110, 84, 52, 255)
DRUM = (60, 62, 66, 255)
FIRE = (238, 150, 40, 255)
POT = (235, 232, 226, 255)
TXT = (225, 222, 214, 255)
DIM = (150, 148, 142, 255)
GOLD = (230, 190, 80, 255)
CHUTE_O = (196, 120, 60, 255)
CHUTE_C = (206, 192, 164, 255)
MOSS = (120, 140, 70, 255)

im = Image.new("RGBA", (PW, PH), DECK)
d = ImageDraw.Draw(im)
d.rectangle([0, 0, PW, 30], fill=WALL); d.rectangle([0, 30, PW, 34], fill=B)
d.rectangle([0, 0, 30, PH], fill=WALL); d.rectangle([30, 0, 34, PH], fill=B)

def guy(x, y):
    d.ellipse([x-15, y-15, x+15, y+15], fill=B)
    d.ellipse([x-12, y-12, x+12, y+12], fill=POT)
    d.ellipse([x-5, y-4, x-2, y-1], fill=B); d.ellipse([x+2, y-4, x+5, y-1], fill=B)

def crate(x, y, w=40, h=30):
    d.rectangle([x-w//2-2, y-h//2-2, x+w//2+2, y+h//2+2], fill=B)
    d.rectangle([x-w//2, y-h//2, x+w//2, y+h//2], fill=CRATE)

def tag(x, y, n):
    d.ellipse([x-11, y-11, x+11, y+11], fill=(20, 20, 24, 230), outline=GOLD)
    d.text((x-4 if n < 10 else x-7, y-7), str(n), fill=GOLD)

# --- parachute-scrap RUG under the fire area (1) ---
d.polygon([(120, 380), (300, 365), (320, 500), (135, 515)], fill=CHUTE_O)
for i, px in enumerate(range(135, 300, 24)):
    if i % 2 == 0:
        d.polygon([(px, 372), (px+22, 370), (px+28, 506), (px+6, 508)], fill=CHUTE_C)
tag(135, 500, 1)

# fire drum + cooking pot on a stick (2) + cooler (3) + bottles (4)
d.ellipse([185, 405, 245, 448], fill=B); d.ellipse([189, 409, 241, 444], fill=DRUM)
d.polygon([(202, 420), (210, 392), (216, 412), (224, 398), (228, 420)], fill=FIRE)
d.line([175, 380, 250, 435], fill=(90, 70, 50, 255), width=4)
d.ellipse([168, 372, 192, 390], fill=(70, 74, 80, 255))
tag(166, 360, 2)
d.rectangle([262, 448, 304, 478], fill=(70, 100, 120, 255), outline=B, width=3)
tag(310, 452, 3)
for (bx, by) in ((150, 545), (170, 552), (330, 530)):
    d.ellipse([bx, by, bx+9, by+16], fill=(90, 120, 90, 255), outline=B, width=2)
tag(348, 528, 4)

# Wildcard seat + oversized dice (5)
crate(105, 335); guy(105, 312)
d.rectangle([60, 370, 84, 394], fill=POT, outline=B, width=3)
d.ellipse([66, 376, 72, 382], fill=B); d.ellipse([74, 384, 80, 390], fill=B)
tag(52, 402, 5)

# Mole on floor + dirt mound he came out of (6)
guy(285, 430)
d.polygon([(310, 452), (330, 428), (352, 452)], fill=(84, 66, 48, 255))
d.ellipse([316, 444, 348, 456], fill=(64, 50, 38, 255))
tag(358, 448, 6)

# Demon wall-leaner + scorch mark behind (7)
guy(100, 150)
d.ellipse([78, 96, 130, 128], fill=(24, 22, 24, 255))
d.ellipse([88, 102, 120, 122], fill=(38, 30, 28, 255))
tag(140, 104, 7)

# card table: P2W vs Smith, cards + material chips (8)
crate(470, 195, 50, 38)
crate(415, 250, 26, 22); guy(415, 228)
crate(525, 250, 26, 22); guy(525, 228)
for (cx, cy, rot) in ((458, 188, 0), (476, 192, 1), (468, 200, 0)):
    d.rectangle([cx, cy, cx+11, cy+15], fill=POT, outline=B, width=2)
d.ellipse([488, 184, 498, 194], fill=(90, 200, 120, 255), outline=B)
d.ellipse([494, 190, 504, 200], fill=(90, 200, 120, 255), outline=B)
tag(508, 172, 8)

# Gourmet + skewer rack by his crate (9)
crate(360, 520, 40, 30); guy(360, 498)
d.line([400, 500, 400, 540], fill=(90, 70, 50, 255), width=4)
d.line([388, 508, 412, 508], fill=(90, 70, 50, 255), width=3)
for sx in (392, 400, 408):
    d.line([sx, 508, sx, 522], fill=B, width=2)
    d.ellipse([sx-3, 520, sx+3, 528], fill=(160, 90, 60, 255))
tag(418, 496, 9)

# hammock + lantern on post (10) + alien moss plant pot (11)
d.rectangle([640, 300, 648, 390], fill=DRUM)
d.rectangle([700, 300, 708, 390], fill=DRUM)
d.arc([644, 312, 704, 378], 0, 180, fill=B, width=5)
d.ellipse([662, 336, 686, 356], fill=POT)
d.text((688, 318), "z z", fill=TXT)
d.line([644, 300, 644, 288], fill=B, width=2)
d.ellipse([637, 274, 651, 292], fill=(238, 196, 66, 255), outline=B, width=2)
tag(624, 268, 10)
d.rectangle([712, 430, 744, 456], fill=(96, 70, 50, 255), outline=B, width=3)
d.polygon([(716, 432), (728, 402), (734, 428), (742, 410), (744, 432)], fill=MOSS)
tag(752, 408, 11)

# wall: OFF DUTY sign (12), dartboard (13), tally graffiti (14), string lights (15)
d.polygon([(300, 40), (420, 36), (424, 78), (304, 84)], fill=(84, 60, 46, 255))
d.text((318, 50), "OFF DUTY", fill=(220, 200, 150, 255))
tag(290, 66, 12)
d.ellipse([480, 40, 532, 92], fill=(150, 60, 50, 255), outline=B, width=3)
d.ellipse([494, 54, 518, 78], fill=CHUTE_C)
d.ellipse([502, 62, 510, 70], fill=B)
tag(542, 46, 13)
for i in range(9):
    x0 = 580 + (i % 5) * 8 + (i // 5) * 48
    d.line([x0, 50, x0, 70], fill=(120, 118, 112, 255), width=2)
d.line([578, 52, 612, 68], fill=(120, 118, 112, 255), width=2)
tag(668, 52, 14)
import math
for i in range(41):
    t = i / 40.0
    px = 120 + (600 - 120) * t
    py = 100 + math.sin(t * 3.14159) * 24
    if i % 5 == 0:
        d.ellipse([px-4, py-4, px+4, py+4], fill=(238, 196, 66, 255))
tag(96, 96, 15)

# chalkboard (16) + radio (17)
d.rectangle([560, 120, 640, 172], fill=B)
d.rectangle([566, 126, 634, 166], fill=(40, 44, 40, 255))
d.text((574, 132), "MODES", fill=(200, 205, 200, 255))
tag(650, 124, 16)
d.rectangle([196, 470, 232, 494], fill=(70, 72, 78, 255), outline=B, width=3)
d.line([224, 470, 238, 452], fill=B, width=2)
d.ellipse([201, 476, 211, 486], fill=B)
tag(244, 466, 17)

board = Image.new("RGBA", (PW + 40, PH + 240), (24, 22, 20, 255))
dd = ImageDraw.Draw(board)
board.alpha_composite(im, (20, 46))
dd.text((20, 16), "OFF DUTY - decorated (layout C)", fill=TXT)
legend = [
 "1 parachute-scrap rug (booth-curtain canon)   2 cook pot on a stick over the fire",
 "3 cooler box   4 empty bottles scattered      5 Wildcard's oversized dice",
 "6 Mole's dirt mound (how he arrived)          7 scorch mark behind the Demon",
 "8 cards + material chips (P2W vs Smith game)  9 Gourmet's skewer rack",
 "10 lantern on the hammock post                11 potted alien moss (statue-moss canon)",
 "12 crooked OFF DUTY scrap sign                13 dartboard on hull plate",
 "14 tally graffiti (waves survived)            15 sagging work-light string",
 "16 MODES chalkboard                           17 scrap radio with antenna",
]
for i, line in enumerate(legend):
    dd.text((24, PH + 60 + i * 21), line, fill=DIM)
board.save("offduty_decor_board.png")
print("decor board written")
