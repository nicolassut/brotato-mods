#!/usr/bin/env python3
"""gen_<slug>.png -> 96px item icon installed to items/custom/<slug>/<slug>.png (live) +
asset-dev/items_newpack/raw + 128px vecprep (256 if detail-dense) into TO_VECTORIZE.
Usage: process_newpack.py <slug> [...]"""
import sys, os
sys.path.insert(0, '/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
from process_gen import thicken, downscale, final_cleanup, outline_med, vector_prep, fill_holes, BIG_ITEMS_256
from PIL import Image
SCRATCH = '/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad'
ADEV = '/Users/nicolassutcliffe/brotato-mods/asset-dev'
DEC = '/Users/nicolassutcliffe/brotato-decompiled'
TV = '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/TO_VECTORIZE'

for slug in sys.argv[1:]:
    gen = Image.open(f'{SCRATCH}/gen_{slug}.png').convert('RGBA')
    gen.save(f'{ADEV}/items_newpack/raw/{slug}.png')
    for W in (3, 4, 5):
        final = final_cleanup(downscale(thicken(gen, W)))
        m = outline_med(final)
        if m >= 6:
            break
    live = f'{DEC}/items/custom/{slug}/{slug}.png'
    installed = 'adev only'
    if os.path.isdir(os.path.dirname(live)):
        final.save(live)
        installed = 'LIVE'
    tgt = 256 if slug in BIG_ITEMS_256 else 128
    fill_holes(vector_prep(gen, target=tgt)).save(f'{TV}/item__{slug}.png')
    print(f'{slug}: W={W} outline={m:.0f}px vec={tgt}px [{installed}]')
