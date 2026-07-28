extends Turret

# Gourmet DLC - Fancy Restaurant structure: serves an Escargot on a fixed
# interval (structure attack speed applies) while a live player at full HP is
# inside the serving radius. NOTE: as a structure the interval no longer resets
# when the player loses full HP (the old personal-timer version did).

export (String) var anchored_food = "consumable_food_escargot"


func shoot() -> void :
	SoundManager2D.play(Utils.get_rand_element(stats.shooting_sounds), global_position, stats.sound_db_mod, 0.2)
	emit_signal("wanted_to_spawn_food", Keys.generate_hash(anchored_food), global_position)


func should_shoot() -> bool:
	return _cooldown <= 0 and not _is_shooting and _is_full_hp_player_in_radius()


func _is_full_hp_player_in_radius() -> bool:
	for player in get_tree().current_scene._players:
		if player.dead:
			continue
		if player.current_stats.health < player.max_stats.health:
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
