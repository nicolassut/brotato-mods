extends Node


var factor_cache: = {}


func reset_cache() -> void :
	factor_cache.clear()


func get_final_enemy_damage(from_value: float, percent_modifier: int = 0) -> int:
	var cache_key: int = Keys.enemy_damage_hash
	var factor = factor_cache.get(cache_key)
	if factor == null:
		var effects_factor = max(0.01, 1.0 + Utils.sum_all_player_stats(Keys.enemy_damage_hash) / 100.0)
		var danger_factor = max(0.01, 1.0 + RunData.get_player_effect(Keys.danger_enemy_damage_hash, 0) / 100.0)
		var coop_factor = max(0.01, 1.0 + ((RunData.get_player_count() - 1) * CoopService.additional_enemy_damage_per_coop_player))
		var accessibility_factor = RunData.current_run_accessibility_settings.damage

		var curse_factor = 0
		if Keys.stat_curse_hash in RunData.get_player_effects(0):
			var curse_stat = Utils.average_all_player_stats(Keys.stat_curse_hash)
			if (curse_stat < 0):
				curse_factor = 0
			else:
				curse_factor = sqrt(curse_stat) / 25.0


		var endless_factor = max(0.01, 1.0 + (RunData.get_endless_factor() * (1.0 + curse_factor)))

		factor = danger_factor * accessibility_factor * coop_factor * effects_factor * endless_factor
		factor_cache[cache_key] = factor

	var boost_factor = max(0.01, 1.0 + percent_modifier / 100.0)
	return round(from_value * factor * boost_factor) as int


func get_final_enemy_health(from_value: int, percent_modifier: int = 0) -> int:
	var cache_key: int = Keys.enemy_health_hash
	var factor = factor_cache.get(cache_key)
	if factor == null:
		var effects_factor = max(0.01, 1.0 + Utils.sum_all_player_stats(Keys.enemy_health_hash) / 100.0)
		var danger_factor = max(0.01, 1.0 + RunData.get_player_effect(Keys.danger_enemy_health_hash, 0) / 100.0)
		var coop_factor = max(0.01, 1.0 + ((RunData.get_player_count() - 1) * CoopService.additional_enemy_health_per_coop_player))
		var accessibility_factor = RunData.current_run_accessibility_settings.health

		var curse_factor = 0
		if Keys.stat_curse_hash in RunData.get_player_effects(0):
			var curse_stat = Utils.average_all_player_stats(Keys.stat_curse_hash)
			if (curse_stat < 0):
				curse_factor = 0
			else:
				curse_factor = sqrt(curse_stat) / 10.0

		var endless_factor = max(0.01, 1.0 + (RunData.get_endless_factor() * 2.25) * (1.0 + curse_factor))

		factor = danger_factor * accessibility_factor * coop_factor * effects_factor * endless_factor
		factor_cache[cache_key] = factor

	var boost_factor = max(0.01, 1.0 + percent_modifier / 100.0)
	return round(from_value * factor * boost_factor) as int


func get_final_enemy_speed(from_value: int, effects_factor: float, percent_modifier: int = 0) -> int:
	var cache_key: = Keys.enemy_speed_hash
	var factor = factor_cache.get(cache_key)
	if factor == null:
		var accessibility_factor = RunData.current_run_accessibility_settings.speed
		var danger_speed_factor = max(0.01, 1.0 + RunData.get_player_effect(Keys.danger_enemy_speed_hash, 0) / 100.0)
		var endless_factor = 1.0 + (min(1.75, RunData.get_endless_factor() / 13.33))
		factor = effects_factor * accessibility_factor * endless_factor * danger_speed_factor
		factor_cache[cache_key] = factor

	var boost_factor = 1.0 + percent_modifier / 100.0
	return round(from_value * factor * boost_factor) as int


func is_considered_turret(structure_effect: StructureEffect) -> bool:
	# Gourmet DLC - food spawners (Beehive, Street Vendor, etc.) are TurretEffects with
	# is_spawning = true; they are NOT combat turrets, so they must not count toward the
	# turret cap (and must never reach the vanilla turret sort, which asserts on their keys).
	return (structure_effect is TurretEffect
		and not structure_effect.is_spawning
		and structure_effect.text_key != "effect_garden"
		and structure_effect.text_key != "effect_wandering_bot"
	)


func is_offensive(structure: Structure) -> bool:
	return (structure is Turret
		and not structure is Garden
		and not structure is WanderingBot
		and not structure.stats.is_healing
	)


func sort_turrets_by_strength(a: TurretEffect, b: TurretEffect) -> bool:
	var ordering: = ["effect_builder_turret_alt", "effect_turret_rocket", "effect_turret_laser", "effect_tyler", 
		"effect_turret_flame", "effect_turret", "effect_turret_healing"]

	var a_index: = ordering.find(a.text_key)
	var b_index: = ordering.find(b.text_key)
	# Gourmet DLC - never crash on an unknown (modded) turret key; sort unknowns last
	# so trimming keeps the known vanilla turrets first.
	if a_index == - 1: a_index = ordering.size()
	if b_index == - 1: b_index = ordering.size()
	return a_index < b_index


func is_weapon_spawning_structure(weapon: WeaponData) -> bool:
	return (weapon.weapon_id_hash == Keys.weapon_screwdriver_hash
		or weapon.weapon_id_hash == Keys.weapon_wrench_hash
		or weapon.weapon_id_hash == Keys.weapon_pruner_hash)
