#!/usr/bin/env python3
"""Install the 3_new_spawners_vectorized 640px masters at their in-game sizes.

Each category is fitted with the SAME rule its pixel counterpart uses, so the new art
lands at exactly the scale the rest of the game already sits at:
  foods      -> fit_food:      68px max dim on an 80 canvas, soft shadow, baseline cy=74
  item icons -> downscale:     88px max dim on a 96 canvas, centred
  structures -> fit_structure: (size-6) max dim, bottom-anchored (they stand on the floor)

vectorizer.ai THINS outlines, so each master is thickened at master resolution (W scaled
by 640/target) and bumped until the downscaled result clears its category outline floor -
the same additive border pass border_pass_masters.py established.

cocktail_bar (icon AND structure) is never fill_holes'd: the gaps under its roof are
see-through to the arena. The gumball is asserted to stay COLOURLESS, because main.gd
tints that one texture red/blue/green with modulate and any baked hue would multiply wrong.
"""
import os, sys, shutil
import numpy as np
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
from process_gen import thicken, final_cleanup, fill_holes, outline_med, interior_holes

ROOT = '/Users/nicolassutcliffe/brotato-mods'
SRC  = f'{ROOT}/Brotato Icons/3_new_spawners_vectorized'
BK   = f'{ROOT}/Brotato Icons/_pre_vector_backup_batch3'
ADEV = f'{ROOT}/asset-dev'
DEC  = '/Users/nicolassutcliffe/brotato-decompiled'


def fit_food(c):
    s = 68 / max(c.size)
    nw, nh = round(c.width * s), round(c.height * s)
    c = c.resize((nw, nh), Image.LANCZOS)
    cv = Image.new('RGBA', (80, 80), (0, 0, 0, 0))
    ImageDraw.Draw(cv).ellipse([(80-nw)//2 - 3, 68, (80+nw)//2 + 3, 76], fill=(40, 40, 46, 80))
    cv.paste(c, ((80-nw)//2, 72 - nh), c)
    return cv


def fit_icon(c):
    s = 88 / max(c.size)
    nw, nh = round(c.width * s), round(c.height * s)
    c = c.resize((nw, nh), Image.LANCZOS)
    cv = Image.new('RGBA', (96, 96), (0, 0, 0, 0))
    cv.paste(c, ((96-nw)//2, (96-nh)//2), c)
    return cv


def fit_structure(c, size):
    s = (size - 6) / max(c.size)
    nw, nh = round(c.width * s), round(c.height * s)
    c = c.resize((nw, nh), Image.LANCZOS)
    cv = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    cv.paste(c, ((size - nw)//2, size - 3 - nh), c)
    return cv


# master file -> (kind, live path relative to DEC, adev mirror dir, canvas, outline floor)
JOBS = [
 ('fried_egg_vecprep.png', 'food', 'items/foods/fried_egg/fried_egg.png',
  f'{ADEV}/foods/final/fried_egg.png', 80, 4),
 ('gumball_vecprep.png', 'food', 'items/foods/gumball/gumball.png',
  f'{ADEV}/foods/final/gumball.png', 80, 4),
 ('bloody_mary_vecprep.png', 'food', 'items/foods/bloody_mary/bloody_mary.png',
  f'{ADEV}/foods/final/bloody_mary.png', 80, 4),
 ('cocktail_bar_vecprep.png', 'icon', 'items/custom/cocktail_bar/cocktail_bar.png',
  f'{ADEV}/items_food_system/final/cocktail_bar.png', 96, 6),
 ('Gumball_Machine_Sprite.png', 'icon', 'items/custom/gumball_machine/gumball_machine.png',
  f'{ADEV}/items_food_system/final/gumball_machine.png', 96, 6),
 ('cocktail_bar_ingame.png', 'struct', 'entities/structures/turret/cocktail_bar/cocktail_bar_ingame.png',
  f'{ADEV}/structures_food/final/cocktail_bar_ingame.png', 100, 5),
 ('Gumball_Machine_ingame.png', 'struct', 'entities/structures/turret/gumball_machine/gumball_machine_ingame.png',
  f'{ADEV}/structures_food/final/gumball_machine_ingame.png', 115, 5),
]

# see-through frames: filling their interior holes would weld the arena gaps shut
OPEN_FRAME = {'cocktail_bar_vecprep.png', 'cocktail_bar_ingame.png'}

print(f'{"asset":30s} {"W":>3s} {"outline":>7s} {"canvas":>7s} {"bbox":>22s}  holes')
print('-' * 92)
for name, kind, rel, adev, size, floor in JOBS:
    master = Image.open(f'{SRC}/{name}').convert('RGBA')
    used_W = 0
    for W in (0, 1, 2, 3, 4, 5, 6):
        # thicken at MASTER resolution so the border survives the 640 -> target downscale
        src = master if W == 0 else thicken(master, max(1, round(W * max(master.size) / size)))
        c = src.crop(src.getbbox())
        fitted = fit_food(c) if kind == 'food' else fit_icon(c) if kind == 'icon' else fit_structure(c, size)
        out = final_cleanup(fitted)
        if name not in OPEN_FRAME:
            out = fill_holes(out)
        used_W = W
        if outline_med(out) >= floor:
            break

    live = f'{DEC}/{rel}'
    os.makedirs(os.path.dirname(f'{BK}/{rel}'), exist_ok=True)
    if os.path.exists(live) and not os.path.exists(f'{BK}/{rel}'):
        shutil.copy2(live, f'{BK}/{rel}')
    out.save(live)
    os.makedirs(os.path.dirname(adev), exist_ok=True)
    out.save(adev)
    a = np.array(out)
    print(f'{name[:-4]:30s} {used_W:3d} {outline_med(out):7.1f} {str(out.size):>7s} '
          f'{str(out.getbbox()):>22s}  {int(interior_holes(a).sum())}')

print(f'\nbackups -> {BK}')
