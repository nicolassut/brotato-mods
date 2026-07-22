#!/usr/bin/env python3
"""Queue PixelLab jobs for CUSTOM character appearance PROPS (150x150 overlays).
Usage: char_jobs.py <slug> [<slug> ...]  -> prints slug=object_id lines.

House method: eyes/mouths are BORROWED from the ~50-piece library (build_roster part());
only distinctive object-props are generated here (like the cow nose / snail stalks / bowler).
Style ref = a real Brotato asset chosen by material/trait (potato body for neutral line
weight; piggy_bank for pink flesh; ugly_tooth for grunge/faces). Size 192 NEAREST keeps it
a single candidate. Strong 'no head, no face' exclusions because PixelLab attaches heads to
accessories."""
import json, base64, io, subprocess, sys, os
from PIL import Image

REAL = '/Users/nicolassutcliffe/brotato-mods/asset-dev/brotato-real-icons'
BODY = '/Users/nicolassutcliffe/brotato-decompiled/entities/units/player/potato.png'
PIPE = os.path.dirname(os.path.abspath(__file__)) + '/../pipeline'
TAIL = (", wonky hand-drawn shape, very thick chunky black outline, flat cartoon colors, "
        "isolated object on transparent background")

# slug -> (style_ref, prompt). style_ref 'potato' = the body; else a REAL icon stem.
JOBS = {
 "mole_snout": ("piggy_bank",
   "a mole's snout nose, a small stubby pointed pink fleshy nose with exactly two dark round "
   "nostrils and exactly two tiny white buck teeth poking out just below it, tilted at a "
   "slight three-quarter angle" + TAIL +
   ", just the snout by itself, no head, no face, no eyes, no whiskers, nothing else"),
 # ---- refinement pass (2026-07-20, user feedback) ----
 # butcher: cleaver "coming out of the head" was illogical. Replace with a convincing forehead
 # blood splat. Ref = bloody_hand (real Brotato blood look).
 "butcher_blood": ("bloody_hand",
   "a messy splatter of bright red blood, one irregular wet blood splat with a few thick drips "
   "running downward and a couple of small flying droplets around it, glossy and gross, slightly "
   "tilted" + TAIL +
   ", just the red blood splatter by itself, no head, no face, no hand, no weapon, nothing else"),
 # tourist: camera must be WORN on a neck strap, not floating. Strap rises from both top corners
 # of the camera and splays up-and-out in a wide V, as if looped around a neck.
 "tourist_camera_worn": ("toolbox",
   "a black vintage tourist photo camera worn on a neck strap, the boxy black camera body with "
   "one big round lens hangs at the bottom centre, and a thick black fabric strap rises up from "
   "both top corners of the camera and splays outward to the upper left and upper right in a wide "
   "V shape as if it is looped around a neck, front view, symmetric" + TAIL +
   ", just the camera and its neck strap, no head, no face, no person, no body, nothing else"),
 # ---- borrowed-OK tier (2026-07-20): one distinctive custom prop each ----
 "gourmet_monocle": ("lucky_coin",
   "a single classy gold monocle, one round glass lens in a thin gold rim with a little chain "
   "dangling off it and a bright glass glint, only one lens, tilted at a slight angle" + TAIL +
   ", just the monocle by itself, no head, no face, no eye behind it, nothing else"),
 "tourist_camera": ("toolbox",
   "a small chunky black tourist photo camera with one big round lens on the front, a little "
   "viewfinder and a flash on top, hanging from a neck strap, tilted at a slight angle" + TAIL +
   ", just the camera and its strap, no head, no face, no hands, nothing else"),
 "comp_eater_headband": ("bandana_icon",
   "a sporty stretchy athletic sweatband headband, a single cloth band with a bold red stripe "
   "across the middle, worn across a forehead, empty in the middle, tilted at a slight angle" + TAIL +
   ", just the headband by itself, no head, no face, no hair inside it, nothing else"),
 # comp_eater_headband v1 came out a full RING (reads as a floating donut even cropped). Regen flat.
 "comp_eater_headband2": ("bandana_icon",
   "a simple flat red athletic sweatband, a straight horizontal strip of red terrycloth fabric "
   "with one thin white stripe along it, seen straight from the front as a flat wide band, worn "
   "across a forehead, it is a flat straight band and NOT a ring and NOT a circle and NOT a "
   "donut, slightly wonky" + TAIL +
   ", just the flat band by itself, no head, no face, no hair, nothing else"),
 "butcher_cleaver": ("toolbox",
   "a butcher's meat cleaver, a big rectangular shiny steel blade with a small hole in the "
   "corner and a chunky wooden handle, a little red blood smear along the cutting edge, tilted "
   "at a jaunty angle" + TAIL +
   ", just the cleaver by itself, no hand, no head, no face, nothing else"),
 "dishwasher_suds": ("piggy_bank",
   "a fluffy pile of white soap suds foam, a lumpy mound of frothy round white soap bubbles "
   "with a few shiny highlights and one or two little floating bubbles above it, tilted "
   "slightly" + TAIL +
   ", just the white soap foam by itself, no head, no face, no dish, nothing else"),
 # zombie_stitches (ugly_tooth ref) FAILED: x-stitches rendered as spiky stars on a filled
 # tan lozenge. Kept for record; do not requeue. Pivoted to a custom mouth instead.
 "zombie_stitches": ("ugly_tooth",
   "a short curved stitched gash wound, a dark jagged cut sewn shut with three or four bold "
   "black x-shaped stitches crossing over it, a little sickly green-grey bruising around the "
   "cut, tilted at an angle" + TAIL +
   ", just the stitched gash by itself, no head, no face, no eyes, no mouth, nothing else"),
 "zombie_mouth_grin": ("ugly_tooth",
   "a lopsided open zombie grin mouth, a wide crooked gash of a mouth with a few jagged "
   "uneven rotten teeth, dark inside, a thin drip of sickly green drool at one corner, "
   "tilted and lopsided" + TAIL +
   ", just the mouth by itself, no head, no face, no eyes, no nose, nothing else"),
 # v1 goggles had the lenses on a DIAGONAL (3/4 object) - always looked tilted/cluttered when
 # worn. Regen: clean, LEVEL, front-on pair to sit straight over both eyes.
 "blacksmith_goggles2": ("toolbox",
   "a pair of round welding goggles worn straight over the eyes, exactly two round dark glass "
   "lenses of equal size sitting side by side at the exact same height, joined by a short metal "
   "bridge between them, a plain flat strap band running straight out to the left and to the "
   "right, drawn front-on and perfectly level and symmetric, clean solid dark lenses, simple, "
   "only two lenses" + TAIL +
   ", just the goggles by themselves, no head, no face, no eyes behind them, nothing else"),
 "blacksmith_goggles": ("toolbox",
   "a pair of round welding goggles, exactly two round dark glass lenses in thick metal rims "
   "joined by a leather strap across the middle, only two lenses, front view, tilted at a "
   "slight angle, worn pushed up on a forehead" + TAIL +
   ", just the goggles by themselves, no head, no face, no eyes behind them, nothing else"),
 "picky_nose": ("potato",
   "a small scrunched-up wrinkled nose turned up in disgust, a pale cream button nose with "
   "exactly two little nostrils and a couple of wrinkle crease lines on the bridge, front "
   "view, tilted slightly" + TAIL +
   ", just the nose by itself, no head, no face, no eyes, no mouth, nothing else"),
 # picky_nose FAILED: big bulbous "schnoz" that covered the mouth, didn't read disgust.
 # picky_fork FAILED: pea floated beside the tines (not speared), and a big vertical utensil
 # doesn't sit on a face. Pivoted to a tongue-out "blegh" custom mouth.
 "picky_tongue": ("ugly_tooth",
   "a disgusted mouth sticking its tongue out in a big BLEGH of revulsion, an open mouth with "
   "one pink tongue lolling out and down to one side, grossed out and gagging, tilted and "
   "lopsided" + TAIL +
   ", just the mouth and one tongue, no head, no face, no eyes, no nose, nothing else"),
 # picky_tongue v1 (ugly_tooth ref) read too zombie-ish: rotten yellow teeth. Regen clean.
 "picky_tongue2": ("piggy_bank",
   "a cartoon mouth sticking its tongue out in a disgusted blegh, an open mouth with a few "
   "clean plain white teeth, one big pink tongue lolling out and down to one side, grossed "
   "out, tilted and lopsided, clean solid mouth with plain white teeth and no rotten teeth" + TAIL +
   ", just the mouth and one tongue, no head, no face, no eyes, no nose, nothing else"),
 "picky_fork": ("lucky_coin",
   "a shiny silver dinner fork held upright with the tines pointing up and a single small "
   "round green pea speared on the very tip, exactly one pea, tilted at a jaunty angle" + TAIL +
   ", just the fork and one pea, no hand, no head, no face, nothing else"),
 "zombie_mouth_stitched": ("ugly_tooth",
   "a crooked zombie mouth roughly sewn shut, uneven grey lips pulled together by a few "
   "short straight black thread stitches like sewn sewing thread, one chipped tooth poking "
   "out at one side, sickly and gross, tilted and lopsided, the stitches are short straight "
   "threads NOT stars and NOT asterisks" + TAIL +
   ", just the mouth by itself, no head, no face, no eyes, no nose, nothing else"),
}

def style_b64(name):
    path = BODY if name == 'potato' else f'{REAL}/{name}.png'
    im = Image.open(path).convert('RGBA').resize((192, 192), Image.NEAREST)
    buf = io.BytesIO(); im.save(buf, 'PNG')
    return base64.b64encode(buf.getvalue()).decode()

def main():
    for slug in sys.argv[1:]:
        style, desc = JOBS[slug]
        args = {"description": desc, "view": "sidescroller",
                "style_images": [{"type": "base64", "base64": style_b64(style), "format": "png"}]}
        r = subprocess.run(['python3', f'{PIPE}/pixellab_mcp.py', 'call',
                            'create_1_direction_object', json.dumps(args)],
                           capture_output=True, text=True)
        try:
            t = json.loads(r.stdout)['result']['content'][0]['text']
            oid = [l for l in t.splitlines() if l.startswith('id:')][0].split(': ')[1]
            print(f'{slug}={oid}')
        except Exception:
            print(f'{slug}=ERROR {r.stdout[:200]} {r.stderr[:200]}')

if __name__ == '__main__':
    main()
