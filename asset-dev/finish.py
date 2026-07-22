#!/usr/bin/env python3
"""Finish a GOOD vectorized icon for the game. Two steps only — no re-tracing,
no flatten, no blur:

  1. thicken the black outline a bit (dilate the dark line pixels; thickens
     the border and internal feature lines uniformly, Brotato-style)
  2. downscale to the game size (LANCZOS), then center on a transparent square

Usage: finish.py IN.png OUT.png [--grow 2] [--canvas 96] [--target 88]
"""
import argparse
import numpy as np
from PIL import Image


def thicken_border(im, grow, lum_thresh=70, alpha_thresh=128):
    a = np.array(im.convert("RGBA"))
    rgb = a[..., :3].astype(np.int32)
    al = a[..., 3]
    lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    line = (lum <= lum_thresh) & (al >= alpha_thresh)
    mask = line.copy()
    for dy in range(-grow, grow + 1):
        for dx in range(-grow, grow + 1):
            if dx * dx + dy * dy > grow * grow:
                continue
            mask |= np.roll(np.roll(line, dy, 0), dx, 1)
    out = a.copy()
    out[mask, 0] = 0
    out[mask, 1] = 0
    out[mask, 2] = 0
    out[mask, 3] = 255
    return Image.fromarray(out)


def finish(inp, outp, grow, canvas, target):
    im = Image.open(inp).convert("RGBA")
    im = thicken_border(im, grow)               # 1. thicker border (at full res)
    a = np.array(im)
    ys, xs = np.where(a[..., 3] > 8)
    im = im.crop((xs.min(), ys.min(), xs.max() + 1, ys.max() + 1))  # autocrop
    w, h = im.size
    s = target / max(w, h)
    nw, nh = max(1, round(w * s)), max(1, round(h * s))
    im = im.resize((nw, nh), Image.LANCZOS)     # 2. downscale to game size
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    out.alpha_composite(im, ((canvas - nw) // 2, (canvas - nh) // 2))
    out.save(outp)
    print(f"wrote {outp}: grow={grow} -> {nw}x{nh} -> {canvas}x{canvas}")


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("inp"); p.add_argument("outp")
    p.add_argument("--grow", type=int, default=2, help="border thickening radius (full-res px)")
    p.add_argument("--canvas", type=int, default=96)
    p.add_argument("--target", type=int, default=88)
    a = p.parse_args()
    finish(a.inp, a.outp, a.grow, a.canvas, a.target)
