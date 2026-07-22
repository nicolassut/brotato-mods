#!/usr/bin/env python3
"""Thicken ALL dark lines (outer outline + internal lines) uniformly to match
Brotato's consistent heavy black line weight.

Approach: identify "line" pixels = opaque AND dark (low luminance), then
morphologically dilate that mask and paint it pure black. Because it targets
dark pixels rather than the alpha edge, it thickens internal lines too.

Usage: thicken_lines.py IN.png OUT.png [--radius N] [--lum T] [--upscale 96]
"""
import sys, argparse
import numpy as np
from PIL import Image


def thicken(img: Image.Image, radius: int, lum_thresh: int, alpha_thresh: int) -> Image.Image:
    img = img.convert("RGBA")
    a = np.array(img)
    rgb = a[..., :3].astype(np.int32)
    alpha = a[..., 3]
    lum = (0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2])
    line = (lum <= lum_thresh) & (alpha >= alpha_thresh)

    # square dilation via max-pooling over shifts
    mask = line.copy()
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx * dx + dy * dy > radius * radius:  # circular kernel
                continue
            shifted = np.roll(np.roll(line, dy, axis=0), dx, axis=1)
            mask |= shifted

    out = a.copy()
    out[mask, 0] = 0
    out[mask, 1] = 0
    out[mask, 2] = 0
    out[mask, 3] = 255
    return Image.fromarray(out, "RGBA")


def _disk(mask: np.ndarray, radius: int) -> np.ndarray:
    """Morphological dilation of a boolean mask with a circular kernel."""
    out = mask.copy()
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx * dx + dy * dy > radius * radius:
                continue
            out |= np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
    return out


def rim_outline(img: Image.Image, thickness: int, alpha_thresh: int) -> Image.Image:
    """Replace only the outermost `thickness` px rim of the shape with uniform
    black, leaving the interior fully smooth and untouched. Color-independent —
    works the same on a red blob or a silver hat."""
    img = img.convert("RGBA")
    a = np.array(img)
    shape = a[..., 3] >= alpha_thresh

    # erode shape by `thickness` -> interior; rim = shape AND NOT interior.
    # erosion = NOT dilate(NOT shape)
    interior = ~_disk(~shape, thickness)
    rim = shape & ~interior

    out = a.copy()
    out[rim, 0] = 0
    out[rim, 1] = 0
    out[rim, 2] = 0
    out[rim, 3] = 255
    return Image.fromarray(out)


def main():
    p = argparse.ArgumentParser()
    p.add_argument("inp")
    p.add_argument("outp")
    p.add_argument("--mode", choices=["lines", "rim"], default="rim",
                   help="rim: blacken only the outer edge (smooth interior); lines: dilate all dark pixels")
    p.add_argument("--radius", type=int, default=1, help="lines mode: dilation radius")
    p.add_argument("--thickness", type=int, default=3, help="rim mode: black rim thickness in px")
    p.add_argument("--lum", type=int, default=70, help="lines mode: max luminance counted as a line pixel")
    p.add_argument("--alpha", type=int, default=128)
    p.add_argument("--upscale", type=int, default=0, help="final square size")
    p.add_argument("--resample", choices=["nearest", "lanczos"], default="nearest",
                   help="lanczos = smooth (de-pixelate); nearest = crisp pixels")
    p.add_argument("--blur", type=float, default=0.0,
                   help="Gaussian blur radius applied after upscale to melt residual pixelation")
    args = p.parse_args()

    img = Image.open(args.inp)
    if args.mode == "rim":
        out = rim_outline(img, args.thickness, args.alpha)
        desc = f"rim thickness={args.thickness}"
    else:
        out = thicken(img, args.radius, args.lum, args.alpha)
        desc = f"lines radius={args.radius} lum<={args.lum}"
    if args.upscale:
        flt = Image.LANCZOS if args.resample == "lanczos" else Image.NEAREST
        out = out.resize((args.upscale, args.upscale), flt)
    if args.blur > 0:
        from PIL import ImageFilter
        out = out.filter(ImageFilter.GaussianBlur(args.blur))
    out.save(args.outp)
    print(f"wrote {args.outp} ({out.size[0]}x{out.size[1]}) {desc} resample={args.resample} blur={args.blur}")


if __name__ == "__main__":
    main()
