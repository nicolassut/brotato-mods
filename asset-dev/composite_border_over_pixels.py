#!/usr/bin/env python3
"""v5: border = YOUR vector (verbatim); interior = crisp original pixels (no smoothing).

- Dark linework (outer border + internal fold lines) is taken from the supplied
  vector render, with its anti-aliasing -> smooth borders.
- The fill inside is the ORIGINAL raster, upscaled NEAREST so pixels stay crisp
  and un-smoothed ("non-vector interior").
- Silhouette = the vector's smooth alpha, so the outer edge is the vector's edge.
- Spill zone: no vector outline, original's soft faded sand kept.
"""
import argparse, sys
import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, "/Users/nicolassutcliffe/brotato-mods/asset-dev")
from vectorize_icon import edge_extend


def luma(rgb):
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def _f(mask, filt):
    return np.array(Image.fromarray((mask * 255).astype("uint8")).filter(filt)) > 128


def dilate(m, r): return _f(m, ImageFilter.MaxFilter(2 * r + 1))
def erode(m, r):  return _f(m, ImageFilter.MinFilter(2 * r + 1))
def opening(m, r): return dilate(erode(m, r), r)


def blur01(m01, r):
    im = Image.fromarray((m01 * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(r))
    return np.array(im).astype(np.float32) / 255.0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("original")
    p.add_argument("vector")
    p.add_argument("outp")
    p.add_argument("--out", dest="out_size", type=int, default=640)
    p.add_argument("--lo", type=int, default=42, help="luma<=lo -> full vector line")
    p.add_argument("--hi", type=int, default=110, help="luma>=hi -> pure interior")
    p.add_argument("--sand", type=int, default=140)
    p.add_argument("--sopen", type=int, default=3)
    p.add_argument("--spad", type=int, default=4)
    p.add_argument("--sfeather", type=float, default=1.5)
    a = p.parse_args()
    N = a.out_size

    # --- vector (border source) at output size ---
    V = Image.open(a.vector).convert("RGBA").resize((N, N), Image.LANCZOS)
    va = np.array(V).astype(np.float32)
    v_rgb = va[..., :3]
    v_alpha = va[..., 3]
    cov = np.clip((a.hi - luma(v_rgb)) / max(a.hi - a.lo, 1), 0.0, 1.0) * (v_alpha / 255.0)

    # --- original interior, kept CRISP (work at 128 then NEAREST up) ---
    O = Image.open(a.original).convert("RGBA")
    oa = np.array(O)
    known = oa[..., 3] >= 128
    tex128 = edge_extend(oa[..., :3].astype(np.uint8).copy(), known.copy(), iters=12)
    tex = np.array(Image.fromarray(tex128, "RGB").resize((N, N), Image.NEAREST)).astype(np.float32)
    o_a = np.array(Image.fromarray(oa[..., 3]).resize((N, N), Image.NEAREST)).astype(np.float32)
    ol = luma(oa[..., :3].astype(np.float32))

    # --- spill (soft, no outline): big sandy blob at native res, NEAREST up ---
    warm = oa[..., 0].astype(np.float32) > oa[..., 2].astype(np.float32) + 12
    sand = (ol > a.sand) & warm & (oa[..., 3] > 128)
    spill128 = dilate(opening(sand, a.sopen), a.spad)
    spill = np.array(Image.fromarray((spill128 * 255).astype("uint8")).resize((N, N), Image.NEAREST))
    spill_soft = blur01((spill > 128).astype(np.float32), a.sfeather)
    cov = cov * (1.0 - spill_soft)

    # --- composite: vector border over crisp interior ---
    out_rgb = tex * (1.0 - cov[..., None]) + v_rgb * cov[..., None]
    out_a = v_alpha * (1.0 - spill_soft) + o_a * spill_soft

    res = np.dstack([np.clip(out_rgb, 0, 255), np.clip(out_a, 0, 255)]).astype(np.uint8)
    Image.fromarray(res, "RGBA").save(a.outp)
    print(f"wrote {a.outp} {N}px lo={a.lo} hi={a.hi}")


if __name__ == "__main__":
    main()
