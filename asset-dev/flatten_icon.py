#!/usr/bin/env python3
"""Brotato-style FLATTEN pipeline.

Real Brotato icons are a few FLAT solid colors with clean smooth edges and
almost no shading. This pass makes an AI generation look redrawn rather than
blurred:

  1. LANCZOS upscale 96 -> size
  2. light pre-blur (merge gradient noise so quantize finds clean regions)
  3. quantize interior to N flat colors, no dithering  -> solid color regions
  4. median filter -> smooth, round, de-speckle the region boundaries
  5. stamp uniform black rim (thickness px) -> bold consistent outline
  6. optional tiny final blur to soften region seams a hair

Usage: flatten_icon.py IN.png OUT.png [--size 256] [--colors 8]
       [--pre-blur 1.5] [--median 5] [--thickness 8] [--final-blur 0.3]
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
    a[rim, :3] = 0
    a[rim, 3] = 255
    return Image.fromarray(a)


def edge_extend(rgb, alpha_mask, iters):
    """Bleed opaque colors outward into transparent pixels so quantize/median
    don't pull a halo across the alpha boundary."""
    arr = np.array(rgb).astype(np.uint8)
    known = alpha_mask.copy()
    for _ in range(iters):
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            shifted_known = np.roll(np.roll(known, dy, axis=0), dx, axis=1)
            shifted_col = np.roll(np.roll(arr, dy, axis=0), dx, axis=1)
            fill = shifted_known & ~known
            arr[fill] = shifted_col[fill]
            known = known | fill
    return Image.fromarray(arr)


def process(inp, size, colors, pre_blur, median, thickness, final_blur):
    img = Image.open(inp).convert("RGBA").resize((size, size), Image.LANCZOS)
    alpha = np.array(img)[..., 3]
    mask = alpha >= 128

    rgb = img.convert("RGB")
    rgb = edge_extend(rgb, mask, iters=max(thickness + 2, 6))
    if pre_blur > 0:
        rgb = rgb.filter(ImageFilter.GaussianBlur(pre_blur))
    q = rgb.quantize(colors=colors, method=Image.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    if median and median >= 3:
        q = q.filter(ImageFilter.MedianFilter(median if median % 2 else median + 1))

    out = q.convert("RGBA")
    out.putalpha(Image.fromarray(alpha))
    out = stamp_rim(out, thickness)
    if final_blur > 0:
        out = out.filter(ImageFilter.GaussianBlur(final_blur))
    return out


def main():
    p = argparse.ArgumentParser()
    p.add_argument("inp"); p.add_argument("outp")
    p.add_argument("--size", type=int, default=256)
    p.add_argument("--colors", type=int, default=8)
    p.add_argument("--pre-blur", type=float, default=1.5)
    p.add_argument("--median", type=int, default=5)
    p.add_argument("--thickness", type=int, default=8)
    p.add_argument("--final-blur", type=float, default=0.3)
    a = p.parse_args()
    out = process(a.inp, a.size, a.colors, a.pre_blur, a.median, a.thickness, a.final_blur)
    out.save(a.outp)
    print(f"wrote {a.outp} ({out.size[0]}px) colors={a.colors} pre_blur={a.pre_blur} median={a.median} rim={a.thickness}")


if __name__ == "__main__":
    main()
