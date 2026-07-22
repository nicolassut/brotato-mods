#!/usr/bin/env python3
"""Held-sprite size pass v3 (user playtest feedback 2026-07-22). Per-weapon target content
WIDTH (px) - small ones +~8%, fish/rolling/spatula/tenderizer bigger, champagne+sauce +40%,
grater smaller. champagne gets a bigger canvas so it can grow past the pistol 80px box.
Skewer/trident keep length (= hit radius). Borders NOT touched here (separate later pass).
Usage: build_held3.py bases | install"""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, '/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
sys.path.append('/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad')
from build_held2 import source_art

DEC = '/Users/nicolassutcliffe/brotato-decompiled'
SC = '/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad'
BK = '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/_pre_vector_backup'

# slug: (canvas, target_content_width, height_fit_px or None)
SPEC = {
 'cleaver':         ((110, 70),  81, None),
 'rolling_pin':     ((100, 64),  90, None),
 'skewer':          ((225, 75), 185, None),   # length = hit radius
 'cheese_grater':   ((100, 100), 80, None),   # was too big
 'whisk':           ((110, 70),  81, None),
 'ladle':           ((110, 70),  81, None),
 'baguette':        ((225, 75), 158, None),
 'butchers_saw':    ((100, 64),  82, None),
 'meat_tenderizer': ((150, 75), 104, None),   # bigger (hammer)
 'golden_spatula':  ((110, 70),  89, None),   # bigger
 'trident_fork':    ((225, 75), 185, None),   # length = hit radius
 'pizza_cutter':    ((100, 100), 75, None),
 'ice_cream_scoop': ((175, 88),  90, None),
 'dinner_bell':     ((110, 70),  81, None),
 'corn_cannon':     ((150, 75),  92, None),
 'galley_cannon':   ((150, 75), 108, None),
 'sauce_blaster':   ((117, 75),  84, None),   # +40%
 'champagne_popper':((110, 90),  92, None),   # +40%, ENLARGED canvas (was 80x80)
 'fish_slapper':    ((100, 64),  90, None),   # bigger
 'frying_pan':      ((110, 70), None, 60),    # height-fit bulky
}
KIND = {'corn_cannon': 'ranged', 'galley_cannon': 'ranged', 'sauce_blaster': 'ranged',
        'champagne_popper': 'ranged', 'pizza_cutter': 'ranged', 'ice_cream_scoop': 'ranged'}

def base(slug):
    (W, H), tw, hf = SPEC[slug]
    im = source_art(slug)
    if hf is not None:
        s = hf / im.height
    else:
        s = tw / im.width
    if im.height * s > H * 0.92:
        s = H * 0.92 / im.height
    if im.width * s > W * 0.96:
        s = W * 0.96 / im.width
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    cv = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cv.alpha_composite(im, ((W - im.width) // 2, (H - im.height) // 2))
    return cv

def main():
    mode = sys.argv[1] if len(sys.argv) > 1 else 'bases'
    os.makedirs('hand_bases3', exist_ok=True)
    for s in SPEC:
        base(s).save(f'hand_bases3/{s}.png')
    if mode == 'bases':
        files = sorted(SPEC)
        COLS = 4; CW = 250; CH = 150
        R = math.ceil(len(files) / COLS)
        sheet = Image.new('RGBA', (COLS * CW, R * CH), (70, 70, 78, 255))
        d = ImageDraw.Draw(sheet)
        for i, s in enumerate(files):
            x0 = (i % COLS) * CW; y0 = (i // COLS) * CH
            im = Image.open(f'hand_bases3/{s}.png')
            z = im.resize((im.width * 2, im.height * 2), Image.NEAREST); zf = 2
            if z.width > CW - 8 or z.height > CH - 22:
                z = im.copy(); z.thumbnail((CW - 8, CH - 22)); zf = z.width / im.width
            b = im.getbbox()
            d.text((x0 + 4, y0 + 2), f'{s} {b[2]-b[0]}x{b[3]-b[1]}', fill=(255, 255, 255, 255))
            px, py = x0 + 4, y0 + 16
            sheet.alpha_composite(z, (px, py))
            for gx in range(0, im.width + 1, 10):
                X = px + round(gx * zf); d.line([X, py, X, py + z.height], fill=(255, 255, 255, 40))
                if gx % 50 == 0: d.text((X, py + z.height + 1), str(gx), fill=(200, 200, 120, 255))
            for gy in range(0, im.height + 1, 10):
                Y = py + round(gy * zf); d.line([px, Y, px + z.width, Y], fill=(255, 255, 255, 40))
        sheet.save('hand_grid3.png'); print('grid saved')

if __name__ == '__main__':
    main()
