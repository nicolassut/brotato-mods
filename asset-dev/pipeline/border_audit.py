#!/usr/bin/env python3
"""Border-consistency audit for the Gourmet mod. Measures outline thickness
(process_gen.outline_med) for every mod-made asset and vanilla references per
category, and renders per-category contact sheets at TRUE in-game px (2x nearest
so 1px diffs are legible; labels show the real px). Read-only: writes montages +
a CSV report to scratchpad, touches NO live art."""
import os, sys, glob, csv
import numpy as np
from PIL import Image, ImageDraw, ImageFont

sys.path.insert(0, "/Users/nicolassutcliffe/brotato-mods/asset-dev/pipeline")
from process_gen import outline_med

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
OUT = "/private/tmp/claude-501/-Users-nicolassutcliffe/6949b960-285c-419d-ab13-30210f65bc9b/scratchpad/border_audit"
os.makedirs(OUT, exist_ok=True)

def P(*a): return os.path.join(DEC, *a)
def ex(p): return p if os.path.exists(p) else None

# ---------- build the asset inventory ----------
# each entry: (name, path, source 'mod'|'van')
def item_icons():
    out = []
    for d in sorted(glob.glob(P("items/custom/*/"))):
        slug = os.path.basename(d.rstrip("/"))
        p = ex(os.path.join(d, slug + ".png"))
        if p: out.append((slug, p, "mod"))
    return out

def van_item_icons():
    picks = ["acid","adrenaline","alien_baby","baby_elephant","bat","bemand","blood_donation",
             "coffee","crown","dangerous_bunny","fertilizer","gnome","lemonade","medikit",
             "padding","ricochet","scared_sausage","spicy_sauce","tools","wine"]
    out = []
    for s in picks:
        p = ex(P(f"items/all/{s}/{s}_icon.png"))
        if p: out.append((s, p, "van"))
    return out

def foods():
    out = []
    for d in sorted(glob.glob(P("items/foods/*/"))):
        slug = os.path.basename(d.rstrip("/"))
        p = ex(os.path.join(d, slug + ".png"))
        if p: out.append((slug, p, "mod"))
    return out

def van_food_like():
    out = []
    for p in ["items/consumables/fruit/fruit.png",
              "items/consumables/diamond/diamond.png",
              "items/consumables/gold/gold.png"]:
        if ex(P(p)): out.append((os.path.basename(p)[:-4], P(p), "van"))
    return out

MOD_WEAPONS = {  # slug: (melee|ranged)
 "baguette":"melee","butchers_saw":"melee","cheese_grater":"melee","cleaver":"melee",
 "dinner_bell":"melee","fish_slapper":"melee","frying_pan":"melee","golden_spatula":"melee",
 "ladle":"melee","meat_tenderizer":"melee","rolling_pin":"melee","skewer":"melee",
 "trident_fork":"melee","whisk":"melee","champagne_popper":"ranged","corn_cannon":"ranged",
 "galley_cannon":"ranged","ice_cream_scoop":"ranged","pizza_cutter":"ranged","sauce_blaster":"ranged"}

def weapon_icons():
    out = []
    for slug, kind in sorted(MOD_WEAPONS.items()):
        p = ex(P(f"weapons/{kind}/{slug}/{slug}_icon.png"))
        if p: out.append((slug, p, "mod"))
    return out

def van_weapon_icons():
    picks = [("melee","knife"),("melee","spear"),("melee","hammer"),("melee","sword"),
             ("ranged","pistol"),("ranged","smg"),("ranged","rocket_launcher"),
             ("ranged","shotgun"),("melee","hatchet"),("ranged","minigun")]
    out = []
    for kind,s in picks:
        p = ex(P(f"weapons/{kind}/{s}/{s}_icon.png"))
        if p: out.append((s, p, "van"))
    return out

def weapon_sprites():
    out = []
    for slug, kind in sorted(MOD_WEAPONS.items()):
        p = ex(P(f"weapons/{kind}/{slug}/{slug}.png"))
        if p: out.append((slug, p, "mod"))
    return out

def van_weapon_sprites():
    picks = [("melee","knife"),("melee","spear"),("ranged","pistol"),
             ("ranged","rocket_launcher"),("melee","hammer"),("ranged","shotgun"),
             ("melee","sword"),("ranged","smg")]
    out = []
    for kind,s in picks:
        p = ex(P(f"weapons/{kind}/{s}/{s}.png"))
        if p: out.append((s, p, "van"))
    return out

def structures():
    out = []
    for p in sorted(glob.glob(P("entities/structures/turret/*/*_ingame.png"))):
        out.append((os.path.basename(p)[:-4], p, "mod"))
    return out

def van_structures():
    out = []
    for p in ["entities/structures/turret/tyler/tyler.png",
              "entities/structures/turret/turret.png",
              "entities/structures/garden/garden.png",
              "entities/structures/landmine/landmine.png"]:
        if ex(P(p)): out.append((os.path.basename(p)[:-4], P(p), "van"))
    return out

def projectiles():
    out = []
    for slug, kind in sorted(MOD_WEAPONS.items()):
        p = ex(P(f"weapons/{kind}/{slug}/{slug}_projectile.png"))
        if p: out.append((slug, p, "mod"))
    return out

def van_projectiles():
    picks = ["projectiles/bullet_slingshot/slingshot_projectile.png",
             "projectiles/bullet_rail_gun/rail_gun_bullet.png",
             "weapons/ranged/crossbow/crossbow_projectile.png",
             "projectiles/bullet_enemy/bullet_enemy.png"]
    out = []
    for p in picks:
        if ex(P(p)): out.append((os.path.basename(p)[:-4], P(p), "van"))
    return out

def char_icons():
    out = []
    for d in sorted(glob.glob(P("items/custom_characters/*/"))):
        slug = os.path.basename(d.rstrip("/"))
        p = ex(os.path.join(d, slug + "_icon.png"))
        if p: out.append((slug, p, "mod"))
    return out

def van_char_icons():
    out = []
    for p in glob.glob(P("items/characters/*/*_icon.png"))[:12]:
        out.append((os.path.basename(p)[:-9], p, "van"))
    return out

CATS = [
 ("items",        item_icons()    + van_item_icons(),    96),
 ("foods",        foods()         + van_food_like(),     80),
 ("weapon_icons", weapon_icons()  + van_weapon_icons(),  96),
 ("weapon_sprites", weapon_sprites() + van_weapon_sprites(), 230),
 ("structures",   structures()    + van_structures(),    140),
 ("projectiles",  projectiles()   + van_projectiles(),   64),
 ("characters",   char_icons()    + van_char_icons(),    96),
]

# ---------- measure + report ----------
def measure(path):
    try:
        im = Image.open(path).convert("RGBA")
        bb = im.getbbox()
        w, h = (bb[2]-bb[0], bb[3]-bb[1]) if bb else im.size
        return outline_med(im), (w, h), im
    except Exception as e:
        return -1.0, (0,0), None

rows = []
data = {}
for cat, assets, canvas in CATS:
    recs = []
    for name, path, src in assets:
        px, dim, im = measure(path)
        recs.append((name, src, px, dim, im, path))
        rows.append((cat, name, src, f"{px:.1f}", f"{dim[0]}x{dim[1]}"))
    data[cat] = (recs, canvas)

with open(os.path.join(OUT, "report.csv"), "w", newline="") as f:
    w = csv.writer(f); w.writerow(["category","name","source","outline_px","content_dim"])
    w.writerows(rows)

# vanilla band per category (median +/- spread)
print("\n=== VANILLA TARGET BANDS (outline_med px at in-game size) ===")
for cat,(recs,_) in data.items():
    van = sorted(r[2] for r in recs if r[1]=="van" and r[2]>=0)
    mod = sorted(r[2] for r in recs if r[1]=="mod" and r[2]>=0)
    if van:
        vmed = van[len(van)//2]
        print(f"{cat:15s} vanilla n={len(van)} min={van[0]:.1f} med={vmed:.1f} max={van[-1]:.1f}  | mod n={len(mod)} min={mod[0]:.1f} med={mod[len(mod)//2]:.1f} max={mod[-1]:.1f}")
    else:
        print(f"{cat:15s} (no vanilla sample) mod n={len(mod)} min={mod[0]:.1f} med={mod[len(mod)//2]:.1f} max={mod[-1]:.1f}")

# ---------- contact sheets ----------
try:
    FONT = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial.ttf", 13)
    FB = ImageFont.truetype("/System/Library/Fonts/Supplemental/Arial Bold.ttf", 13)
except Exception:
    FONT = FB = ImageFont.load_default()

SCALE = 2   # integer nearest-neighbor zoom for legibility (labels show TRUE px)
COLS = 8

def tile(name, src, px, dim, im, canvas, target_lo, target_hi):
    tw = canvas*SCALE
    th = canvas*SCALE + 34
    bg = (38,40,46,255) if src=="mod" else (24,30,26,255)
    t = Image.new("RGBA",(tw,th),bg)
    d = ImageDraw.Draw(t)
    if im is not None:
        c = im.crop(im.getbbox()) if im.getbbox() else im
        c = c.resize((c.width*SCALE, c.height*SCALE), Image.NEAREST)
        # center within canvas area
        ox = (tw - c.width)//2
        oy = (canvas*SCALE - c.height)//2
        t.alpha_composite(c, (max(0,ox), max(0,oy)))
    # verdict color
    if px < 0:            col=(150,150,150)
    elif px < target_lo:  col=(255,120,120)   # too thin
    elif px > target_hi:  col=(120,180,255)   # too thick
    else:                 col=(140,230,140)   # ok
    tag = "MOD" if src=="mod" else "van"
    d.text((3, canvas*SCALE+2), f"{name[:16]}", font=FB, fill=(235,235,235))
    d.text((3, canvas*SCALE+17), f"{tag} {px:.1f}px {dim[0]}x{dim[1]}", font=FONT, fill=col)
    return t

for cat,(recs,canvas) in data.items():
    van = sorted(r[2] for r in recs if r[1]=="van" and r[2]>=0)
    if van:
        lo = van[len(van)//2]*0.72
        hi = van[len(van)//2]*1.5
    else:
        lo, hi = 4.0, 9.0
    # mod first (sorted by px asc so thinnest lead), then vanilla refs
    mod = sorted([r for r in recs if r[1]=="mod"], key=lambda r:r[2])
    vrf = sorted([r for r in recs if r[1]=="van"], key=lambda r:r[2])
    ordered = mod + vrf
    tiles = [tile(n,s,px,dim,im,canvas,lo,hi) for (n,s,px,dim,im,_) in ordered]
    if not tiles: continue
    tw, th = tiles[0].size
    ncol = min(COLS, len(tiles)); nrow = (len(tiles)+ncol-1)//ncol
    sheet = Image.new("RGBA",(ncol*tw, nrow*th),(15,15,18,255))
    for i,t in enumerate(tiles):
        r,cc = divmod(i,ncol)
        sheet.alpha_composite(t,(cc*tw, r*th))
    sheet.convert("RGB").save(os.path.join(OUT,f"sheet_{cat}.png"))
    print(f"sheet_{cat}.png  {len(mod)} mod + {len(vrf)} van  band[{lo:.1f},{hi:.1f}]px  {sheet.size}")

print("\nDONE ->", OUT)
