#!/usr/bin/env python3
"""Turn a high-res vectorized icon into a game-ready Brotato asset.

Brotato item icons are 96x96 px, transparent, item centered with a small
margin. Steps:
  1. autocrop to the opaque bounding box (drop empty margins)
  2. scale the art to fit `target` px on its longest side (LANCZOS = clean
     anti-aliased edges, matching Brotato's soft icon edges)
  3. paste centered onto a `canvas`x`canvas` fully transparent square

Usage: gameready.py IN.png OUT.png [--canvas 96] [--target 86]
"""
import argparse
import numpy as np
from PIL import Image


def gameready(inp, outp, canvas=96, target=86):
    im = Image.open(inp).convert("RGBA")
    a = np.array(im)
    ys, xs = np.where(a[..., 3] > 8)          # opaque pixels
    if len(xs) == 0:
        raise SystemExit("image is fully transparent")
    x0, x1, y0, y1 = xs.min(), xs.max() + 1, ys.min(), ys.max() + 1
    cropped = im.crop((x0, y0, x1, y1))       # 1. autocrop

    w, h = cropped.size
    scale = target / max(w, h)                # 2. fit longest side to target
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    cropped = cropped.resize((nw, nh), Image.LANCZOS)

    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))  # 3. center
    out.alpha_composite(cropped, ((canvas - nw) // 2, (canvas - nh) // 2))
    out.save(outp)
    print(f"wrote {outp}: cropped {w}x{h} -> fit {nw}x{nh} -> {canvas}x{canvas} transparent")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("inp"); p.add_argument("outp")
    p.add_argument("--canvas", type=int, default=96)
    p.add_argument("--target", type=int, default=86)
    p.parse_args()
    a = p.parse_args()
    gameready(a.inp, a.outp, a.canvas, a.target)
