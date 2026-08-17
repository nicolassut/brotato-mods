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

# (slug, Name, tier, value, [kit...], max_nb=-1)   tags = stat keys involved
# kit entry: (key, val)                     plain stat effect, sign 3 (auto)
#            (key, val, text_key, sign)     custom-key effect with its own card line
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
 # Chewing Gum is the cheap early-game food-duration item: +1s per copy, hard-capped at 3
 # (+3s), paid for in Appetite. Since the blanket x1.5 was folded into the food data, this
 # value is literal seconds - the card says +1s and the player gets +1s (x Appetite factor).
 ("chewing_gum","Chewing Gum",0,18,
  [("stat_attack_speed",3),("stat_appetite",-2),
   ("food_buff_duration",1,"EFFECT_FOOD_BUFF_DURATION",0)],3),
 ("nutrient_paste","Nutrient Paste",1,45,[("stat_armor",2),("stat_appetite",-3)]),
 ("meal_in_a_pill","Meal-in-a-Pill",1,50,[("stat_hp_regeneration",3),("stat_appetite",-3)]),
 ("nervous_wreck","Nervous Wreck",2,70,[("stat_dodge",6),("stat_appetite",-4)]),
 ("gastric_band","Gastric Band",2,80,[("stat_max_hp",8),("stat_appetite",-5)]),
]
BASE_ID = 826

# Cut from the shop pool by hand: these 10 were deregistered from item_service.tscn
# (no ext_resource, not in `items`) even though their tres + icons are still on disk.
# The builder used to re-add them on every run, silently putting them back in the shop;
# it now leaves them out. Delete a slug from here to put that item back in the pool.
DEREGISTERED = {"bib", "rumbling_belly", "family_recipe", "growth_spurt", "tapeworm",
                "executive_palate", "nutrient_paste", "meal_in_a_pill", "nervous_wreck",
                "gastric_band"}

def effect_tres(key, value, text_key="", sign=3):
    # sign 3 = auto (from the value); a custom-key line passes its own text_key + sign
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

def item_tres(slug, name, tier, value, kit, max_nb=-1):
    n = len(kit)
    lines = [f'[gd_resource type="Resource" load_steps={n+3} format=2]', ""]
    lines.append('[ext_resource path="res://items/global/item_data.gd" type="Script" id=1]')
    lines.append(f'[ext_resource path="res://items/custom/{slug}/{slug}.png" type="Texture" id=2]')
    for i in range(n):
        lines.append(f'[ext_resource path="res://items/custom/{slug}/{slug}_effect_{i}.tres" type="Resource" id={3+i}]')
    effs = ", ".join(f"ExtResource( {3+i} )" for i in range(n))
    tags = ", ".join(f'"{k}"' for k, *_rest in kit if k.startswith("stat_"))
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
      f"max_nb = {max_nb}",
      "item_appearances = [  ]",
      f"tags = [ {tags} ]",
      ""]
    return "\n".join(lines)

def main():
    built = []
    for slug, name, tier, value, kit, *rest in ITEMS:
        max_nb = rest[0] if rest else -1
        icon = f"{ICONS}/{slug}.png"
        if not os.path.exists(icon):
            print("skip (no icon yet):", slug); continue
        d = f"{DEC}/items/custom/{slug}"
        os.makedirs(d, exist_ok=True)
        shutil.copy(icon, f"{d}/{slug}.png")
        for i, entry in enumerate(kit):
            k, v = entry[0], entry[1]
            text_key, sign = (entry[2], entry[3]) if len(entry) > 2 else ("", 3)
            with open(f"{d}/{slug}_effect_{i}.tres","w") as f: f.write(effect_tres(k, v, text_key, sign))
        with open(f"{d}/{slug}_data.tres","w") as f: f.write(item_tres(slug,name,tier,value,kit,max_nb))
        built.append(slug)
        print("wrote", slug)

    # Ecosystem Phase 2+: register in the FOOD pack (idempotent); DEREGISTERED
    # items stay unregistered on purpose.
    import sys as _sys
    _sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from pack_registry import register as pack_register
    changed = 0
    for slug in built:
        if slug in DEREGISTERED:
            continue
        if pack_register("food", "items", f"items/custom/{slug}/{slug}_data.tres", quiet=True):
            changed += 1
    print(f"food pack: +{changed} appetite items" if changed else "appetite items pack registration up to date")

if __name__ == "__main__":
    main()
