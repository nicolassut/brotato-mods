#!/usr/bin/env python3
"""gen_<slug>_spr.png -> in-game held sprite weapons/<type>/<slug>/<slug>.png, fit
to the template's sprite canvas (business end already points right in the gen).
Usage: process_weapon_sprite.py <type:melee|ranged> <slug> [...]  (reads gen_<slug>_spr.png)"""
import sys, os
sys.path.insert(0, '/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
from process_gen import thicken, final_cleanup, outline_med, vector_prep, fill_holes, BIG_ITEMS_256
from PIL import Image
SCRATCH = '/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad'
ADEV = '/Users/nicolassutcliffe/brotato-mods/asset-dev'
DEC = '/Users/nicolassutcliffe/brotato-decompiled'
TV = '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/TO_VECTORIZE'

# match the template sprite canvas each weapon was cloned from (keeps muzzle/pivot aligned)
SIZES = {'corn_cannon': (150, 75), 'galley_cannon': (150, 75), 'sauce_blaster': (117, 75),
         'champagne_popper': (80, 80), 'fish_slapper': (100, 64), 'frying_pan': (110, 70)}

def fit(im, W, H, margin=8):
    c = im.crop(im.getbbox())
    s = min((W - margin) / c.width, (H - margin) / c.height)
    nw, nh = max(1, round(c.width * s)), max(1, round(c.height * s))
    c = c.resize((nw, nh), Image.LANCZOS)
    cv = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cv.paste(c, ((W - nw) // 2, (H - nh) // 2), c)
    return cv

def main():
    wtype = sys.argv[1]
    for slug in sys.argv[2:]:
        gen = Image.open(f'{SCRATCH}/gen_{slug}_spr.png').convert('RGBA')
        W, H = SIZES[slug]
        sprite = final_cleanup(fit(thicken(gen, 3), W, H))
        os.makedirs(f'{ADEV}/weapons/sprite_raw', exist_ok=True)
        gen.save(f'{ADEV}/weapons/sprite_raw/{slug}_spr.png')
        live = f'{DEC}/weapons/{wtype}/{slug}/{slug}.png'
        installed = 'adev only'
        if os.path.isdir(os.path.dirname(live)):
            sprite.save(live)
            installed = 'LIVE'
        # vecprep so the user can vectorize the sprite too (horizontal, keep as-is)
        tgt = 256 if slug in BIG_ITEMS_256 else 128
        fill_holes(vector_prep(gen, target=tgt)).save(f'{TV}/weapon_sprite__{slug}.png')
        print(f'{slug}: sprite {W}x{H} outline={outline_med(sprite):.0f}px [{installed}]')

if __name__ == '__main__':
    main()
