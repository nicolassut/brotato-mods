#!/usr/bin/env python3
"""TEST character 'Test Armory': starts with all 20 mod weapons + 20 weapon slots.
Shows on the character-select screen (that is where the user looked). Reuses the
well_rounded icon + eyes/mouth appearance so it renders as a normal egg. Idempotent."""
import os, re

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
CDIR = f"{DEC}/items/custom_characters/test_armory"
TSCN = f"{DEC}/singletons/item_service.tscn"
CSV = f"{DEC}/items/custom/custom_translations.csv"
ANCHOR = '[ext_resource path="res://items/custom_stats/stat_appetite.tres" type="Resource" id=825]\n'

# (kind, slug, lowest tier dir)
WEAPONS = [
    ("melee", "frying_pan", 1), ("melee", "cleaver", 1), ("melee", "rolling_pin", 1),
    ("melee", "skewer", 1), ("melee", "cheese_grater", 1), ("melee", "whisk", 1),
    ("melee", "ladle", 1), ("melee", "dinner_bell", 1), ("melee", "baguette", 3),
    ("melee", "butchers_saw", 3), ("melee", "meat_tenderizer", 2), ("melee", "golden_spatula", 4),
    ("melee", "trident_fork", 1), ("melee", "fish_slapper", 1), ("ranged", "corn_cannon", 1),
    ("ranged", "sauce_blaster", 1), ("ranged", "champagne_popper", 1), ("ranged", "pizza_cutter", 1),
    ("ranged", "ice_cream_scoop", 2), ("ranged", "galley_cannon", 1),
]

SLOT_EFFECT = '''[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "weapon_slot"
text_key = "EFFECT_TEST_ARMORY"
value = 20
custom_key = ""
storage_method = 0
effect_sign = 3
custom_args = [  ]
'''


def build():
    os.makedirs(CDIR, exist_ok=True)
    open(f"{CDIR}/test_armory_effect_slots.tres", "w").write(SLOT_EFFECT)

    exts = [
        '[ext_resource path="res://items/characters/character_data.gd" type="Script" id=1]',
        '[ext_resource path="res://items/characters/well_rounded/well_rounded_icon.png" type="Texture" id=2]',
        '[ext_resource path="res://items/characters/well_rounded/well_rounded_eyes_appearance.tres" type="Resource" id=3]',
        '[ext_resource path="res://items/characters/well_rounded/well_rounded_mouth_appearance.tres" type="Resource" id=4]',
        '[ext_resource path="res://items/custom_characters/test_armory/test_armory_effect_slots.tres" type="Resource" id=5]',
    ]
    nid = 6
    wrefs = []
    for kind, slug, lt in WEAPONS:
        path = f"res://weapons/{kind}/{slug}/{lt}/{slug}_{lt}_data.tres"
        assert os.path.exists(f"{DEC}/{path[6:]}"), path
        exts.append(f'[ext_resource path="{path}" type="Resource" id={nid}]')
        wrefs.append(f"ExtResource( {nid} )")
        nid += 1
    body = f'''[gd_resource type="Resource" load_steps={nid} format=2]

{chr(10).join(exts)}

[resource]
script = ExtResource( 1 )
my_id = "character_test_armory"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "CHARACTER_TEST_ARMORY"
tier = 0
value = 1
effects = [ ExtResource( 5 ) ]
tracking_text = ""
is_lockable = false
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
max_nb = -1
item_appearances = [ ExtResource( 3 ), ExtResource( 4 ) ]
tags = [  ]
wanted_tags = [  ]
banned_item_groups = [  ]
banned_items = [  ]
banned_upgrades = [  ]
starting_weapons = [ {", ".join(wrefs)} ]
starting_items = [  ]
'''
    open(f"{CDIR}/test_armory_data.tres", "w").write(body)
    print(f"wrote character with {len(wrefs)} starting weapons")


def register():
    t = open(TSCN).read()
    rel = "items/custom_characters/test_armory/test_armory_data.tres"
    if rel in t:
        print("item_service.tscn: character already registered"); return
    line = f'[ext_resource path="res://{rel}" type="Resource" id=992]\n'
    t = t.replace(ANCHOR, ANCHOR + line, 1)
    m = re.search(r"^characters = \[.*\]$", t, re.M)
    arr = m.group(0)
    t = t.replace(arr, arr[:arr.rfind("]")].rstrip() + ", ExtResource( 992 ) ]", 1)
    m3 = re.search(r"load_steps=(\d+)", t)
    t = t.replace(f"load_steps={m3.group(1)}", f"load_steps={int(m3.group(1)) + 1}", 1)
    open(TSCN, "w").write(t)
    print("item_service.tscn: character registered (ext id 992)")


def add_csv():
    lines = open(CSV).read().rstrip("\n").split("\n")
    rows = [("CHARACTER_TEST_ARMORY", "Test Armory"),
            ("EFFECT_TEST_ARMORY", "TEST: starts with all 20 Gourmet weapons and +20 weapon slots")]
    added = 0
    for k, v in rows:
        if not any(l.startswith(k + ",") for l in lines):
            lines.append(f"{k},{v}"); added += 1
    open(CSV, "w").write("\n".join(lines) + "\n")
    print(f"csv: +{added} rows")


if __name__ == "__main__":
    build(); register(); add_csv()
    print("done - repack; pick 'Test Armory' on the character screen")
