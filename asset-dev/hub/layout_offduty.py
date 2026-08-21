# OFF DUTY corner LAYOUT COMPOSITOR (2026-08-21). Renders the corner
# offline exactly as lobby.gd lays it out (decals under, base-anchored
# props + guys YSorted) so placement is tuned VISUALLY here before any
# coordinates reach the game. Also runs a bbox overlap check on props.
# The POSITIONS dict is the single source of truth - lobby.gd mirrors it.
from PIL import Image, ImageDraw
import os

HERE = os.path.dirname(os.path.abspath(__file__))
ART = os.path.join(HERE, "../../game-src/ui/lobby/art/")

# ---- the layout (world coords) ----
DECALS = [
    ("od_rug",      (-1040, -710)),
    ("od_scorch",   (-1270, -800)),   # under the fire
    ("od_cards",    (-800, -680)),
    ("od_chips",    (-772, -672)),
    ("od_sign",     (-1040, -1245)),
    ("od_dartboard",(-925, -1240)),
    ("od_scorch",   (-1330, -1230)),  # wall scorch
    ("od_tally",    (-1160, -1300)),
]
PROPS = [  # (texture, base position)
    ("od_cookpot",  (-1240, -788)),
    ("od_skewers",  (-1330, -770)),
    ("od_crate2",   (-1330, -880)),
    ("od_radio",    (-1120, -755)),
    ("od_cooler",   (-965, -748)),
    ("od_bottles",  (-1205, -672)),
    ("od_dice",     (-948, -650)),
    ("od_crate",    (-855, -720)),
    ("od_barrel",   (-745, -715)),
    ("od_hammock",  (-1280, -1055)),
    ("od_lantern",  (-1155, -1070)),
    ("od_plant",    (-720, -1120)),
]
GUYS = [  # (label, position, face_left)
    ("Gourmet",  (-1150, -860), True),
    ("Mole",     (-1000, -682), True),
    ("Wildcard", (-1090, -688), False),
    ("P2W",      (-865, -640), False),
    ("Smith",    (-740, -636), True),
    ("Demon",    (-750, -970), True),
]
FIRE = (-1270, -804)


def render(out_path):
    W0, H0 = -1420, -1380
    VW, VH = 800, 840
    canvas = Image.new("RGBA", (VW, VH), (20, 20, 20, 255))
    deck = Image.open(ART + "ground_deck.png").convert("RGBA")
    wall = Image.open(ART + "wall_north.png").convert("RGBA")
    cliff = Image.open(ART + "ground_cliff.png").convert("RGBA")
    base = Image.new("RGBA", (VW, VH), (52, 55, 62, 255))
    canvas.alpha_composite(base, (0, 0))
    canvas.alpha_composite(deck, (-1376 - W0, -1176 - H0))
    canvas.alpha_composite(cliff, (-1376 - W0, -616 - H0))
    canvas.alpha_composite(wall, (-1376 - W0, -1356 - H0))
    # shrine pad placeholder
    d = ImageDraw.Draw(canvas)
    d.rectangle([-976 - W0, -1000 - H0, -784 - W0, -776 - H0], fill=(33, 28, 26, 255))
    d.text((-950 - W0, -900 - H0), "SHRINE", fill=(150, 148, 142, 255))
    for (name, (x, y)) in DECALS:
        im = Image.open(ART + name + ".png").convert("RGBA")
        canvas.alpha_composite(im, (x - im.width // 2 - W0, y - im.height // 2 - H0))
    # YSort: order by base y
    layers = []
    for (name, (x, y)) in PROPS:
        im = Image.open(ART + name + ".png").convert("RGBA")
        layers.append((y, im, (x - im.width // 2 - W0, y - im.height - H0), name))
    potato = Image.open(os.path.expanduser(
        "~/brotato-vanilla-reference/entities/units/player/potato.png")).convert("RGBA")
    for (label, (x, y), flip) in GUYS:
        im = potato.transpose(Image.FLIP_LEFT_RIGHT) if flip else potato
        layers.append((y, im, (x - im.width // 2 - W0, y - 24 - im.height // 2 - H0), label))
    # fire marker
    fl = Image.new("RGBA", (36, 52), (0, 0, 0, 0))
    ImageDraw.Draw(fl).polygon([(8, 48), (14, 8), (20, 30), (26, 4), (32, 48)], fill=(238, 150, 40, 230))
    layers.append((FIRE[1], fl, (FIRE[0] - 18 - W0, FIRE[1] - 48 - H0), "fire"))
    layers.sort(key=lambda e: e[0])
    for (_, im, pos, label) in layers:
        canvas.alpha_composite(im, pos)
    for (label, (x, y), flip) in GUYS:
        d.text((x - len(label) * 3 - W0, y - 92 - H0), label, fill=(225, 222, 214, 255))
    canvas.save(out_path)
    print("render ->", out_path)


def overlap_check():
    boxes = []
    for (name, (x, y)) in PROPS:
        im = Image.open(ART + name + ".png")
        boxes.append((name, x - im.width / 2, y - im.height, x + im.width / 2, y))
    bad = []
    for i in range(len(boxes)):
        for j in range(i + 1, len(boxes)):
            a, b = boxes[i], boxes[j]
            if a[1] < b[3] and b[1] < a[3] and a[2] < b[4] and b[2] < a[4]:
                bad.append((a[0], b[0]))
    print("prop bbox overlaps:", bad if bad else "none")


if __name__ == "__main__":
    overlap_check()
    render("/tmp/offduty_layout.png")
