class_name Weapon
extends Node2D

signal wanted_to_break(weapon, gold_dropped)
signal wanted_to_reset_turrets_cooldown
signal tracked_value_updated(value)
signal tracked_value_set(value)

const DETECTION_RANGE: = 200




const MAX_ATTACK_COUNT_HISTORY: = 20

export (Resource) var curse_particles
export (Array, Resource) var custom_hit_sounds = []
export (Resource) var outline_shader_mat

onready var outline_sprite: Sprite = get_node_or_null("%outline_sprite")

var weapon_pos: = - 1
var stats: Resource
var index: = 0

var effects: = []
var current_stats: = WeaponStats.new()
var weapon_id: String = ""
var weapon_id_hash: int = Keys.empty_hash
var weapon_sets: Array = []
var tier: int = 0
var is_cursed: bool = false

var player_index: int setget _set_player_index, _get_player_index
func _get_player_index() -> int:
	return player_index
func _set_player_index(_v: int) -> void :
	printerr("player_index is readonly")

var _parent: Node

var _idle_angle: = 0.0
var _current_idle_angle: = _idle_angle
var _current_cooldown: float = 0
# Gourmet DLC - Juggler metronome: true while this weapon holds the juggle turn
# (edge flag so the 0.3s interval is assigned exactly once per turn)
var _juggler_turn_started: = false
var _is_shooting: = false
var _nb_shots_taken: = 0
var _stats_every_x_shots: = {}

var _current_shoot_spread: = 0.0
var _current_target: = []
var _targets_in_range: = []
var _original_sprite = null

var _oldest_attack_id: = 0
var _hit_count_by_attack_id: = {}
var _kill_count_by_attack_id: = {}
var _enemies_killed_this_wave_count: = 0

var _manual_aim: bool = false
var _explosion_args: = WeaponServiceExplodeArgs.new()

onready var muzzle: Position2D = $Sprite / Muzzle
onready var tween: Tween = $Tween
onready var tween_animation: Tween = $Tween_animations
onready var sprite: Sprite = $Sprite
onready var _hitbox: Area2D = $Sprite / Hitbox
onready var _attach: Position2D = $Sprite / Attach
onready var _range: Area2D = $Range
onready var _range_shape: CollisionShape2D = $Range / CollisionShape2D
onready var _shooting_behavior: WeaponShootingBehavior = $ShootingBehavior


func _ready() -> void :
	_original_sprite = sprite.texture
	update_sprite(_original_sprite)

	_parent = get_parent().get_parent()
	player_index = _parent.player_index

	disable_hitbox()
	var _behavior = _shooting_behavior.init(self)

	init_stats()
	update_highlighting()
	connect_effects()

	_hitbox.connect("critically_hit_something", self, "_on_weapon_critically_hit_something")

	if is_cursed:
		var instance = curse_particles.instance()
		for child in muzzle.get_children():
			child.queue_free()
		muzzle.add_child(instance)

	_manual_aim = is_manual_aim()


func connect_effects() -> void :
	for effect in effects:
		if effect is OneShotOnHitEffect:
			var _one_shot_something = _hitbox.connect("one_shot_something", self, "on_one_shot_something")

	if effects.size() > 0 or RunData.get_player_effect(Keys.gain_stat_when_attack_killed_enemies_hash, player_index).size() > 0:
		var _killed_something = _hitbox.connect("killed_something", self, "on_killed_something", [_hitbox])

	if effects.size() > 0:
		var _added_gold_on_crit_kill = _hitbox.connect("added_gold_on_crit", self, "on_added_gold_on_crit")


func update_highlighting() -> void :
	var value = ProgressData.settings.weapon_highlighting
	if tier > 0 and value:
		outline_shader_mat.set_shader_param("outline_color_0", ItemService.get_color_from_tier(tier))
		outline_shader_mat.set_shader_param("outline_color_1", Color.transparent)
		outline_shader_mat.set_shader_param("outline_color_2", Color.transparent)
		outline_shader_mat.set_shader_param("outline_color_3", Color.transparent)
		outline_shader_mat.set_shader_param("texture_size", sprite.texture.get_size())
		outline_shader_mat.set_shader_param("alpha", 1.0)
		outline_shader_mat.set_shader_param("desaturation", 0.0)
		sprite.material = outline_shader_mat
		if is_instance_valid(outline_sprite):
			if tier <= 0:
				outline_sprite.visible = false
			else:
				outline_sprite.visible = true
				outline_sprite.modulate = ItemService.get_color_from_tier(tier)
	else:
		sprite.material = null


func init_stats(at_wave_begin: bool = true) -> void :
	var args: = WeaponServiceInitStatsArgs.new()
	args.sets = weapon_sets
	args.effects = effects
	if stats is RangedWeaponStats:
		current_stats = WeaponService.init_ranged_stats(stats, player_index, false, args)
		_stats_every_x_shots = WeaponService.init_stats_every_x_projectiles(stats, player_index, args)
		for x_shot_stats in _stats_every_x_shots.values():
			x_shot_stats.burning_data.from = self
	else:
		current_stats = WeaponService.init_melee_stats(stats, player_index, args)

	_hitbox.projectiles_on_hit = []

	var on_hit_args: = WeaponServiceInitStatsArgs.new()
	for effect in effects:
		if effect is ProjectilesOnHitEffect:
			var weapon_stats = WeaponService.init_ranged_stats(effect.weapon_stats, player_index, true, on_hit_args)
			_hitbox.projectiles_on_hit = [effect.value, weapon_stats, effect.auto_target_enemy]

	current_stats.burning_data.from = self

	var hitbox_args: = Hitbox.HitboxArgs.new().set_from_weapon_stats(current_stats)

	_hitbox.effect_scale = current_stats.effect_scale
	_hitbox.set_damage(current_stats.damage, hitbox_args)
	_hitbox.speed_percent_modifier = current_stats.speed_percent_modifier
	_hitbox.effects = effects
	_hitbox.from = self

	if at_wave_begin:
		_current_cooldown = get_next_cooldown(at_wave_begin)

	reset_cooldown()
	_range_shape.shape.radius = current_stats.max_range + DETECTION_RANGE


func _process(_delta: float) -> void :
	update_sprite_flipv()
	update_idle_angle()
	_manual_aim = is_manual_aim()


func attach(attach_to: Vector2, attach_idle_angle: float) -> void :
	position = attach_to - _attach.position
	_idle_angle = attach_idle_angle


func _physics_process(delta: float) -> void :
	if _manual_aim:
		if should_rotate_manual():
			if Utils.is_player_using_gamepad(player_index):
				rotation = _parent.gamepad_attack_vector.angle()
			else:
				rotation = (get_global_mouse_position() - global_position).angle()
	else:
		if _is_shooting:
			rotation = get_direction()
		else:
			rotation = get_direction_and_calculate_target()

	if not _is_shooting:
		var cooldown_tick: = 60 * delta
		# Gourmet DLC - Juggler metronome: the active weapon fires 0.3s after the
		# previous one (18 frames / (1 + Attack Speed/100)), whatever its own
		# cooldown; inactive weapons are frozen. Clamped to [3, 180] frames as a
		# safety net at extreme +/- Attack Speed. Card mirror: effect.gd
		# EFFECT_JUGGLER_TEMPO computes the same expression.
		if weapon_pos >= 0 and _parent != null and "player_index" in _parent and RunData.is_juggler_cycling(_parent.player_index):
			if RunData.get_juggler_active_pos(_parent.player_index) == weapon_pos:
				if not _juggler_turn_started:
					_juggler_turn_started = true
					var juggler_as: float = Utils.get_stat(Keys.stat_attack_speed_hash, _parent.player_index)
					_current_cooldown = clamp(18.0 / max(0.1, 1.0 + juggler_as / 100.0), 3.0, 180.0)
			else:
				_juggler_turn_started = false
				cooldown_tick = 0.0
		_current_cooldown = max(_current_cooldown - cooldown_tick, 0)

	if _current_cooldown <= 10 and sprite.texture == stats.custom_on_cooldown_sprite:
		update_sprite(_original_sprite)

	
	
	if should_shoot():
		_is_shooting = true
		call_deferred("deferred_shoot")


func deferred_shoot() -> void :
	shoot()




func on_killed_something(_thing_killed: Node, hitbox: Hitbox) -> void :
	var attack_id: = hitbox.player_attack_id
	
	if attack_id >= 0:
		var attack_kill_count = _kill_count_by_attack_id.get(attack_id, 0)
		attack_kill_count += 1
		_kill_count_by_attack_id[attack_id] = attack_kill_count
		for effect in RunData.get_player_effect(Keys.gain_stat_when_attack_killed_enemies_hash, player_index):
			assert (effect[0] is int)
			var stat_hash = effect[0]
			var stat_value = effect[1]
			if attack_kill_count == effect[2]:
				RunData.add_stat(stat_hash, stat_value, player_index)
				if stat_hash == Keys.stat_engineering_hash and RunData.get_player_character(player_index).my_id_hash == Keys.character_dwarf_hash:
					RunData.add_tracked_value(player_index, Keys.character_dwarf_hash, stat_value)

	_enemies_killed_this_wave_count += 1
	for effect in effects:
		if effect is GainStatEveryKilledEnemiesEffect and _enemies_killed_this_wave_count % effect.value == 0:
			assert (effect.stat_hash is int and effect.stat_hash != Keys.empty_hash)
			RunData.add_stat(effect.stat_hash, effect.stat_nb, player_index)
			emit_signal("tracked_value_updated", effect.stat_nb)

func on_one_shot_something(_thing_killed: Node) -> void :
	emit_signal("tracked_value_updated")

func update_sprite(new_sprite: Texture) -> void :
	sprite.texture = SkinManager.get_skin(new_sprite)


func on_added_gold_on_crit(_gold_added: int) -> void :
	for effect in effects:
		if effect.key == "gold_on_crit_kill":
			emit_signal("tracked_value_updated")


func get_max_range() -> int:
	return current_stats.max_range + 50


func get_direction_and_calculate_target() -> float:

	if _targets_in_range.size() == 0:
		return rotation if _is_shooting else _current_idle_angle

	_current_target = Utils.get_nearest_no_max(_targets_in_range, global_position, current_stats.min_range)

	if _current_target[0] == null:
		return rotation if _is_shooting else _current_idle_angle

	var direction_to_target = (_current_target[0].global_position - global_position).angle()
	return direction_to_target


func get_direction() -> float:
	if _current_target.size() == 0 or not is_instance_valid(_current_target[0]):
		return rotation if _is_shooting else get_direction_and_calculate_target()
	else:
		var direction_to_target = (_current_target[0].global_position - global_position).angle()
		return direction_to_target + _current_shoot_spread


func should_shoot() -> bool:
	if _is_shooting:
		return false

	return (_current_cooldown <= 0
		and not _parent._panic_frozen  # Gourmet DLC - Girly can't shoot mid panic-teleport
		and (
			_parent._current_movement == Vector2.ZERO
			or
			RunData.get_player_effect(Keys.can_attack_while_moving_hash, player_index)

		)
		and 
		(
			(
				_current_target.size() > 0
				and is_instance_valid(_current_target[0])
				and Utils.is_between(_current_target[1], current_stats.min_range, current_stats.max_range + 50)
			)
			or (
				_manual_aim
				and not _parent.cleaning_up
			)
		)
	)


func shoot() -> void :
	# Gourmet DLC - Juggler: firing passes the act to the next weapon. The edge
	# flag resets HERE (not just on the inactive branch) so a solo weapon that
	# hands the turn back to itself still re-arms the 0.3s metronome.
	if weapon_pos >= 0 and _parent != null and "player_index" in _parent and RunData.is_juggler_cycling(_parent.player_index) and RunData.get_juggler_active_pos(_parent.player_index) == weapon_pos:
		_juggler_turn_started = false
		RunData.advance_juggler(_parent.player_index)
	_nb_shots_taken += 1
	var original_stats: RangedWeaponStats
	for projectile_count in _stats_every_x_shots:
		
		if _nb_shots_taken % projectile_count == 0:
			original_stats = current_stats
			current_stats = _stats_every_x_shots[projectile_count]

	for effect in effects:
		if effect.key_hash == Keys.reload_turrets_on_shoot_hash:
			emit_signal("wanted_to_reset_turrets_cooldown")

	update_current_spread()
	update_knockback()

	if _manual_aim:
		_shooting_behavior.shoot(current_stats.max_range)
	else:
		if _current_target.size() == 0 or not is_instance_valid(_current_target[0]):
			_shooting_behavior.shoot(current_stats.max_range)
		else:
			_shooting_behavior.shoot(_current_target[1])

	_current_cooldown = get_next_cooldown()

	if stats.custom_on_cooldown_sprite != null and (is_big_reload_active() or current_stats.additional_cooldown_every_x_shots == - 1):
		update_sprite(stats.custom_on_cooldown_sprite)

	if original_stats:
		current_stats = original_stats


func reset_cooldown() -> void :
	var multiplier = current_stats.additional_cooldown_multiplier if is_big_reload_active() else 1
	_current_cooldown = min(_current_cooldown, current_stats.cooldown * multiplier)


func get_next_cooldown(at_wave_begin: bool = false) -> float:
	if is_big_reload_active(at_wave_begin):
		return current_stats.cooldown * current_stats.additional_cooldown_multiplier

	var cooldown_basis = current_stats.cooldown

	
	if at_wave_begin and cooldown_basis >= 180:
		cooldown_basis = 180

	var max_rand = get_max_rand_cooldown(cooldown_basis)

	return rand_range(max(1, cooldown_basis - max_rand), cooldown_basis + max_rand)


func get_max_rand_cooldown(cooldown_basis: int) -> float:
	var weapon_count = min(_parent.get_nb_weapons(), 6)
	return min(weapon_count * cooldown_basis / 5.0, weapon_count * 5.0)


func is_big_reload_active(at_wave_begin: bool = false) -> bool:
	return not at_wave_begin and current_stats.additional_cooldown_every_x_shots != - 1 and _nb_shots_taken % current_stats.additional_cooldown_every_x_shots == 0


func update_current_spread() -> void :
	_current_shoot_spread = rand_range( - 1 + current_stats.accuracy, 1 - current_stats.accuracy)
	rotation += _current_shoot_spread


func update_knockback() -> void :
	_hitbox.set_knockback(Vector2(cos(rotation), sin(rotation)), current_stats.knockback, current_stats.knockback_piercing)


func set_shooting(value: bool) -> void :
	_is_shooting = value


func disable_hitbox() -> void :
	_hitbox.ignored_objects.clear()
	_hitbox.disable()


func enable_hitbox() -> void :
	_hitbox.enable()


func disable_target_tracking() -> void :
	_range_shape.disabled = true


func update_sprite_flipv() -> void :
	if Utils.is_facing_right(rotation_degrees):
		sprite.flip_v = false
	else:
		sprite.flip_v = true


func update_idle_angle() -> void :
	if _parent.get_direction() == 1:
		_current_idle_angle = _idle_angle
	else:
		_current_idle_angle = PI - _idle_angle


func _on_Range_body_entered(body: Node) -> void :
	_targets_in_range.push_back(body)
	var _error = body.connect("died", self, "on_target_died")


func _on_Range_body_exited(body: Node) -> void :
	_targets_in_range.erase(body)
	if _current_target.size() > 0 and body == _current_target[0]:
		_current_target.clear()
	body.disconnect("died", self, "on_target_died")


func on_target_died(target: Node, _args: Entity.DieArgs) -> void :
	_targets_in_range.erase(target)
	if _current_target.size() > 0 and target == _current_target[0]:
		_current_target.clear()


func _on_Hitbox_hit_something(thing_hit: Node, damage_dealt: int) -> void :
	RunData.manage_life_steal(current_stats, player_index)

	_hitbox.ignored_objects.push_back(thing_hit)

	for effect in effects:
		if effect is ExplodingEffect and Utils.get_chance_success(effect.chance):
			_explosion_args.pos = thing_hit.global_position
			_explosion_args.damage = _hitbox.damage
			_explosion_args.accuracy = _hitbox.accuracy
			_explosion_args.crit_chance = _hitbox.crit_chance
			_explosion_args.crit_damage = _hitbox.crit_damage
			_explosion_args.burning_data = _hitbox.burning_data
			_explosion_args.scaling_stats = _hitbox.scaling_stats
			_explosion_args.from_player_index = player_index
			_explosion_args.is_healing = _hitbox.is_healing
			_explosion_args.ignored_objects = [thing_hit]
			var _inst = WeaponService.explode(effect, _explosion_args)

	on_weapon_hit_something(thing_hit, damage_dealt, _hitbox)

	if custom_hit_sounds.size() > 0:
		SoundManager2D.play(Utils.get_rand_element(custom_hit_sounds), thing_hit.global_position, - 2, 0.1)




func on_weapon_hit_something(_thing_hit: Node, damage_dealt: int, hitbox: Hitbox) -> void :
	RunData.add_weapon_dmg_dealt(weapon_pos, damage_dealt, _parent.player_index)
	if hitbox == null:
		return
	var attack_id: = hitbox.player_attack_id
	if attack_id < 0:
		
		return
	var attack_hit_count = _hit_count_by_attack_id.get(attack_id, 0)
	attack_hit_count += 1
	_hit_count_by_attack_id[attack_id] = attack_hit_count
	
	if current_stats is MeleeWeaponStats:
		ChallengeService.try_complete_challenge(ChallengeService.chal_unstoppable_force_hash, attack_hit_count)
	
	var remove_until_attack_id: = attack_id - MAX_ATTACK_COUNT_HISTORY + 1
	for old_attack_id in range(_oldest_attack_id, remove_until_attack_id):
		var _erased = _hit_count_by_attack_id.erase(old_attack_id)
		_erased = _kill_count_by_attack_id.erase(old_attack_id)
	_oldest_attack_id = remove_until_attack_id
	assert (_hit_count_by_attack_id.size() <= MAX_ATTACK_COUNT_HISTORY)
	assert (_kill_count_by_attack_id.size() <= MAX_ATTACK_COUNT_HISTORY)

	for effect in effects:
		if effect.key_hash == Keys.break_on_hit_hash:
			if Utils.get_chance_success(effect.value / 100.0):
				emit_signal("wanted_to_break", self, effect.value2)

		# Gourmet DLC - on-hit food proc: value = tier's % chance; custom_key names the
		# food. Corn/Fish/Pizza/Sauce/Scoop/Spatula each drop their food where they hit.
		elif effect.custom_key.begins_with("food_drop:"):
			if Utils.get_chance_success(effect.value / 100.0) and is_instance_valid(_thing_hit):
				var fd_main = Utils.get_scene_node()
				if fd_main != null:
					var fd_food = ItemService.get_food_from_hash(Keys.generate_hash(effect.custom_key.substr(10)))
					if fd_food != null:
						fd_main.spawn_food(fd_food, _thing_hit.global_position, - 1.0, _parent.player_index)


func should_rotate_manual() -> bool:
	return true


func is_manual_aim() -> bool:
	return Utils.is_manual_aim(player_index)


func _on_weapon_critically_hit_something(_thing_hit, _damage_dealt) -> void :
	tween_animation.interpolate_property(sprite, "self_modulate", 
	Color(1.6, 1.6, 1), Color(1, 1, 1), 0.16, 
	Tween.TRANS_SINE, Tween.EASE_IN_OUT)
	tween_animation.start()


