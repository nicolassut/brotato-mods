#!/usr/bin/env python3
"""Held-sprite refit v2: content scaled to the VANILLA template's measured content WIDTH
(not a canvas-fill fraction - that made everything oversized/fat). Long weapons stay interim
until dedicated long-thin art lands. Usage: build_held2.py bases|grid"""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, '/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
sys.path.append('.')
from build_held import CFG, pca_angle
from process_gen import _flag_small_blobs

NV = '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/New_Vectorized_Icons'
DEC = '/Users/nicolassutcliffe/brotato-decompiled'

# weapon: (canvas, target content WIDTH px = vanilla template content width, source)
# sources: 'icon' = rotate NV/weapon__ master per CFG; 'sprite' = NV/weapon_sprite__ master
# (already horizontal); 'raw:<file>' = scratchpad raw gen (bell)
SPEC = {
 'cleaver':         ((110, 70),  75, 'icon'),
 'rolling_pin':     ((100, 64),  76, 'icon'),
 'skewer':          ((225, 75), 162, 'icon'),
 'cheese_grater':   ((100, 100), 75, 'icon'),
 'whisk':           ((110, 70),  75, 'icon'),
 'ladle':           ((110, 70),  75, 'icon'),
 'baguette':        ((225, 75), 147, 'icon'),
 'butchers_saw':    ((100, 64),  76, 'icon'),
 'meat_tenderizer': ((150, 75),  88, 'icon'),
 'golden_spatula':  ((110, 70),  75, 'icon'),
 'trident_fork':    ((225, 75), 162, 'icon'),
 'pizza_cutter':    ((100, 100), 70, 'icon'),      # vanilla shuriken is 49 but user: too small
 'ice_cream_scoop': ((175, 88),  82, 'icon'),
 'dinner_bell':     ((110, 70),  75, 'raw:gen_dinner_bell.png'),
 'corn_cannon':     ((150, 75), 108, 'sprite'),
 'galley_cannon':   ((150, 75), 108, 'sprite'),
 'sauce_blaster':   ((117, 75),  60, 'sprite'),
 'champagne_popper':((80, 80),   65, 'sprite'),
 'fish_slapper':    ((100, 64),  76, 'sprite'),
 'frying_pan':      ((110, 70),  75, 'sprite'),
}

def source_art(slug):
    kind_src = SPEC[slug][2]
    if kind_src == 'sprite':
        im = Image.open(f'{NV}/weapon_sprite__{slug}.png').convert('RGBA')
        return im.crop(im.getbbox())
    if kind_src.startswith('raw:'):
        gen = Image.open(kind_src[4:]).convert('RGBA')
        a = np.array(gen); a[_flag_small_blobs(a[..., 3] > 128, 1200)] = 0
        im = Image.fromarray(a).rotate(130, expand=True, resample=Image.BICUBIC)
        return im.crop(im.getbbox())
    # icon: rotate per build_held CFG
    _, _, _, extra, fh, fv, _, _ = CFG[slug]
    src = Image.open(f'{NV}/weapon__{slug}.png').convert('RGBA')
    src = src.crop(src.getbbox())
    if fh: src = src.transpose(Image.FLIP_LEFT_RIGHT)
    if fv: src = src.transpose(Image.FLIP_TOP_BOTTOM)
    im = src.rotate(pca_angle(src) + extra, expand=True, resample=Image.BICUBIC)
    return im.crop(im.getbbox())

def base(slug):
    (W, H), target_w, _ = SPEC[slug]
    im = source_art(slug)
    s = target_w / im.width
    if im.height * s > H * 0.95:
        s = H * 0.95 / im.height
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    cv = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cv.alpha_composite(im, ((W - im.width) // 2, (H - im.height) // 2))
    return cv

def main():
    os.makedirs('hand_bases2', exist_ok=True)
    for s in SPEC:
        base(s).save(f'hand_bases2/{s}.png')
        print(s, 'base ok')
    # grid sheet for grip reading
    files = sorted(SPEC)
    COLS = 4; CW = 250; CH = 150
    R = math.ceil(len(files) / COLS)
    sheet = Image.new('RGBA', (COLS * CW, R * CH), (70, 70, 78, 255))
    d = ImageDraw.Draw(sheet)
    for i, s in enumerate(files):
        x0 = (i % COLS) * CW; y0 = (i // COLS) * CH
        im = Image.open(f'hand_bases2/{s}.png')
        z = im.resize((im.width * 2, im.height * 2), Image.NEAREST)
        zf = 2
        if z.width > CW - 8 or z.height > CH - 22:
            z = im.copy(); z.thumbnail((CW - 8, CH - 22)); zf = z.width / im.width
        d.text((x0 + 4, y0 + 2), f'{s} ({im.width}x{im.height})', fill=(255, 255, 255, 255))
        px, py = x0 + 4, y0 + 16
        sheet.alpha_composite(z, (px, py))
        for gx in range(0, im.width + 1, 10):
            X = px + round(gx * zf)
            d.line([X, py, X, py + z.height], fill=(255, 255, 255, 40))
            if gx % 50 == 0: d.text((X, py + z.height + 1), str(gx), fill=(200, 200, 120, 255))
        for gy in range(0, im.height + 1, 10):
            Y = py + round(gy * zf)
            d.line([px, Y, px + z.width, Y], fill=(255, 255, 255, 40))
    sheet.save('hand_grid2.png')
    print('grid saved')

if __name__ == '__main__':
    main()
