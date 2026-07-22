#!/usr/bin/env python3
"""Build the 20 Culinary-class weapons (design PDF section 4) by cloning the
closest vanilla weapon family (scene + stats text, patched), generating tier
ladders per the PDF tier rules, the new Culinary set (+2/+4/+6/+9/+12 Appetite),
PIL placeholder sprites, and item_service.tscn registration (ext ids 918+).

Tier rules: damage x1/1.6/2.3/3.35, cooldown x1/.85/.70/.55, crit chance
x1/1.33/1.66/2.0, prices 12/25/50/95. Baselines are given at each weapon's
starting tier and scaled relative to it.

DESIGN CHANGES vs PDF (user asked for more distinct specials; flagged in chat):
- Dinner Bell: slow-on-hit -> each enemy hit extends food buffs +0.2s
- Ice Cream Scoop: splash slow -> heal 1 HP per enemy hit
APPROXIMATIONS (flagged): Skewer/Trident double poke = single combined hit;
Pizza Cutter pierce-on-crit = flat pierce 1; all weapons unlocked by default."""
import os, re, shutil
from PIL import Image, ImageDraw

DEC  = "/Users/nicolassutcliffe/brotato-decompiled"
TSCN = f"{DEC}/singletons/item_service.tscn"
CSV  = f"{DEC}/items/custom/custom_translations.csv"
BASE_ID = 918

DMG_MULT  = [1.0, 1.6, 2.3, 3.35]
CD_MULT   = [1.0, 0.85, 0.70, 0.55]
CRIT_MULT = [1.0, 1.33, 1.66, 2.0]
VALUES    = [12, 25, 50, 95]

SETS_DIR = f"{DEC}/items/sets"

def w(slug, name, template, kind, start_tier, dmg, cd, critc, critm, rng, kb,
      scaling, sets, lifesteal=0.0, attack_type=None, effect_scale=None,
      nb_projectiles=None, spread=None, piercing=None, bounce=None,
      burn_chance=None, specials=(), end_tier=3,
      explode_scale=None, explode_marker=None):
    return dict(slug=slug, name=name, template=template, kind=kind,
                start_tier=start_tier, end_tier=end_tier, dmg=dmg, cd=cd,
                critc=critc, critm=critm, rng=rng, kb=kb, scaling=scaling,
                sets=sets, lifesteal=lifesteal, attack_type=attack_type,
                effect_scale=effect_scale, nb_projectiles=nb_projectiles,
                spread=spread, piercing=piercing, bounce=bounce,
                burn_chance=burn_chance, specials=list(specials),
                explode_scale=explode_scale, explode_marker=explode_marker)

# specials: (key, value, text_key) -- text_key EFFECT_HIDDEN hides the line
WEAPONS = [
 w("frying_pan", "Frying Pan", "hatchet", "melee", 0, 12, 42, .05, 1.5, 120, 18,
   [("stat_melee_damage", 1.0)], ["culinary"], attack_type=1,
   specials=[("gourmet_slow_on_hit", 50, "EFFECT_W_PAN_SLOW"),
             ("gourmet_slow_chance", 15, "EFFECT_HIDDEN")]),
 w("cleaver", "Cleaver", "hatchet", "melee", 0, 14, 38, .10, 2.0, 130, 4,
   [("stat_melee_damage", 0.9)], ["culinary", "blade"], attack_type=1,
   specials=[("execute_damage", 50, "EFFECT_W_EXECUTE")]),
 w("rolling_pin", "Rolling Pin", "plank", "melee", 0, 22, 78, .03, 1.5, 160, 28,
   [("stat_melee_damage", 1.2)], ["culinary", "blunt"], attack_type=1),
 w("skewer", "Skewer", "spear", "melee", 0, 16, 45, .15, 2.0, 180, 6,
   [("stat_melee_damage", 0.8)], ["culinary", "precise"], attack_type=0),
 w("cheese_grater", "Cheese Grater", "screwdriver", "melee", 0, 3, 9, .03, 1.5, 110, 0,
   [("stat_melee_damage", 0.35)], ["culinary", "tool"], lifesteal=0.03, attack_type=0),
 w("whisk", "Whisk", "hatchet", "melee", 0, 6, 30, .05, 1.5, 100, 10,
   [("stat_melee_damage", 0.5)], ["culinary"], attack_type=1, effect_scale=1.3),
 w("ladle", "Ladle", "hatchet", "melee", 0, 9, 40, .05, 1.5, 140, 8,
   [("stat_melee_damage", 0.6), ("stat_appetite", 0.3)], ["culinary", "support"],
   lifesteal=0.08, attack_type=1),
 w("dinner_bell", "Dinner Bell", "hatchet", "melee", 0, 7, 55, .0, 1.5, 150, 12,
   [("stat_elemental_damage", 0.4), ("stat_appetite", 0.4)], ["musical", "support"],
   attack_type=1, effect_scale=1.5,
   specials=[("extend_buffs_on_hit", 2, "EFFECT_W_BELL")]),
 w("baguette", "Baguette", "jousting_lance", "melee", 2, 48, 78, .15, 2.0, 270, 22,
   [("stat_melee_damage", 1.1)], ["culinary"], attack_type=1),
 w("butchers_saw", "Butcher's Saw", "plank", "melee", 2, 45, 85, .08, 2.0, 170, 15,
   [("stat_melee_damage", 1.1)], ["culinary", "heavy"], attack_type=1,
   specials=[("execute_damage", 100, "EFFECT_W_EXECUTE")]),
 w("meat_tenderizer", "Meat Tenderizer", "hammer", "melee", 1, 18, 50, .08, 1.8, 130, 12,
   [("stat_melee_damage", 0.9)], ["culinary", "tool"], attack_type=1,
   specials=[("tenderize_on_hit", 10, "EFFECT_W_TENDERIZE")]),
 w("golden_spatula", "Golden Spatula", "hatchet", "melee", 3, 40, 30, .20, 2.5, 150, 20,
   [("stat_appetite", 1.2)], ["culinary", "legendary"], lifesteal=0.10, attack_type=1,
   specials=[("gourmet_slow_on_hit", 30, "EFFECT_W_SPATULA_SLOW")]),
 w("trident_fork", "Trident Fork", "spear", "melee", 0, 22, 55, .10, 2.0, 200, 14,
   [("stat_melee_damage", 0.9)], ["culinary", "naval"], attack_type=0),
 w("fish_slapper", "Fish Slapper", "plank", "melee", 0, 13, 48, .05, 1.5, 150, 24,
   [("stat_melee_damage", 1.0)], ["naval", "blunt"], attack_type=1,
   specials=[("gourmet_slow_on_hit", 15, "EFFECT_W_SLAP_SLOW")]),
 w("corn_cannon", "Corn Cannon", "rocket_launcher", "ranged", 0, 16, 95, .05, 1.5, 380, 8,
   [("stat_ranged_damage", 0.8)], ["culinary", "explosive"],
   explode_scale=1.36, explode_marker="gourmet_corn_popcorn",
   specials=[("", 0, "EFFECT_W_CORN_POPCORN")]),
 w("sauce_blaster", "Sauce Blaster", "fireball", "ranged", 0, 4, 55, .03, 1.5, 240, 3,
   [("stat_ranged_damage", 0.4), ("stat_elemental_damage", 0.4)],
   ["culinary", "elemental"], nb_projectiles=3, spread=0.44, burn_chance=0.25),
 w("champagne_popper", "Champagne Popper", "pistol", "ranged", 0, 16, 75, .10, 2.0, 350, 32,
   [("stat_ranged_damage", 1.0)], ["culinary", "gun"], bounce=1),
 w("pizza_cutter", "Pizza Cutter", "shuriken", "ranged", 0, 9, 60, .15, 2.2, 320, 0,
   [("stat_ranged_damage", 0.7)], ["culinary", "precise"], piercing=1),
 w("ice_cream_scoop", "Ice Cream Scoop", "potato_thrower", "ranged", 1, 20, 70, .08, 1.8, 300, 6,
   [("stat_ranged_damage", 0.9)], ["culinary", "medical"],
   specials=[("heal_on_hit", 1, "EFFECT_W_SCOOP")]),
 w("galley_cannon", "Galley Cannon", "rocket_launcher", "ranged", 0, 24, 110, .05, 1.5, 420, 22,
   [("stat_ranged_damage", 1.0)], ["naval", "explosive"], explode_scale=1.68),
]

CSV_ROWS = [
 ("WEAPON_CLASS_CULINARY", "Culinary"),
 ("EFFECT_W_PAN_SLOW", "15% chance to slow enemies 50% for 1 second"),
 ("EFFECT_W_EXECUTE", "+{0}% damage against enemies below 25% HP"),
 ("EFFECT_W_TENDERIZE", "Hit enemies take +{0}% damage for 3 seconds"),
 ("EFFECT_W_BELL", "Each enemy hit extends your food buffs by 0.2 seconds"),
 ("EFFECT_W_SPATULA_SLOW", "Hits slow enemies 30% for 1 second"),
 ("EFFECT_W_SLAP_SLOW", "Hits slow enemies 15% for 1 second"),
 ("EFFECT_W_SCOOP", "Heal {0} HP for every enemy hit"),
 ("EFFECT_W_CORN_POPCORN", "Each explosion has a 3% chance to pop a Popcorn. Appetite increases the chance"),
] + [("WEAPON_" + x["slug"].upper(), x["name"]) for x in WEAPONS]


# ---------- placeholder sprites ----------
OUTLINE = (20, 16, 12, 255)
STEEL = (168, 174, 186, 255)
WOOD = (150, 104, 66, 255)
GOLD = (240, 196, 80, 255)

def draw_weapon(slug, size):
    img = Image.new("RGBA", size, (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    wd, ht = size
    cy = ht // 2
    def handle(x0, x1, thick=6, color=WOOD):
        d.rectangle([x0, cy - thick // 2, x1, cy + thick // 2], fill=color, outline=OUTLINE, width=2)
    if slug == "frying_pan":
        handle(2, wd * 0.45)
        d.ellipse([wd * 0.4, cy - ht * 0.42, wd - 2, cy + ht * 0.42], fill=(58, 60, 70, 255), outline=OUTLINE, width=3)
    elif slug == "cleaver":
        handle(2, wd * 0.35)
        d.polygon([(wd * 0.32, cy - ht * 0.42), (wd - 2, cy - ht * 0.42), (wd - 2, cy + ht * 0.32), (wd * 0.38, cy + ht * 0.42)], fill=STEEL, outline=OUTLINE)
    elif slug == "rolling_pin":
        handle(2, wd * 0.18); handle(wd * 0.82, wd - 2)
        d.rounded_rectangle([wd * 0.16, cy - ht * 0.3, wd * 0.84, cy + ht * 0.3], radius=6, fill=(214, 178, 130, 255), outline=OUTLINE, width=3)
    elif slug in ("skewer", "baguette"):
        color = (222, 184, 120, 255) if slug == "baguette" else STEEL
        d.polygon([(2, cy - 3), (wd - 8, cy - 3), (wd - 2, cy), (wd - 8, cy + 3), (2, cy + 3)], fill=color, outline=OUTLINE)
        if slug == "skewer":
            for x in (wd * 0.4, wd * 0.6, wd * 0.8):
                d.ellipse([x - 5, cy - 8, x + 5, cy + 2], fill=(200, 56, 48, 255), outline=OUTLINE, width=2)
        else:
            for x in (wd * 0.3, wd * 0.5, wd * 0.7):
                d.line([x, cy - 4, x + 8, cy + 4], fill=OUTLINE, width=2)
    elif slug == "cheese_grater":
        handle(2, wd * 0.3)
        d.polygon([(wd * 0.3, cy - ht * 0.35), (wd - 2, cy - ht * 0.25), (wd - 2, cy + ht * 0.25), (wd * 0.3, cy + ht * 0.35)], fill=STEEL, outline=OUTLINE)
        for x in (wd * 0.45, wd * 0.6, wd * 0.75):
            d.ellipse([x, cy - 4, x + 5, cy + 1], fill=(120, 124, 138, 255))
    elif slug == "whisk":
        handle(2, wd * 0.4)
        d.arc([wd * 0.38, cy - ht * 0.35, wd - 2, cy + ht * 0.35], 270, 90, fill=STEEL, width=3)
        d.arc([wd * 0.45, cy - ht * 0.35, wd * 0.92, cy + ht * 0.35], 270, 90, fill=STEEL, width=3)
        d.ellipse([wd * 0.38, cy - ht * 0.35, wd - 2, cy + ht * 0.35], outline=OUTLINE, width=2)
    elif slug == "ladle":
        handle(2, wd * 0.6, 5)
        d.pieslice([wd * 0.55, cy - 4, wd - 2, cy + ht * 0.4], 0, 180, fill=STEEL, outline=OUTLINE, width=3)
    elif slug == "dinner_bell":
        handle(2, wd * 0.35, 5)
        d.polygon([(wd * 0.5, cy - ht * 0.4), (wd * 0.9, cy + ht * 0.25), (wd * 0.35, cy + ht * 0.25)], fill=GOLD, outline=OUTLINE)
        d.ellipse([wd * 0.58, cy + ht * 0.22, wd * 0.68, cy + ht * 0.38], fill=OUTLINE)
    elif slug == "butchers_saw":
        handle(2, wd * 0.25)
        d.rectangle([wd * 0.25, cy - ht * 0.25, wd - 2, cy + ht * 0.1], fill=STEEL, outline=OUTLINE, width=2)
        for x in range(int(wd * 0.28), int(wd - 4), 8):
            d.polygon([(x, cy + ht * 0.1), (x + 4, cy + ht * 0.3), (x + 8, cy + ht * 0.1)], fill=STEEL, outline=OUTLINE)
    elif slug == "meat_tenderizer":
        handle(2, wd * 0.55)
        d.rounded_rectangle([wd * 0.55, cy - ht * 0.4, wd - 2, cy + ht * 0.4], radius=4, fill=STEEL, outline=OUTLINE, width=3)
        for gx in (wd * 0.63, wd * 0.78):
            d.line([gx, cy - ht * 0.35, gx, cy + ht * 0.35], fill=OUTLINE, width=2)
    elif slug == "golden_spatula":
        handle(2, wd * 0.5, 5, GOLD)
        d.rounded_rectangle([wd * 0.5, cy - ht * 0.35, wd - 2, cy + ht * 0.35], radius=5, fill=GOLD, outline=OUTLINE, width=3)
        for x in (wd * 0.62, wd * 0.75, wd * 0.88):
            d.line([x, cy - ht * 0.25, x, cy + ht * 0.25], fill=OUTLINE, width=2)
    elif slug == "trident_fork":
        handle(2, wd * 0.6, 5)
        for dy in (-ht * 0.25, 0, ht * 0.25):
            d.polygon([(wd * 0.6, cy + dy - 2), (wd - 4, cy + dy - 2), (wd - 2, cy + dy), (wd - 4, cy + dy + 2), (wd * 0.6, cy + dy + 2)], fill=STEEL, outline=OUTLINE)
    elif slug == "fish_slapper":
        d.polygon([(2, cy - 4), (wd * 0.3, cy - 6), (wd * 0.3, cy + 6), (2, cy + 4)], fill=(120, 170, 200, 255), outline=OUTLINE)
        d.ellipse([wd * 0.25, cy - ht * 0.35, wd - 6, cy + ht * 0.35], fill=(120, 170, 200, 255), outline=OUTLINE, width=3)
        d.polygon([(wd - 12, cy), (wd - 2, cy - ht * 0.3), (wd - 2, cy + ht * 0.3)], fill=(120, 170, 200, 255), outline=OUTLINE)
        d.ellipse([wd * 0.35, cy - 6, wd * 0.42, cy + 1], fill=OUTLINE)
    elif slug in ("corn_cannon", "galley_cannon"):
        color = GOLD if slug == "corn_cannon" else (84, 88, 100, 255)
        d.rounded_rectangle([2, cy - ht * 0.3, wd * 0.85, cy + ht * 0.3], radius=6, fill=(72, 74, 86, 255), outline=OUTLINE, width=3)
        d.rectangle([wd * 0.8, cy - ht * 0.4, wd - 2, cy + ht * 0.4], fill=color, outline=OUTLINE, width=3)
        if slug == "corn_cannon":
            for x, y in ((wd * 0.2, cy - 4), (wd * 0.35, cy + 2), (wd * 0.5, cy - 3)):
                d.ellipse([x, y, x + 6, y + 6], fill=GOLD, outline=OUTLINE, width=1)
    elif slug == "sauce_blaster":
        d.rounded_rectangle([2, cy - ht * 0.28, wd * 0.7, cy + ht * 0.28], radius=8, fill=(200, 56, 48, 255), outline=OUTLINE, width=3)
        d.rectangle([wd * 0.68, cy - 5, wd - 2, cy + 5], fill=(238, 214, 130, 255), outline=OUTLINE, width=2)
    elif slug == "champagne_popper":
        d.rounded_rectangle([2, cy - ht * 0.25, wd * 0.75, cy + ht * 0.25], radius=8, fill=(46, 90, 60, 255), outline=OUTLINE, width=3)
        d.rectangle([wd * 0.72, cy - 6, wd * 0.9, cy + 6], fill=GOLD, outline=OUTLINE, width=2)
        d.ellipse([wd * 0.88, cy - 7, wd - 2, cy + 7], fill=WOOD, outline=OUTLINE, width=2)
    elif slug == "pizza_cutter":
        handle(2, wd * 0.45)
        d.ellipse([wd * 0.4, cy - ht * 0.42, wd - 2, cy + ht * 0.42], fill=STEEL, outline=OUTLINE, width=3)
        d.ellipse([wd * 0.62, cy - 4, wd * 0.75, cy + 4], fill=OUTLINE)
    elif slug == "ice_cream_scoop":
        handle(2, wd * 0.55, 5)
        d.ellipse([wd * 0.5, cy - ht * 0.38, wd - 2, cy + ht * 0.38], fill=STEEL, outline=OUTLINE, width=3)
        d.ellipse([wd * 0.58, cy - ht * 0.25, wd * 0.9, cy + ht * 0.2], fill=(238, 150, 170, 255), outline=OUTLINE, width=2)
    else:
        handle(2, wd - 2)
    return img


# ---------- tres generation ----------

def special_effect_tres(key, value, text_key):
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{key}"
text_key = "{text_key}"
value = {value}
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]
"""

# template -> (its projectile scene, [sprite-texture paths inside that scene to swap]).
# pistol has no projectile_scene in its stats: WeaponService falls back to the default
# bullet (bullet_projectile.tscn), so we clone that and assign it explicitly.
PROJ_BY_TEMPLATE = {
    "rocket_launcher": ("projectiles/rocket/rocket_projectile.tscn", ["projectiles/rocket/rocket.png"]),
    "fireball": ("projectiles/fireball_projectile/fireball_projectile.tscn", ["projectiles/fireball_projectile/fireball_projectile.png"]),
    "pistol": ("projectiles/rocket/rocket_projectile.tscn", ["projectiles/rocket/rocket.png"]),  # STATIC base; animated bullet clone rendered as default bullet (2026-07-22)
    "shuriken": ("projectiles/shuriken/shuriken_projectile.tscn", ["projectiles/shuriken/shuriken.png"]),
    "potato_thrower": ("projectiles/potato/potato_bullet.tscn", ["projectiles/potato/potato.png"]),
}


PROJ_SKIP = {"sauce_blaster"}  # user prefers the vanilla fireball ball (2026-07-22)


def wire_projectile(wpn, tmpl_stats, ndir):
    """Give a ranged weapon its own projectile: clone the template's projectile scene with the
    weapon's projectile sprite swapped in, and point the stats' projectile_scene at it. Returns
    the patched stats text. The projectile PNG is installed separately by process_projectile.py."""
    slug, kind, template = wpn["slug"], wpn["kind"], wpn["template"]
    if kind != "ranged" or template not in PROJ_BY_TEMPLATE or slug in PROJ_SKIP:
        return tmpl_stats
    scene_rel, tex_rels = PROJ_BY_TEMPLATE[template]
    scene = open(f"{DEC}/{scene_rel}").read()
    new_tex = f"res://weapons/{kind}/{slug}/{slug}_projectile.png"
    for t in tex_rels:
        scene = scene.replace(f"res://{t}", new_tex)
    open(f"{ndir}/{slug}_projectile.tscn", "w").write(scene)

    cloned = f"res://weapons/{kind}/{slug}/{slug}_projectile.tscn"
    if f"res://{scene_rel}" in tmpl_stats:
        return tmpl_stats.replace(f"res://{scene_rel}", cloned)
    # pistol path: no projectile_scene in stats -> add an ext_resource + the field, bump load_steps
    ids = [int(i) for i in re.findall(r"id=(\d+)", tmpl_stats)]
    nid = max(ids) + 1 if ids else 2
    ext_line = f'[ext_resource path="{cloned}" type="PackedScene" id={nid}]\n'
    tmpl_stats = re.sub(r'(\[ext_resource[^\]]*\]\n)(?!.*\[ext_resource)', r'\1' + ext_line, tmpl_stats, count=1, flags=re.S)
    # MUST go AFTER `script = ExtResource( 1 )` - Godot drops script-defined props set before
    # the script is attached (this silently null'd champagne's projectile_scene -> default bullet)
    tmpl_stats = re.sub(r'(\[resource\]\nscript = ExtResource\( 1 \)\n)',
                        r'\1' + f'projectile_scene = ExtResource( {nid} )\n', tmpl_stats, count=1)
    m = re.search(r"load_steps=(\d+)", tmpl_stats)
    if m:
        tmpl_stats = tmpl_stats.replace(f"load_steps={m.group(1)}", f"load_steps={int(m.group(1)) + 1}", 1)
    return tmpl_stats


def exploding_effect_tres(scale, marker):
    # Own copy of rocket_launcher_effect.tres. marker rides in custom_key so the
    # runtime can tell this weapon's blast apart from every other explosion.
    return f"""[gd_resource type="Resource" load_steps=3 format=2]

[ext_resource path="res://projectiles/explosion.tscn" type="PackedScene" id=1]
[ext_resource path="res://effects/weapons/exploding_effect.gd" type="Script" id=6]

[resource]
script = ExtResource( 6 )
key = "effect_explode"
text_key = ""
value = 0
custom_key = "{marker}"
storage_method = 0
effect_sign = 3
custom_args = [  ]
chance = 1.0
explosion_scene = ExtResource( 1 )
scale = {scale}
base_smoke_amount = 40
sound_db_mod = -10
"""


# weapons whose animation needs a custom shooting behavior the template scene lacks.
# slug -> script path. Injected as a ShootingBehavior node override (index 4 = the
# ShootingBehavior child of weapon.tscn, same slot the melee weapons override).
SHOOTING_BEHAVIOR = {
    "ice_cream_scoop": "res://weapons/ranged/ice_cream_scoop/scoop_swing_behavior.gd",
}


def inject_shooting_behavior(scene, slug):
    path = SHOOTING_BEHAVIOR.get(slug)
    if path is None or path in scene:
        return scene
    nid = max((int(i) for i in re.findall(r"id=(\d+)", scene)), default=0) + 1
    # add the script ext_resource after the last existing ext_resource line
    last = 0
    for m in re.finditer(r"^\[ext_resource .*\]$", scene, re.M):
        last = m.end()
    ext_line = f'\n[ext_resource path="{path}" type="Script" id={nid}]'
    scene = scene[:last] + ext_line + scene[last:]
    # bump load_steps
    m = re.search(r"load_steps=(\d+)", scene)
    scene = scene.replace(f"load_steps={m.group(1)}", f"load_steps={int(m.group(1)) + 1}", 1)
    # add the node override before [editable ...] (or at end of file)
    node = f'[node name="ShootingBehavior" parent="." index="4"]\nscript = ExtResource( {nid} )\n\n'
    em = re.search(r"^\[editable ", scene, re.M)
    if em:
        scene = scene[:em.start()] + node + scene[em.start():]
    else:
        scene = scene.rstrip() + "\n\n" + node
    return scene


def patch_stats(template_text, wpn, tier_idx):
    rel = tier_idx - wpn["start_tier"]
    base_idx = wpn["start_tier"]
    t = template_text
    def setf(field, value):
        nonlocal t
        if re.search(rf"^{field} = ", t, re.M):
            t = re.sub(rf"^{field} = .*$", f"{field} = {value}", t, count=1, flags=re.M)
    dmg = int(round(wpn["dmg"] * DMG_MULT[tier_idx] / DMG_MULT[base_idx]))
    cd = max(5, int(round(wpn["cd"] * CD_MULT[tier_idx] / CD_MULT[base_idx])))
    critc = round(min(0.6, wpn["critc"] * CRIT_MULT[tier_idx] / CRIT_MULT[base_idx]), 3)
    setf("damage", dmg)
    setf("cooldown", cd)
    setf("crit_chance", critc)
    setf("crit_damage", wpn["critm"])
    setf("max_range", wpn["rng"])
    setf("knockback", wpn["kb"])
    setf("lifesteal", wpn["lifesteal"])
    scaling = "[ " + ", ".join(f'[ "{k}", {v} ]' for k, v in wpn["scaling"]) + " ]"
    t = re.sub(r"^scaling_stats = .*$", f"scaling_stats = {scaling}", t, count=1, flags=re.M)
    if wpn["attack_type"] is not None:
        setf("attack_type", wpn["attack_type"])
    if wpn["effect_scale"] is not None:
        setf("effect_scale", wpn["effect_scale"])
    if wpn["nb_projectiles"] is not None:
        setf("nb_projectiles", wpn["nb_projectiles"])
    if wpn["spread"] is not None:
        setf("projectile_spread", wpn["spread"])
    if wpn["piercing"] is not None:
        setf("piercing", wpn["piercing"])
    if wpn["bounce"] is not None:
        setf("bounce", wpn["bounce"])
    # Sauce Blaster inherits the fireball template's custom_on_cooldown_sprite (the
    # empty-hand "just threw it" pose). That swap made the bottle vanish every shot and
    # read as a fireball throw. Strip it so the bottle stays in hand and only recoils.
    if wpn["slug"] == "sauce_blaster" and "fireball_reloading" in t:
        t = re.sub(r'^\[ext_resource path="[^"]*fireball_reloading\.png"[^\]]*\]\n', '', t, flags=re.M)
        t = re.sub(r'^custom_on_cooldown_sprite = ExtResource\( \d+ \)\n', '', t, flags=re.M)
        m = re.search(r'load_steps=(\d+)', t)
        if m:
            t = t.replace(f'load_steps={m.group(1)}', f'load_steps={int(m.group(1))-1}', 1)
    return t


def build_weapon(wpn, next_id):
    slug, template, kind = wpn["slug"], wpn["template"], wpn["kind"]
    tdir = f"{DEC}/weapons/{kind}/{template}"
    ndir = f"{DEC}/weapons/{kind}/{slug}"
    os.makedirs(ndir, exist_ok=True)

    # sprite + icon sized like the template's. NEVER overwrite curated art: only
    # draw the PIL placeholder when the file does not exist yet, so a rebuild
    # keeps the generated/vectorized sprites already installed.
    tmpl_png = f"{tdir}/{template}.png"
    size = Image.open(tmpl_png).size if os.path.exists(tmpl_png) else (56, 24)
    if not os.path.exists(f"{ndir}/{slug}.png"):
        draw_weapon(slug, size).save(f"{ndir}/{slug}.png")
    icon_png = f"{tdir}/{template}_icon.png"
    isize = Image.open(icon_png).size if os.path.exists(icon_png) else (48, 48)
    if not os.path.exists(f"{ndir}/{slug}_icon.png"):
        draw_weapon(slug, isize).save(f"{ndir}/{slug}_icon.png")

    # scene: template scene with our texture
    scene = open(f"{tdir}/{template}.tscn").read()
    scene = scene.replace(f"res://weapons/{kind}/{template}/{template}.png",
                          f"res://weapons/{kind}/{slug}/{slug}.png")
    scene = inject_shooting_behavior(scene, slug)
    open(f"{ndir}/{slug}.tscn", "w").write(scene)

    # template stats + data from its lowest tier dir (some start above tier 1)
    tmpl_tiers = sorted(int(x) for x in os.listdir(tdir) if x.isdigit())
    tt = tmpl_tiers[0]
    def tier_file(base):
        for cand in (f"{tdir}/{tt}/{template}_{base}.tres", f"{tdir}/{tt}/{template}_{tt}_{base}.tres"):
            if os.path.exists(cand):
                return cand
        raise FileNotFoundError(f"{template} {base} in tier {tt}")
    tmpl_stats = open(tier_file("stats")).read()
    tmpl_data = open(tier_file("data")).read()
    wtype = re.search(r"^type = (\d+)", tmpl_data, re.M).group(1)

    # copy the template's burning data if we need burning, patching the chance
    burning_line = ""
    if wpn["burn_chance"] is not None:
        m = re.search(rf'\[ext_resource path="(res://weapons/{kind}/{template}/[^"]*burning[^"]*)" [^\]]*\]', tmpl_stats)
        if m:
            bsrc = f"{DEC}/{m.group(1)[6:]}"
            btxt = open(bsrc).read()
            btxt = re.sub(r"^chance = .*$", f"chance = {wpn['burn_chance']}", btxt, count=1, flags=re.M)
            open(f"{ndir}/{slug}_burning_data.tres", "w").write(btxt)
            tmpl_stats = tmpl_stats.replace(m.group(1), f"res://weapons/{kind}/{slug}/{slug}_burning_data.tres")

    # give ranged weapons their own themed projectile (clone scene + swap sprite)
    tmpl_stats = wire_projectile(wpn, tmpl_stats, ndir)

    # specials as effect resources (shared by every tier)
    for i, (key, value, text_key) in enumerate(wpn["specials"]):
        open(f"{ndir}/{slug}_effect_{i}.tres", "w").write(special_effect_tres(key, value, text_key))

    # explosive weapons get their own ExplodingEffect (rocket_launcher clones do
    # NOT inherit the template's explosion - it lives in the template's data, not
    # the copied stats). Shared across tiers.
    if wpn["explode_scale"] is not None:
        open(f"{ndir}/{slug}_explode.tres", "w").write(
            exploding_effect_tres(wpn["explode_scale"], wpn["explode_marker"] or ""))

    tiers = list(range(wpn["start_tier"], wpn["end_tier"] + 1))
    ids = {}
    for tier_idx in tiers:
        ids[tier_idx] = next_id
        next_id += 1

    registered = []
    for tier_idx in tiers:
        n = tier_idx + 1
        d = f"{ndir}/{n}"
        os.makedirs(d, exist_ok=True)
        open(f"{d}/{slug}_{n}_stats.tres", "w").write(patch_stats(tmpl_stats, wpn, tier_idx))

        exts = [
            '[ext_resource path="res://items/global/weapon_data.gd" type="Script" id=1]',
            f'[ext_resource path="res://weapons/{kind}/{slug}/{slug}_icon.png" type="Texture" id=2]',
            f'[ext_resource path="res://weapons/{kind}/{slug}/{slug}.tscn" type="PackedScene" id=3]',
            f'[ext_resource path="res://weapons/{kind}/{slug}/{n}/{slug}_{n}_stats.tres" type="Resource" id=4]',
        ]
        next_ext = 5
        set_refs = []
        for set_name in wpn["sets"]:
            path = None
            set_dir = {"elemental": "fire"}.get(set_name, set_name)
            for cand in (f"res://items/sets/{set_dir}/{set_dir}_set_data.tres",
                         f"res://dlcs/dlc_1/sets/{set_dir}/{set_dir}_set_data.tres"):
                if os.path.exists(f"{DEC}/{cand[6:]}"):
                    path = cand
                    break
            if path is None:
                print(f"  ! set missing on disk, skipped: {set_name} ({slug})")
                continue
            exts.append(f'[ext_resource path="{path}" type="Resource" id={next_ext}]')
            set_refs.append(f"ExtResource( {next_ext} )")
            next_ext += 1
        upgrade_ref = ""
        if tier_idx < wpn["end_tier"]:
            exts.append(f'[ext_resource path="res://weapons/{kind}/{slug}/{tier_idx + 2}/{slug}_{tier_idx + 2}_data.tres" type="Resource" id={next_ext}]')
            upgrade_ref = f"ExtResource( {next_ext} )"
            next_ext += 1
        effect_refs = []
        for i in range(len(wpn["specials"])):
            exts.append(f'[ext_resource path="res://weapons/{kind}/{slug}/{slug}_effect_{i}.tres" type="Resource" id={next_ext}]')
            effect_refs.append(f"ExtResource( {next_ext} )")
            next_ext += 1
        if wpn["explode_scale"] is not None:
            exts.append(f'[ext_resource path="res://weapons/{kind}/{slug}/{slug}_explode.tres" type="Resource" id={next_ext}]')
            effect_refs.append(f"ExtResource( {next_ext} )")
            next_ext += 1

        data = f"""[gd_resource type="Resource" load_steps={next_ext} format=2]

{chr(10).join(exts)}

[resource]
script = ExtResource( 1 )
my_id = "weapon_{slug}_{n}"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "WEAPON_{slug.upper()}"
tier = {tier_idx}
value = {VALUES[tier_idx]}
effects = [ {", ".join(effect_refs)} ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
weapon_id = "weapon_{slug}"
type = {wtype}
sets = [ {", ".join(set_refs)} ]
scene = ExtResource( 3 )
stats = ExtResource( 4 )
upgrades_into = {upgrade_ref if upgrade_ref else "null"}
add_to_chars_as_starting = [  ]
"""
        open(f"{d}/{slug}_{n}_data.tres", "w").write(data)
        registered.append((f"weapons/{kind}/{slug}/{n}/{slug}_{n}_data.tres", ids[tier_idx]))
    return registered, next_id


def build_culinary_set(next_id):
    d = f"{SETS_DIR}/culinary"
    os.makedirs(d, exist_ok=True)
    bonuses = [2, 4, 6, 9, 12]
    for i, v in enumerate(bonuses):
        open(f"{d}/culinary_bonus_{i + 2}.tres", "w").write(special_effect_tres("stat_appetite", v, ""))
    exts = ['[ext_resource path="res://items/sets/set_data.gd" type="Script" id=1]']
    refs = []
    for i in range(5):
        exts.append(f'[ext_resource path="res://items/sets/culinary/culinary_bonus_{i + 2}.tres" type="Resource" id={i + 2}]')
        refs.append(f"[ ExtResource( {i + 2} ) ]")
    open(f"{d}/culinary_set_data.tres", "w").write(f"""[gd_resource type="Resource" load_steps=7 format=2]

{chr(10).join(exts)}

[resource]
script = ExtResource( 1 )
my_id = "set_culinary"
name = "WEAPON_CLASS_CULINARY"
set_bonuses = [ {", ".join(refs)} ]
""")
    return [("items/sets/culinary/culinary_set_data.tres", next_id)], next_id + 1


ANCHOR = '[ext_resource path="res://items/custom_stats/stat_appetite.tres" type="Resource" id=825]\n'

def register(weapon_entries, set_entries):
    t = open(TSCN).read()
    assert ANCHOR in t
    new_w, new_s = [], []
    for rel, ext_id in weapon_entries + set_entries:
        line = f'[ext_resource path="res://{rel}" type="Resource" id={ext_id}]\n'
        if line not in t:
            t = t.replace(ANCHOR, ANCHOR + line)
            (new_s if "sets/" in rel else new_w).append(ext_id)
    for arr_name, ids in (("weapons", new_w), ("sets", new_s)):
        if ids:
            m = re.search(rf"^{arr_name} = \[.*\]$", t, re.M)
            arr = m.group(0)
            add = "".join(f", ExtResource( {i} )" for i in ids)
            t = t.replace(arr, arr[:arr.rfind("]")].rstrip() + add + " ]", 1)
    total_new = len(new_w) + len(new_s)
    if total_new:
        m3 = re.search(r"load_steps=(\d+)", t)
        t = t.replace(f"load_steps={m3.group(1)}", f"load_steps={int(m3.group(1)) + total_new}", 1)
        open(TSCN, "w").write(t)
    print(f"registered {len(new_w)} weapon tiers + {len(new_s)} sets")


def add_csv_rows():
    lines = open(CSV).read().rstrip("\n").split("\n")
    added = 0
    for key, text in CSV_ROWS:
        assert "," not in text, key
        if not any(l.startswith(key + ",") for l in lines):
            lines.append(f"{key},{text}")
            added += 1
    open(CSV, "w").write("\n".join(lines) + "\n")
    print(f"added {added} translation rows")


def main():
    next_id = BASE_ID
    set_entries, next_id = build_culinary_set(next_id)
    weapon_entries = []
    for wpn in WEAPONS:
        entries, next_id = build_weapon(wpn, next_id)
        weapon_entries += entries
        print(f"{wpn['slug']}: tiers {[e[1] for e in entries]}")
    register(weapon_entries, set_entries)
    add_csv_rows()
    print(f"next free ext id: {next_id}")

if __name__ == "__main__":
    main()
