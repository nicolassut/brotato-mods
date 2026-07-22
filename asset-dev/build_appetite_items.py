#!/usr/bin/env python3
"""Build the 14 fully-implementable Appetite granter/suppressant items (design
doc section 2a) into items/custom/ and register them in item_service.tscn
(ext ids 826-839). The 6 items needing unbuilt food systems are deferred.
Icons: expects <slug>.png (96x96) in asset-dev/items_appetite/final/ — the
builder skips items whose icon isn't there yet, so it can run incrementally."""
import os, shutil, re

DEC   = "/Users/nicolassutcliffe/brotato-decompiled"
ICONS = "/Users/nicolassutcliffe/brotato-mods/asset-dev/items_appetite/final"
TSCN  = f"{DEC}/singletons/item_service.tscn"

# (slug, Name, tier, value, [(key,val),...])   tags = stat keys involved
ITEMS = [
 ("bib","Bib",0,18,[("stat_appetite",1)]),
 ("salt_shaker","Salt Shaker",0,20,[("stat_appetite",1),("stat_percent_damage",2)]),
 ("rumbling_belly","Rumbling Belly",0,22,[("stat_appetite",2),("stat_max_hp",-1)]),
 ("silver_fork","Silver Fork",0,25,[("stat_appetite",1),("stat_luck",3)]),
 ("chopsticks","Chopsticks",1,45,[("stat_appetite",2),("stat_attack_speed",3),("stat_armor",-1)]),
 ("family_recipe","Family Recipe",1,50,[("stat_appetite",3),("stat_percent_damage",-2)]),
 ("growth_spurt","Growth Spurt",1,50,[("stat_appetite",3),("xp_gain",5)]),
 ("tapeworm","Tapeworm",2,70,[("stat_appetite",6),("stat_hp_regeneration",-2),("stat_max_hp",-3)]),
 ("executive_palate","Executive Palate",2,85,[("stat_appetite",3),("stat_percent_damage",5),("stat_attack_speed",-5)]),
 ("chewing_gum","Chewing Gum",0,18,[("stat_attack_speed",3),("stat_appetite",-2)]),
 ("nutrient_paste","Nutrient Paste",1,45,[("stat_armor",2),("stat_appetite",-3)]),
 ("meal_in_a_pill","Meal-in-a-Pill",1,50,[("stat_hp_regeneration",3),("stat_appetite",-3)]),
 ("nervous_wreck","Nervous Wreck",2,70,[("stat_dodge",6),("stat_appetite",-4)]),
 ("gastric_band","Gastric Band",2,80,[("stat_max_hp",8),("stat_appetite",-5)]),
]
BASE_ID = 826

def effect_tres(key, value):
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{key}"
text_key = ""
value = {value}
custom_key = ""
storage_method = 0
effect_sign = 3
custom_args = [  ]
"""

def item_tres(slug, name, tier, value, kit):
    n = len(kit)
    lines = [f'[gd_resource type="Resource" load_steps={n+3} format=2]', ""]
    lines.append('[ext_resource path="res://items/global/item_data.gd" type="Script" id=1]')
    lines.append(f'[ext_resource path="res://items/custom/{slug}/{slug}.png" type="Texture" id=2]')
    for i in range(n):
        lines.append(f'[ext_resource path="res://items/custom/{slug}/{slug}_effect_{i}.tres" type="Resource" id={3+i}]')
    effs = ", ".join(f"ExtResource( {3+i} )" for i in range(n))
    tags = ", ".join(f'"{k}"' for k,_ in kit if k.startswith("stat_"))
    lines += ["", "[resource]",
      "script = ExtResource( 1 )",
      f'my_id = "item_{slug}"',
      "unlocked_by_default = true",
      "can_be_looted = true",
      "icon = ExtResource( 2 )",
      f'name = "{name}"',
      f"tier = {tier}",
      f"value = {value}",
      f"effects = [ {effs} ]",
      'tracking_text = ""',
      "is_lockable = true",
      "unlock_codex_descr_after_get_it = 1",
      "is_cursed = false",
      "curse_factor = 0.0",
      "max_nb = -1",
      "item_appearances = [  ]",
      f"tags = [ {tags} ]",
      ""]
    return "\n".join(lines)

def main():
    built = []
    for slug, name, tier, value, kit in ITEMS:
        icon = f"{ICONS}/{slug}.png"
        if not os.path.exists(icon):
            print("skip (no icon yet):", slug); continue
        d = f"{DEC}/items/custom/{slug}"
        os.makedirs(d, exist_ok=True)
        shutil.copy(icon, f"{d}/{slug}.png")
        for i,(k,v) in enumerate(kit):
            with open(f"{d}/{slug}_effect_{i}.tres","w") as f: f.write(effect_tres(k,v))
        with open(f"{d}/{slug}_data.tres","w") as f: f.write(item_tres(slug,name,tier,value,kit))
        built.append(slug)
        print("wrote", slug)

    # register the built ones (idempotent per item)
    t = open(TSCN).read()
    ids = {slug: BASE_ID+i for i,(slug,*_) in enumerate(ITEMS)}
    changed = 0
    anchor = '[ext_resource path="res://items/custom_stats/stat_appetite.tres" type="Resource" id=825]\n'
    assert anchor in t, "appetite stat anchor missing"
    new_ids = []
    for slug in built:
        line = f'[ext_resource path="res://items/custom/{slug}/{slug}_data.tres" type="Resource" id={ids[slug]}]\n'
        if line in t: continue
        t = t.replace(anchor, anchor + line)
        new_ids.append(ids[slug])
        changed += 1
    if new_ids:
        # append to the items = [ ... ] array (single line), before its closing bracket
        m = re.search(r"^items = \[.*\]$", t, re.M)
        arr = m.group(0)
        add = "".join(f", ExtResource( {i} )" for i in new_ids)
        t = t.replace(arr, arr[:arr.rfind("]")].rstrip() + add + " ]", 1)
        m2 = re.search(r"load_steps=(\d+)", t)
        t = t.replace(f"load_steps={m2.group(1)}", f"load_steps={int(m2.group(1))+changed}", 1)
        open(TSCN,"w").write(t)
    print(f"registered {changed} new items in item_service.tscn")

if __name__ == "__main__":
    main()
