#!/usr/bin/env python3
"""Generate all 14 Gourmet-DLC CharacterData resources into the decompiled
project and register them in item_service.tscn.

Kits follow asset-dev/characters/CHARACTER_SPECS.md (the recovered authoritative
spec). Exact [DATA] lines are implemented; positives marked #PROV are temporary
stand-ins for food-system/deep mechanics and get replaced when those land.
Every character gets a THEMED STARTING WEAPON POOL (validated against disk).
Re-runnable; the .tscn patch self-skips once ext ids are present."""
import os, shutil, re

DEC   = "/Users/nicolassutcliffe/brotato-decompiled"
FINAL = "/Users/nicolassutcliffe/brotato-mods/asset-dev/characters/final"
APPSRC= f"{FINAL}/appearances"
CUSTOM= f"{DEC}/items/custom_characters"
TSCN  = f"{DEC}/singletons/item_service.tscn"

ANVIL = "res://items/all/anvil/anvil_data.tres"
DOGGY_BAG = "res://items/custom/doggy_bag/doggy_bag_data.tres"
FONDUE_SET = "res://items/custom/fondue_set/fondue_set_data.tres"
CHICKEN_SOUP = "res://items/custom/chicken_soup/chicken_soup_data.tres"
POCKET_SAND = "res://items/custom/pocket_sand/pocket_sand_data.tres"
MAGNIFYING_GLASS = "res://items/custom/magnifying_glass/magnifying_glass_data.tres"
MOSQUITO_JAR = "res://items/custom/mosquito_jar/mosquito_jar_data.tres"

def weapon_path(name):
    """resolve a tier-1 weapon name to its res:// path, checking disk (handles
    melee/ranged and the rail_gun-style _1_data naming)."""
    for kind in ("melee","ranged"):
        for fn in (f"{name}_data.tres", f"{name}_1_data.tres"):
            rel = f"weapons/{kind}/{name}/1/{fn}"
            if os.path.exists(f"{DEC}/{rel}"):
                return "res://" + rel
    return None

# themed starting-weapon pools (tier-1 names; validated at build time).
# Sized like vanilla (Mage 8 ... Streamer 25): generalists get wide culinary+
# vanilla spreads, deliberate restrictions stay rare (Minimalist = fist only).
# Culinary T1 roster: ladle, cleaver, frying_pan, rolling_pin, whisk,
# cheese_grater, skewer, trident_fork, dinner_bell, fish_slapper (melee) +
# sauce_blaster, pizza_cutter, corn_cannon, champagne_popper (ranged).
# baguette/butchers_saw/golden_spatula/meat_tenderizer/ice_cream_scoop start
# at tier 2+ on purpose (shop finds) and cannot be starting weapons.
POOLS = {
 "gourmet":     ["ladle","frying_pan","rolling_pin","whisk","cheese_grater","skewer",
                 "trident_fork","dinner_bell","fish_slapper","cleaver","knife","torch",
                 "sauce_blaster","pizza_cutter","corn_cannon","champagne_popper"],
 "picky_eater": ["skewer","trident_fork","scissors","pistol","slingshot","taser","crossbow",
                 "wand","smg","revolver","pizza_cutter","champagne_popper","medical_gun"],
 "dishwasher":  ["wrench","plank","stick","hand","fist","frying_pan","ladle","rolling_pin",
                 "whisk","cheese_grater","dinner_bell","fish_slapper","sauce_blaster"],
 "comp_eater":  ["fist","hand","claw","plank","sharp_tooth","trident_fork","skewer",
                 "dinner_bell","frying_pan","chopper","torch","corn_cannon"],
 "butcher":     ["cleaver","chopper","knife","hatchet","dagger","skewer","scissors","spear",
                 "sharp_tooth","trident_fork","fish_slapper"],
 "zombie":      ["fist","hand","claw","rock","stick","plank","torch","sharp_tooth",
                 "screwdriver","dagger","slingshot"],
 "minimalist":  ["fist"],
 "mime":        ["knife","hand","scissors","fighting_stick","stick","plank","fist","wand"],
 "tourist":     ["knife","stick","pistol","slingshot","smg","revolver","crossbow","wand",
                 "double_barrel_shotgun","taser","champagne_popper","corn_cannon",
                 "pizza_cutter","galley_cannon"],
 "ruminant":    ["stick","plank","rock","cactus_mace","hatchet","fighting_stick","torch",
                 "frying_pan","rolling_pin","dinner_bell","whisk","corn_cannon"],
 "snail":       ["spiky_shield","rock","plank","stick","cactus_mace","jousting_lance",
                 "screwdriver","trident_fork","fish_slapper","icicle","sauce_blaster"],
 "blacksmith":  ["wrench","hatchet","screwdriver","rock","knife","spear","torch","chopper",
                 "cactus_mace","skewer","fighting_stick","jousting_lance"],
 "juggler":     ["knife","dagger","scissors","shuriken","chopper","skewer","wand",
                 "pizza_cutter","shredder","champagne_popper"],
 "mole":        ["screwdriver","claw","dagger","hand","knife","scissors","rock","skewer",
                 "cheese_grater","pruner","torch"],
}

# guaranteed starting weapons per spec ("Gourmet starts with Ladle", "Butcher
# starts with a Cleaver"), granted via the vanilla starting_weapon effect
# (ranger_effect_3 pattern) on top of the normal weapon choice.
WEAPON_GRANTS = {
 "gourmet": "weapon_ladle_1",
 "butcher": "weapon_cleaver_1",
}

ALL_STATS = ["stat_max_hp","stat_hp_regeneration","stat_lifesteal","stat_percent_damage",
 "stat_melee_damage","stat_ranged_damage","stat_elemental_damage","stat_attack_speed",
 "stat_crit_chance","stat_engineering","stat_range","stat_armor","stat_dodge",
 "stat_speed","stat_luck","stat_harvesting"]

# entry: (key,value) | ("FOOD",stat,val) | ("SLOT",stat,val) | ("DIFF",stat,val)
#        ("POS",key,val) sign0 | ("NEG",key,val) sign1 | ("TXT",key,val,text_key) sign1
#        ("SPECIFIC_PRICE",item_id,val)

# tracking_text translation keys per character (live "[label]: N" card line;
# the key must also be seeded in run_data.gd init_tracked_items and fed via
# RunData.add_tracked_value)
TRACKING = {"gourmet": "GOURMET_APPETITE_GAINED",
            "snail": "GOURMET_SNAIL_ARMOR_GAINED"}  # escargot easter-egg armor

# banned shop items per character (balance law: Dishwasher bans Cooler Box)
BANNED = {"dishwasher": ["item_cooler_box"]}

CHARS = [
 ("gourmet","Gourmet","character_gourmet",["food"],
   [("LINE","EFFECT_GOURMET_FRUIT",0),("LINE","EFFECT_GOURMET_EAT",0),("LINE","EFFECT_GOURMET_NOHEAL",1),
    ("gain_stat_hp_regeneration",-50),("stat_speed",-5)],[]),
 ("picky_eater","Picky Eater","character_picky_eater",["food"],
   [("LINE","EFFECT_PICKY_ONE_SPAWNER",2),("LINE","EFFECT_PICKY_STRONGER",0),
    ("LINE","EFFECT_PICKY_PENALTY",1),
    ("POS","spawner_items_price",-25),
    ("gain_stat_luck",-50)],[]),
 ("dishwasher","Dishwasher","character_dishwasher",["food"],
   [("LINE","EFFECT_DISHWASHER_EXPIRY",1),("LINE","EFFECT_DISHWASHER_LEFTOVERS",0),
    ("LINE","EFFECT_DISHWASHER_REFUND",0),
    ("weapon_slot",-1),("stat_percent_damage",-10),("NEG","items_price",5)],[DOGGY_BAG]),
 ("comp_eater","Competitive Eater","character_comp_eater",["food"],
   [("LINE","EFFECT_COMP_EATER_STACK",2),            # double-stack/half-duration is live engine code
    ("gain_stat_max_hp",-30),("stat_dodge",-10)],[]),
 ("butcher","Butcher","character_butcher",[],
   [("LINE","EFFECT_BUTCHER_STEAK",0),
    ("stat_speed",-15),("gain_stat_speed",-50),("stat_attack_speed",-20),
    ("gain_stat_attack_speed",-25),("gain_stat_ranged_damage",-100)],[]),
 ("zombie","Zombie","character_zombie",[],
   [("NEG","no_heal",1),("gain_stat_percent_damage",50),("stat_attack_speed",-20),
    ("TXT","dodge_cap",-50,"EFFECT_ZOMBIE_DODGE_CAP")],[MOSQUITO_JAR]),
 ("minimalist","Minimalist","character_minimalist",[],
   [("MINISUM",),("LINE","EFFECT_MINIMALIST_ALL12",0),
    ("LINE","EFFECT_MINIMALIST_SELL",2),("LINE","EFFECT_MINIMALIST_CAP",1),
    ("weapon_slot",-1),("NEG","reroll_price",100),("NEG","items_price",25),
    ("stat_harvesting",-25),("gain_stat_harvesting",-50)] + [("DIFF",s,2) for s in ALL_STATS],[]),
 ("mime","Mime","character_mime",[],
   [("LINE","EFFECT_MIME_MIRROR_SHOP",2),("LINE","EFFECT_MIME_MIRROR_WEAPONS",2),
    ("SPECIFIC_PRICE","item_mirror",-50),
    ("NEG","reroll_price",50),("NEG","enemy_health",15),("NEG","enemy_attack_speed",15)],[]),
 ("tourist","Tourist","character_tourist",[],
   [("LINE","EFFECT_TOURIST_MODS",0),("LINE","EFFECT_TOURIST_ENEMY",1),
    ("xp_gain",-20),("gain_xp_gain",-50)],[MAGNIFYING_GLASS]),        # danger scaling applied in main.gd hook
 ("ruminant","Ruminant","character_ruminant",["food"],
   [("LINE","EFFECT_RUMINANT_ECHO",0),
    ("stat_speed",-20),("gain_stat_speed",-25),("stat_armor",-2)],[CHICKEN_SOUP]),
 ("snail","Slug","character_snail",[],
   [("LINE","EFFECT_SLUG_TRAIL",0),("stat_armor",6),("stat_max_hp",20),("gain_stat_dodge",-100),
    ("TXT","speed_cap",-100000019,"EFFECT_SLUG_SPEED_CAP")],[FONDUE_SET]),
 ("blacksmith","Blacksmith","character_blacksmith",[],
   [("LINE","EFFECT_BLACKSMITH_FORGE",0),
    ("NEG","weapons_price",25),("gain_stat_elemental_damage",-50),("stat_speed",-5)],[ANVIL]),
 ("juggler","Juggler","character_juggler",[],
   [("LINE","EFFECT_JUGGLER_CYCLE",2),("LINE","EFFECT_JUGGLER_FAST",0),
    ("stat_percent_damage",-15),("gain_stat_armor",-50)],[]),     # cycling is live engine code
 ("mole","Mole","character_mole",[],
   [("LINE","EFFECT_MOLE_FOG",2),
    ("stat_percent_damage",30),("stat_luck",10),("xp_gain",15),("gain_stat_melee_damage",50),
    ("stat_range",-50),("gain_stat_ranged_damage",-25)],[POCKET_SAND]),
]

SKINNED = {"zombie","snail","mole"}
LEGS_MOD = {
 "zombie": (0.581, 0.961, 0.470),
 "snail":  (0.716, 0.783, 0.727),
 "mole":   (0.950, 0.805, 0.615),
}

def plain(key, value, sign):
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{key}"
text_key = ""
value = {value}
custom_key = ""
storage_method = 0
effect_sign = {sign}
custom_args = [  ]
"""

def txt_effect_tres(key, value, text_key, sign=1):
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{key}"
text_key = "{text_key}"
value = {value}
custom_key = ""
storage_method = 0
effect_sign = {sign}
custom_args = [  ]
"""

def line_tres(text_key, sign):
    """pure description line: no functional key, just translated text (the DLC's
    own tooltip-effect pattern, e.g. EFFECT_CURSED_MIRROR)."""
    return txt_effect_tres("", 0, text_key, sign)

def minisum_tres():
    """Minimalist's live summary line (custom script shows +8/+12 and the running total)."""
    return """[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://effects/items/minimalist_all_stats_effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = ""
text_key = "EFFECT_MINIMALIST_ALL"
value = 8
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [  ]
"""

def grant_tres(element_id, custom_key):
    """vanilla guaranteed-start pattern (arms_dealer_effect_1c / ranger_effect_3):
    custom_key 'starting_item' or 'starting_weapon', key = element my_id.
    RunData.add_starting_items_and_weapons() grants these at run start; the
    CharacterData.starting_items ARRAY is NOT this - that array only adds
    selectable picks to the weapon-selection screen."""
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{element_id}"
text_key = "effect_starting_item"
value = 1
custom_key = "{custom_key}"
storage_method = 1
effect_sign = 3
custom_args = [  ]
"""

def item_my_id(res_path):
    """read my_id out of an item .tres given its res:// path."""
    disk = res_path.replace("res://", f"{DEC}/")
    with open(disk) as f:
        m = re.search(r'^my_id = "([^"]+)"', f.read(), re.M)
    assert m, f"no my_id in {disk}"
    return m.group(1)

def specific_price_tres(item_id, value):
    """fisherman_effect_2 pattern: per-item shop price modifier."""
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{item_id}"
text_key = "EFFECT_SPECIFIC_ITEM_PRICE"
value = {value}
custom_key = "specific_items_price"
storage_method = 1
effect_sign = 0
custom_args = [  ]
"""

def scaler_tres(stat_key, value, scaled, text_key):
    return f"""[gd_resource type="Resource" load_steps=4 format=2]

[ext_resource path="res://effects/items/gain_stat_for_every_stat_effect.gd" type="Script" id=1]
[ext_resource path="res://items/global/custom_arg.gd" type="Script" id=2]

[sub_resource type="Resource" id=1]
script = ExtResource( 2 )
arg_index = 4
arg_sign = 4
arg_value = 0
arg_format = 0
arg_key = ""

[resource]
script = ExtResource( 1 )
key = "{stat_key}"
text_key = "{text_key}"
value = {value}
custom_key = ""
storage_method = 0
effect_sign = 0
custom_args = [ SubResource( 1 ) ]
nb_stat_scaled = 1
stat_scaled = "{scaled}"
perm_stats_only = false
"""

def effect_txt(entry):
    if entry[0]=="FOOD": return scaler_tres(entry[1],entry[2],"food_item","EFFECT_GAIN_STAT_FOR_EVERY_STAT")
    if entry[0]=="SLOT": return scaler_tres(entry[1],entry[2],"free_weapon_slots","EFFECT_GAIN_STAT_FOR_FREE_WEAPON_SLOTS")
    if entry[0]=="DIFF": return scaler_tres(entry[1],entry[2],"minimalist_item","EFFECT_HIDDEN")
    if entry[0]=="POS":  return plain(entry[1],entry[2],0)
    if entry[0]=="NEG":  return plain(entry[1],entry[2],1)
    if entry[0]=="TXT":  return txt_effect_tres(entry[1],entry[2],entry[3])
    if entry[0]=="LINE": return line_tres(entry[1],entry[2])
    if entry[0]=="MINISUM": return minisum_tres()
    if entry[0]=="SPECIFIC_PRICE": return specific_price_tres(entry[1],entry[2])
    return plain(entry[0],entry[1],3)

def appearance_tres(sprite_rel, position, depth, priority):
    return f"""[gd_resource type="Resource" load_steps=3 format=2]

[ext_resource path="res://items/global/item_appearance_data.gd" type="Script" id=1]
[ext_resource path="{sprite_rel}" type="Texture" id=2]

[resource]
script = ExtResource( 1 )
sprite = ExtResource( 2 )
position = {position}
display_priority = {priority}
depth = {depth}
is_character_appearance = true
"""

def char_tres(slug, disp, myid, wanted, n_effects, weapon_paths):
    skinned = slug in SKINNED
    ext = [("res://items/characters/character_data.gd","Script"),
           (f"res://items/custom_characters/{slug}/{slug}_icon.png","Texture")]
    face_id = len(ext)+1
    ext.append((f"res://items/custom_characters/{slug}/{slug}_face_appearance.tres","Resource"))
    if skinned:
        skin_id = len(ext)+1
        ext.append((f"res://items/custom_characters/{slug}/{slug}_skin_appearance.tres","Resource"))
    wep_ids = []
    for wp in weapon_paths:
        wep_ids.append(len(ext)+1); ext.append((wp,"Resource"))
    eff_ids = []
    for i in range(n_effects):
        eff_ids.append(len(ext)+1)
        ext.append((f"res://items/custom_characters/{slug}/{slug}_effect_{i}.tres","Resource"))

    lines = [f'[gd_resource type="Resource" load_steps={len(ext)+1} format=2]', ""]
    for i,(p,t) in enumerate(ext):
        lines.append(f'[ext_resource path="{p}" type="{t}" id={i+1}]')
    apps = (f"ExtResource( {skin_id} ), " if skinned else "") + f"ExtResource( {face_id} )"
    effs = ", ".join(f"ExtResource( {e} )" for e in eff_ids)
    weps = ", ".join(f"ExtResource( {w} )" for w in wep_ids)
    wanted_str = ", ".join(f'"{t}"' for t in wanted)
    lines += ["", "[resource]",
      "script = ExtResource( 1 )",
      f'my_id = "{myid}"',
      "unlocked_by_default = true",
      "can_be_looted = true",
      "icon = ExtResource( 2 )",
      f'name = "{disp}"',
      "tier = 0",
      "value = 1",
      f"effects = [ {effs} ]",
      f'tracking_text = "{TRACKING.get(slug, "")}"',
      "is_lockable = false",
      "unlock_codex_descr_after_get_it = 1",
      "is_cursed = false",
      "curse_factor = 0.0",
      "max_nb = -1",
      f"item_appearances = [ {apps} ]",
      "tags = [  ]",
      f"wanted_tags = [ {wanted_str} ]",
      "banned_item_groups = [  ]",
      f"banned_items = [ {', '.join(chr(34) + b + chr(34) for b in BANNED.get(slug, []))} ]",
      "banned_upgrades = [  ]",
      f"starting_weapons = [ {weps} ]",
      "starting_items = [  ]"]
    if slug in LEGS_MOD:
        r,g,b = LEGS_MOD[slug]
        lines.append(f"legs_modulate = Color( {r}, {g}, {b}, 1 )")
    lines.append("")
    return "\n".join(lines)

def main():
    for slug, disp, myid, wanted, kit, starting_items in CHARS:
        d = f"{CUSTOM}/{slug}"
        os.makedirs(d, exist_ok=True)
        # ART IS ONLY WRITTEN WHEN MISSING: the live pngs and appearance tres
        # are owned by the art pipeline (vectorized icons + full-body overlay
        # faces at depth 1.0, blanked legacy skins). Rerunning this builder
        # must never regress them.
        if not os.path.exists(f"{d}/{slug}_icon.png"):
            shutil.copy(f"{FINAL}/{slug}_icon.png", f"{d}/{slug}_icon.png")
        if not os.path.exists(f"{d}/{slug}_face.png"):
            shutil.copy(f"{APPSRC}/{slug}_face.png", f"{d}/{slug}_face.png")
        if not os.path.exists(f"{d}/{slug}_face_appearance.tres"):
            with open(f"{d}/{slug}_face_appearance.tres","w") as f:
                f.write(appearance_tres(f"res://items/custom_characters/{slug}/{slug}_face.png", 0, "600.0", 0))
        if slug in SKINNED:
            if not os.path.exists(f"{d}/{slug}_skin.png"):
                shutil.copy(f"{APPSRC}/{slug}_skin.png", f"{d}/{slug}_skin.png")
            if not os.path.exists(f"{d}/{slug}_skin_appearance.tres"):
                with open(f"{d}/{slug}_skin_appearance.tres","w") as f:
                    f.write(appearance_tres(f"res://items/custom_characters/{slug}/{slug}_skin.png", 14, "1.0", 3))
        for i,entry in enumerate(kit):
            with open(f"{d}/{slug}_effect_{i}.tres","w") as f: f.write(effect_txt(entry))
        # guaranteed starts appended as extra effects after the kit:
        # weapon grants (spec) then item grants (was wrongly starting_items array)
        idx = len(kit)
        if slug in WEAPON_GRANTS:
            with open(f"{d}/{slug}_effect_{idx}.tres","w") as f:
                f.write(grant_tres(WEAPON_GRANTS[slug], "starting_weapon"))
            idx += 1
        for si in starting_items:
            with open(f"{d}/{slug}_effect_{idx}.tres","w") as f:
                f.write(grant_tres(item_my_id(si), "starting_item"))
            idx += 1
        pool = []
        for name in POOLS[slug]:
            wp = weapon_path(name)
            if wp is None: print(f"  WARN {slug}: weapon '{name}' not found, skipped")
            else: pool.append(wp)
        assert pool, f"{slug}: empty weapon pool"
        with open(f"{d}/{slug}_data.tres","w") as f:
            f.write(char_tres(slug,disp,myid,wanted,idx,pool))
        print(f"wrote {slug} ({len(pool)} weapons, {idx} effects)")

    with open(TSCN) as f: t = f.read()
    base = 811
    ids = {slug: base+i for i,(slug,*_) in enumerate(CHARS)}
    new_ext = "".join(
      f'[ext_resource path="res://items/custom_characters/{slug}/{slug}_data.tres" type="Resource" id={ids[slug]}]\n'
      for slug,*_ in CHARS)
    if f"id={base}]" not in t:
        last_ext = t.rfind("[ext_resource ")
        assert last_ext != -1, "no ext_resource declarations found"
        insert_at = t.index("\n", last_ext) + 1
        t = t[:insert_at] + new_ext + t[insert_at:]
        add = "".join(f", ExtResource( {ids[slug]} )" for slug,*_ in CHARS)
        m = re.search(r"characters = \[ (.*?) \]", t)
        assert m, "characters array not found"
        t = t.replace(m.group(0), "characters = [ " + m.group(1) + add + " ]", 1)
        m = re.search(r"load_steps=(\d+)", t)
        t = t.replace(f"load_steps={m.group(1)}", f"load_steps={int(m.group(1))+len(CHARS)}", 1)
        with open(TSCN,"w") as f: f.write(t)
        print(f"patched item_service.tscn: +{len(CHARS)} characters")
    else:
        print("item_service.tscn already patched - skipped")

if __name__ == "__main__":
    main()
