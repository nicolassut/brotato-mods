#!/usr/bin/env python3
"""Durability step for the additive border pass: apply the SAME thicken to the
hi-res vector masters so a future re-vectorize/re-install can't revert the live
border. W scaled by master_dim/96. Masters backed up to _pre_border_backup2/masters/."""
import os, sys, glob, shutil
from PIL import Image
sys.path.insert(0, "/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline")
from process_gen import thicken

ROOT = "/Users/nicolassutcliffe/brotato-mods/Brotato Icons"
BK   = os.path.join(ROOT, "_pre_border_backup2", "masters")

# live W per slug (same amounts used on the 96px lives)
W = {}
for s in ["cake_slice","cheese_cube","escargot","espresso","fruit_salad","honey_drop","ice_cream",
          "leftovers","mint","pizza_slice","popcorn","protein_shake","steak","buffet_insurance",
          "chopsticks","compost_bin","food_fight","intermittent_fasting","mosquito_jar","msg",
          "overclocked_chip","overtime_pay","pepper_grinder","second_helping","silver_fork",
          "slow_cooker","snack_break","static_cling","sunscreen","vampire_fang","cheese_grater",
          "golden_spatula","wok_station","chili_greenhouse","street_vendor","snail","butcher",
          "dishwasher","tourist"]:
    W[s] = 1
for s in ["alarm_clock","bottomless_pit","burp_of_power","echo_chamber","michelin_star",
          "potato_peeler","preservatives","sugar_rush","sauce_blaster","fancy_restaurant","juggler"]:
    W[s] = 2
W["loyalty_card"] = 3

# resolve each slug -> its master (same search order as the audit scan)
allpng = {os.path.basename(p): p for p in glob.glob(ROOT + "/**/*.png", recursive=True)
          if "_pre_" not in p and "backup" not in p.lower() and "OLD_8x" not in p}
def master_of(s):
    for cand in (f"food__{s}.png", f"item__{s}.png", f"weapon__{s}.png",
                 f"character__{s}.png", f"structure__{s}.png", f"{s}.png", f"{s}_icon.png"):
        if cand in allpng: return allpng[cand]
    return None

done = 0
for s, w in W.items():
    mp = master_of(s)
    if not mp:
        print(f"  {s}: NO MASTER FOUND"); continue
    im = Image.open(mp).convert("RGBA")
    dim = max(im.size)
    wm = max(1, round(w * dim / 96.0))          # scale border to master resolution
    rel = mp.replace(ROOT + "/", "")
    bkp = os.path.join(BK, rel)
    os.makedirs(os.path.dirname(bkp), exist_ok=True)
    if not os.path.exists(bkp):
        shutil.copy2(mp, bkp)
    out = thicken(im, wm)                         # keeps native master canvas (grows outward, fine for archival)
    out.save(mp)
    done += 1
    print(f"  {s:22s} master {dim}px  +{wm}px  {rel}")
print(f"\n{done} masters thickened. backups -> {BK}")
