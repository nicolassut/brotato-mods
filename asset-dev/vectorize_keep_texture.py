#!/usr/bin/env python3
"""v4: border + silhouette come 100% from the vector; only the interior fill
is swapped for the original texture.

v3's bug: it used the ORIGINAL's jagged alpha for the outer edge, so the
pixelated silhouette leaked past the smooth rim. Here the alpha is the pure
vector's alpha everywhere (identical smooth border), EXCEPT inside the spill
zone, where the original's soft faded sand is used instead of the hard blob.
"""
import argparse, sys
import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, "/Users/nicolassutcliffe/brotato-mods/asset-dev")
from vectorize_icon import process, edge_extend


def luma(rgb):
    return 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]


def _f(mask, filt):
    return np.array(Image.fromarray((mask * 255).astype("uint8")).filter(filt)) > 128


def dilate(m, r):
    return _f(m, ImageFilter.MaxFilter(2 * r + 1))


def erode(m, r):
    return _f(m, ImageFilter.MinFilter(2 * r + 1))


def opening(m, r):
    return dilate(erode(m, r), r)


def blur01(m01, r):
    im = Image.fromarray((m01 * 255).astype("uint8")).filter(ImageFilter.GaussianBlur(r))
    return np.array(im).astype(np.float32) / 255.0


def main():
    p = argparse.ArgumentParser()
    p.add_argument("inp"); p.add_argument("outp")
    p.add_argument("--out", dest="out_size", type=int, default=320)
    p.add_argument("--lo", type=int, default=32)
    p.add_argument("--hi", type=int, default=110)
    p.add_argument("--sand", type=int, default=140)
    p.add_argument("--sopen", type=int, default=5)
    p.add_argument("--spad", type=int, default=6)
    p.add_argument("--sfeather", type=float, default=2.0)
    p.add_argument("--work", type=int, default=512)
    p.add_argument("--colors", type=int, default=6)
    p.add_argument("--speckle", type=int, default=8)
    p.add_argument("--thick", type=int, default=12)
    p.add_argument("--corner", type=int, default=60)
    a = p.parse_args()
    N = a.out_size

    # pure vector: smooth border + smooth silhouette (this is our edge, verbatim)
    V = process(a.inp, a.work, N, a.colors, a.speckle, a.thick, a.corner)
    va = np.array(V).astype(np.float32)
    v_rgb = va[..., :3]
    v_alpha = va[..., 3]
    v_lum = luma(v_rgb)
    # soft black coverage from the vector (its border + internal lines, with AA)
    cov = np.clip((a.hi - v_lum) / max(a.hi - a.lo, 1), 0.0, 1.0) * (v_alpha / 255.0)

    # original texture, edge-extended so there are no transparent holes under the rim
    O = Image.open(a.inp).convert("RGBA").resize((N, N), Image.LANCZOS)
    oa = np.array(O)
    o_a = oa[..., 3].astype(np.float32)
    known = oa[..., 3] >= 128
    tex = edge_extend(oa[..., :3].astype(np.uint8).copy(), known.copy(), iters=10).astype(np.float32)
    ol = luma(oa[..., :3].astype(np.float32))

    # spill = large sandy blob (thin drawstrings/specks removed by opening)
    warm = oa[..., 0].astype(np.float32) > oa[..., 2].astype(np.float32) + 12
    sand = (ol > a.sand) & warm & (oa[..., 3] > 128)
    spill_soft = blur01(dilate(opening(sand, a.sopen), a.spad).astype(np.float32), a.sfeather)

    # no black rim inside the spill
    cov = cov * (1.0 - spill_soft)

    # RGB: texture interior with vector black composited over it
    out_rgb = tex * (1.0 - cov[..., None])

    # ALPHA: pure-vector silhouette everywhere, original soft alpha inside spill
    out_a = v_alpha * (1.0 - spill_soft) + o_a * spill_soft

    res = np.dstack([np.clip(out_rgb, 0, 255), np.clip(out_a, 0, 255)]).astype(np.uint8)
    Image.fromarray(res, "RGBA").save(a.outp)
    V.save(a.outp.replace(".png", "__purevector.png"))
    print(f"wrote {a.outp} lo={a.lo} hi={a.hi} thick={a.thick}")


if __name__ == "__main__":
    main()
