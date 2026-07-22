import os

PROJECT_ROOT = "/Users/nicolassutcliffe/brotato-decompiled"

item_paths = []
with open("/tmp/decompiled_item_paths.txt") as f:
    for line in f:
        item_id, name, path = line.strip().split("|")
        item_paths.append((item_id, name, path))


def effect_starting_item_tres(item_my_id):
    return f'''[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = "{item_my_id}"
text_key = "effect_starting_item"
value = 1
custom_key = "starting_item"
storage_method = 1
effect_sign = 3
custom_args = [  ]
'''


char_dir = f"{PROJECT_ROOT}/items/custom_characters/test_character"
os.makedirs(char_dir, exist_ok=True)

effect_ext_lines = []
effect_ids = []
next_id = 6
for item_id, name, path in item_paths:
    my_id = f"item_{item_id}"
    fname = f"test_character_starting_{item_id}.tres"
    with open(os.path.join(char_dir, fname), "w") as f:
        f.write(effect_starting_item_tres(my_id))
    effect_ext_lines.append(
        f'[ext_resource path="res://items/custom_characters/test_character/{fname}" type="Resource" id={next_id}]'
    )
    effect_ids.append(next_id)
    next_id += 1

lines = []
lines.append('[ext_resource path="res://items/characters/character_data.gd" type="Script" id=1]')
lines.append('[ext_resource path="res://items/characters/well_rounded/well_rounded_icon.png" type="Texture" id=2]')
lines.append('[ext_resource path="res://items/characters/well_rounded/well_rounded_eyes_appearance.tres" type="Resource" id=3]')
lines.append('[ext_resource path="res://items/characters/well_rounded/well_rounded_mouth_appearance.tres" type="Resource" id=4]')
lines.append('[ext_resource path="res://weapons/melee/knife/1/knife_data.tres" type="Resource" id=5]')
lines.extend(effect_ext_lines)

effects_str = ", ".join(f"ExtResource( {i} )" for i in effect_ids)

body = f'''[gd_resource type="Resource" load_steps={next_id - 1} format=2]

{chr(10).join(lines)}

[resource]
script = ExtResource( 1 )
my_id = "character_test_new_items"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "Test Character"
tier = 0
value = 1
effects = [ {effects_str} ]
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
starting_weapons = [ ExtResource( 5 ) ]
starting_items = [  ]
'''

out_path = f"{char_dir}/test_character_data.tres"
with open(out_path, "w") as f:
    f.write(body)
print("wrote", out_path)
print(body)
