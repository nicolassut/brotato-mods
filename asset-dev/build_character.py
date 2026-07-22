MOD_ROOT = "/Users/nicolassutcliffe/brotato-mods/mods-unpacked/nicolassut-NewItems"

item_paths = []
with open("/tmp/item_ext_paths.txt") as f:
    for line in f:
        item_id, name, path = line.strip().split("|")
        item_paths.append((item_id, name, path))

lines = []
lines.append('[ext_resource path="res://items/characters/character_data.gd" type="Script" id=1]')
lines.append('[ext_resource path="res://items/characters/well_rounded/well_rounded_icon.png" type="Texture" id=2]')
lines.append('[ext_resource path="res://items/characters/well_rounded/well_rounded_eyes_appearance.tres" type="Resource" id=3]')
lines.append('[ext_resource path="res://items/characters/well_rounded/well_rounded_mouth_appearance.tres" type="Resource" id=4]')
lines.append('[ext_resource path="res://weapons/melee/knife/1/knife_data.tres" type="Resource" id=5]')

item_ids = []
next_id = 6
for item_id, name, path in item_paths:
    lines.append(f'[ext_resource path="{path}" type="Resource" id={next_id}]')
    item_ids.append(next_id)
    next_id += 1

starting_items_str = ", ".join(f"ExtResource( {i} )" for i in item_ids)

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
effects = [  ]
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
starting_items = [ {starting_items_str} ]
'''

out_path = f"{MOD_ROOT}/content/characters/test_character/test_character.tres"
with open(out_path, "w") as f:
    f.write(body)
print("wrote", out_path)
print()
print(body)
