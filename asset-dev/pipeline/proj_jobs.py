#!/usr/bin/env python3
"""Queue the 6 ranged-weapon projectile sprites on PixelLab. Prints slug=object_id.
Usage: proj_jobs.py <slug> [...]  (slug = proj_<weapon>)"""
import json, subprocess, sys
sys.path.insert(0, '/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
from sweep_jobs import style_b64

TAIL = (", bold thick chunky black outline, flat cartoon colors, isolated single object on "
        "transparent background, small 2D video game projectile sprite")

JOBS = {
 "proj_corn_cannon": ("fruit_food", "a single plump ripe corn cob flying horizontally pointing to the right, bright golden yellow kernels in neat rows, two little green husk leaves peeled back at the left tail end, a small motion streak behind it" + TAIL),
 "proj_galley_cannon": ("fruit_food", "a single round solid black cast iron cannonball, a small round white highlight glint on the upper left, perfectly round smooth and simple, dark iron sphere" + TAIL),
 "proj_sauce_blaster": ("fruit_food", "a flying splattering blob of fiery red and orange hot sauce, a messy round glossy splat with a few flying droplets around it and tiny flame licks, wet and saucy" + TAIL),
 "proj_champagne_popper": ("fruit_food", "a champagne bottle cork flying to the right, a tan mushroom-shaped cork with a little twist of gold wire cage and gold foil at the base, two tiny white fizz bubbles trailing behind it at the left" + TAIL),
 "proj_pizza_cutter": ("fruit_food", "a small round whole pepperoni pizza seen from directly straight above, a golden crust rim, melted yellow cheese, a few round red pepperoni slices on top, round appetizing and flat" + TAIL),
 "proj_ice_cream_scoop": ("fruit_food", "a single round scoop of pink strawberry ice cream, a smooth creamy round ball with a soft white highlight and one little melty drip at the bottom" + TAIL),
}

def main():
    for slug in sys.argv[1:]:
        style, desc = JOBS[slug]
        args = {"description": desc, "view": "sidescroller",
                "style_images": [{"type": "base64", "base64": style_b64(style), "format": "png"}]}
        r = subprocess.run(['python3', 'pixellab_mcp.py', 'call', 'create_1_direction_object',
                            json.dumps(args)], capture_output=True, text=True,
                           cwd='/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
        try:
            t = json.loads(r.stdout)['result']['content'][0]['text']
            oid = [l for l in t.splitlines() if l.startswith('id:')][0].split(': ')[1]
            print(f'{slug}={oid}')
        except Exception:
            print(f'{slug}=ERROR {r.stdout[:200]} {r.stderr[:200]}')

if __name__ == '__main__':
    main()
