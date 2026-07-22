#!/usr/bin/env python3
"""Process gen_<slug>_ingame.png into the 100x100 in-world structure sprite.
Bottom-anchored (structures stand on the arena floor), outline >= 5px at 100.
Installs to entities/structures/turret/<base>/<slug>.png + asset-dev/structures_food.
Usage: process_structure.py <slug>_ingame [...]"""
import sys, os
import numpy as np
from PIL import Image, ImageFilter

SCRATCH = '/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad'
ADEV = '/Users/nicolassutcliffe/brotato-mods/asset-dev'
DEC = '/Users/nicolassutcliffe/brotato-decompiled'
sys.path.insert(0, f'{ADEV}/pipeline')
from process_gen import outline_med, thicken, final_cleanup

# relative world scale (user 2026-07-20): trucks/buildings bigger than stoves/hives
SIZES = {'beehive_ingame': 100, 'wok_station_ingame': 95, 'street_vendor_ingame': 105,
         'farmers_market_ingame': 120, 'chili_greenhouse_ingame': 125,
         'fancy_restaurant_ingame': 130, 'ice_cream_truck_ingame': 135}

def fit_structure(im, size=100):
    c = im.crop(im.getbbox())
    s = (size - 6) / max(c.size)
    nw, nh = round(c.width * s), round(c.height * s)
    c = c.resize((nw, nh), Image.LANCZOS)
    cv = Image.new('RGBA', (size, size), (0, 0, 0, 0))
    cv.paste(c, ((size - nw) // 2, size - 3 - nh), c)
    return cv

def main():
    for slug in sys.argv[1:]:
        base = slug.replace('_ingame', '')
        im = Image.open(f'{SCRATCH}/gen_{slug}.png').convert('RGBA')
        for W in (2, 3, 4):
            final = final_cleanup(fit_structure(thicken(im, W), SIZES.get(slug, 100)))
            m = outline_med(final)
            if m >= 5:
                break
        final.save(f'{ADEV}/structures_food/final/{slug}.png')
        im.save(f'{ADEV}/structures_food/raw/{slug}.png')
        dst = f'{DEC}/entities/structures/turret/{base}/{slug}.png'
        installed = 'adev only'
        if os.path.isdir(os.path.dirname(dst)):
            final.save(dst)
            installed = 'live+adev'
        print(f'{slug}: W={W} outline={m:.0f}px bbox={final.getbbox()} [{installed}]')

if __name__ == '__main__':
    main()
