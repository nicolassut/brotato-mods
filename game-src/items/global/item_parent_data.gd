class_name ItemParentData
extends Resource

enum Tier { COMMON, UNCOMMON, RARE, LEGENDARY, DANGER_4, DANGER_5, NIGHTMARE }

export(String) var my_id = ""
export(bool) var unlocked_by_default = false
export(bool) var can_be_looted = true
export(Texture) var icon
export(String) var name = ""
export(Tier) var tier = Tier.COMMON
export(int) var value = 1
export(Array, Resource) var effects
export(String) var tracking_text = ""

export(bool) var is_lockable := true
export(int) var unlock_codex_descr_after_get_it : int = 1

export(bool) var is_cursed := false
export(float) var curse_factor: float = 0.0

var my_id_hash: int = Keys.empty_hash

var is_locked := false


func _init() -> void:


	if my_id_hash == Keys.empty_hash:
		call_deferred("_generate_hashes")


func _generate_hashes() -> void:
	my_id_hash = Keys.generate_hash(my_id)



func get_my_id_hash():
	if my_id_hash == null or my_id_hash == Keys.empty_hash:
		my_id_hash = Keys.generate_hash(my_id)
	return my_id_hash

func duplicate(subresources := false) -> Resource:
	var duplication = .duplicate(subresources)

	if my_id_hash == Keys.empty_hash:
		my_id_hash = Keys.generate_hash(my_id)

	duplication.my_id_hash = my_id_hash
	duplication.is_locked = is_locked
	return duplication


func get_icon() -> Resource:
	return SkinManager.get_skin(icon)


func get_category() -> int:
	return -1


func get_effects_text(player_index: int) -> String:
	var text = ""

	for i in effects.size():
		# effects marked EFFECT_HIDDEN work silently (their text lives in a summary line)
		var effect_text = "" if effects[i].text_key == "EFFECT_HIDDEN" else effects[i].get_text(player_index)

		text += effect_text

		if effect_text != "" and i < effects.size() - 1:
			 text += "\n"

	text += _get_tracking_text(player_index)

	return text


func _get_tracking_text(player_index: int) -> String:
	var text : String = ""
	if player_index != RunData.DUMMY_PLAYER_INDEX and RunData.tracked_item_effects[player_index].has(my_id_hash) and tracking_text != "[EMPTY]":
		var item_effect = RunData.tracked_item_effects[player_index][my_id_hash]
		if item_effect is Array:
			for i in item_effect.size():
				var tracked_count = item_effect[i]

				var tracking_text_to_use = tracking_text

				if my_id_hash == Keys.item_bone_dice_hash and i == 1:
					tracking_text_to_use = "stats_lost"
				elif my_id_hash == Keys.item_bonk_dog_hash and i == 1:
					tracking_text_to_use = "damage_dealt"
				elif my_id_hash == Keys.item_bot_o_mine_hash and i == 1:
					tracking_text_to_use = "dropped_landmines"
				elif my_id_hash == Keys.character_hiker_hash and i == 0:
					tracking_text_to_use = "materials_gained"
				elif my_id_hash == Keys.item_doc_moth_hash and i == 1:
					tracking_text_to_use = "health_recovered"
				elif my_id_hash == Keys.item_soul_food_hash and i == 1:
					tracking_text_to_use = "soul_food_flipped"
				# Gourmet DLC - characters that bank a second, different quantity. Index 0 keeps
				# the card's own tracking_text; index 1 is relabelled here, same as Soul Food.
				elif my_id_hash == Keys.generate_hash("character_butcher") and i == 1:
					tracking_text_to_use = "butcher_appetite_rendered"
				elif my_id_hash == Keys.generate_hash("character_gourmet") and i == 1:
					tracking_text_to_use = "gourmet_speed_lost"
				elif my_id_hash == Keys.generate_hash("character_snail") and i == 1:
					tracking_text_to_use = "damage_dealt"

				text += "\n[color=#" + Utils.SECONDARY_FONT_COLOR.to_html() + "]" + Text.text(tracking_text_to_use.to_upper(), [Text.get_formatted_number(tracked_count)]) + "[/color]"
		else:
			var after = ""
			if my_id_hash == Keys.item_fish_hook_hash:
				after = "%"

			var append_text = "\n[color=#" + Utils.SECONDARY_FONT_COLOR.to_html() + "]" + Text.text(tracking_text.to_upper(), [Text.get_formatted_number(item_effect)]) + after + "[/color]"

			if my_id_hash == Keys.item_fish_hook_hash and item_effect == 0:
				append_text = ""

			text += append_text
	return text


func _is_locked_in_codex() -> bool:
	return _get_bought_times() < unlock_codex_descr_after_get_it


func _is_silhouette_in_codex() -> bool:
	return _get_bought_times() < 1


func _get_bought_times() -> int:
	var bought : int
	if ProgressData.items_bought.has(my_id_hash) :
		bought = ProgressData.items_bought[my_id_hash]
	else :
		bought = 0
	return bought


func _get_item_player_stats_description( side : int = 0 )-> String:
	var text : String = ""
	var bought : int
	if ProgressData.items_bought.has(my_id_hash) :
		bought = ProgressData.items_bought[my_id_hash]
	else :
		bought = 0
	text += _write_description_line(Text.text("CODEX_BOUGHT"), bought, Keys.empty_hash, side, ProgressData.settings.color_positive)
	if not can_be_looted :
		text += _write_description_line(Text.text("CANT_BE_BOUGHT_IN_SHOP"), "", Keys.empty_hash, side)
	else :
		text += _write_description_line(Text.text("CODEX_PRICE"), value, Keys.harvesting_icon_hash, side)

	return text


func _write_description_line(pname : String, pvalue, stat_id : int = Keys.empty_hash, side = 0, color : String = "") -> String:
	var text : String = ""
	if side >= 1 :
		text += "[right]"
	if side <= 0 :
		text += Text.text(pname)
		if stat_id != Keys.empty_hash:
			text += " : "
	if side >= 0 :
		if color != "" :
			text += "[color=#"+color+"]"
		text += str(pvalue)
		if stat_id != Keys.empty_hash :
			text += " " +_get_icon(stat_id)
		if color != "" :
			text += "[/color]"
	if side >= 1 :
		text += "[/right]"
	return text + "\n"


func _get_icon(stat_id : int) -> String:
	var l_icon : String = ""
	if stat_id != null :
		var w = 20 * ProgressData.settings.font_size
		var small_icon : Resource = ItemService.get_stat_small_icon(stat_id)
		if stat_id == Keys.harvesting_icon_hash :
			small_icon = load("res://items/materials/harvesting_icon.png")
		if small_icon == null :
			l_icon = "[img=%sx%s]%s[/img]" % [w, w, "res://items/stats/empty.png"]
		else :
			l_icon = "[img=%sx%s]%s[/img]" % [w, w, small_icon.resource_path]
	return l_icon


func get_name_text(player_index: int = - 1) -> String:
	return tr(name)


func serialize() -> Dictionary:

	var serialized_effects = []

	for effect in effects:
		serialized_effects.push_back(effect.serialize())

	return {
		"my_id": my_id,
		"name": name,
		"tier": str(tier),
		"value": str(value),
		"effects": serialized_effects,
		"tracking_text": tracking_text,
		"is_locked": is_locked,
		"is_cursed": is_cursed,
		"curse_factor": curse_factor,
		"is_lockable": is_lockable
	}


func deserialize_and_merge(serialized: Dictionary) -> void:
	my_id = serialized.my_id
	my_id_hash = Keys.generate_hash(my_id)
	name = serialized.name
	tier = serialized.tier as int
	value = serialized.value as int
	tracking_text = serialized.tracking_text
	is_locked = serialized.is_locked
	is_cursed = serialized.is_cursed
	is_lockable = serialized.is_lockable if "is_lockable" in serialized else true
	curse_factor = serialized.curse_factor as float if "curse_factor" in serialized else 0.0

	var deserialized_effects = []

	for serialized_effect in serialized.effects:
		for effect in ItemService.effects:
			if effect.get_id() == serialized_effect.effect_id:
				var instance = effect.new()
				instance.deserialize_and_merge(serialized_effect)
				deserialized_effects.push_back(instance)
				break

	effects = deserialized_effects

func is_pet_item() -> bool:
	for effect in effects:
		if effect is PetEffect:
			return true
		elif effect is StructureEffect and effect.is_pet:
			return true

	return false

func is_structure_item() -> bool:
	for effect in effects:
		if effect is StructureEffect:
			return true
		elif effect is PetEffect and effect.is_structure:
			return true

	return false
