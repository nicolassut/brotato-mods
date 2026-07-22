#!/usr/bin/env python3
"""Brotato-style icon post-process pipeline.

Order matters: smooth the INTERIOR first, then stamp a crisp bold black rim on
top so the outline stays defined while pixelation in the fill melts away.

Steps:
  1. LANCZOS upscale 96 -> target (de-pixelates gradients)
  2. Gaussian blur the whole image (melts residual pixel edges into soft fill)
  3. Stamp uniform black rim of `thickness` px at target resolution (crisp,
     color-independent outline of consistent weight on every item)
  4. optional tiny final blur to marry rim<->interior without going soft

Usage: process_icon.py IN.png OUT.png [--size 256] [--blur 2.0]
                       [--thickness 8] [--final-blur 0.4]
"""
import argparse
import numpy as np
from PIL import Image, ImageFilter


def _disk(mask, radius):
    out = mask.copy()
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx * dx + dy * dy > radius * radius:
                continue
            out |= np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
    return out


def stamp_rim(img, thickness, alpha_thresh=128):
    a = np.array(img.convert("RGBA"))
    shape = a[..., 3] >= alpha_thresh
    interior = ~_disk(~shape, thickness)
    rim = shape & ~interior
    a[rim, 0] = 0
    a[rim, 1] = 0
    a[rim, 2] = 0
    a[rim, 3] = 255
    return Image.fromarray(a)


def process(inp, size, blur, thickness, final_blur):
    img = Image.open(inp).convert("RGBA")
    img = img.resize((size, size), Image.LANCZOS)          # 1. de-pixelate
    if blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(blur))    # 2. melt fill
    img = stamp_rim(img, thickness)                         # 3. crisp bold rim
    if final_blur > 0:
        img = img.filter(ImageFilter.GaussianBlur(final_blur))  # 4. marry
    return img


def main():
    p = argparse.ArgumentParser()
    p.add_argument("inp")
    p.add_argument("outp")
    p.add_argument("--size", type=int, default=256)
    p.add_argument("--blur", type=float, default=2.0)
    p.add_argument("--thickness", type=int, default=8)
    p.add_argument("--final-blur", type=float, default=0.4)
    a = p.parse_args()
    out = process(a.inp, a.size, a.blur, a.thickness, a.final_blur)
    out.save(a.outp)
    print(f"wrote {a.outp} ({out.size[0]}px) blur={a.blur} rim={a.thickness} final_blur={a.final_blur}")


if __name__ == "__main__":
    main()
