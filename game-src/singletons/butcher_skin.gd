extends Node
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
