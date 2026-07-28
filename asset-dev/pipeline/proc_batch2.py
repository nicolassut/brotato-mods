#!/usr/bin/env python3
"""Content-batch-2 icon post-process. Reuses process_gen recipe but lets the
delivery_drone keep its open quadcopter frame (blanket fill_holes would weld the
rotor gaps into a grey blob). Reads gen_<slug>.png from BROTATO_SCRATCH.
Usage: proc_batch2.py <slug> [...]   (slug WITHOUT gen_ prefix)
"""
import sys, os
import numpy as np
from PIL import Image
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from process_gen import (SCRATCH, ADEV, DEC, VEC, FINAL_DIR, RAW_DIR,
                         thicken, downscale, final_cleanup, fill_holes,
                         vector_prep, outline_med, interior_holes)

# icons whose interior transparency is an INTENTIONAL open frame, not a paint
# hole: fill only tiny shine-dot holes, leave the big see-through gaps open.
SMALL_HOLE_ONLY = {"delivery_drone": 40}

def fill_small_holes(im, max_area):
    from collections import deque
    a = np.array(im)
    hole = interior_holes(a)
    # label hole components, fill only those below max_area
    lab = np.zeros(hole.shape, int); cur = 0
    comp = {}
    for y, x in zip(*np.nonzero(hole)):
        if lab[y, x]:
            continue
        cur += 1; q = deque([(y, x)]); lab[y, x] = cur; pix = []
        while q:
            cy, cx = q.popleft(); pix.append((cy, cx))
            for dy, dx in ((1,0),(-1,0),(0,1),(0,-1)):
                ny, nx = cy+dy, cx+dx
                if 0 <= ny < hole.shape[0] and 0 <= nx < hole.shape[1] and hole[ny, nx] and not lab[ny, nx]:
                    lab[ny, nx] = cur; q.append((ny, nx))
        comp[cur] = pix
    solid = a[..., 3] > 0
    for cid, pix in comp.items():
        if len(pix) > max_area:
            continue
        for y, x in pix:
            nb = [(y+dy, x+dx) for dy in (-1,0,1) for dx in (-1,0,1) if (dy or dx)
                  and 0 <= y+dy < a.shape[0] and 0 <= x+dx < a.shape[1] and solid[y+dy, x+dx]]
            if nb:
                a[y, x, :3] = np.median(np.array([a[p][:3] for p in nb]), axis=0).astype(np.uint8)
                a[y, x, 3] = 255
    return Image.fromarray(a)

def main():
    for slug in sys.argv[1:]:
        im = Image.open(f'{SCRATCH}/gen_{slug}.png').convert('RGBA')
        for W in (3, 4, 5):
            base = final_cleanup(downscale(thicken(im, W)))
            final = fill_small_holes(base, SMALL_HOLE_ONLY[slug]) if slug in SMALL_HOLE_ONLY else fill_holes(base)
            m = outline_med(final)
            if m >= 6:
                break
        final.save(f'{FINAL_DIR["food"]}/{slug}.png')
        im.save(f'{RAW_DIR["food"]}/{slug}.png')
        live = f'{DEC}/items/custom/{slug}/{slug}.png'
        installed = 'adev only'
        if os.path.isdir(os.path.dirname(live)):
            final.save(live)
            installed = 'live+adev'
        vp = fill_holes(vector_prep(im)) if slug not in SMALL_HOLE_ONLY else fill_small_holes(vector_prep(im), SMALL_HOLE_ONLY[slug]*4)
        vp.save(f'{VEC}/{slug}_vecprep.png')
        print(f'{slug}: W={W} outline={m:.0f}px bbox={final.getbbox()} [{installed}]')

if __name__ == '__main__':
    main()
