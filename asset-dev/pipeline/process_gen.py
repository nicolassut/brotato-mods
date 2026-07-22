#!/usr/bin/env python3
"""Process downloaded gen_<slug>.png into installed finals + vecprep staging.
Usage: process_gen.py <pack:appetite|food> <slug> [...]
Steps: auto-thicken outline to >=6px median at 96, downscale to 96 (fill 88),
install to asset-dev final folder + live items/custom/<slug>/<slug>.png, vecprep to staging.
"""
import sys, os, shutil
import numpy as np
from PIL import Image, ImageFilter

SCRATCH = os.environ.get('BROTATO_SCRATCH',
    '/private/tmp/claude-501/-Users-nicolassutcliffe/5eeaab96-3e6e-43a4-a19c-c6809e254d53/scratchpad')
ADEV = '/Users/nicolassutcliffe/brotato-mods/asset-dev'
DEC = '/Users/nicolassutcliffe/brotato-decompiled'
VEC = '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/items_to_vectorize'
FINAL_DIR = {'appetite': f'{ADEV}/items_appetite/final', 'food': f'{ADEV}/items_food_system/final',
             'basic10': '/Users/nicolassutcliffe/brotato-mods/Brotato Icons/scaled_96'}
RAW_DIR = {'appetite': f'{ADEV}/items_appetite/raw', 'food': f'{ADEV}/items_food_system/raw',
           'basic10': f'{ADEV}/items_basic10/raw'}

def outline_med(img):
    a = np.array(img).astype(int)
    alpha = a[..., 3]; lum = a[..., :3].mean(axis=2)
    runs = []
    H, W = alpha.shape
    for y in range(H):
        xs = np.nonzero(alpha[y] > 40)[0]
        if len(xs) < 4: continue
        for x0, step in ((xs[0], 1), (xs[-1], -1)):
            n = 0; x = x0
            while 0 <= x < W and alpha[y, x] > 40 and lum[y, x] < 90 and n < 20: n += 1; x += step
            if n: runs.append(n)
    for x in range(W):
        ys = np.nonzero(alpha[:, x] > 40)[0]
        if len(ys) < 4: continue
        for y0, step in ((ys[0], 1), (ys[-1], -1)):
            n = 0; y = y0
            while 0 <= y < H and alpha[y, x] > 40 and lum[y, x] < 90 and n < 20: n += 1; y += step
            if n: runs.append(n)
    return float(np.median(runs)) if runs else 0.0

def _components(alpha):
    from collections import deque
    solid = alpha > 40
    lab = np.zeros(solid.shape, int); cur = 0
    for y, x in zip(*np.nonzero(solid)):
        if lab[y, x]: continue
        cur += 1; lab[y, x] = cur; q = deque([(y, x)])
        while q:
            cy, cx = q.popleft()
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy+dy, cx+dx
                    if 0 <= ny < solid.shape[0] and 0 <= nx < solid.shape[1] \
                       and solid[ny, nx] and not lab[ny, nx]:
                        lab[ny, nx] = cur; q.append((ny, nx))
    return lab, cur

def thicken(im, W, min_area=250):
    # v2 2026-07-20: dilate the MAIN component(s) only. Small detached bits (sweat
    # drops, sparkles) got W-thick black halos and read as blobs (nervous_wreck redo).
    a0 = np.array(im)
    lab, n = _components(a0[..., 3])
    if n > 1:
        sizes = {i: int((lab == i).sum()) for i in range(1, n+1)}
        keep = [i for i, s in sizes.items() if s >= min_area]
        if keep and len(keep) < n:
            main = np.isin(lab, keep)
            main_img = a0.copy(); main_img[~main] = 0
            small_img = a0.copy(); small_img[main] = 0
            mb = Image.fromarray(main_img).getbbox()
            thick = _thicken_all(Image.fromarray(main_img), W)
            canvas = Image.new('RGBA', (im.width + 2*(W+8), im.height + 2*(W+8)), (0, 0, 0, 0))
            canvas.paste(thick, (mb[0], mb[1]), thick)
            canvas.alpha_composite(Image.fromarray(small_img), (W+8, W+8))
            return canvas
    return _thicken_all(im, W)

def _thicken_all(im, W):
    c = im.crop(im.getbbox())
    pad = Image.new('RGBA', (c.width + 2*(W+8), c.height + 2*(W+8)), (0, 0, 0, 0))
    pad.paste(c, (W+8, W+8), c)
    a = np.array(pad)
    sil = ((a[..., 3] > 40).astype(np.uint8)) * 255
    grown = Image.fromarray(sil).filter(ImageFilter.MaxFilter(2*W+1))
    black = Image.new('RGBA', pad.size, (0, 0, 0, 255))
    empty = Image.new('RGBA', pad.size, (0, 0, 0, 0))
    under = Image.composite(black, empty, grown)
    return Image.alpha_composite(under, pad)

def downscale(im):
    c = im.crop(im.getbbox())
    s = 88 / max(c.size)
    nw, nh = round(c.width*s), round(c.height*s)
    c = c.resize((nw, nh), Image.LANCZOS)
    cv = Image.new('RGBA', (96, 96), (0, 0, 0, 0))
    cv.paste(c, ((96-nw)//2, (96-nh)//2), c)
    return cv

def final_cleanup(img):
    # v2 2026-07-20: saturation-aware. Only unsaturated darks snap to black; saturated
    # dark tones (chili shadows, dark red awning stripes) are legitimate paint. The
    # old lum-only rule turned the chili greenhouse dirty and the user caught it.
    a = np.array(img.convert('RGBA')).astype(int)
    a[a[..., 3] < 110] = 0
    solid = a[..., 3] > 0
    rgb = a[..., :3]
    lum = rgb.mean(axis=2); maxc = rgb.max(axis=2); sat = maxc - rgb.min(axis=2)
    smask = Image.fromarray((solid * 255).astype(np.uint8))
    inner = np.array(smask.filter(ImageFilter.MinFilter(5))) > 127
    edge_band = solid & ~inner
    black = (solid & (maxc < 50)) | (edge_band & (lum < 90) & (sat < 40))
    a[black, 0] = 0; a[black, 1] = 0; a[black, 2] = 0
    return despeckle(Image.fromarray(a.astype(np.uint8)))

def neighbors8(mask):
    n = np.zeros(mask.shape, int)
    for dy in (-1, 0, 1):
        for dx in (-1, 0, 1):
            if dy == 0 and dx == 0: continue
            n += np.roll(np.roll(mask.astype(int), dy, 0), dx, 1)
    return n


def open_enclosed_black(img, rim=9, stroke=5, lumk=70):
    """Remove black POOLS filling the see-through gaps of open structures (whisk wires,
    tapeworm coil, meat-rack frame, cork cage) while keeping every legitimate black stroke.
    A black pixel survives if it is (a) within `rim` px of a coloured pixel - that is the
    outline hugging the parts - or (b) within `stroke` px of transparency - that keeps thin
    isolated black lines (hanging hooks, straps) whose every pixel sits near open air.
    Enclosed pool interiors are far from BOTH, so only they get erased. Tune rim to roughly
    the sprite's outline thickness."""
    a = np.array(img.convert('RGBA')).astype(int)
    alpha = a[..., 3]
    opaque = alpha > 128
    lum = a[..., :3].mean(axis=2)
    black = opaque & (lum < lumk)
    cream = opaque & (lum >= lumk)
    def dil(mask, r):
        if r <= 0:
            return mask
        return np.array(Image.fromarray((mask * 255).astype(np.uint8))
                        .filter(ImageFilter.MaxFilter(2 * r + 1))) > 127
    keep = dil(cream, rim) | dil(~opaque, stroke)
    remove = black & ~keep
    a[remove] = 0
    return Image.fromarray(a.astype(np.uint8))


def remove_black_pools(img, m=5, rim=3, lumk=70):
    """v2 of the gap fix (2026-07-22, after open_enclosed_black ATE the meat rack's hanging
    hooks). Pools are detected by THICKNESS, not distance: erode the black mask by m - only
    the cores of thick pools survive (thin strokes like hooks/straps/joints vanish entirely,
    even when embedded inside a pool) - then grow the cores back by m+1 to recover each pool
    up to its boundary WITHOUT flooding along connected thin arms. Black within `rim` of
    colour is always kept (outline hugging the parts). m ~ half the width of the thinnest
    stroke that must survive; pools thinner than 2m are left alone."""
    a = np.array(img.convert('RGBA')).astype(int)
    alpha = a[..., 3]
    opaque = alpha > 128
    lum = a[..., :3].mean(axis=2)
    black = opaque & (lum < lumk)
    cream = opaque & (lum >= lumk)
    def dil(mask, r):
        if r <= 0:
            return mask
        return np.array(Image.fromarray((mask * 255).astype(np.uint8))
                        .filter(ImageFilter.MaxFilter(2 * r + 1))) > 127
    def ero(mask, r):
        if r <= 0:
            return mask
        return np.array(Image.fromarray((mask * 255).astype(np.uint8))
                        .filter(ImageFilter.MinFilter(2 * r + 1))) > 127
    core = ero(black, m)
    if not core.any():
        return img
    pool = dil(core, m + 1) & black
    remove = pool & ~dil(cream, rim)
    a[remove] = 0
    return Image.fromarray(a.astype(np.uint8))


def restore_thin_from_raw(fixed, raw, target, m_thin=4, lumk=70):
    """User-designed repair (2026-07-22): overlay the RAW generation and restore ONLY the
    thin black structure (hanging hooks, joints, connectors) that the vecprep pipeline lost -
    never the thick pools that were removed on purpose. Needed because vector_prep's
    upscale+median EATS thin strokes before pool removal even runs (the meat rack's hooks
    were never in the vecprep at all). Alignment assumption: vector_prep maps the raw canvas
    to the target by whole-canvas resize, so a NEAREST resize of the raw lines up 1:1.
    Only valid for vecpreps - the live-icon path (crop+fit) has different geometry."""
    ref = raw.convert('RGBA').resize((target, target), Image.NEAREST)
    R = np.array(ref).astype(int)
    R[R[..., 3] < 110] = 0
    rop = R[..., 3] > 0
    lum = R[..., :3].mean(axis=2)
    black = rop & (lum < lumk)
    def dil(m, r):
        return (np.array(Image.fromarray((m * 255).astype(np.uint8))
                         .filter(ImageFilter.MaxFilter(2 * r + 1))) > 127) if r > 0 else m
    def ero(m, r):
        return (np.array(Image.fromarray((m * 255).astype(np.uint8))
                         .filter(ImageFilter.MinFilter(2 * r + 1))) > 127) if r > 0 else m
    pool = dil(ero(black, m_thin), m_thin + 1) & black
    thin = black & ~pool
    F = np.array(fixed.convert('RGBA'))
    take = thin & ~(F[..., 3] > 128)
    F[take, 0] = 0; F[take, 1] = 0; F[take, 2] = 0; F[take, 3] = 255
    return Image.fromarray(F)


def _flag_small_blobs(mask, max_comp):
    """Return a bool array flagging pixels that live in a connected (8-way) component of
    `mask` no larger than max_comp - i.e. small isolated blobs, not long/large shapes."""
    from collections import deque
    H, W = mask.shape
    seen = np.zeros_like(mask); flag = np.zeros_like(mask)
    ys, xs = np.nonzero(mask)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        q = deque([(y0, x0)]); seen[y0, x0] = True; comp = []
        while q:
            cy, cx = q.popleft(); comp.append((cy, cx))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < H and 0 <= nx < W and mask[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx))
        if len(comp) <= max_comp:
            for (y, x) in comp:
                flag[y, x] = True
    return flag


def despeckle(img, thresholds=(72, 118, 168), max_sat=70, max_comp=12, dark_surround=82):
    """Erase the stray light 'dust' specks PixelLab scatters on the black outline and along
    edges - the white dots the user keeps flagging - WITHOUT touching real highlights on a
    light body (e.g. the shine along a whisk's grey wires). Two gates define a border dot:
    (1) it is a SMALL isolated light blob (swept over several absolute thresholds, since a
    grey-on-black rim dot and a white-on-grey dot separate from their body at different
    luminances); (2) its immediate surroundings are dark or transparent - it sits IN the
    outline, not on a lit surface. Saturated colour (gold sparkle, corn, egg, chili) is spared
    by the saturation guard. Each kept speck is inpainted from its neighbours: a rim dot
    becomes black, a dot buried in a wire outline becomes that outline's black. Inpainting one
    dot can expose an adjacent one, so we iterate to convergence (a clump of dots peels one
    ring per pass)."""
    # Two passes only: one clears the dots, a second mops up inpaint artifacts. More passes
    # start PEELING legitimate highlight streaks on dark subjects one ring at a time (it
    # blobbed the near-black frying pan), which is worse than leaving a stray dot or two.
    prev = None
    for _ in range(2):
        img = _despeckle_once(img, thresholds, max_sat, max_comp, dark_surround)
        sig = np.array(img).tobytes()
        if sig == prev:
            break
        prev = sig
    return img


def _despeckle_once(img, thresholds, max_sat, max_comp, dark_surround):
    a = np.array(img.convert('RGBA')).astype(int)
    alpha = a[..., 3]; rgb = a[..., :3]
    opaque = alpha > 128
    lum = rgb.mean(axis=2)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    cand = np.zeros_like(opaque)
    for T in thresholds:
        bright = opaque & (lum > T) & (sat < max_sat)
        if bright.any():
            cand |= _flag_small_blobs(bright, max_comp)
    if not cand.any():
        return img
    H, W = alpha.shape
    # gate 2: keep a candidate blob only if its ring of neighbours is mostly dark/transparent
    flag = np.zeros_like(cand)
    from collections import deque
    seen = np.zeros_like(cand)
    ys, xs = np.nonzero(cand)
    for y0, x0 in zip(ys.tolist(), xs.tolist()):
        if seen[y0, x0]:
            continue
        q = deque([(y0, x0)]); seen[y0, x0] = True; comp = []
        while q:
            cy, cx = q.popleft(); comp.append((cy, cx))
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = cy + dy, cx + dx
                    if 0 <= ny < H and 0 <= nx < W and cand[ny, nx] and not seen[ny, nx]:
                        seen[ny, nx] = True; q.append((ny, nx))
        ring_lum = []
        cset = set(comp)
        for (y, x) in comp:
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < H and 0 <= nx < W and (ny, nx) not in cset and opaque[ny, nx]:
                        ring_lum.append(lum[ny, nx])
        # surrounded by transparency, or by a dark outline -> it is a border dot
        if not ring_lum or np.median(ring_lum) < dark_surround:
            for (y, x) in comp:
                flag[y, x] = True
    if not flag.any():
        return img
    for _ in range(max_comp + 3):
        fy, fx = np.nonzero(flag)
        if len(fy) == 0:
            break
        updates = []
        for y, x in zip(fy.tolist(), fx.tolist()):
            cols = []
            for dy in (-1, 0, 1):
                for dx in (-1, 0, 1):
                    if dy == 0 and dx == 0:
                        continue
                    ny, nx = y + dy, x + dx
                    if 0 <= ny < H and 0 <= nx < W and opaque[ny, nx] and not flag[ny, nx]:
                        cols.append(a[ny, nx, :3])
            if cols:
                updates.append((y, x, np.median(np.array(cols), axis=0)))
        if not updates:
            break
        for y, x, v in updates:
            a[y, x, :3] = v; flag[y, x] = False
    return Image.fromarray(a.astype(np.uint8))

# Icons with dense fine detail (marbling, lettering, spokes, dither shading, packed
# small objects): MedianFilter(9) smears them - use med=5. Audited per icon 2026-07-20.
# Detail-dense items that lose too much when scaled to 128 for vectorizing - keep at 256
# (user flagged deep_fryer 2026-07-20: fries+wire-mesh need the pixels). Bold-simple items
# and all foods go to 128; structures stay 256. Adjust this set as the user calls out items.
BIG_ITEMS_256 = {'deep_fryer','popcorn_machine','ice_cream_truck','chili_greenhouse',
                 'street_vendor','farmers_market','butchers_hook','family_recipe',
                 'fancy_restaurant','second_mortgage','grandmas_cookbook','espresso_machine',
                 'overclocked_chip','after_dinner_mints','frying_pan'}

DETAIL_DENSE = ['butchers_hook', 'chewing_gum', 'ice_cream_truck', 'street_vendor',
                'chili_greenhouse', 'deep_fryer', 'popcorn_machine']

def vector_prep(img, target=128, med=3):
    """Vectorizer input from the RAW generation. Cleans dither, normalizes the outline to
    pure black, then outputs at a SMALL absolute size for vectorizer.ai to trace.
    v11 (2026-07-20 late, user-validated): output SIZE is the whole game. vectorizer.ai only
    smooths pixel-art into curves when the pixel blocks are small; too big and it traces each
    block as geometry = CHUNKY. Smaller = smoother (minor detail loss is fine for these
    shapes). User settled on 128 for items and foods; STRUCTURES stay at 256 (they vectorize
    fine at that size - bold buildings). The raws are ~192, so 128 is a DOWNSCALE - use
    LANCZOS (NEAREST would drop pixels unevenly), then re-binarize to keep hard edges (hard
    beat AA on vectorizer.ai)."""
    # v8 2026-07-20: saturation guards everywhere. The v7 density snap fused the gaps
    # between saturated dark tones (chili greenhouse) into black mush. Saturated pixels
    # are paint, not stroke; only unsaturated darks participate in solidification.
    a = np.array(img.convert('RGBA')).astype(int)
    a[a[..., 3] < 110] = 0
    a[..., 3] = np.where(a[..., 3] > 0, 255, 0)
    rgb = a[..., :3]
    lum = rgb.mean(axis=2); maxc = rgb.max(axis=2); sat = maxc - rgb.min(axis=2)
    solid = a[..., 3] > 0
    black = solid & (maxc < 50)
    a[black, 0] = 0; a[black, 1] = 0; a[black, 2] = 0
    dens = np.array(Image.fromarray((black*255).astype(np.uint8)).filter(ImageFilter.BoxBlur(2))) / 255.0
    snap = solid & (dens >= 0.45) & (lum < 170) & (sat < 40)
    a[snap, 0] = 0; a[snap, 1] = 0; a[snap, 2] = 0
    for _ in range(2):
        solid = a[..., 3] > 0
        rgb = a[..., :3]
        lum = rgb.mean(axis=2); sat = rgb.max(axis=2) - rgb.min(axis=2)
        darkish = solid & (lum < 100) & (sat < 60)
        rim = solid & (neighbors8(~solid) >= 1)
        dn = neighbors8(darkish)
        to_black = rim & (lum < 170) & (lum > 0) & (dn >= 2) & (sat < 50)
        to_erase = rim & (lum >= 90) & (dn == 0)
        a[to_black, 0] = 0; a[to_black, 1] = 0; a[to_black, 2] = 0
        a[to_erase] = 0
    im = Image.fromarray(a.astype(np.uint8))
    if target < im.width:                          # downscale: LANCZOS averages cleanly
        big = im.resize((target, target), Image.LANCZOS)
    else:                                          # upscale: NEAREST + median to round stairs
        big = im.resize((target, target), Image.NEAREST)
        if med >= 3:
            big = big.filter(ImageFilter.MedianFilter(med))
    b = np.array(big).astype(int)
    bs = b[..., 3] >= 128
    b[..., 3] = np.where(bs, 255, 0)
    b[~bs] = 0
    return despeckle(Image.fromarray(b.astype(np.uint8)))

def interior_holes(a):
    from collections import deque
    empty = a[..., 3] == 0
    H, W = empty.shape
    seen = np.zeros_like(empty, bool); q = deque()
    for x in range(W):
        for y in (0, H-1):
            if empty[y, x] and not seen[y, x]: seen[y, x] = True; q.append((y, x))
    for y in range(H):
        for x in (0, W-1):
            if empty[y, x] and not seen[y, x]: seen[y, x] = True; q.append((y, x))
    while q:
        y, x = q.popleft()
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            ny, nx = y+dy, x+dx
            if 0 <= ny < H and 0 <= nx < W and empty[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True; q.append((ny, nx))
    return empty & ~seen

def fill_holes(im):
    # PixelLab "white" is sometimes alpha-0 (tapeworm dither, market awning stripes).
    # Fill interior transparent pixels with the median of their solid neighbours.
    a = np.array(im)
    while True:
        hole = interior_holes(a)
        if not hole.any(): break
        solid = a[..., 3] > 0; any_f = False
        for y, x in zip(*np.nonzero(hole)):
            nb = [(y+dy, x+dx) for dy in (-1, 0, 1) for dx in (-1, 0, 1) if (dy or dx)
                  and 0 <= y+dy < a.shape[0] and 0 <= x+dx < a.shape[1] and solid[y+dy, x+dx]]
            if nb:
                a[y, x, :3] = np.median(np.array([a[p][:3] for p in nb]), axis=0).astype(np.uint8)
                a[y, x, 3] = 255; any_f = True
        if not any_f: break
    return Image.fromarray(a)

def main():
    pack = sys.argv[1]
    for slug in sys.argv[2:]:
        src = f'{SCRATCH}/gen_{slug}.png'
        im = Image.open(src).convert('RGBA')
        for W in (3, 4, 5):
            final = fill_holes(final_cleanup(downscale(thicken(im, W))))
            m = outline_med(final)
            if m >= 6:
                break
        final.save(f'{FINAL_DIR[pack]}/{slug}.png')
        im.save(f'{RAW_DIR[pack]}/{slug}.png')
        live = f'{DEC}/items/custom/{slug}/{slug}.png'
        if os.path.isdir(os.path.dirname(live)):
            final.save(live)
            installed = 'live+adev'
        else:
            installed = 'adev only'
        fill_holes(vector_prep(im)).save(f'{VEC}/{slug}_vecprep.png')
        print(f'{slug}: W={W} outline={m:.0f}px bbox={final.getbbox()} [{installed}]')

if __name__ == '__main__':
    main()
