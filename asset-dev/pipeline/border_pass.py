#!/usr/bin/env python3
"""Additive border pass (full sweep). Thickens only; never removes border.
Backs up every live PNG to Brotato Icons/_pre_border_backup2/ first, thickens by
a per-asset amount toward the vanilla floor (~5px; chars ~7px), preserves the
original canvas (structures bottom-anchored, icons centered), never upscales.
Re-measures before/after."""
import os, sys, shutil
from PIL import Image
sys.path.insert(0, "/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline")
from process_gen import thicken, outline_med

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
BK  = "/Users/nicolassutcliffe/brotato-mods/Brotato Icons/_pre_border_backup2"

# (live_path, W, anchor)  anchor: 'c' center | 'b' bottom
JOBS = []
def food(s, w):   JOBS.append((f"items/foods/{s}/{s}.png", w, 'c'))
def item(s, w):   JOBS.append((f"items/custom/{s}/{s}.png", w, 'c'))
def wicon(s,k,w): JOBS.append((f"weapons/{k}/{s}/{s}_icon.png", w, 'c'))
def struct(s, w): JOBS.append((f"entities/structures/turret/{s}/{s}_ingame.png", w, 'b'))
def char(s, w):   JOBS.append((f"items/custom_characters/{s}/{s}_icon.png", w, 'c'))

for s in ["cake_slice","cheese_cube","escargot","espresso","fruit_salad","honey_drop",
          "ice_cream","leftovers","mint","pizza_slice","popcorn","protein_shake","steak"]:
    food(s, 1)
item("loyalty_card", 3)
for s in ["alarm_clock","bottomless_pit","burp_of_power","echo_chamber","michelin_star",
          "potato_peeler","preservatives","sugar_rush"]:
    item(s, 2)
for s in ["buffet_insurance","chopsticks","compost_bin","food_fight","intermittent_fasting",
          "mosquito_jar","msg","overclocked_chip","overtime_pay","pepper_grinder",
          "second_helping","silver_fork","slow_cooker","snack_break","static_cling",
          "sunscreen","vampire_fang"]:
    item(s, 1)
wicon("sauce_blaster","ranged",2); wicon("cheese_grater","melee",1); wicon("golden_spatula","melee",1)
struct("fancy_restaurant",2); struct("wok_station",1); struct("chili_greenhouse",1); struct("street_vendor",1)
char("juggler",2)
for s in ["butcher","dishwasher","snail","tourist"]: char(s,1)

def add_border(im, W, anchor):
    canvas = im.size
    cw, ch = canvas
    thick = thicken(im, W)
    thick = thick.crop(thick.getbbox())
    margin = 2
    s = min((cw - margin) / thick.width, (ch - margin) / thick.height, 1.0)  # never upscale
    if s < 1.0:
        thick = thick.resize((max(1, round(thick.width*s)), max(1, round(thick.height*s))), Image.LANCZOS)
    out = Image.new("RGBA", canvas, (0, 0, 0, 0))
    ox = (cw - thick.width)//2
    oy = (ch - thick.height)//2 if anchor == 'c' else (ch - thick.height - 3)
    out.paste(thick, (max(0, ox), max(0, oy)), thick)
    return out

print(f"{'asset':28s} {'W':>2s} {'before':>7s} {'after':>7s}")
for rel, W, anchor in JOBS:
    live = os.path.join(DEC, rel)
    im = Image.open(live).convert("RGBA")
    before = outline_med(im)
    bkp = os.path.join(BK, rel)
    os.makedirs(os.path.dirname(bkp), exist_ok=True)
    if not os.path.exists(bkp):
        shutil.copy2(live, bkp)
    out = add_border(im, W, anchor)
    out.save(live)
    after = outline_med(out)
    flag = "" if after >= before else "  <-- DID NOT GROW"
    print(f"{os.path.basename(rel)[:-4]:28s} +{W:d} {before:7.1f} {after:7.1f}{flag}")
print(f"\n{len(JOBS)} files thickened. backups -> {BK}")
