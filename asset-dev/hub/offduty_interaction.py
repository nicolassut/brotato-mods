# OFF DUTY corner INTERACTION concepts (2026-08-20, planning). Left: scatter
# camp layout with per-guy interaction ranges + prompts (every guy is his own
# LobbyNpc station). Right: dialog mockups for two guys showing the tick
# grammar - P2W (supersede + linked switch) and Gourmet (exclusive pair).
from PIL import Image, ImageDraw

GOLD = (230, 190, 80, 255)
TXT = (225, 222, 214, 255)
DIM = (140, 138, 132, 255)
PANEL = (28, 26, 30, 245)
PANEL_B = (90, 82, 60, 255)
POT = (235, 232, 226, 255)
B = (16, 14, 12, 255)


def guy(d, x, y):
    d.ellipse([x-16, y-16, x+16, y+16], fill=B)
    d.ellipse([x-13, y-13, x+13, y+13], fill=POT)
    d.ellipse([x-6, y-5, x-2, y-1], fill=B)
    d.ellipse([x+2, y-5, x+6, y-1], fill=B)


def ring(d, x, y, r):
    for ang in range(0, 360, 30):
        d.arc([x-r, y-r, x+r, y+r], ang, ang+18, fill=(150, 170, 200, 160), width=2)


# ---------------- left: layout with interaction layer ----------------
L = Image.new("RGBA", (640, 560), (52, 55, 62, 255))
d = ImageDraw.Draw(L)
d.rectangle([0, 0, 640, 26], fill=(30, 30, 34, 255)); d.rectangle([0, 26, 640, 30], fill=B)
d.rectangle([0, 0, 26, 560], fill=(30, 30, 34, 255)); d.rectangle([26, 0, 30, 560], fill=B)
spots = [
    ("The P2W",     "[E] Chat",  390, 205),
    ("The Smith",   "[E] Chat",  500, 205),
    ("The Wildcard","[E] Chat",  120, 330),
    ("The Mole",    "[E] Chat",  255, 380),
    ("The Demon",   "[E] Chat",  95, 130),
    ("The Gourmet", "[E] Chat",  340, 470),
]
# fire + hammock landmarks
d.ellipse([150, 395, 200, 430], fill=(60, 62, 66, 255))
d.polygon([(165, 408), (172, 385), (178, 402), (185, 390), (188, 408)], fill=(238, 150, 40, 255))
d.rectangle([560, 290, 568, 370], fill=(60, 62, 66, 255))
d.rectangle([612, 290, 620, 370], fill=(60, 62, 66, 255))
d.arc([564, 300, 616, 360], 0, 180, fill=B, width=5)
d.ellipse([578, 322, 602, 342], fill=POT)
d.text((600, 300), "z z", fill=TXT)
for (name, prompt, x, y) in spots:
    ring(d, x, y, 62)
    guy(d, x, y)
    d.text((x - len(name)*3, y - 44), name, fill=TXT)
    d.text((x - len(prompt)*3, y + 22), prompt, fill=GOLD)
d.text((40, 535), "each guy = his own station: name plate + [E] prompt + HIS dialog", fill=DIM)

# ---------------- right: two dialog mockups ----------------
def dialog(title, bark, rows, note):
    W, H = 460, 66 + 34*len(rows) + 54
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d2 = ImageDraw.Draw(im)
    d2.rectangle([0, 0, W-1, H-1], fill=PANEL, outline=PANEL_B, width=3)
    guy(d2, 30, 32)
    d2.text((56, 16), title, fill=GOLD)
    d2.text((56, 34), '"%s"' % bark, fill=DIM)
    y = 66
    for (state, label, extra) in rows:
        box = [20, y+2, 36, y+18]
        if state == "on":
            d2.rectangle(box, fill=(60, 120, 60, 255), outline=TXT, width=2)
            d2.line([23, y+10, 27, y+15], fill=TXT, width=2)
            d2.line([27, y+15, 34, y+5], fill=TXT, width=2)
            d2.text((46, y+2), label, fill=TXT)
        elif state == "off":
            d2.rectangle(box, outline=TXT, width=2)
            d2.text((46, y+2), label, fill=TXT)
        else:  # greyed
            d2.rectangle(box, outline=DIM, width=2)
            d2.line([22, y+4, 34, y+16], fill=DIM, width=2)
            d2.text((46, y+2), label, fill=DIM)
        if extra:
            d2.text((W - 12 - len(extra)*6, y+2), extra, fill=(150, 170, 200, 255))
        y += 34
    d2.text((20, y+8), note, fill=DIM)
    d2.text((W-70, y+8), "[Esc] Close", fill=GOLD)
    return im

dlgA = dialog("The P2W", "Spin to win, baby.",
    [("on",  "All crates are lootboxes", ""),
     ("off", "Lootboxes appear in the shop", ""),
     ("grey","EVERYTHING is lootboxes", "supersedes"),
     ("on",  "Full 8-tier ladder", "linked: Smith")],
    "ladder tick mirrors live in The Smith's dialog")

dlgB = dialog("The Gourmet", "Tonight's menu is... everything.",
    [("on",  "All fruit becomes steak", ""),
     ("grey","All fruit becomes food", "exclusive"),
     ("off", "30% chance: food spawner in shop", "")],
    "steak/food auto-cancel each other (exclusive pair)")

R = Image.new("RGBA", (500, 560), (24, 22, 20, 0))
R.alpha_composite(dlgA, (10, 30))
R.alpha_composite(dlgB, (10, 320))

board = Image.new("RGBA", (640 + 520 + 60, 620), (24, 22, 20, 255))
dd = ImageDraw.Draw(board)
board.alpha_composite(L, (20, 50))
board.alpha_composite(R, (690, 50))
dd.text((20, 20), "WALK UP TO EACH GUY (rings = interact range)", fill=TXT)
dd.text((700, 20), "HIS OWN TICK-BOX DIALOG (the grammar in action)", fill=TXT)
board.save("offduty_interaction_board.png")
print("interaction board written")
