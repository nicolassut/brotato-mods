#!/usr/bin/env python3
"""gen_food_<slug>.png -> 80x80 ground consumable with soft shadow, installed to
items/foods/<slug>/<slug>.png + asset-dev/foods. Usage: process_food.py food_<slug> [...]"""
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
SCRATCH = '/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad'
ADEV = '/Users/nicolassutcliffe/brotato-mods/asset-dev'
DEC = '/Users/nicolassutcliffe/brotato-decompiled'
sys.path.insert(0, f'{ADEV}/pipeline')
from process_gen import outline_med, thicken, final_cleanup

def fit_food(im):
    c = im.crop(im.getbbox())
    s = 68 / max(c.size)
    nw, nh = round(c.width*s), round(c.height*s)
    c = c.resize((nw, nh), Image.LANCZOS)
    cv = Image.new('RGBA', (80, 80), (0, 0, 0, 0))
    sh = ImageDraw.Draw(cv)
    cy = 74
    sh.ellipse([(80-nw)//2 - 3, cy - 6, (80+nw)//2 + 3, cy + 2], fill=(40, 40, 46, 80))
    cv.paste(c, ((80-nw)//2, cy - 2 - nh), c)
    return cv

for slug in sys.argv[1:]:
    base = slug.replace('food_', '')
    im = Image.open(f'{SCRATCH}/gen_{slug}.png').convert('RGBA')
    for W in (2, 3):
        final = final_cleanup(fit_food(thicken(im, W)))
        m = outline_med(final)
        if m >= 4:
            break
    final.save(f'{ADEV}/foods/final/{base}.png')
    im.save(f'{ADEV}/foods/raw/{base}.png')
    dst = f'{DEC}/items/foods/{base}/{base}.png'
    installed = 'adev only'
    if os.path.isdir(os.path.dirname(dst)):
        final.save(dst)
        installed = 'live+adev'
    print(f'{base}: W={W} outline={m:.0f}px [{installed}]')
