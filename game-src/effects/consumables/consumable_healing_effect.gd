class_name ConsumableHealingEffect
extends NullEffect


func apply(player_index: int) -> void :
	# Gourmet DLC - Gourmet: consumables no longer heal (all sustain comes from food buffs)
	var gourmet_char = RunData.get_player_character(player_index)
	if gourmet_char != null and gourmet_char.my_id == "character_gourmet":
		return

	# Gourmet DLC - Growling Stomach: consumables no longer heal you
	if RunData.get_player_effect(Keys.consumables_no_heal_hash, player_index) > 0:
		return

	var consumable_heal_effect = RunData.get_player_effect(Keys.consumable_heal_hash, player_index)
	var total_healing: = max(0, value + consumable_heal_effect)

	if total_healing <= 0:
		return

	var duration: int = RunData.get_player_effect(Keys.consumable_heal_over_time_hash, player_index)
	if duration > 0:
		RunData.emit_signal("heal_over_time_effect", total_healing, duration, player_index)
	else:
		RunData.emit_signal("healing_effect", total_healing, player_index, Keys.empty_hash)
