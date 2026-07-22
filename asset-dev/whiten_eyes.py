#!/usr/bin/env python3
"""Normalize eye catchlights to PURE white. Light specks enclosed by dark
(the shine inside black eyes) get forced to #FFFFFF so a vectorizer keeps them
as one unambiguous white -- never splitting one to the cheek color."""
import sys
import numpy as np
from PIL import Image


def whiten(inp, outp, radius=4, dark_frac=0.40, light_lum=150, dark_lum=70):
    a = np.array(Image.open(inp).convert("RGBA"))
    rgb = a[..., :3].astype(np.int32)
    al = a[..., 3]
    lum = 0.299 * rgb[..., 0] + 0.587 * rgb[..., 1] + 0.114 * rgb[..., 2]
    light = (lum >= light_lum) & (al >= 128)
    dark = (lum <= dark_lum) & (al >= 128)
    darkcount = np.zeros(dark.shape, np.float32)
    total = 0
    for dy in range(-radius, radius + 1):
        for dx in range(-radius, radius + 1):
            if dx * dx + dy * dy > radius * radius:
                continue
            total += 1
            darkcount += np.roll(np.roll(dark, dy, 0), dx, 1).astype(np.float32)
    enclosed = light & (darkcount / total >= dark_frac)
    out = a.copy()
    out[enclosed, 0] = 255
    out[enclosed, 1] = 255
    out[enclosed, 2] = 255
    out[enclosed, 3] = 255
    Image.fromarray(out).save(outp)
    print(f"wrote {outp}: {int(enclosed.sum())} catchlight px -> pure white")


if __name__ == "__main__":
    whiten(sys.argv[1], sys.argv[2])
