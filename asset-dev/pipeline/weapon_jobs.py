#!/usr/bin/env python3
"""Queue redesigned Culinary weapon art on PixelLab. Two gens per weapon:
  <slug>       = tilted 96px shop ICON
  <slug>_spr   = horizontal in-game SPRITE (business end pointing RIGHT)
Prints slug=object_id lines. Usage: weapon_jobs.py <slug> [<slug> ...]"""
import json, subprocess, sys
sys.path.insert(0, '/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline')
from sweep_jobs import style_b64

ICON = (", tilted at a dynamic angle, very thick chunky black outline, flat cartoon "
        "colors, isolated object on transparent background, 2D video game weapon icon")
SPR = (", drawn in perfect horizontal side view, very thick chunky black outline, flat "
       "cartoon colors, isolated object on transparent background, 2D video game weapon sprite")

JOBS = {
 # ---- ICONS (tilted shop art) ----
 "corn_cannon": ("weapon_ranged", "a whimsical handheld corn cannon, a short fat cannon barrel shaped like a giant yellow corn cob covered in kernels, a dark metal muzzle ring at the front firing a popped kernel, a small wooden pistol grip and stock underneath to hold it, a compact hand weapon, NO carriage and NO wheels and NO stand" + ICON),
 "galley_cannon": ("weapon_ranged", "just a single short fat naval cannon barrel tube held like a hand cannon, a tapered dark iron tube with brass reinforcing rings and a round knob at the back breech end, a wide round muzzle opening at the front, NO carriage and NO wheels and NO stand and NO base, only the barrel tube alone" + ICON),
 "sauce_blaster": ("weapon_ranged", "a glass hot sauce bottle with a red screw cap nozzle and a chili pepper label, a big splash of fiery red-orange hot sauce squirting out of the nozzle, a real sauce bottle, absolutely not a gun and not a pistol, NO trigger and NO pistol grip and NO handle" + ICON),
 "champagne_popper": ("weapon_ranged", "a sealed unopened dark green champagne bottle standing upright and corked, gold foil wrapping the neck, a twisted wire cage over the cork which is firmly ON, a fancy cream label, one little gold star sparkle, the bottle is completely closed with NO foam and NO spray and NO cork popping off, just a bottle and not a gun" + ICON),
 "fish_slapper": ("weapon_melee", "a big fat silver dead fish seen from the side, a plump rounded body with fins and a wide fanned tail, one simple round X dead eye, a bold clean readable classic cartoon fish, chunky and simple" + ICON),
 "frying_pan": ("weapon_melee", "a cast iron frying pan tilted, a clearly LIGHTER medium-grey round cooking surface inside that stands out from the thick black rim, a bright silver highlight along the top edge, one sunny-side-up fried egg with a white and a round yellow yolk sitting inside, a sturdy handle, clean bold and readable, absolutely NOT a solid black blob" + ICON),
 # ---- SPRITES (horizontal, business end -> RIGHT) ----
 "corn_cannon_spr": ("weapon_ranged", "a whimsical handheld corn cannon lying flat and horizontal, a short fat cannon barrel shaped like a giant yellow corn cob covered in kernels, the dark metal muzzle ring at the far right firing a popped kernel to the right, a small wooden grip and stock underneath at the left to hold it, a compact hand weapon, NO carriage and NO wheels and NO stand" + SPR),
 "galley_cannon_spr": ("weapon_ranged", "just a single short fat naval cannon barrel tube lying flat and horizontal held like a bazooka, a tapered dark iron tube with brass reinforcing rings, the wide round muzzle opening at the far right, a round knob breech at the left end, NO carriage and NO wheels and NO stand, only the barrel tube alone" + SPR),
 "sauce_blaster_spr": ("weapon_ranged", "a glass hot sauce bottle lying flat and horizontal like a blaster, the red nozzle cap at the far right squirting a splash of fiery red hot sauce to the right, the round bottle base as a grip at the left, not a gun" + SPR),
 "champagne_popper_spr": ("weapon_ranged", "an opened dark green champagne bottle lying flat and horizontal, held by its round base at the far left, the neck pointing to the far right with the cork blasting off and white foam spraying out to the right, just a plain champagne bottle with NO pistol grip and NO trigger and NO gun" + SPR),
 "fish_slapper_spr": ("weapon_melee", "a big fat dead silver fish lying flat and horizontal, the narrow tail at the left as a handle grip and the head at the far right, floppy and limp, one big X dead eye" + SPR),
 "frying_pan_spr": ("weapon_melee", "a cast iron frying pan lying flat and horizontal, the long handle at the left and the round pan bowl at the far right, a clearly LIGHTER medium-grey cooking surface inside distinct from the black rim, a bright silver rim highlight, one sunny-side-up fried egg inside, bold and readable, NOT a solid black blob" + SPR),
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
