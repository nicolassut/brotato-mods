#!/usr/bin/env python3
"""Build in-game held sprites for the 13 mod weapons that still have placeholders
(dinner_bell joins once its icon renders). Source = the weapon's vectorized 640 master, so
the held sprite matches the icon art exactly. Auto-rotate to horizontal (PCA) + per-weapon
manual tweak, business end RIGHT, vanilla potato fist composited at the grip.
Usage: build_held.py preview|install [slug ...]"""
import sys, os, math
import numpy as np
from PIL import Image, ImageDraw

NV = '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/New_Vectorized_Icons'
DEC = '/Users/nicolassutcliffe/brotato-decompiled'
SC = '/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad'
BK = '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/_pre_vector_backup'

# slug: (kind, canvas, fill, extra_rot_deg CCW after PCA, flip_h, flip_v, hand (fx,fy) or None, hand_scale)
CFG = {
 'cleaver':         ('melee', (110, 70), 0.94,   0, False, False, (0.10, 0.52), 1.0),
 'rolling_pin':     ('melee', (100, 64), 0.96,   0, False, False, (0.10, 0.50), 1.0),
 'skewer':          ('melee', (225, 75), 0.97, 180, False, False, (0.22, 0.55), 1.1),
 'cheese_grater':   ('melee', (100, 100), 0.75,   0, True,  False, (0.16, 0.42), 1.0),
 'whisk':           ('melee', (110, 70), 0.95,   0, False, False, (0.10, 0.50), 1.0),
 'ladle':           ('melee', (110, 70), 0.95, 180, False, False, (0.10, 0.50), 1.0),
 'baguette':        ('melee', (225, 75), 0.97,   0, False, False, (0.22, 0.52), 1.1),
 'butchers_saw':    ('melee', (100, 64), 0.96,   0, False, False, (0.10, 0.50), 1.0),
 'meat_tenderizer': ('melee', (150, 75), 0.95,   0, False, False, (0.10, 0.52), 1.0),
 'golden_spatula':  ('melee', (110, 70), 0.94,   0, False, False, (0.10, 0.50), 1.0),
 'trident_fork':    ('melee', (225, 75), 0.97,   0, False, False, (0.22, 0.53), 1.1),
 'pizza_cutter':    ('ranged', (100, 100), 0.62,   0, False, False, (0.25, 0.45), 1.0),
 'ice_cream_scoop': ('ranged', (175, 88), 0.92,  0, False, True,  (0.12, 0.50), 1.1),  # flip_v: user wanted the scoop mirrored vertically (2026-07-22)
 'dinner_bell':     ('melee', (110, 70), 0.92,   0, False, False, (0.10, 0.50), 1.0),
}

def hand_stamp():
    im = Image.open(f'{DEC}/weapons/melee/hatchet/hatchet.png').convert('RGBA')
    box = im.crop((14, 16, 48, 42))
    a = np.array(box).astype(int)
    lum = a[..., :3].mean(2); sat = a[..., :3].max(2) - a[..., :3].min(2)
    white = (a[..., 3] > 128) & (lum > 165) & (sat < 45)
    from PIL import ImageFilter
    keep = np.array(Image.fromarray((white * 255).astype(np.uint8)).filter(ImageFilter.MaxFilter(7))) > 127
    a[~keep] = 0
    st = Image.fromarray(a.astype(np.uint8))
    return st.crop(st.getbbox())

def pca_angle(im):
    a = np.array(im)[..., 3] > 128
    ys, xs = np.nonzero(a)
    x = xs - xs.mean(); y = ys - ys.mean()
    cxx = (x * x).mean(); cyy = (y * y).mean(); cxy = (x * y).mean()
    return math.degrees(0.5 * math.atan2(2 * cxy, cxx - cyy))

def build(slug):
    kind, canvas, fill, extra, fh, fv, hand, hscale = CFG[slug]
    src = Image.open(f'{NV}/weapon__{slug}.png').convert('RGBA')
    src = src.crop(src.getbbox())
    if fh: src = src.transpose(Image.FLIP_LEFT_RIGHT)
    if fv: src = src.transpose(Image.FLIP_TOP_BOTTOM)
    ang = pca_angle(src)
    im = src.rotate(ang + extra, expand=True, resample=Image.BICUBIC)
    im = im.crop(im.getbbox())
    W, H = canvas
    s = min(W * fill / im.width, H * fill / im.height)
    im = im.resize((max(1, round(im.width * s)), max(1, round(im.height * s))), Image.LANCZOS)
    cv = Image.new('RGBA', (W, H), (0, 0, 0, 0))
    cv.alpha_composite(im, ((W - im.width) // 2, (H - im.height) // 2))
    if hand:
        st = HAND.resize((max(1, round(HAND.width * hscale * W / 110)),
                          max(1, round(HAND.height * hscale * W / 110))), Image.LANCZOS)
        hx = round(hand[0] * W - st.width / 2); hy = round(hand[1] * H - st.height / 2)
        cv.alpha_composite(st, (hx, hy))
    return cv

HAND = hand_stamp()

def main():
    mode = sys.argv[1]
    slugs = sys.argv[2:] or [s for s in CFG if s != 'dinner_bell']
    outs = {}
    for s in slugs:
        if not os.path.exists(f'{NV}/weapon__{s}.png'):
            print(f'{s}: no master, skip'); continue
        outs[s] = build(s)
    if mode == 'preview':
        COLS = 4; CELL = 250
        R = math.ceil(len(outs) / COLS)
        sheet = Image.new('RGBA', (COLS * CELL, R * 120), (90, 90, 98, 255))
        d = ImageDraw.Draw(sheet)
        for i, (s, im) in enumerate(outs.items()):
            x = (i % COLS) * CELL; y = (i // COLS) * 120
            d.text((x + 4, y + 2), f'{s} {im.size}', fill=(255, 255, 255, 255))
            t = im.copy(); t.thumbnail((CELL - 12, 96))
            sheet.alpha_composite(t, (x + 6, y + 16))
        sheet.save(f'{SC}/held_preview.png')
        print('preview saved:', len(outs))
    else:
        os.makedirs(BK, exist_ok=True)
        import shutil
        for s, im in outs.items():
            kind = CFG[s][0]
            live = f'{DEC}/weapons/{kind}/{s}/{s}.png'
            tag = live.replace('/', '__')[-120:]
            if not os.path.exists(f'{BK}/{tag}'):
                shutil.copy2(live, f'{BK}/{tag}')
            im.save(live)
            print(f'{s}: INSTALLED {im.size}')

if __name__ == '__main__':
    main()
