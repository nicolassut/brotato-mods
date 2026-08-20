# Changing-booth CONCEPT BOARD (2026-08-20). Four rough directions for the
# user to choose from - deliberately crude mockups, NOT final art. The chosen
# one goes to PixelLab probes per HUB_ART_SPEC. Laws respected loosely:
# black borders, light from the left. Footprint: BOOTH_RECT 224x256, sprite
# ~230x300 (body taller than footprint, 2.5D).
from PIL import Image, ImageDraw, ImageFont

B = (16, 14, 12, 255)
METAL = (46, 48, 52, 255)
HI = (58, 60, 64, 255)
DK = (34, 36, 40, 255)
CAP = (56, 58, 62, 255)
RED = (140, 50, 50, 255)
RED_D = (108, 38, 38, 255)
RED_H = (164, 66, 62, 255)
YEL = (198, 168, 44, 255)
GLASS = (96, 110, 124, 255)
GLASS_H = (130, 146, 160, 255)

W, H = 240, 310


def outlined(draw_fn):
    im = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(im)
    draw_fn(d)
    # crude dilate border
    mask = im.split()[3].point(lambda v: 255 if v > 60 else 0)
    out = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    black = Image.new("RGBA", (W, H), B)
    for dx in range(-4, 5):
        for dy in range(-4, 5):
            if dx * dx + dy * dy <= 16:
                out.paste(black, (dx, dy), mask)
    out.paste(im, (0, 0), im)
    return out


def concept_a():  # ESCAPE-POD WARDROBE - salvaged pod stood upright
    def f(d):
        d.rounded_rectangle([30, 20, 210, 280], 60, fill=METAL)
        d.rectangle([30, 150, 210, 280], fill=METAL)
        d.rounded_rectangle([44, 20, 82, 280], 30, fill=HI)          # left light
        d.rounded_rectangle([176, 30, 210, 280], 30, fill=DK)
        d.ellipse([88, 38, 152, 96], fill=(70, 82, 94, 255))         # porthole
        d.ellipse([96, 44, 130, 72], fill=(112, 128, 142, 255))
        d.rectangle([76, 116, 168, 272], fill=RED_D)                 # door + curtain
        for i, x in enumerate(range(76, 168, 16)):
            d.rectangle([x, 116, x + 8, 268 - (i % 2) * 8], fill=RED)
        d.rectangle([76, 116, 168, 128], fill=CAP)                   # rail
        d.rectangle([20, 268, 92, 292], fill=DK)                     # skids
        d.rectangle([150, 268, 222, 292], fill=DK)
    return outlined(f)


def concept_b():  # CURTAIN STALL - PvZ-style changing cubicle, hazard top bar
    def f(d):
        d.rectangle([28, 60, 52, 284], fill=METAL)                   # posts
        d.rectangle([30, 60, 38, 284], fill=HI)
        d.rectangle([188, 60, 212, 284], fill=METAL)
        d.rectangle([190, 60, 196, 284], fill=DK)
        d.rectangle([16, 30, 224, 66], fill=(40, 42, 46, 255))       # top bar
        for x in range(16, 224, 32):                                  # hazard
            d.polygon([(x, 34), (x + 16, 34), (x + 4, 62), (x - 12, 62)], fill=YEL)
        d.rectangle([16, 30, 224, 38], fill=CAP)
        d.rectangle([52, 66, 188, 252], fill=RED_D)                  # curtain
        for i, x in enumerate(range(52, 188, 18)):
            d.rectangle([x, 66, x + 9, 246 + (i % 2) * 6], fill=RED)
        d.rectangle([56, 66, 64, 250], fill=RED_H)                   # left light
        d.rectangle([44, 284, 196, 300], fill=DK)                    # step plate
    return outlined(f)


def concept_c():  # CARGO-CRATE CABIN - shipping crate on end, cut-in door
    def f(d):
        d.rectangle([32, 24, 208, 288], fill=METAL)
        d.rectangle([36, 24, 52, 288], fill=HI)
        d.rectangle([192, 24, 208, 288], fill=DK)
        d.rectangle([32, 24, 208, 46], fill=CAP)                     # lid lip
        for y in (98, 190):                                           # plate seams
            d.rectangle([32, y, 208, y + 4], fill=DK)
        for x, y in ((44, 34), (196, 34), (44, 276), (196, 276)):     # rivets
            d.ellipse([x - 4, y - 4, x + 4, y + 4], fill=DK)
        d.rectangle([84, 92, 164, 276], fill=(40, 42, 46, 255))      # door
        d.rectangle([88, 96, 100, 272], fill=HI)
        d.rectangle([150, 170, 160, 196], fill=CAP)                  # handle
        for y in (108, 236):                                          # hinges
            d.rectangle([78, y, 88, y + 22], fill=CAP)
        for y in range(120, 160, 10):                                 # vents
            d.rectangle([108, y, 148, y + 5], fill=DK)
    return outlined(f)


def concept_d():  # TECH POD - spaceport stall, frosted panel, status lamp
    def f(d):
        d.rounded_rectangle([30, 34, 210, 292], 22, fill=METAL)
        d.rectangle([34, 60, 48, 280], fill=HI)
        d.rectangle([194, 60, 210, 280], fill=DK)
        d.rectangle([64, 76, 178, 268], fill=GLASS)                  # frosted panel
        d.polygon([(76, 268), (128, 76), (158, 76), (106, 268)], fill=GLASS_H)
        d.rectangle([64, 76, 178, 86], fill=CAP)
        d.ellipse([104, 32, 136, 62], fill=(60, 130, 70, 255))       # status lamp
        d.ellipse([110, 38, 124, 50], fill=(96, 190, 104, 255))
        d.rectangle([16, 120, 30, 240], fill=DK)                     # side pipe
        d.rectangle([210, 120, 224, 240], fill=DK)
        d.rectangle([48, 276, 192, 296], fill=DK)                    # base plinth
    return outlined(f)


board = Image.new("RGBA", (W * 4 + 100, H + 80), (24, 22, 20, 255))
dd = ImageDraw.Draw(board)
labels = ["A  ESCAPE-POD WARDROBE", "B  CURTAIN STALL", "C  CARGO-CRATE CABIN", "D  TECH POD"]
for i, (c, lab) in enumerate(zip([concept_a(), concept_b(), concept_c(), concept_d()], labels)):
    x = 20 + i * (W + 20)
    board.alpha_composite(c, (x, 50))
    dd.text((x + 10, 20), lab, fill=(230, 225, 215, 255))
board.save("booth_concept_board.png")
print("board written")
