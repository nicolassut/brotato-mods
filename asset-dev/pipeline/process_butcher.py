#!/usr/bin/env python3
"""gen_<slug>.png -> items/custom/butcher_skin/ art for the Butcher meat reskin.
Icons (meat_rack, meat_locker, meat_cooler, beef_broth, butchers_apron) -> 96px item icons.
World sprites: meat_rack_ingame -> 225px canvas (tree neutral) at frac 0.75: user wants
the rack 20% smaller than the tree fit (2026-07-22); canvas stays 225 so the bottom
anchor keeps its ground line. meat_locker_ingame -> 100px (matches garden_ingame).
Vecpreps: icons 128, world sprites 256 (structure rule).
Usage: process_butcher.py <slug> [...]"""
import sys, os
sys.path.insert(0, '/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
from process_gen import (thicken, downscale, final_cleanup, outline_med, vector_prep,
                         fill_holes, remove_black_pools, open_enclosed_black,
                         restore_thin_from_raw)
from PIL import Image
SCRATCH = os.environ.get('BROTATO_SCRATCH',
    '/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad')
ADEV = '/Users/nicolassutcliffe/brotato-mods/asset-dev'
SKIN = '/Users/nicolassutcliffe/brotato-decompiled/items/custom/butcher_skin'
TV = '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/TO_VECTORIZE'

ICONS = {'meat_rack', 'meat_locker', 'meat_cooler', 'beef_broth', 'butchers_apron'}
WORLD = {'meat_rack_ingame': (225, 0.75), 'meat_locker_ingame': (100, 0.94)}

# these icons are detail-dense: vecprep at 200 (user rule 2026-07-22), not 128
VEC_200 = ICONS

# gap fixes for see-through sprites. Two methods, chosen per sprite (2026-07-22, learned
# the hard way): 'v2' remove_black_pools (thickness-cored) for thin-lined sprites with BIG
# pools (the rack - it keeps hanging hooks embedded in pools); 'v1' open_enclosed_black
# (distance) for thick-outlined sprites (apron - v2 eats thick outlines as pools).
# (live_fix, live_kwargs, vec_fix, vec_kwargs)
GAP_FIX = {
    'meat_rack':        ('v2', dict(m=3, rim=2), 'v2', dict(m=6, rim=3)),
    'butchers_apron':   ('v1', dict(rim=3, stroke=2, lumk=70), 'v1', dict(rim=6, stroke=4, lumk=70)),
    'meat_rack_ingame': ('v2', dict(m=5, rim=3), 'v2', dict(m=6, rim=3)),
}

def apply_fix(im, spec):
    if spec is None:
        return im
    kind, kw = spec
    return remove_black_pools(im, **kw) if kind == 'v2' else open_enclosed_black(im, **kw)

def fit(im, canvas, frac):
    c = im.crop(im.getbbox())
    s = (canvas * frac) / max(c.size)
    nw, nh = max(1, round(c.width * s)), max(1, round(c.height * s))
    c = c.resize((nw, nh), Image.LANCZOS)
    cv = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    # world sprites sit on the ground: bottom-anchor like the tree/garden art
    cv.paste(c, ((canvas - nw) // 2, canvas - nh - max(0, (canvas - nh) // 8)), c)
    return cv

def main():
    os.makedirs(f'{ADEV}/butcher_skin/raw', exist_ok=True)
    os.makedirs(SKIN, exist_ok=True)
    for slug in sys.argv[1:]:
        gen = Image.open(f'{SCRATCH}/gen_{slug}.png').convert('RGBA')
        gen.save(f'{ADEV}/butcher_skin/raw/{slug}.png')
        live_fix = (GAP_FIX[slug][0], GAP_FIX[slug][1]) if slug in GAP_FIX else None
        vec_fix = (GAP_FIX[slug][2], GAP_FIX[slug][3]) if slug in GAP_FIX else None
        if slug in ICONS:
            for W in (3, 4, 5):
                final = final_cleanup(downscale(thicken(gen, W)))
                m = outline_med(final)
                if m >= 6:
                    break
            final = apply_fix(final, live_fix)
            final.save(f'{SKIN}/{slug}_icon.png')
            tgt = 200 if slug in VEC_200 else 128
            vp = apply_fix(fill_holes(vector_prep(gen, target=tgt)), vec_fix)
            if slug in GAP_FIX:
                # vector_prep's upscale+median eats thin hooks/joints; restore them from raw
                vp = restore_thin_from_raw(vp, gen, tgt)
            vp.save(f'{TV}/butcher__{slug}.png')
            print(f'{slug}: icon 96 W={W} outline={m:.0f}px vec={tgt} [LIVE]')
        else:
            canvas, frac = WORLD[slug]
            final = apply_fix(final_cleanup(fit(thicken(gen, 3), canvas, frac)), live_fix)
            final.save(f'{SKIN}/{slug}.png')
            vp = apply_fix(fill_holes(vector_prep(gen, target=256)), vec_fix)
            if slug in GAP_FIX:
                vp = restore_thin_from_raw(vp, gen, 256)
            vp.save(f'{TV}/butcher__{slug}.png')
            print(f'{slug}: world {canvas}px outline={outline_med(final):.0f}px [LIVE]')

if __name__ == '__main__':
    main()
