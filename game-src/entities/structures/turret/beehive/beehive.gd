extends Turret

# Gourmet DLC - Beehive structure: drips a Honey Drop on a fixed interval
# (structure attack speed applies), no player proximity required.

export (String) var anchored_food = "consumable_food_honey_drop"


func shoot() -> void :
	SoundManager2D.play(Utils.get_rand_element(stats.shooting_sounds), global_position, stats.sound_db_mod, 0.2)
	emit_signal("wanted_to_spawn_food", Keys.generate_hash(anchored_food), global_position)


func should_shoot() -> bool:
	return _cooldown <= 0 and not _is_shooting


func _get_next_cooldown(at_wave_begin: bool = false) -> float:
	# Gourmet DLC - Michelin Star: food spawners trigger faster; Set Menu makes
	# the selected spawner 40% faster and the others 20% slower
	var speed: int = RunData.sum_all_player_effects(Keys.spawner_trigger_speed_hash)
	if player_index >= 0 and RunData.get_player_effect(Keys.set_menu_hash, player_index) > 0:
		var selected: int = RunData.get_player_effect(Keys.selected_spawner_hash, player_index)
		if selected != 0:
			speed += 40 if selected == Keys.generate_hash(anchored_food) else - 20
	return ._get_next_cooldown(at_wave_begin) * 100.0 / (100.0 + speed)
