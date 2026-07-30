extends Node

const MIN_RANGE = 25
const DEFAULT_PROJECTILE_SCENE = preload("res://projectiles/bullet/bullet_projectile.tscn")
const MIN_COOLDOWN: = 2

var default_projectile_pool_id = Keys.generate_hash("res://projectiles/bullet/bullet_projectile.tscn")

var breaking_sounds: Array = [
	preload("res://weapons/melee_sounds/glass_smashable_small_break_01.wav"), 
	preload("res://weapons/melee_sounds/glass_smashable_small_break_02.wav"), 
	preload("res://weapons/melee_sounds/glass_smashable_small_break_03.wav"), 
]

var _init_stats_args_service: = WeaponServiceInitStatsArgs.new()
var _default_spawn_projectile_args: = WeaponServiceSpawnProjectileArgs.new()
var _hitbox_args = Hitbox.HitboxArgs.new()


func init_melee_stats(from_stats: MeleeWeaponStats, player_index: int, args: WeaponServiceInitStatsArgs = _init_stats_args_service) -> MeleeWeaponStats:
	var new_stats = init_base_stats(from_stats, player_index, args) as MeleeWeaponStats
	new_stats.alternate_attack_type = from_stats.alternate_attack_type

	var min_range = MIN_RANGE

	if new_stats.min_range != 0:
		min_range = new_stats.min_range + MIN_RANGE

	new_stats.max_range = max(min_range, new_stats.max_range + (Utils.get_stat(Keys.stat_range_hash, player_index) / 2.0)) as int

	return new_stats


func init_ranged_stats(from_stats: RangedWeaponStats, player_index: int, is_special_spawn: = false, args: WeaponServiceInitStatsArgs = _init_stats_args_service) -> RangedWeaponStats:
	var new_stats = init_base_stats(from_stats, player_index, args, false, is_special_spawn) as RangedWeaponStats

	var min_range = MIN_RANGE

	if new_stats.min_range != 0:
		min_range = new_stats.min_range + MIN_RANGE

	new_stats.max_range = max(min_range, new_stats.max_range + Utils.get_stat(Keys.stat_range_hash, player_index)) as int
	_set_common_ranged_stats(new_stats, from_stats, player_index)
	return new_stats


func init_structure_stats(from_stats: RangedWeaponStats, player_index: int, args: WeaponServiceInitStatsArgs = _init_stats_args_service) -> RangedWeaponStats:
	var is_structure: = true
	var new_stats = init_base_stats(from_stats, player_index, args, is_structure) as RangedWeaponStats

	new_stats.max_range = max(MIN_RANGE, new_stats.max_range + Utils.get_stat(Keys.structure_range_hash, player_index))

	_set_common_ranged_stats(new_stats, from_stats, player_index)

	return new_stats

func init_melee_pet_stats(from_stats: MeleeWeaponStats, player_index: int, args: = WeaponServiceInitStatsArgs.new()) -> MeleeWeaponStats:
	var new_stats = init_base_stats(from_stats, player_index, args, false, false, true) as MeleeWeaponStats
	new_stats.alternate_attack_type = from_stats.alternate_attack_type

	var min_range = MIN_RANGE

	if new_stats.min_range != 0:
		min_range = new_stats.min_range + MIN_RANGE

	new_stats.max_range = max(min_range, new_stats.max_range + (Utils.get_stat(Keys.stat_range_hash, player_index) / 2.0)) as int

	return new_stats

func init_ranged_pet_stats(from_stats: RangedWeaponStats, player_index: int, is_special_spawn: = false, args: = WeaponServiceInitStatsArgs.new()) -> RangedWeaponStats:
	var new_stats = init_base_stats(from_stats, player_index, args, false, is_special_spawn, true) as RangedWeaponStats

	var min_range = MIN_RANGE

	if new_stats.min_range != 0:
		min_range = new_stats.min_range + MIN_RANGE

	new_stats.max_range = max(min_range, new_stats.max_range + Utils.get_stat(Keys.stat_range_hash, player_index)) as int
	_set_common_ranged_stats(new_stats, from_stats, player_index)
	return new_stats

func init_structure_pet_stats(from_stats: RangedWeaponStats, player_index: int, args: = WeaponServiceInitStatsArgs.new()) -> RangedWeaponStats:
	var new_stats = init_base_stats(from_stats, player_index, args, true, false, true) as RangedWeaponStats

	new_stats.max_range = max(MIN_RANGE, new_stats.max_range + Utils.get_stat(Keys.structure_range_hash, player_index))

	_set_common_ranged_stats(new_stats, from_stats, player_index)

	return new_stats


func _set_common_ranged_stats(new_stats: RangedWeaponStats, from_stats: RangedWeaponStats, player_index: int):
	var projectiles_effect = RunData.get_player_effect(Keys.projectiles_hash, player_index)
	new_stats.projectile_spread = from_stats.projectile_spread + (projectiles_effect * 0.1)

	if from_stats.nb_projectiles > 0:
		new_stats.nb_projectiles = from_stats.nb_projectiles + projectiles_effect

	var piercing_dmg_bonus = (Utils.get_stat(Keys.piercing_damage_hash, player_index) / 100.0)
	var bounce_dmg_bonus = (Utils.get_stat(Keys.bounce_damage_hash, player_index) / 100.0)

	new_stats.piercing = from_stats.piercing + RunData.get_player_effect(Keys.piercing_hash, player_index)
	new_stats.piercing_dmg_reduction = clamp(from_stats.piercing_dmg_reduction - piercing_dmg_bonus, 0, 1)

	if from_stats.can_bounce:
		new_stats.bounce = from_stats.bounce + RunData.get_player_effect(Keys.bounce_hash, player_index)
	else:
		new_stats.bounce = 0

	new_stats.bounce_dmg_reduction = clamp(from_stats.bounce_dmg_reduction - bounce_dmg_bonus, 0, 1)
	new_stats.projectile_scene = from_stats.projectile_scene

	if from_stats.increase_projectile_speed_with_range:
		var stat_range = Utils.get_stat(Keys.stat_range_hash, player_index)
		new_stats.projectile_speed = clamp(from_stats.projectile_speed + (from_stats.projectile_speed / 300.0) * stat_range, 50, 6000) as int
	else:
		new_stats.projectile_speed = from_stats.projectile_speed

func init_base_stats(from_stats: WeaponStats, player_index: int, args: WeaponServiceInitStatsArgs = _init_stats_args_service, is_structure: = false, is_special_spawn: = false, is_pet: = false) -> WeaponStats:
	var new_stats: WeaponStats
	if from_stats is MeleeWeaponStats:
		new_stats = MeleeWeaponStats.new()
	else:
		new_stats = RangedWeaponStats.new()

	
	new_stats.cooldown = from_stats.cooldown
	new_stats.damage = from_stats.damage
	new_stats.accuracy = from_stats.accuracy
	new_stats.crit_chance = from_stats.crit_chance
	new_stats.crit_damage = from_stats.crit_damage
	new_stats.min_range = from_stats.min_range
	new_stats.max_range = from_stats.max_range
	new_stats.knockback = from_stats.knockback
	new_stats.knockback_piercing = from_stats.knockback_piercing
	new_stats.can_have_positive_knockback = from_stats.can_have_positive_knockback
	new_stats.can_have_negative_knockback = from_stats.can_have_negative_knockback
	new_stats.effect_scale = from_stats.effect_scale
	new_stats.scaling_stats = Utils.convert_to_hash_array(from_stats.scaling_stats)
	new_stats.lifesteal = from_stats.lifesteal
	new_stats.shooting_sounds = from_stats.shooting_sounds
	new_stats.sound_db_mod = from_stats.sound_db_mod
	new_stats.is_healing = from_stats.is_healing
	new_stats.recoil = from_stats.recoil
	new_stats.recoil_duration = from_stats.recoil_duration
	new_stats.additional_cooldown_every_x_shots = from_stats.additional_cooldown_every_x_shots
	new_stats.additional_cooldown_multiplier = from_stats.additional_cooldown_multiplier
	new_stats.speed_percent_modifier = from_stats.speed_percent_modifier

	new_stats.burning_data = from_stats.burning_data
	new_stats.burning_data._late_init()
	new_stats.attack_speed_mod = from_stats.attack_speed_mod

	
	for weapon_type_bonus in RunData.get_player_effect(Keys.weapon_type_bonus_hash, player_index):
		var weapon_type = weapon_type_bonus[0]
		var stat_name = Keys.hash_to_string[weapon_type_bonus[1]]
		var effect_value = weapon_type_bonus[2]

		if new_stats is RangedWeaponStats and weapon_type == WeaponType.RANGED:
			var value = new_stats.get(stat_name) + effect_value
			new_stats.set(stat_name, value)
		if new_stats is MeleeWeaponStats and weapon_type == WeaponType.MELEE:
			var value = new_stats.get(stat_name) + effect_value
			new_stats.set(stat_name, value)

	var set_bonus_dmg: = 0.0
	for class_bonus in RunData.get_player_effect(Keys.weapon_class_bonus_hash, player_index):
		var set_id = class_bonus[0]
		var stat_h = class_bonus[1]
		var stat_name = Keys.hash_to_string[stat_h]
		var effect_value = class_bonus[2]
		for set in args.sets:
			assert (set_id is int)
			if set.my_id_hash == set_id:
				if stat_h == Keys.stat_percent_damage_hash:
					set_bonus_dmg += effect_value / 100.0
				else:
					var value = new_stats.get(stat_name) + effect_value
					if stat_h == Keys.lifesteal_hash or stat_h == Keys.crit_damage_hash:
						value = new_stats.get(stat_name) + (effect_value / 100.0)
					new_stats.set(stat_name, value)

	var is_exploding: = false
	for effect in args.effects:
		if effect is BurningEffect:
			new_stats.burning_data = effect.burning_data
		elif effect is ExplodingEffect:
			is_exploding = true
		elif effect is WeaponSlowOnHitEffect:
			new_stats.speed_percent_modifier += effect.get_speed_percent_modifier(player_index)
		elif effect is WeaponStackEffect:
			var nb_same_weapon = 0
			for checked_weapon in RunData.get_player_weapons_ref(player_index):
				if checked_weapon.weapon_id_hash == effect.weapon_stacked_id_hash:
					nb_same_weapon += 1
			new_stats.set(effect.stat_name, new_stats.get(effect.stat_name) + (effect.value * max(0.0, nb_same_weapon - 1)))

		elif effect is WeaponGainStatForEveryStatEffect:
			var perm_stats_only = true
			var bonus = RunData.get_scaling_bonus(effect.value, effect.stat_scaled, effect.nb_stat_scaled, perm_stats_only, player_index)
			new_stats.set(effect.increased_stat_name, new_stats.get(effect.increased_stat_name) + bonus)

	if is_pet:
		new_stats.scaling_stats = _apply_beast_master_weapon_scaling_stat_effects(new_stats.scaling_stats, player_index)

	if not is_structure and not is_special_spawn or (is_structure and is_pet):
		new_stats.scaling_stats = _apply_weapon_scaling_stat_effects(new_stats.scaling_stats, player_index)

	var slow_on_hit_effects = RunData.get_player_effect(Keys.slow_on_hit_hash, player_index)
	for slow_on_hit_effect in slow_on_hit_effects:
		assert (slow_on_hit_effect[0] is int)
		if find_scaling_stat(slow_on_hit_effect[0], new_stats.scaling_stats) != null:
			new_stats.speed_percent_modifier -= slow_on_hit_effect[1]
			break

	
	new_stats.burning_data = init_burning_data(new_stats.burning_data, player_index, is_structure)

	
	var atk_spd = (Utils.get_stat(Keys.stat_attack_speed_hash, player_index) + new_stats.attack_speed_mod) / 100.0
	if is_structure or is_pet:
		atk_spd = 0
	
	
	
	if new_stats.cooldown < MIN_COOLDOWN:
		new_stats.cooldown = MIN_COOLDOWN
	new_stats.cooldown = apply_attack_speed_mod_to_cooldown(new_stats.cooldown, atk_spd)
	if atk_spd > 0:
		new_stats.recoil /= 1 + atk_spd
		new_stats.recoil_duration /= 1 + atk_spd
	_apply_min_cooldown_effect(new_stats, player_index)
	_apply_max_cooldown_effect(new_stats, player_index)

	
	new_stats.damage = apply_scaling_stats_to_damage(new_stats.damage, new_stats.scaling_stats, player_index)

	var percent_dmg_bonus = (1 + (Utils.get_stat(Keys.stat_percent_damage_hash, player_index) / 100.0))
	if is_structure and not is_pet:
		percent_dmg_bonus = (1 + (Utils.get_stat(Keys.structure_percent_damage_hash, player_index) / 100.0))
	elif is_structure and is_pet:
		percent_dmg_bonus += Utils.get_stat(Keys.structure_percent_damage_hash, player_index) / 100.0

	var exploding_dmg_bonus = 0
	if is_exploding:
		exploding_dmg_bonus = (Utils.get_stat(Keys.explosion_damage_hash, player_index) / 100.0)

	new_stats.damage = max(1, round(new_stats.damage * (set_bonus_dmg + percent_dmg_bonus + exploding_dmg_bonus))) as int

	
	if not is_structure or RunData.get_player_effect_bool(Keys.structures_can_crit_hash, player_index):
		new_stats.crit_chance += Utils.get_capped_stat(Keys.stat_crit_chance_hash, player_index) / 100.0

	
	new_stats.accuracy += RunData.get_player_effect(Keys.accuracy_hash, player_index) / 100.0

	
	if not is_structure:
		new_stats.lifesteal += Utils.get_stat(Keys.stat_lifesteal_hash, player_index) / 100.0

	
	var min_knockback = - Utils.LARGE_NUMBER if new_stats.can_have_negative_knockback else 0
	var max_knockback = Utils.LARGE_NUMBER if new_stats.can_have_positive_knockback else 0
	var player_knockback = RunData.get_player_effect(Keys.knockback_hash, player_index)

	if new_stats.can_have_negative_knockback and not new_stats.can_have_positive_knockback:
		player_knockback = - player_knockback

	new_stats.knockback = clamp(new_stats.knockback + player_knockback, min_knockback, max_knockback) as int
	if RunData.get_player_effect_bool(Keys.negative_knockback_hash, player_index):
		if from_stats.knockback < 0:
			new_stats.knockback -= player_knockback
		elif new_stats.knockback >= 0:
			new_stats.knockback *= - 1

	return new_stats



func get_explosion_damage(from_stats: WeaponStats, player_index: int) -> int:
	var scaling_stats = _apply_weapon_scaling_stat_effects(from_stats.scaling_stats, player_index)
	var damage = apply_scaling_stats_to_damage(from_stats.damage, scaling_stats, player_index)
	var percent_dmg_bonus = (1 + (Utils.get_stat(Keys.stat_percent_damage_hash, player_index) / 100.0))
	var exploding_dmg_bonus = (Utils.get_stat(Keys.explosion_damage_hash, player_index) / 100.0)
	return max(1, round(damage * (percent_dmg_bonus + exploding_dmg_bonus))) as int



func init_burning_data(base_burning_data: BurningData, player_index: int, is_structure: bool = false, is_pet: bool = false) -> BurningData:
	var global_burning = RunData.get_player_effect(Keys.burn_chance_hash, player_index)

	var no_global_burning = global_burning.is_not_burning()
	var base_weapon_has_no_burning = base_burning_data.is_not_burning()

	var new_burning_data: = BurningData.new()

	if no_global_burning and base_weapon_has_no_burning:
		return new_burning_data

	new_burning_data.chance = base_burning_data.chance
	new_burning_data.damage = base_burning_data.damage
	new_burning_data.duration = base_burning_data.duration
	new_burning_data.spread = base_burning_data.spread
	new_burning_data.scaling_stats = Utils.convert_to_hash_array(base_burning_data.scaling_stats)

	if base_burning_data.is_global_burn:
		new_burning_data.damage = apply_scaling_stats_to_damage(new_burning_data.damage, new_burning_data.scaling_stats, player_index)
		new_burning_data.damage = apply_damage_bonus(new_burning_data.damage, player_index)
		return new_burning_data

	if is_pet:
		new_burning_data.scaling_stats = _apply_beast_master_weapon_scaling_stat_effects(new_burning_data.scaling_stats, player_index)

	
	if base_weapon_has_no_burning:
		
		new_burning_data.chance = global_burning.chance
		new_burning_data.duration = global_burning.duration
		new_burning_data.scaling_stats = Utils.convert_to_hash_array(global_burning.scaling_stats)
		new_burning_data.spread = global_burning.spread
		new_burning_data.damage = global_burning.damage
		new_burning_data.is_global_burn = true

	else:
		new_burning_data.damage += global_burning.damage

	new_burning_data.damage = apply_scaling_stats_to_damage(new_burning_data.damage, new_burning_data.scaling_stats, player_index)
	if is_structure and not base_weapon_has_no_burning:
		new_burning_data.damage = apply_structure_damage_bonus(new_burning_data.damage, player_index)
	else:
		new_burning_data.damage = apply_damage_bonus(new_burning_data.damage, player_index)

	new_burning_data.spread += RunData.get_player_effect(Keys.burning_spread_hash, player_index)

	return new_burning_data


func manage_special_spawn_projectile(
	entity_from, 
	weapon_stats: RangedWeaponStats, 
	direction: float, 
	auto_target_enemy: bool, 
	entity_spawner_ref: EntitySpawner, 
	from: Node, 
	args: WeaponServiceSpawnProjectileArgs = _default_spawn_projectile_args
) -> Node:
	var pos = entity_from.global_position

	if weapon_stats.shooting_sounds.size() > 0:
		SoundManager2D.play(Utils.get_rand_element(weapon_stats.shooting_sounds), pos, 0, 0.2)

	if auto_target_enemy:
		var target = entity_spawner_ref.get_rand_enemy(entity_from)

		if target != null and is_instance_valid(target):
			direction = (target.global_position - pos).angle()

	args.deferred = true
	args.knockback_direction = Vector2(cos(direction), sin(direction))
	var projectile = spawn_projectile(pos, weapon_stats, direction, from, args)

	return projectile


func spawn_projectile(
	pos: Vector2, 
	weapon_stats: RangedWeaponStats, 
	direction: float, 
	from: Node, 
	args: WeaponServiceSpawnProjectileArgs
) -> Node:
	_hitbox_args.set_from_weapon_stats(weapon_stats)

	var duplicated_effects = []
	for effect in args.effects:
		duplicated_effects.push_back(effect.duplicate())
	duplicated_effects = set_projectile_effects(duplicated_effects, args.from_player_index)

	var main = Utils.get_scene_node()

	var projectile_pool_id: int = default_projectile_pool_id

	if weapon_stats.projectile_scene != null:
		projectile_pool_id = weapon_stats.projectile_scene.get_instance_id()

	var projectile = main.get_node_from_pool(projectile_pool_id, main._player_projectiles)
	if not is_instance_valid(projectile):
		var projectile_scene = weapon_stats.projectile_scene if weapon_stats.projectile_scene != null else DEFAULT_PROJECTILE_SCENE
		projectile = projectile_scene.instance()
		if args.deferred:
			main.call_deferred("add_player_projectile", projectile)
		else:
			main.add_player_projectile(projectile)

		projectile.set_meta("pool_id", projectile_pool_id)

	if args.deferred:
		
		projectile.call_deferred("shoot_ex", 
			from, 
			pos, 
			Vector2.RIGHT.rotated(direction) * weapon_stats.projectile_speed, 
			(Vector2.RIGHT.rotated(direction) * weapon_stats.projectile_speed).angle(), 
			weapon_stats, 
			args.damage_tracking_key_hash, 
			duplicated_effects, 
			_hitbox_args, 
			args.knockback_direction)
	else:
		projectile.shoot_ex(
			from, 
			pos, 
			Vector2.RIGHT.rotated(direction) * weapon_stats.projectile_speed, 
			(Vector2.RIGHT.rotated(direction) * weapon_stats.projectile_speed).angle(), 
			weapon_stats, 
			args.damage_tracking_key_hash, 
			duplicated_effects, 
			_hitbox_args, 
			args.knockback_direction)

	return projectile


func set_projectile_effects(base_effects: Array, player_index: int = - 1) -> Array:
	var all_effects = base_effects.duplicate()

	if player_index >= 0:
		all_effects = _add_player_effect_to_effects(all_effects, "pierce_on_crit", Keys.pierce_on_crit_hash, player_index)
		all_effects = _add_player_effect_to_effects(all_effects, "bounce_on_crit", Keys.bounce_on_crit_hash, player_index)

	return all_effects


func _add_player_effect_to_effects(effects: Array, key: String, key_hash: int, player_index: int) -> Array:
	
	var player_effect: int = RunData.get_player_effect(key_hash, player_index)
	if player_effect <= 0:
		return effects
	var found: = false
	for effect in effects:
		if effect.key_hash == key_hash:
			effect.value += player_effect
			found = true
	if not found:
		var effect: = NullEffect.new()
		effect.key = key
		effect.key_hash = key_hash
		effect.value = player_effect
		effects.append(effect)

	return effects



func get_scaling_stats_icon_text(p_scaling_stats: Array) -> String:
	var stat_icon_text: = ""
	for i in p_scaling_stats.size():
		assert (p_scaling_stats[i][0] is int)
		stat_icon_text += Utils.get_scaling_stat_icon_text(p_scaling_stats[i][0], p_scaling_stats[i][1])
	return stat_icon_text

func has_scaling_stats_hash(p_scaling_stats: Array, stat_name_hash: int) -> bool:
	for i in p_scaling_stats.size():
		if stat_name_hash == p_scaling_stats[i][0]:
			return true
	return false

func sum_scaling_stat_values(p_scaling_stats: Array, player_index: int) -> float:
	var value = 0
	for scaling_stat in p_scaling_stats:
		assert (scaling_stat[0] is int)
		if scaling_stat[0] == Keys.stat_levels_hash:
			value += RunData.get_player_level(player_index) * scaling_stat[1]
		else:
			value += Utils.get_stat(scaling_stat[0], player_index) * scaling_stat[1]

	return value


func find_scaling_stat(stat_id: int, scaling_stats: Array):
	for scaling_stat in scaling_stats:
		assert (scaling_stat[0] is int)
		if scaling_stat[0] == stat_id:
			return scaling_stat
	return null


func apply_scaling_stats_to_damage(damage: int, p_scaling_stats: Array, player_index: int) -> int:
	return max(1.0, damage + sum_scaling_stat_values(p_scaling_stats, player_index)) as int


func apply_damage_bonus(value: int, player_index: int) -> int:
	var percent_dmg_bonus = 1 + Utils.get_stat(Keys.stat_percent_damage_hash, player_index) / 100.0
	return max(1, round(max(1, value) * percent_dmg_bonus)) as int


func apply_structure_damage_bonus(value: int, player_index: int) -> int:
	var percent_dmg_bonus = 1 + Utils.get_stat(Keys.structure_percent_damage_hash, player_index) / 100.0
	return max(1, round(max(1, value) * percent_dmg_bonus)) as int



func apply_inverted_health_bonus(value: int, per_health_percent_amount: int, current_health: int, max_health: int) -> int:
	if max_health == 0:
		return 0
	var percent_missing_health: = max(0.0, 1.0 - float(current_health) / float(max_health)) * 100.0
	return round(value * (percent_missing_health / per_health_percent_amount)) as int


func explode(effect: ExplodingEffect, args: WeaponServiceExplodeArgs) -> Node:
	var main: Main = Utils.get_scene_node()
	var instance = main.get_node_from_pool(effect.explosion_scene.get_instance_id(), main._explosions)

	if instance == null:
		instance = effect.explosion_scene.instance()
		main.add_explosion(instance)

	if main._is_fog_wave:
		main._fog_viewport._on_spawn_explosion(instance)
	instance.pool_id = effect.explosion_scene.get_instance_id()
	instance.player_index = args.from_player_index
	instance.global_position = args.pos
	instance.sound_db_mod = effect.sound_db_mod
	instance.set_damage_tracking_key(args.damage_tracking_key_hash)
	instance.set_damage(args)
	instance.set_smoke_amount(round(effect.scale * effect.base_smoke_amount))
	instance.set_area(effect.scale)
	if args.from != null:
		instance.set_from(args.from)

	instance.start_explosion()

	# Gourmet DLC - Popcorn Machine hook. Deliberately HERE and not in main.add_explosion:
	# this runs for every explosion (pooled instances never reach add_explosion) and
	# instance.player_index has been assigned by now. See main.on_explosion_spawned.
	main.on_explosion_spawned(instance.player_index)

	return instance


func should_spawn_landmines_on_enemy_death(hitbox: Hitbox, was_burning: bool, player_index: int) -> bool:
	var from = hitbox.from if hitbox != null else null
	var landmines_on_death_effects = RunData.get_player_effect(Keys.landmines_on_death_chance_hash, player_index)
	for landmines_on_death_effect in landmines_on_death_effects:
		var effect_stat = landmines_on_death_effect[0]
		assert (effect_stat is int)
		var chance = landmines_on_death_effect[1] / 100.0
		if not Utils.get_chance_success(chance):
			continue
		var weapon_did_stat_damage = from is Weapon and find_scaling_stat(effect_stat, from.current_stats.scaling_stats) != null
		var burning_did_stat_damage = effect_stat == Keys.stat_elemental_damage_hash and was_burning
		if weapon_did_stat_damage or burning_did_stat_damage:
			return true
	return false


func get_structure_attack_speed(player_index: int) -> float:
	var structure_attack_speed = Utils.get_stat(Keys.structure_attack_speed_hash, player_index)
	var effect_scaling_stats = RunData.get_player_effect(Keys.structures_cooldown_reduction_hash, player_index)
	var scaling_stats = []
	for effect_scaling_stat in effect_scaling_stats:
		scaling_stats.push_back([effect_scaling_stat[0], effect_scaling_stat[1] / 100.0])
	return sum_scaling_stat_values(scaling_stats, player_index) + structure_attack_speed


func apply_structure_attack_speed_effects(base_cooldown: int, player_index: int) -> int:
	if base_cooldown <= 0:
		return base_cooldown
	var total_attack_speed_percent = get_structure_attack_speed(player_index) / 100.0
	base_cooldown = apply_attack_speed_mod_to_cooldown(base_cooldown, total_attack_speed_percent)
	return base_cooldown


func apply_attack_speed_mod_to_cooldown(base_cooldown: int, attack_speed_mod: float) -> int:
	if attack_speed_mod < 0:
		return max(MIN_COOLDOWN, base_cooldown * (1 + abs(attack_speed_mod))) as int
	return max(MIN_COOLDOWN, base_cooldown / (1 + attack_speed_mod)) as int


func _apply_min_cooldown_effect(stats: WeaponStats, player_index: int) -> void :
	var min_cooldown_effects = RunData.get_player_effect(Keys.minimum_weapon_cooldowns_hash, player_index)
	if min_cooldown_effects.empty():
		return
	
	var min_cooldown_effect_value: int = min_cooldown_effects.back()
	assert (min_cooldown_effect_value >= MIN_COOLDOWN)
	
	
	var total_cooldown_seconds: = stats.get_cooldown_value(player_index, 1.0)
	var total_cooldown: = total_cooldown_seconds * 60.0
	var cooldown_below_min: = min_cooldown_effect_value - total_cooldown
	if cooldown_below_min <= 0:
		return

	
	
	
	var new_cooldown = stats.cooldown + ceil(cooldown_below_min) as int

	
	
	if stats.additional_cooldown_every_x_shots != - 1:
		stats.additional_cooldown_multiplier = max(1, (stats.additional_cooldown_multiplier * stats.cooldown) / new_cooldown)

	stats.cooldown = new_cooldown


func _apply_max_cooldown_effect(stats: WeaponStats, player_index: int) -> void :
	var max_cooldown_effects = RunData.get_player_effect(Keys.maximum_weapon_cooldowns_hash, player_index)
	if max_cooldown_effects.empty():
		return

	var max_cooldown_value: int = max_cooldown_effects[0]
	var total_cooldown_seconds: = stats.get_cooldown_value(player_index, 1.0)
	var total_cooldown: = total_cooldown_seconds * 60.0

	var cooldown_above_max: = total_cooldown - max_cooldown_value
	if cooldown_above_max <= 0:
		return

	stats.cooldown -= ceil(cooldown_above_max) as int


func _apply_weapon_scaling_stat_effects(scaling_stats: Array, player_index: int) -> Array:
	var weapon_scaling_stat_effects = RunData.get_player_effect(Keys.weapon_scaling_stats_hash, player_index)
	if weapon_scaling_stat_effects.empty():
		return scaling_stats
	var new_scaling_stats = scaling_stats.duplicate(true)
	for scaling_stat_effect in weapon_scaling_stat_effects:
		assert (scaling_stat_effect[0] is int)
		var scaling_stat_hash = scaling_stat_effect[0]
		var scaling_stat_value = scaling_stat_effect[1] / 100.0
		var existing_scaling_stat = find_scaling_stat(scaling_stat_hash, new_scaling_stats)
		if existing_scaling_stat != null:
			existing_scaling_stat[1] += scaling_stat_value
		else:
			new_scaling_stats.push_back([scaling_stat_hash, scaling_stat_value])
	return new_scaling_stats

func _apply_beast_master_weapon_scaling_stat_effects(scaling_stats: Array, player_index: int) -> Array:
	if RunData.get_player_effects(player_index).has(Keys.stat_beast_master_effect_hash) and RunData.get_player_effect_bool(Keys.stat_beast_master_effect_hash, player_index):
		var damage_stats = Utils.convert_to_hash_array(["stat_melee_damage", "stat_ranged_damage", "stat_elemental_damage", "stat_engineering"])
		var new_scaling_stats = scaling_stats.duplicate(true)
		if new_scaling_stats.size() > 0:
			var value = new_scaling_stats[0][1]
			for stats in new_scaling_stats:
				damage_stats.erase(stats[0])

			for stat_name in damage_stats:
				new_scaling_stats.push_back([stat_name, value])

			return new_scaling_stats
	return scaling_stats


func init_stats_every_x_projectiles(base_stats: WeaponStats, player_index: int, args: WeaponServiceInitStatsArgs) -> Dictionary:
	
	var modify_projectile_effects = []
	var nb_projectile_effect = 0
	var item_effects = RunData.get_player_effect(Keys.modify_every_x_projectile_hash, player_index)
	modify_projectile_effects.append_array(item_effects)

	for effect in args.effects:
		if effect is WeaponEffectWithSubEffects:
			modify_projectile_effects.push_back(effect)

	var stats_every_x_shots = {}

	for effect in modify_projectile_effects:
		for sub_effect in effect.sub_effects:
			sub_effect.apply(player_index)
			if sub_effect.key_hash == Keys.projectiles_hash:
				nb_projectile_effect += sub_effect.value

		var modified_stats: RangedWeaponStats = init_ranged_stats(base_stats, player_index, false, args)

		modified_stats.projectile_spread += nb_projectile_effect * 0.15
		stats_every_x_shots[effect.value] = modified_stats

		for sub_effect in effect.sub_effects:
			sub_effect.unapply(player_index)

	return stats_every_x_shots
