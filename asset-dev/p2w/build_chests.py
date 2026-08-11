"""P2W chest data layer (Phase 2).

Generates into the LIVE tree (~/brotato-decompiled):
  items/custom/p2w/chest.png                      - shared placeholder icon (vanilla crate)
  items/custom/p2w/chest_<r>/chest_<r>_data.tres  - one ItemData per rung 1..8
  items/custom/p2w/chest_<r>/chest_<r>_effect_*.tres - card text LINEs (honest odds + curse)
  items/custom/p2w/p2w_data.gd                    - boot-safe const dicts (spread, odds, paths)
and update-or-appends the chest CSV rows into the live custom_translations.csv.

Chests are deliberately NOT registered in item_service.tscn: the engine preloads
them via p2w_data.gd CHEST_PATHS, so normal shops/pools/codex never see them.
Chest tier field = the LADDER tier int (0/7/1/8/2/3/9/10) purely so
change_panel_stylebox_from_tier paints the right rung color on the card.

After running: sync the mirror CSV (cmp game-src copy) per CLAUDE.md.
"""
import csv
import hashlib
import json
import os
import shutil

DEC = os.path.expanduser("~/brotato-decompiled")
HERE = os.path.dirname(os.path.abspath(__file__))
OUT = f"{DEC}/items/custom/p2w"

RUNG_TIERS = {1: 0, 2: 7, 3: 1, 4: 8, 5: 2, 6: 3, 7: 9, 8: 10}
RUNG_NAMES = {1: "White", 2: "Green", 3: "Blue", 4: "Teal",
              5: "Purple", 6: "Red", 7: "Pink", 8: "Gold"}
# engine ladder colors (item_service.gd) - crates tint toward these
RUNG_COLORS = {1: (230, 230, 230), 2: (122, 219, 88), 3: (90, 190, 255), 4: (0, 210, 190),
               5: (173, 90, 255), 6: (255, 59, 59), 7: (255, 105, 199), 8: (255, 205, 60)}
VALUES = {1: 12, 2: 20, 3: 32, 4: 45, 5: 60, 6: 80, 7: 105, 8: 135}
WEAPON_CHANCE = 30       # % of drops that are weapons
CURSED_CHEST_CHANCE = 10  # % rolled at purchase (Abyssal owners only)
CURSED_ITEM_CHANCE = 33   # % per item out of a cursed chest


def odds_for(rung):
    """Honest odds centered on the chest's rung, spilling upward; weight past
    rung 8 folds into 8 so a Gold chest is a guaranteed Gold."""
    raw = [(rung, 70), (rung + 1, 20), (rung + 2, 7), (rung + 3, 3)]
    folded = {}
    for r, w in raw:
        folded[min(r, 8)] = folded.get(min(r, 8), 0) + w
    return sorted(folded.items())


def effect_tres(text_key):
    return f"""[gd_resource type="Resource" load_steps=2 format=2]

[ext_resource path="res://items/global/effect.gd" type="Script" id=1]

[resource]
script = ExtResource( 1 )
key = ""
text_key = "{text_key}"
value = 0
custom_key = ""
storage_method = 0
effect_sign = 2
custom_args = [  ]
"""


def tint_crate(src_png, dst_png, rgb):
    """Rarity-tint the crate: luminance x rung color, dark outline pixels stay
    dark, alpha preserved. White rung keeps the crate nearly untouched."""
    from PIL import Image
    img = Image.open(src_png).convert("RGBA")
    px = img.load()
    w, h = img.size
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            lum = (r * 299 + g * 587 + b * 114) // 1000
            if lum < 40:  # outline stays black
                continue
            f = lum / 255.0
            px[x, y] = (int(rgb[0] * f), int(rgb[1] * f), int(rgb[2] * f), a)
    img.save(dst_png)


def chest_tres(rung, n_effects):
    ext = ['[ext_resource path="res://items/global/item_data.gd" type="Script" id=1]',
           f'[ext_resource path="res://items/custom/p2w/chest_{rung}/chest_{rung}.png" type="Texture" id=2]']
    for i in range(n_effects):
        ext.append(f'[ext_resource path="res://items/custom/p2w/chest_{rung}/chest_{rung}_effect_{i}.tres" type="Resource" id={3 + i}]')
    effects = ", ".join(f"ExtResource( {3 + i} )" for i in range(n_effects))
    return f"""[gd_resource type="Resource" load_steps={3 + n_effects} format=2]

{chr(10).join(ext)}

[resource]
script = ExtResource( 1 )
my_id = "item_p2w_chest_{rung}"
unlocked_by_default = true
can_be_looted = false
icon = ExtResource( 2 )
name = "CHEST_P2W_{rung}"
tier = {RUNG_TIERS[rung]}
value = {VALUES[rung]}
effects = [ {effects} ]
tracking_text = ""
is_lockable = false
unlock_codex_descr_after_get_it = 1
is_cursed = false
curse_factor = 0.0
max_nb = -1
item_appearances = [  ]
tags = [  ]
"""


def csv_update(rows):
    """update-or-append into the LIVE custom_translations.csv (pantry pattern)."""
    path = f"{DEC}/items/custom/custom_translations.csv"
    with open(path, newline="") as f:
        existing = list(csv.reader(f))
    by_key = {r[0]: i for i, r in enumerate(existing) if r}
    for key, text in rows:
        if key in by_key:
            existing[by_key[key]] = [key, text]
        else:
            existing.append([key, text])
    with open(path, "w", newline="") as f:
        csv.writer(f).writerows(existing)


def write_import_sidecar(dest_png, res_path):
    sidecar = dest_png + ".import"
    if os.path.exists(sidecar):
        return
    stex = f"res://.import/{os.path.basename(dest_png)}-{hashlib.md5(res_path.encode()).hexdigest()}.stex"
    open(sidecar, "w").write(f"""[remap]

importer="texture"
type="StreamTexture"
path="{stex}"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{res_path}"
dest_files=[ "{stex}" ]

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
detect_3d=false
svg/scale=1.0
""")


def main():
    spread = json.load(open(os.path.join(HERE, "rarity_spread.json")))
    assert spread.get("locked"), "rarity spread must be locked before building chests"

    os.makedirs(OUT, exist_ok=True)
    shutil.copy(f"{DEC}/items/consumables/item_box/item_box.png", f"{OUT}/chest.png")
    write_import_sidecar(f"{OUT}/chest.png", "res://items/custom/p2w/chest.png")
    for rung in range(1, 9):
        os.makedirs(f"{OUT}/chest_{rung}", exist_ok=True)
        tint_crate(f"{OUT}/chest.png", f"{OUT}/chest_{rung}/chest_{rung}.png", RUNG_COLORS[rung])
        write_import_sidecar(f"{OUT}/chest_{rung}/chest_{rung}.png",
                             f"res://items/custom/p2w/chest_{rung}/chest_{rung}.png")

    csv_rows = [("P2W_OPEN", "OPEN"),
                ("P2W_CURSED", "CURSED"),
                ("P2W_CHESTS", "Chests opened: {0}"),
                ("EFFECT_P2W_SHOP", "The shop sells Chests instead of items and weapons"),
                ("EFFECT_P2W_CHEST_CURSE",
                 f"{CURSED_CHEST_CHANCE}% chance to be cursed when bought - "
                 f"each item inside is then {CURSED_ITEM_CHANCE}% likely to come out cursed")]
    for rung in range(1, 9):
        d = f"{OUT}/chest_{rung}"
        os.makedirs(d, exist_ok=True)
        odds = odds_for(rung)
        odds_text = ", ".join(f"{w}% {RUNG_NAMES[r]}" for r, w in odds)
        csv_rows.append((f"CHEST_P2W_{rung}", f"{RUNG_NAMES[rung]} Chest"))
        csv_rows.append((f"EFFECT_P2W_CHEST_ODDS_{rung}",
                         f"Contains one item ({100 - WEAPON_CHANCE}%) or weapon ({WEAPON_CHANCE}%): {odds_text}"))
        with open(f"{d}/chest_{rung}_effect_0.tres", "w") as f:
            f.write(effect_tres(f"EFFECT_P2W_CHEST_ODDS_{rung}"))
        with open(f"{d}/chest_{rung}_effect_1.tres", "w") as f:
            f.write(effect_tres("EFFECT_P2W_CHEST_CURSE"))
        with open(f"{d}/chest_{rung}_data.tres", "w") as f:
            f.write(chest_tres(rung, 2))
    csv_update(csv_rows)

    # boot-safe engine data: plain const dicts, preloaded by item_service
    rung_by_id = {k: v["rung"] for k, v in sorted(spread["items"].items())}
    def gd_dict(d, key_quotes=True):
        entries = ", ".join((f'"{k}": {v}' if key_quotes else f"{k}: {v}") for k, v in d.items())
        return "{" + entries + "}"
    chest_paths = {r: f'"res://items/custom/p2w/chest_{r}/chest_{r}_data.tres"' for r in range(1, 9)}
    chest_odds = {r: [[x, w] for x, w in odds_for(r)] for r in range(1, 9)}
    gd = f"""extends Reference
# GENERATED by asset-dev/p2w/build_chests.py from the LOCKED rarity_spread.json.
# Do not hand-edit; rerun the builder. Loaded via preload() in item_service.gd.

const RUNG_TIERS = {gd_dict(RUNG_TIERS, False)}
const CHEST_PATHS = {gd_dict(chest_paths, False)}
const CHEST_ODDS = {gd_dict(chest_odds, False)}
const WEAPON_CHANCE = {WEAPON_CHANCE}
const CURSED_CHEST_CHANCE = {CURSED_CHEST_CHANCE}
const CURSED_ITEM_CHANCE = {CURSED_ITEM_CHANCE}
const RUNG_BY_ID = {gd_dict(rung_by_id)}
"""
    with open(f"{OUT}/p2w_data.gd", "w") as f:
        f.write(gd)
    print(f"chests 1-8 written to {OUT}; p2w_data.gd holds {len(rung_by_id)} spread entries; CSV rows updated")


if __name__ == "__main__":
    main()
