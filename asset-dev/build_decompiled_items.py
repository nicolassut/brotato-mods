import os
import hashlib
import shutil

PROJECT_ROOT = "/Users/nicolassutcliffe/brotato-decompiled"
ICON_SRC_DIR = "/Users/nicolassutcliffe/brotato-mods/Brotato Icons/scaled_96"

ITEMS = [
    ("vampire_fang", "Vampire Fang", 4, 110,
        [("stat_lifesteal", 15), ("stat_max_hp", -5)]),
    ("iron_lung", "Iron Lung", 4, 95,
        [("stat_max_hp", 30), ("stat_attack_speed", -15), ("stat_speed", -10)]),
    ("overclocked_chip", "Overclocked Chip", 4, 105,
        [("stat_engineering", 6), ("structure_attack_speed", 25), ("stat_percent_damage", -15)]),
    ("overtime_pay", "Overtime Pay", 3, 80,
        [("stat_attack_speed", 6), ("stat_armor", -2)]),
    ("second_mortgage", "Second Mortgage", 3, 70,
        [("gain_pct_gold_start_wave", -15), ("percent_materials", 10)]),
    ("voodoo_potato", "Voodoo Potato", 3, 70,
        [("stat_elemental_damage", 10), ("stat_max_hp", -5)]),
    ("energy_drink", "Energy Drink", 2, 50,
        [("stat_attack_speed", 15), ("stat_speed", 5), ("stat_max_hp", -3)]),
    ("loaded_dice", "Loaded Dice", 2, 60,
        [("stat_luck", 8), ("stat_crit_chance", 5), ("stat_armor", -3)]),
    ("tin_foil_hat", "Tin Foil Hat", 1, 15,
        [("stat_dodge", 5), ("stat_max_hp", -1)]),
    ("potato_peeler", "Potato Peeler", 1, 15,
        [("stat_engineering", 2)]),
]


def fake_hash(name):
    return hashlib.md5(name.encode()).hexdigest()


def write(path, content):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w") as f:
        f.write(content)


def effect_tres(key, value):
    return f'''[gd_resource type="Resource" load_steps=2 format=2]

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
'''


def png_import_tres(res_path_png, stex_hash):
    return f'''[remap]

importer="texture"
type="StreamTexture"
path="res://.import/{os.path.basename(res_path_png)}-{stex_hash}.stex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res_path_png}"
dest_files=[ "res://.import/{os.path.basename(res_path_png)}-{stex_hash}.stex" ]

[params]

compress/mode=0
compress/lossy_quality=0.7
compress/hdr_mode=0
compress/bptc_ldr=0
compress/normal_map=0
flags/repeat=0
flags/filter=true
flags/mipmaps=false
flags/anisotropic=false
flags/srgb=2
process/fix_alpha_border=true
process/premult_alpha=false
process/HDR_as_SRGB=false
process/invert_color=false
process/normal_map_invert_y=false
stream=false
size_limit=0
detect_3d=true
svg/scale=1.0
'''


item_res_paths = []

for item_id, name, tier, value, effects in ITEMS:
    item_dir = f"items/custom/{item_id}"
    res_dir = f"res://{item_dir}"

    src_png = os.path.join(ICON_SRC_DIR, f"{item_id}.png")
    dst_png = os.path.join(PROJECT_ROOT, item_dir, f"{item_id}.png")
    os.makedirs(os.path.dirname(dst_png), exist_ok=True)
    shutil.copyfile(src_png, dst_png)

    png_res_path = f"{res_dir}/{item_id}.png"
    stex_hash = fake_hash(png_res_path)
    write(os.path.join(PROJECT_ROOT, item_dir, f"{item_id}.png.import"),
          png_import_tres(png_res_path, stex_hash))

    effect_ext_lines = []
    effect_ext_ids = []
    load_id = 3
    for i, (key, val) in enumerate(effects, start=1):
        fname = f"{item_id}_effect_{i}.tres"
        write(os.path.join(PROJECT_ROOT, item_dir, fname), effect_tres(key, val))
        eid = load_id
        load_id += 1
        effect_ext_ids.append(eid)
        effect_ext_lines.append(f'[ext_resource path="{res_dir}/{fname}" type="Resource" id={eid}]')

    tags = sorted(set(k for k, v in effects))
    tags_str = ", ".join(f'"{t}"' for t in tags)
    effects_str = ", ".join(f"ExtResource( {eid} )" for eid in effect_ext_ids)

    item_tres = f'''[gd_resource type="Resource" load_steps={2 + len(effects)} format=2]

[ext_resource path="res://items/global/item_data.gd" type="Script" id=1]
[ext_resource path="{png_res_path}" type="Texture" id=2]
{chr(10).join(effect_ext_lines)}

[resource]
script = ExtResource( 1 )
my_id = "item_{item_id}"
unlocked_by_default = true
can_be_looted = true
icon = ExtResource( 2 )
name = "{name}"
tier = {tier}
value = {value}
effects = [ {effects_str} ]
tracking_text = ""
is_lockable = false
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
max_nb = -1
item_appearances = [  ]
tags = [ {tags_str} ]
'''
    item_res_path = f"{res_dir}/{item_id}_data.tres"
    write(os.path.join(PROJECT_ROOT, item_dir, f"{item_id}_data.tres"), item_tres)
    item_res_paths.append((item_id, name, item_res_path))

print("Items built in decompiled project:")
for item_id, name, path in item_res_paths:
    print(f"  {item_id}: {path}")

with open("/tmp/decompiled_item_paths.txt", "w") as f:
    for item_id, name, path in item_res_paths:
        f.write(f"{item_id}|{name}|{path}\n")
