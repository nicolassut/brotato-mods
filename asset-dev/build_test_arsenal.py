#!/usr/bin/env python3
"""TEST item 'Test Arsenal': grants all 20 custom Culinary/mod weapons + 20 weapon slots.
For playtesting. Weapons are granted via a one-shot hook in RunData.add_item (add_item runs
exactly once per gain, so no double-add). +20 slots comes from a normal weapon_slot effect
(applies live). Registered as a tier-1 lootable item. Idempotent."""
import os, re

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
IDIR = f"{DEC}/items/custom/test_arsenal"
TSCN = f"{DEC}/singletons/item_service.tscn"
CSV = f"{DEC}/items/custom/custom_translations.csv"
ANCHOR = '[ext_resource path="res://items/custom_stats/stat_appetite.tres" type="Resource" id=825]\n'

# lowest-tier my_id per weapon (start tiers differ)
WEAPON_IDS = [
    "weapon_frying_pan_1", "weapon_cleaver_1", "weapon_rolling_pin_1", "weapon_skewer_1",
    "weapon_cheese_grater_1", "weapon_whisk_1", "weapon_ladle_1", "weapon_dinner_bell_1",
    "weapon_baguette_3", "weapon_butchers_saw_3", "weapon_meat_tenderizer_2",
    "weapon_golden_spatula_4", "weapon_trident_fork_1", "weapon_fish_slapper_1",
    "weapon_corn_cannon_1", "weapon_sauce_blaster_1", "weapon_champagne_popper_1",
    "weapon_pizza_cutter_1", "weapon_ice_cream_scoop_2", "weapon_galley_cannon_1",
]

SLOT_EFFECT = '''[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "weapon_slot"
text_key = ""
value = 20
custom_key = ""
storage_method = 0
effect_sign = 3
custom_args = [  ]
'''

DESC_EFFECT = '''[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = ""
text_key = "EFFECT_TEST_ARSENAL"
value = 0
custom_key = ""
storage_method = 0
effect_sign = 3
custom_args = [  ]
'''


def write_item():
    os.makedirs(IDIR, exist_ok=True)
    open(f"{IDIR}/test_arsenal_effect_slots.tres", "w").write(SLOT_EFFECT)
    open(f"{IDIR}/test_arsenal_effect_desc.tres", "w").write(DESC_EFFECT)
    # reuse an existing texture so the item renders (no dedicated art for a test item)
    icon = "res://weapons/melee/butchers_saw/butchers_saw_icon.png"
    data = f'''[gd_resource type="Resource" load_steps=5 format=2]

[ext_resource path="res://items/global/item_data.gd" type="Script" id=1]
[ext_resource path="{icon}" type="Texture" id=2]
[ext_resource path="res://items/custom/test_arsenal/test_arsenal_effect_slots.tres" type="Resource" id=3]
[ext_resource path="res://items/custom/test_arsenal/test_arsenal_effect_desc.tres" type="Resource" id=4]

[resource]
script = ExtResource( 1 )
my_id = "item_test_arsenal"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "ITEM_TEST_ARSENAL"
tier = 0
value = 5
effects = [ ExtResource( 4 ), ExtResource( 3 ) ]
tracking_text = ""
is_lockable = true
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
max_nb = 1
item_appearances = [  ]
tags = [  ]
'''
    open(f"{IDIR}/test_arsenal_data.tres", "w").write(data)
    print("wrote item + effects")


def patch_add_item():
    p = f"{DEC}/singletons/run_data.gd"
    t = open(p).read()
    if "item_test_arsenal" in t:
        print("run_data.gd: add_item hook already present"); return
    anchor = """func add_item(item: ItemData, player_index: int, is_selection: bool = false) -> void :
	if is_selection:
		players_data[player_index].selected_item = item.duplicate()

	players_data[player_index].items.push_back(item)"""
    assert anchor in t
    ids = ", ".join(f'"{w}"' for w in WEAPON_IDS)
    hook = anchor + f"""

	# TEST Arsenal - grants all mod weapons once on gain (add_item runs once per pickup)
	if item != null and item.my_id == "item_test_arsenal":
		for wid in [{ids}]:
			var w = ItemService.get_element(ItemService.weapons, Keys.generate_hash(wid))
			if w != null:
				var _tw = add_weapon(w, player_index)"""
    open(p, "w").write(t.replace(anchor, hook, 1))
    print("run_data.gd: add_item grants 20 weapons on Test Arsenal pickup")


def register():
    t = open(TSCN).read()
    rel = "items/custom/test_arsenal/test_arsenal_data.tres"
    if rel in t:
        print("item_service.tscn: already registered"); return
    line = f'[ext_resource path="res://{rel}" type="Resource" id=991]\n'
    t = t.replace(ANCHOR, ANCHOR + line, 1)
    m = re.search(r"^items = \[.*\]$", t, re.M)
    arr = m.group(0)
    t = t.replace(arr, arr[:arr.rfind("]")].rstrip() + ", ExtResource( 991 ) ]", 1)
    m3 = re.search(r"load_steps=(\d+)", t)
    t = t.replace(f"load_steps={m3.group(1)}", f"load_steps={int(m3.group(1)) + 1}", 1)
    open(TSCN, "w").write(t)
    print("item_service.tscn: registered (ext id 991)")


def add_csv():
    lines = open(CSV).read().rstrip("\n").split("\n")
    rows = [("ITEM_TEST_ARSENAL", "Test Arsenal"),
            ("EFFECT_TEST_ARSENAL", "TEST: start with all 20 Gourmet weapons and 20 weapon slots")]
    added = 0
    for k, v in rows:
        if not any(l.startswith(k + ",") for l in lines):
            lines.append(f"{k},{v}"); added += 1
    open(CSV, "w").write("\n".join(lines) + "\n")
    print(f"csv: +{added} rows")


if __name__ == "__main__":
    write_item(); patch_add_item(); register(); add_csv()
    print("done - repack to test")
