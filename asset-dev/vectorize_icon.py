#!/usr/bin/env python3
"""Brotato-style VECTORIZE pipeline. No blur, ever — crisp clean vector edges.

  1. LANCZOS upscale 96 -> work size
  2. edge-extend colors into transparency (no halo), stamp bold black rim
  3. vtracer -> SVG: smooth spline paths, flat colors, speckle filtered
     (crisp vector eyes / mouth / edges)
  4. render SVG -> raster, re-apply original silhouette alpha for clean cutout

Usage: vectorize_icon.py IN.png OUT.png [--work 512] [--out 320]
       [--colors 6] [--speckle 8] [--thickness 10] [--corner 60]
"""
import argparse, tempfile, os
import numpy as np
from PIL import Image
import vtracer
from svglib.svglib import svg2rlg
from reportlab.graphics import renderPM


def _disk(mask, radius):
    out = mask.copy()
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx * dx + dy * dy > radius * radius:
                continue
            out |= np.roll(np.roll(mask, dy, axis=0), dx, axis=1)
    return out


def edge_extend(arr, known, iters):
    for _ in range(iters):
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sk = np.roll(np.roll(known, dy, axis=0), dx, axis=1)
            sc = np.roll(np.roll(arr, dy, axis=0), dx, axis=1)
            fill = sk & ~known
            arr[fill] = sc[fill]
            known = known | fill
    return arr


def prep(inp, work, thickness, colors):
    img = Image.open(inp).convert("RGBA").resize((work, work), Image.LANCZOS)
    a = np.array(img)
    alpha = a[..., 3]
    mask = alpha >= 128
    rgb = edge_extend(a[..., :3].copy(), mask.copy(), iters=max(thickness + 2, 8))
    # quantize the interior to a controlled few flat colors (keeps cork vs glass
    # separated instead of merging) BEFORE stamping the outline
    q = Image.fromarray(rgb, "RGB").quantize(
        colors=colors, method=Image.MEDIANCUT, dither=Image.Dither.NONE).convert("RGB")
    rgb = np.array(q)
    # stamp bold black rim onto the RGB so vtracer traces a clean outline
    interior = ~_disk(~mask, thickness)
    rim = mask & ~interior
    rgb[rim] = 0
    out = np.dstack([rgb, np.where(mask, 255, 0).astype(np.uint8)])
    return Image.fromarray(out, "RGBA"), alpha


def render_svg(svg_path, out_size, supersample=3):
    """Render big then downscale = smooth anti-aliased edges (renderPM itself
    does not anti-alias, so we supersample)."""
    drawing = svg2rlg(svg_path)
    big = out_size * supersample
    sx, sy = big / drawing.width, big / drawing.height
    drawing.scale(sx, sy)
    drawing.width, drawing.height = big, big
    pil = renderPM.drawToPIL(drawing, bg=0xffffff).convert("RGB")
    return pil.resize((out_size, out_size), Image.LANCZOS)


def process(inp, work, out_size, colors, speckle, thickness, corner):
    prepped, alpha = prep(inp, work, thickness, colors)
    with tempfile.TemporaryDirectory() as td:
        pin = os.path.join(td, "in.png")
        psvg = os.path.join(td, "out.svg")
        prepped.convert("RGB").save(pin)
        vtracer.convert_image_to_svg_py(
            pin, psvg,
            colormode="color", hierarchical="stacked", mode="spline",
            filter_speckle=speckle, color_precision=8,
            layer_difference=8, corner_threshold=corner,
            length_threshold=4.0, splice_threshold=45, path_precision=8,
        )
        rendered = render_svg(psvg, out_size)
    # clean cutout using original silhouette
    amask = np.array(Image.fromarray(alpha).resize((out_size, out_size), Image.LANCZOS))
    rgba = np.dstack([np.array(rendered), amask])
    return Image.fromarray(rgba, "RGBA")


def main():
    p = argparse.ArgumentParser()
    p.add_argument("inp"); p.add_argument("outp")
    p.add_argument("--work", type=int, default=512)
    p.add_argument("--out", dest="out_size", type=int, default=320)
    p.add_argument("--colors", type=int, default=6)
    p.add_argument("--speckle", type=int, default=8)
    p.add_argument("--thickness", type=int, default=10)
    p.add_argument("--corner", type=int, default=60)
    a = p.parse_args()
    out = process(a.inp, a.work, a.out_size, a.colors, a.speckle, a.thickness, a.corner)
    out.save(a.outp)
    print(f"wrote {a.outp} ({out.size[0]}px) colors={a.colors} speckle={a.speckle} rim={a.thickness}")


if __name__ == "__main__":
    main()
