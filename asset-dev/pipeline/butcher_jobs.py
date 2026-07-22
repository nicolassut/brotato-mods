#!/usr/bin/env python3
"""Queue the Butcher meat-reskin art on PixelLab. Prints slug=object_id.
5 item icons (96) + 2 world sprites (tree 225, locker 100)."""
import json, subprocess, sys
sys.path.insert(0, '/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
from sweep_jobs import style_b64

ICON = (", tilted at an angle, wonky hand-drawn shape, very thick chunky black outline, "
        "flat cartoon colors, isolated object on transparent background, game item icon")
WORLD = (", flat front view facing the camera like a paper cutout, standing upright, wonky "
         "hand-drawn shape, very thick chunky black outline, flat cartoon colors, isolated "
         "object on transparent background, game structure sprite")

JOBS = {
 # item icons (replace tree/garden/fruit_basket/lemonade/lumberjack_shirt for the Butcher)
 "meat_rack": ("bag_icon", "a wooden butcher drying rack, a sturdy standing wooden frame with a crossbar, two big raw red steaks and a link of sausages hanging from metal hooks" + ICON),
 "meat_locker": ("toolbox", "a small industrial steel meat locker fridge with a frosty slightly open door revealing hanging sausages and a raw steak inside, icy blue frost on the metal" + ICON),
 "meat_cooler": ("toolbox", "a red and white picnic cooler box with the lid ajar, overflowing with raw red steaks, one steak flopped over the edge" + ICON),
 "beef_broth": ("extra_stomach", "a rustic glass jar full of steaming hot brown beef broth with a big white marrow bone sticking out the top, curls of steam" + ICON),
 "butchers_apron": ("banner_icon", "a white butcher apron splattered with red blood stains, hanging by its neck strap from a metal hook, slightly crumpled cloth" + ICON),
 # world sprites
 "meat_rack_ingame": ("garden_structure", "a tall wooden butcher drying rack standing upright, a wooden frame with a crossbar, big sides of raw red beef and links of sausages hanging from hooks" + WORLD),
 "meat_locker_ingame": ("turret_structure", "a small industrial steel meat locker cabinet standing upright, a frosty door slightly ajar with a raw red steak poking out, a little puff of cold mist" + WORLD),
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
