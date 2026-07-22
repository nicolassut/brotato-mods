#!/usr/bin/env python3
"""gen_proj_<weapon>.png -> weapons/ranged/<weapon>/<weapon>_projectile.png, fit to the
template projectile's canvas so in-game scale matches (directional ones already point right).
Usage: process_projectile.py <weapon> [...]"""
import sys, os
sys.path.insert(0, '/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
from process_gen import thicken, final_cleanup, outline_med, vector_prep, fill_holes, despeckle
from PIL import Image
SCRATCH = '/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad'
ADEV = '/Users/nicolassutcliffe/brotato-mods/asset-dev'
DEC = '/Users/nicolassutcliffe/brotato-decompiled'
TV = '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/TO_VECTORIZE'

# weapon -> (canvas px matching the template projectile, content fill fraction).
# round shots fill less so they are not giant; directional shots (corn, cork) fill more.
SIZES = {'corn_cannon': (120, 0.92), 'galley_cannon': (110, 0.70), 'sauce_blaster': (64, 0.90),
         'champagne_popper': (110, 0.90), 'pizza_cutter': (100, 0.82), 'ice_cream_scoop': (55, 0.72)}

def fit(im, canvas, frac):
    c = im.crop(im.getbbox())
    s = (canvas * frac) / max(c.size)
    nw, nh = max(1, round(c.width * s)), max(1, round(c.height * s))
    c = c.resize((nw, nh), Image.LANCZOS)
    cv = Image.new('RGBA', (canvas, canvas), (0, 0, 0, 0))
    cv.paste(c, ((canvas - nw) // 2, (canvas - nh) // 2), c)
    return cv

# dark, near-black shots whose sphere/body shading final_cleanup would crush to a black void
# (invisible on the dark arena). Keep the grey: thicken the outline, drop the alpha fringe, and
# brighten the mid-grey body a touch - but NEVER run the black snap.
DARK_BODY = {'galley_cannon'}

def gentle(gen, canvas, frac):
    import numpy as np
    a = np.array(fit(thicken(gen, 3), canvas, frac)).astype(int)
    a[a[..., 3] < 110] = 0
    op = a[..., 3] > 0
    lum = a[..., :3].mean(axis=2)
    body = op & (lum >= 18) & (lum < 120)   # not the black outline, not the white highlight
    a[body, :3] = np.clip(a[body, :3] * 1.7 + 18, 0, 255)
    return despeckle(Image.fromarray(a.astype('uint8')))

def main():
    for slug in sys.argv[1:]:
        gen = Image.open(f'{SCRATCH}/gen_proj_{slug}.png').convert('RGBA')
        canvas, frac = SIZES[slug]
        out = gentle(gen, canvas, frac) if slug in DARK_BODY else final_cleanup(fit(thicken(gen, 3), canvas, frac))
        os.makedirs(f'{ADEV}/projectiles_raw', exist_ok=True)
        gen.save(f'{ADEV}/projectiles_raw/{slug}.png')
        live = f'{DEC}/weapons/ranged/{slug}/{slug}_projectile.png'
        installed = 'adev only'
        if os.path.isdir(os.path.dirname(live)):
            out.save(live); installed = 'LIVE'
        if slug in DARK_BODY:
            # vector_prep's black snap would crush the grey too - build the vecprep from the
            # gentle result instead, just hard-alpha it at 128 for the tracer.
            import numpy as np
            c = out.crop(out.getbbox()); s = 128 * 0.92 / max(c.size)
            c = c.resize((max(1, round(c.width * s)), max(1, round(c.height * s))), Image.LANCZOS)
            cv = Image.new('RGBA', (128, 128), (0, 0, 0, 0)); cv.paste(c, ((128 - c.width) // 2, (128 - c.height) // 2), c)
            va = np.array(cv); va[..., 3] = np.where(va[..., 3] >= 128, 255, 0); va[va[..., 3] == 0] = 0
            vp = fill_holes(despeckle(Image.fromarray(va)))
        else:
            vp = fill_holes(vector_prep(gen, target=128))
        vp.save(f'{TV}/projectile__{slug}.png')
        print(f'{slug}: projectile {canvas}px outline={outline_med(out):.0f}px [{installed}]')

if __name__ == '__main__':
    main()
