class_name ShootingAttackBehavior
extends AttackBehavior

signal shot
signal finished_shooting
signal entered_long_cooldown

export (PackedScene) var projectile_scene = preload("res://projectiles/bullet_enemy/enemy_projectile.tscn")
export (int) var projectile_speed = 3000
export (int) var projectile_speed_randomization = 0
export (int) var speed_change_after_each_projectile = 0
export (float) var cooldown = 60.0
export (int) var initial_cooldown = 0
export (int) var max_cd_randomization = 10
export (int) var long_cooldown_every_x_shoots = 0
export (int) var long_cooldown = 0
export (int) var damage = 1
export (float) var damage_increase_each_wave = 1.0
export (int) var min_range = 0
export (int) var max_range = 500
export (float) var attack_anim_speed = 1.0
export (float, 0, 3.14, 0.01) var base_direction_randomization = 0.0
export (bool) var base_direction_constant_spread = false
export (bool) var alternate_between_base_direction_spread = false
export (bool) var random_direction = false
export (int) var number_projectiles = 1
export (float, 0, 3.14, 0.1) var projectile_spread = 0.0
export (bool) var spawn_projectiles_on_target = false
export (int) var projectile_spawn_spread = 0
export (bool) var projectile_spawn_only_on_borders = false
export (Array) var specific_degrees_spawns = []
export (bool) var constant_spread = false
export (float, 0, 3.14, 0.1) var constant_spread_rand_base_pos = 0.0
export (bool) var atleast_one_projectile_on_target = false
export (bool) var shoot_towards_unit = false
export (bool) var shoot_in_unit_direction = false
export (bool) var shoot_away_from_unit = false
export (bool) var shoot_from_proj_pos_towards_player = false
export (float, 0, 3.14, 0.1) var random_rotation = 0.0
export (bool) var rotate_projectile = true
export (bool) var delete_projectile_on_death = false

var custom_collision_layer: int
var custom_sprite_material: ShaderMaterial
var projectile_pool_id: int = Keys.empty_hash

var _current_initial_cooldown = 0
var _current_cd: float = cooldown
var _shots_taken: int = 0
var _last_base_direction_spread: float = base_direction_randomization

var projectile_damage: int = 0


func _ready() -> void :
	_current_cd = get_cd()
	_current_initial_cooldown = initial_cooldown
	if projectile_scene != null:
		projectile_pool_id = Keys.generate_hash(projectile_scene.resource_path)


func reset() -> void :
	_current_cd = get_cd()
	_current_initial_cooldown = initial_cooldown
	_shots_taken = 0
	_last_base_direction_spread = base_direction_randomization
	projectile_damage = 0


func physics_process(delta: float) -> void :

	if _current_initial_cooldown > 0:
		_current_initial_cooldown = max(_current_initial_cooldown - Utils.physics_one(delta), 0)
		return

	_current_cd = max(_current_cd - 60 * delta, 0)

	if not _parent.is_playing_shoot_animation() and _current_cd <= 0 and Utils.is_between(_parent.global_position.distance_to(_parent.current_target.global_position), min_range, max_range):
		_parent._animation_player.playback_speed = attack_anim_speed
		_parent._animation_player.play(_parent.shoot_animation_name)
		emit_signal("shot")


func shoot() -> void :
	var target_pos = _parent.current_target.global_position
	var base_randomization = rand_range( - base_direction_randomization, base_direction_randomization)

	if base_direction_constant_spread:
		if alternate_between_base_direction_spread:
			if _last_base_direction_spread < 0:
				base_randomization = base_direction_randomization
			else:
				base_randomization = - base_direction_randomization
		else:
			base_randomization = Utils.get_rand_element([ - base_direction_randomization, base_direction_randomization])
		_last_base_direction_spread = base_randomization

	if shoot_in_unit_direction:
		target_pos = _parent.global_position + _parent.get_movement()

	var base_pos = 0.0

	if constant_spread_rand_base_pos > 0.0:
		base_pos = rand_range(0.0, constant_spread_rand_base_pos)

	var rand_rot = rand_range( - random_rotation, random_rotation)
	var speed
	var _projectile

	for i in number_projectiles:
		var pos: Vector2 = get_projectile_spawn_pos(target_pos, i, base_pos)

		var base_rot = (target_pos - _parent.global_position).angle() + base_randomization

		var rot = rand_range(base_rot - projectile_spread, base_rot + projectile_spread)

		speed = projectile_speed

		if random_direction:
			rot = rand_range( - PI, PI)

		if constant_spread and number_projectiles > 1:
			var chunk = (2 * projectile_spread) / (number_projectiles - 1)
			var start = base_rot - projectile_spread
			rot = start + (i * chunk)

		if shoot_away_from_unit:
			target_pos = pos
			if rand_rot != 0.0:
				target_pos = get_new_target_pos(target_pos, rand_rot)
			rot = (target_pos - _parent.global_position).angle()

		if shoot_towards_unit:
			target_pos = _parent.global_position
			if rand_rot != 0.0:
				target_pos = get_new_target_pos(target_pos, rand_rot)
			rot = (target_pos - pos).angle()

		if shoot_from_proj_pos_towards_player:
			target_pos = _parent.current_target.global_position
			if rand_rot != 0.0:
				target_pos = get_new_target_pos(target_pos, rand_rot)
			rot = (target_pos - pos).angle()

		if speed_change_after_each_projectile != 0:
			speed += speed_change_after_each_projectile * i

		_projectile = spawn_projectile(rot, pos, rand_range(speed - projectile_speed_randomization, speed + projectile_speed_randomization) as int)

	_shots_taken += 1


func get_new_target_pos(target_pos: Vector2, rand_rot: float) -> Vector2:
	var direction = target_pos - _parent.global_position
	var angle = direction.angle() + rand_rot
	return _parent.global_position + Vector2(cos(angle), sin(angle)) * direction.length()


func get_projectile_spawn_pos(target_pos: Vector2, projectile_index: int, base_pos: float) -> Vector2:
	var pos = _parent.global_position

	if spawn_projectiles_on_target:
		pos = target_pos

	if projectile_spawn_only_on_borders:
		var rand = rand_range(0, 2 * PI)

		if constant_spread:
			rand = base_pos + projectile_index * ((2 * PI) / number_projectiles)

		if specific_degrees_spawns.size() > 0:
			rand = deg2rad(specific_degrees_spawns[projectile_index])
			rand += _parent.global_position.direction_to(target_pos).angle()

		pos = Vector2(pos.x + cos(rand) * (projectile_spawn_spread / 2), pos.y + sin(rand) * (projectile_spawn_spread / 2))
	elif not atleast_one_projectile_on_target or projectile_index != 0:
		pos = Vector2(
			rand_range(pos.x - projectile_spawn_spread / 2, pos.x + projectile_spawn_spread / 2), 
			rand_range(pos.y - projectile_spawn_spread / 2, pos.y + projectile_spawn_spread / 2)
		)

	return pos


func animation_finished(anim_name: String) -> void :
	if _parent.is_shooting_anim(anim_name):
		_current_cd = get_cd()
		emit_signal("finished_shooting")


func spawn_projectile(rot: float, pos: Vector2, spd: int) -> Node:
	var main = Utils.get_scene_node()
	var projectile = main.get_node_from_pool(projectile_pool_id, main._enemy_projectiles)

	if not is_instance_valid(projectile):
		
		
		
		
		

		projectile = projectile_scene.instance()
		main.add_enemy_projectile(projectile)
		projectile.set_meta("pool_id", projectile_pool_id)

	projectile.global_position = pos
	projectile.set_from(_parent)
	projectile.velocity = Vector2.RIGHT.rotated(rot) * spd * RunData.current_run_accessibility_settings.speed

	if rotate_projectile:
		projectile.rotation = rot

	if delete_projectile_on_death and not _parent.is_connected("died", projectile, "on_entity_died"):
		var _error_died = _parent.connect("died", projectile, "on_entity_died")

	projectile.set_damage(projectile_damage)

	if custom_collision_layer != 0:
		projectile.set_collision_layer(custom_collision_layer)

	if custom_sprite_material:
		projectile.set_sprite_material(custom_sprite_material)

	projectile.shoot()

	return projectile


func get_cd() -> float:

	# Gourmet DLC - enemy_attack_speed effect (Tourist per Danger, Mime +15%):
	# positive values make enemies attack faster by shrinking their cooldowns
	var attack_speed_factor: float = 100.0 / (100.0 + RunData.sum_all_player_effects(Keys.enemy_attack_speed_hash))

	if long_cooldown_every_x_shoots != 0 and _shots_taken >= long_cooldown_every_x_shoots:
		_shots_taken = 0
		emit_signal("entered_long_cooldown")
		return long_cooldown * attack_speed_factor

	return rand_range(max(1, cooldown - max_cd_randomization), cooldown + max_cd_randomization) * attack_speed_factor
