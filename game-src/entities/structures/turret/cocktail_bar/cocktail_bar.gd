extends Turret

# Gourmet DLC - Cocktail Bar structure: serves a Bloody Mary on a fixed interval
# (structure attack speed applies) while any live player is inside the serving radius.
# Unlike the Fancy Restaurant it does NOT require the player to be at full HP.

export (String) var anchored_food = "consumable_food_bloody_mary"


func shoot() -> void :
	SoundManager2D.play(Utils.get_rand_element(stats.shooting_sounds), global_position, stats.sound_db_mod, 0.2)
	emit_signal("wanted_to_spawn_food", Keys.generate_hash(anchored_food), global_position)


func should_shoot() -> bool:
	return _cooldown <= 0 and not _is_shooting and _is_player_in_radius()


func _is_player_in_radius() -> bool:
	for player in get_tree().current_scene._players:
		if player.dead:
			continue
		if global_position.distance_to(player.global_position) <= stats.max_range:
			return true
	return false


func _get_next_cooldown(at_wave_begin: bool = false) -> float:
	# Gourmet DLC - Michelin Star: food spawners trigger faster; Set Menu makes
	# the selected spawner 40% faster and the others 20% slower
	var speed: int = RunData.sum_all_player_effects(Keys.spawner_trigger_speed_hash)
	if player_index >= 0 and RunData.get_player_effect(Keys.set_menu_hash, player_index) > 0:
		var selected: int = RunData.get_player_effect(Keys.selected_spawner_hash, player_index)
		if selected != 0:
			speed += 40 if selected == Keys.generate_hash(anchored_food) else - 20
	return ._get_next_cooldown(at_wave_begin) * 100.0 / (100.0 + speed)
