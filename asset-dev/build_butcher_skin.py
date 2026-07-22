#!/usr/bin/env python3
"""Butcher meat reskin: when the Butcher is in the run, every fruit/tree-themed thing
becomes its meat equivalent (same mechanics, new name/icon/description/world sprite).

Verified fruit/tree content this covers (from keys.gd + carriers, base + DLC):
  item_tree             (+1 tree)                  -> Meat Rack
  item_garden           (structure spawns fruit)   -> Meat Locker (+ world sprite)
  item_fruit_basket     (enemy fruit drops)        -> Meat Cooler
  item_lemonade         (consumables heal +1)      -> Beef Broth
  item_lumberjack_shirt (one-shot trees)           -> Bloody Butcher's Apron
  tree neutral on map   (base + DLC 225px)         -> meat drying rack world sprite
  descriptions: every effect text_key mentioning fruit/trees swaps to a meat line,
  including Pocket Factory / Cryptid / Explorer / Druid lines that reuse those keys.
  (Fruit Salad the FOOD deliberately keeps its name - it is food, not the fruit system.)

Also removes the old placeholder red tint in consumable.gd (raw_steak.png is the real art,
tinting it on top made it over-red).

Idempotent: every patch checks for its marker before writing. Art PNGs are installed
separately by process_butcher.py into items/custom/butcher_skin/."""
import os, re

DEC = "/Users/nicolassutcliffe/brotato-decompiled"
SKIN_DIR = f"{DEC}/items/custom/butcher_skin"
CSV = f"{DEC}/items/custom/custom_translations.csv"

# texts mirror the vanilla strings' argument structure exactly (verified against
# .assets/resources/translations/translations.csv) - wrong arg counts print literal braces
CSV_ROWS = [
    ("ITEM_MEAT_RACK", "Meat Rack"),
    ("ITEM_MEAT_LOCKER", "Meat Locker"),
    ("ITEM_MEAT_COOLER", "Meat Cooler"),
    ("ITEM_BEEF_BROTH", "Beef Broth"),
    ("ITEM_BUTCHERS_APRON", "Bloody Butcher's Apron"),
    ("EFFECT_MEAT_RACKS", "More meat racks spawn"),
    ("EFFECT_MEAT_RACKS_PLURAL", "More meat racks spawn"),
    ("EFFECT_MEAT_LOCKER_SPAWN", "Spawns a meat locker that dispenses a steak every {0} seconds"),
    ("EFFECT_ENEMY_STEAK_DROPS", "Enemies have a higher chance of dropping steaks"),
    ("EFFECT_ONE_SHOT_MEAT_RACKS", "Meat racks die in one hit"),
    ("EFFECT_MEAT_RACK_TURRET", "Killing a meat rack spawns a turret"),
    ("EFFECT_GAIN_STAT_FOR_EVERY_MEAT_RACK", "{0} {1} for every current living meat rack [{4}]"),
    ("EFFECT_STAT_ON_STEAK", "+{0} {1} until the end of the wave when picking up a steak"),
    ("EFFECT_POISONED_STEAK", "Steaks have a {0}% chance to be rotten"),
    ("EFFECT_PET_LOOTWORM_MEAT", "Spawns a Lootworm pet that collects materials and destroys meat racks for the player. Each time it picks up a material, it has a {0} chance to double it"),
]

BUTCHER_SKIN_GD = '''extends Node
# Gourmet DLC - Butcher meat reskin. When the Butcher is in the run, the fruit/tree
# ecosystem shows as meat: items rename/re-icon, and every effect description that
# mentions fruit or trees swaps to a meat line. Mechanics are untouched - only
# name/icon/text_key fields change, and they restore on the next non-Butcher run
# (apply() runs from Main._ready() every wave, so state self-heals; menus right
# after a Butcher run may briefly show meat names until the next run starts).

const ICON_DIR = "res://items/custom/butcher_skin/"

# item my_id -> [meat name key, meat icon file]
const ITEM_SWAPS = {
	"item_tree": ["ITEM_MEAT_RACK", "meat_rack_icon.png"],
	"item_garden": ["ITEM_MEAT_LOCKER", "meat_locker_icon.png"],
	"item_fruit_basket": ["ITEM_MEAT_COOLER", "meat_cooler_icon.png"],
	"item_lemonade": ["ITEM_BEEF_BROTH", "beef_broth_icon.png"],
	"item_lumberjack_shirt": ["ITEM_BUTCHERS_APRON", "butchers_apron_icon.png"],
}

# original effect text_key -> meat text_key (covers items AND characters that reuse them)
const TEXT_SWAPS = {
	"effect_trees": "EFFECT_MEAT_RACKS",
	"effect_trees_plural": "EFFECT_MEAT_RACKS_PLURAL",
	"effect_garden": "EFFECT_MEAT_LOCKER_SPAWN",
	"EFFECT_ENEMY_FRUIT_DROPS": "EFFECT_ENEMY_STEAK_DROPS",
	"effect_one_shot_trees": "EFFECT_ONE_SHOT_MEAT_RACKS",
	"EFFECT_TREE_TURRET": "EFFECT_MEAT_RACK_TURRET",
	"EFFECT_GAIN_STAT_FOR_EVERY_TREE": "EFFECT_GAIN_STAT_FOR_EVERY_MEAT_RACK",
	"EFFECT_STAT_ON_FRUIT": "EFFECT_STAT_ON_STEAK",
	"EFFECT_POISONED_FRUIT": "EFFECT_POISONED_STEAK",
	"EFFECT_PET_LOOTWORM": "EFFECT_PET_LOOTWORM_MEAT",
}

var _orig_items: = {}
var _reverse_text: = {}


func _ready() -> void :
	for k in TEXT_SWAPS:
		_reverse_text[TEXT_SWAPS[k]] = k


func is_butcher_in_run() -> bool:
	for i in RunData.get_player_count():
		var c = RunData.get_player_character(i)
		if c != null and c.my_id == "character_butcher":
			return true
	return false


func world_texture(kind: String):
	# kind: "meat_rack_ingame" (tree neutral, 225) or "meat_locker_ingame" (garden, 100)
	var path = ICON_DIR + kind + ".png"
	if ResourceLoader.exists(path):
		return load(path)
	return null


func apply() -> void :
	var meaty: = is_butcher_in_run()
	_apply_list(ItemService.items, meaty)
	_apply_list(ItemService.characters, meaty)


func _apply_list(list, meaty: bool) -> void :
	for data in list:
		if data == null:
			continue
		if data.my_id in ITEM_SWAPS:
			if meaty:
				if not (data.my_id in _orig_items):
					_orig_items[data.my_id] = [data.name, data.icon]
				data.name = ITEM_SWAPS[data.my_id][0]
				var tex = null
				var tex_path = ICON_DIR + ITEM_SWAPS[data.my_id][1]
				if ResourceLoader.exists(tex_path):
					tex = load(tex_path)
				if tex != null:
					data.icon = tex
			elif data.my_id in _orig_items:
				data.name = _orig_items[data.my_id][0]
				data.icon = _orig_items[data.my_id][1]
		if "effects" in data:
			for effect in data.effects:
				if effect == null:
					continue
				if meaty and effect.text_key in TEXT_SWAPS:
					effect.text_key = TEXT_SWAPS[effect.text_key]
				elif not meaty and effect.text_key in _reverse_text:
					effect.text_key = _reverse_text[effect.text_key]
'''


def write_singleton():
    path = f"{DEC}/singletons/butcher_skin.gd"
    open(path, "w").write(BUTCHER_SKIN_GD)
    print("wrote singletons/butcher_skin.gd")


def patch_autoload():
    p = f"{DEC}/project.godot"
    t = open(p).read()
    if 'ButcherSkin=' in t:
        print("autoload: already patched"); return
    anchor = 'GourmetTracker="*res://singletons/gourmet_tracker.gd"\n'
    assert anchor in t
    t = t.replace(anchor, anchor + 'ButcherSkin="*res://singletons/butcher_skin.gd"\n', 1)
    open(p, "w").write(t)
    print("autoload: added ButcherSkin")


def patch_main():
    p = f"{DEC}/main.gd"
    t = open(p).read()
    if "ButcherSkin.apply()" in t:
        print("main.gd: already patched"); return
    anchor = "func _ready() -> void :\n"
    assert anchor in t
    t = t.replace(anchor, anchor + "\t# Gourmet DLC - Butcher meat reskin (fruit/tree items show as meat)\n\tButcherSkin.apply()\n", 1)
    open(p, "w").write(t)
    print("main.gd: apply() call added")


def patch_neutral():
    p = f"{DEC}/entities/units/neutral/neutral.gd"
    t = open(p).read()
    if "butcher_meat_rack" in t:
        print("neutral.gd: already patched"); return
    anchor = """func init(zone_min_pos: Vector2, zone_max_pos: Vector2, players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, players_ref, entity_spawner_ref)
	init_current_stats()"""
    assert anchor in t
    t = t.replace(anchor, anchor + """
	_apply_butcher_meat_rack()


# Gourmet DLC - Butcher: the on-map fruit tree shows as a meat drying rack. Pooled
# nodes carry textures across runs, so both directions are set explicitly. (butcher_meat_rack)
func _apply_butcher_meat_rack() -> void :
	if stats == null or stats.resource_path.find("tree") == - 1:
		return
	var spr = get_node_or_null("Animation/Sprite")
	if spr == null:
		return
	if not has_meta("orig_tree_tex"):
		set_meta("orig_tree_tex", spr.texture)
	if ButcherSkin.is_butcher_in_run():
		var meat = ButcherSkin.world_texture("meat_rack_ingame")
		if meat != null:
			spr.texture = meat
	else:
		spr.texture = get_meta("orig_tree_tex")""", 1)

    anchor2 = """func respawn() -> void :
	.respawn()
	init_current_stats()
	current_number_of_hits = 0"""
    assert anchor2 in t
    t = t.replace(anchor2, anchor2 + "\n\t_apply_butcher_meat_rack()", 1)
    open(p, "w").write(t)
    print("neutral.gd: tree -> meat rack swap added")


def patch_garden():
    p = f"{DEC}/entities/structures/turret/garden/garden.gd"
    t = open(p).read()
    if "butcher_meat_locker" in t:
        print("garden.gd: already patched"); return
    anchor = "class_name Garden\nextends Turret\n"
    assert anchor in t
    t = t.replace(anchor, anchor + """

# Gourmet DLC - Butcher: the garden shows as a meat locker (butcher_meat_locker)
func _ready() -> void :
	._ready()
	var spr = get_node_or_null("Animation/Sprite")
	if spr == null:
		return
	if not has_meta("orig_garden_tex"):
		set_meta("orig_garden_tex", spr.texture)
	if ButcherSkin.is_butcher_in_run():
		var meat = ButcherSkin.world_texture("meat_locker_ingame")
		if meat != null:
			spr.texture = meat
	else:
		spr.texture = get_meta("orig_garden_tex")
""", 1)
    open(p, "w").write(t)
    print("garden.gd: garden -> meat locker swap added")


def patch_consumable_tint():
    p = f"{DEC}/items/consumables/consumable.gd"
    t = open(p).read()
    block = """	# Gourmet DLC - Butcher placeholder: fruit is steak-tinted until dedicated art lands
	if consumable_data != null and consumable_data.my_id == "consumable_fruit":
		for i in RunData.players_data.size():
			var butcher_char = RunData.get_player_character(i)
			if butcher_char != null and butcher_char.my_id == "character_butcher":
				modulate = Color(1.0, 0.45, 0.45)
				break
"""
    if block not in t:
        print("consumable.gd: tint block not found (already removed?)"); return
    t = t.replace(block, "")
    open(p, "w").write(t)
    print("consumable.gd: placeholder red tint removed (raw_steak.png is the real art)")


def add_csv_rows():
    # upsert: rows already present get UPDATED if the text changed (arg structures were
    # corrected against the vanilla strings). Comma-containing texts are CSV-quoted -
    # Godot's csv_translation importer parses standard quoting fine.
    lines = open(CSV).read().rstrip("\n").split("\n")
    added = updated = 0
    for key, text in CSV_ROWS:
        cell = f'"{text}"' if "," in text else text
        row = f"{key},{cell}"
        hit = [i for i, l in enumerate(lines) if l.startswith(key + ",")]
        if hit:
            if lines[hit[0]] != row:
                lines[hit[0]] = row
                updated += 1
        else:
            lines.append(row)
            added += 1
    open(CSV, "w").write("\n".join(lines) + "\n")
    print(f"added {added} / updated {updated} translation rows")


def main():
    os.makedirs(SKIN_DIR, exist_ok=True)
    write_singleton()
    patch_autoload()
    patch_main()
    patch_neutral()
    patch_garden()
    patch_consumable_tint()
    add_csv_rows()
    print("done - install art via process_butcher.py, then repack")


if __name__ == "__main__":
    main()
