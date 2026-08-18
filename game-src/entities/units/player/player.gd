class_name Player
extends Unit

signal wanted_to_spawn_gold(value, pos, spread)
signal healed(value, player_index)
signal run_won_screen()

const MIN_IFRAMES = 0.2
const MAX_IFRAMES = 0.4

export (Array, Resource) var hp_regen_sounds
export (Array, Resource) var step_sounds
export (Array, AudioStream) var swim_sounds
export (Array, Resource) var alien_sounds

export (PackedScene) var starship_beam_scene
export (PackedScene) var parachute_scene
export (PackedScene) var jellyshield_scene

var not_moving_bonuses_applied = false
var moving_bonuses_applied = false
var current_weapons: = []
var consumables_in_range: = []
var gamepad_attack_vector: = Vector2(1, 0)

var _sprites: = []
var _item_appearances: = []

var _explode_on_hit_stats = {}
var _explode_when_below_hp_stats = {}
var _explode_when_below_hp_triggers = {}
var _hit_protection: = 0

var _alien_eyes_timer: Timer
var _total_healed_this_wave = 0
var _chal_medicine_value = 0
var _chal_medicine_completed = false
var _chal_jellyshield = 0

var _hp_regen_val: = 1
var _health_regen_timer: = FixedTimer.new()

var _decaying_stats_on_consumable: = []
var _decaying_stats_on_hit: = []
# Gourmet DLC - active food buffs: food my_id -> {stacks, applied, timer, stat_hash, icon}
var _food_buffs: = {}
# Gourmet DLC - cosmetic HUD chips for ITEM buffs that are not food buffs (Sugar Rush's Speed
# burst). Deliberately a SEPARATE dict from _food_buffs: that one's SIZE drives Full Belly
# (+Armor while any food buff is active) and Food Coma (5+ distinct buffs), so a display-only
# entry in there would silently grant Armor and inflate the Food Coma count.
var _item_buff_chips: = {}
# Gourmet DLC - Competitive Eater: buffs gained this wave (drives his +5% Speed /
# +5% Pickup Range momentum; node is wave-fresh so this resets with the wave)
var _comp_momentum_stacks: = 0
# Gourmet DLC - Butcher: consumables eaten this wave == the temp Damage % he is carrying.
# main.gd banks 20% of it as permanent Appetite at wave end (wave-fresh node, so no reset).
var _butcher_wave_damage: = 0
var _food_attract_frames: = 0
var _nine_lives_used_this_wave: = false
var _full_belly_applied: = 0
var _food_coma_active: = false
var _picky_penalty_active: = false
var _remove_temp_stats_on_hit: = {}
var _one_second_timeouts: = 0
var _explode_args_player: = WeaponServiceExplodeArgs.new()




var _original_boost_args: BoostArgs
var _max_hp_before_boost: int

var player_index: = 0
var jellyshields: = []
var inside_doc_moth_area: = []

var animation_idle: String
var animation_move: String
var animation_landing: String

var _take_damage_args = TakeDamageArgs.new( - 1)
var _dodge_damage_args = TakeDamageArgs.new( - 1)

# Vampire Fang custom mechanic: Life Steal and consumables can overheal up to +20% of max HP past max HP
const VAMPIRE_FANG_OVERHEAL_PCT: = 0.20
# Gourmet DLC - Soul Food flip risk, FLAT (was (5 - 0.1 x Luck)% which floored at 0).
# Must stay in sync with soul_food_effect_1.tres value, which the card renders as {0}.
const SOUL_FLIP_PCT: = 3.0
# Gourmet DLC - Mint: seconds added to every active food buff timer.
# Card mirror: EFFECT_FOOD_MINT in build_food_system.py.
const MINT_EXTEND_SECONDS: = 6.0
# Gourmet DLC - Wine Cellar: seconds a food must sit on the ground to count as aged.
# Card mirror: EFFECT_WINE_CELLAR in build_pantry_items.py.
const WINE_CELLAR_AGE_SECONDS: = 6.0

onready var _lifesteal_timer = $LifestealTimer
onready var _invincibility_timer = $InvincibilityTimer
onready var _legs = $Animation / Legs
onready var _shadow: = $Animation / Shadow as Sprite
onready var _item_attract_area: = $ItemAttractArea as ItemAttractArea
onready var _item_pickup_area: = $ItemPickupArea as Area2D

onready var _weapons_container = $Weapons

onready var highlight: Sprite = $Animation / Highlight

onready var _running_smoke: CPUParticles2D = $RunningSmoke
onready var _lose_health_timer: Timer = $LoseHealthTimer
onready var _one_second_timer: Timer = $OneSecondTimer
onready var _moving_timer: Timer = $MovingTimer
onready var _not_moving_timer: Timer = $NotMovingTimer
onready var _boost_timer: Timer = $BoostTimer



onready var _life_bar_transform: = $LifeBarTransform as RemoteTransform2D
onready var _animation_node: Node = $Animation / Sprite

func _ready() -> void :
	match RunData.current_zone:
		1:
			animation_idle = "idle_swim"
			animation_move = "move_swim"
			animation_landing = "landing_swim"
			_running_smoke.queue_free()
			_running_smoke = $SwimmingBubble
			step_sounds = swim_sounds
		_:
			animation_idle = "idle"
			animation_move = "move"
			animation_landing = "landing"
			$SwimmingBubble.queue_free()
	_animation_player.play(animation_idle)

	var pickup_range = RunData.get_player_effect(Keys.pickup_range_hash, player_index)
	_item_attract_area.apply_pickup_range_effect(pickup_range)

	_chal_medicine_value = ChallengeService.get_chal(ChallengeService.chal_medicine_hash).value

	_hit_protection = RunData.get_player_effect(Keys.hit_protection_hash, player_index)

	_running_smoke.stop()

	if RunData.invulnerable:
		disable_hurtbox()

	if DebugService.invisible:
		visible = false

	set_hp_regen_timer_value()

	var init_triggers = true
	init_exploding_stats(init_triggers)

	if RunData.get_player_effect(Keys.lose_hp_per_second_hash, player_index) > 0:
		_lose_health_timer.start()

	if RunData.get_player_effect(Keys.temp_stats_per_interval_hash, player_index).size() > 0:
		_one_second_timer.start()

	var alien_eyes_effect = RunData.get_player_effect(Keys.alien_eyes_hash, player_index)
	if alien_eyes_effect.size() > 0:
		_alien_eyes_timer = Timer.new()
		_alien_eyes_timer.wait_time = alien_eyes_effect[3]
		var _alien_eyes = _alien_eyes_timer.connect("timeout", self, "on_alien_eyes_timeout")
		add_child(_alien_eyes_timer)
		_alien_eyes_timer.start()

		
		

		
		
		
		

		
		
		
		
		
			
			

	update_highlight()
	init_effect_behaviors()

	# Gourmet DLC - Picky Eater starts each wave buffless (-15% Damage penalty on)
	_update_food_buff_bonuses()


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, p_players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, p_players_ref, entity_spawner_ref)

	var effects = RunData.get_player_effects(player_index)
	if effects.has(Keys.stat_jellyshield_count_hash):
		var jellyshield_count = effects[Keys.stat_jellyshield_count_hash]
		for i in range(jellyshield_count):
			var args = EntitySpawner.SpawnEntityArgs.new(global_position, - 1)
			args.player_index = player_index
			var jellyshield = _entity_spawner_ref.spawn_entity(jellyshield_scene, args)
			jellyshield.init_trajectory(i, jellyshield_count, self)
			jellyshields.push_back(jellyshield)



func respawn() -> void :
	assert (false, "Players can't be respawned")


func init_effect_behaviors() -> void :
	assert (effect_behaviors.get_child_count() == 0, "init_effect_behaviors should only be called once")
	for effect_behavior_data in EffectBehaviorService.player_effect_behaviors:
		var effect_behavior = effect_behavior_data.scene.instance().init(self)
		if effect_behavior.should_add_on_spawn():
			effect_behaviors.add_child(effect_behavior)
		else:
			effect_behavior.queue_free()


func update_animation(movement: Vector2) -> void :

	check_not_moving_stats(movement)
	check_moving_stats(movement)

	if movement.x > 0:
		_shadow.scale.x = abs(_shadow.scale.x)
		for sprite in _sprites:
			sprite.scale.x = abs(sprite.scale.x)
	elif movement.x < 0:
		_shadow.scale.x = - abs(_shadow.scale.x)
		for sprite in _sprites:
			sprite.scale.x = - abs(sprite.scale.x)

	if _animation_player.current_animation == animation_idle:
		_animation_player.playback_speed = 1
	elif _animation_player.current_animation == animation_move:
		_animation_player.playback_speed = get_move_speed() / stats.speed

	if _animation_player.current_animation == animation_idle and movement != Vector2.ZERO:
		_animation_player.play(animation_move)
		_running_smoke.emit()
	elif _animation_player.current_animation == animation_move and movement == Vector2.ZERO:
		_animation_player.play(animation_idle)
		_running_smoke.stop()


func check_not_moving_stats(movement: Vector2) -> void :
	assert ( not dead)
	var stat_changed = false
	var temp_stats_while_not_moving = RunData.get_player_effect(Keys.temp_stats_while_not_moving_hash, player_index)
	if not not_moving_bonuses_applied and temp_stats_while_not_moving.size() > 0 and movement.x == 0 and movement.y == 0:
		not_moving_bonuses_applied = true

		_not_moving_timer.start()

		for temp_stat in temp_stats_while_not_moving:
			assert (temp_stat[0] is int)
			if temp_stat[0] != Keys.percent_materials_hash:
				TempStats.add_stat(temp_stat[0], temp_stat[1], player_index)
				stat_changed = true

	elif not_moving_bonuses_applied and (movement.x != 0 or movement.y != 0):
		not_moving_bonuses_applied = false

		_not_moving_timer.stop()

		for temp_stat in temp_stats_while_not_moving:
			assert (temp_stat[0] is int)
			if temp_stat[0] != Keys.percent_materials_hash:
				TempStats.remove_stat(temp_stat[0], temp_stat[1], player_index)
				stat_changed = true

	if stat_changed:
		LinkedStats.reset_player(player_index)


func check_moving_stats(movement: Vector2) -> void :
	assert ( not dead)
	var temp_stats_while_moving = RunData.get_player_effect(Keys.temp_stats_while_moving_hash, player_index)
	if not moving_bonuses_applied and temp_stats_while_moving.size() > 0 and (movement.x != 0 or movement.y != 0):
		moving_bonuses_applied = true

		_moving_timer.start()

		for temp_stat in temp_stats_while_moving:
			assert (temp_stat[0] is int)
			if temp_stat[0] != Keys.percent_materials_hash:
				TempStats.add_stat(temp_stat[0], temp_stat[1], player_index)

	elif moving_bonuses_applied and movement.x == 0 and movement.y == 0:
		moving_bonuses_applied = false

		_moving_timer.stop()

		for temp_stat in temp_stats_while_moving:
			assert (temp_stat[0] is int)
			if temp_stat[0] != Keys.percent_materials_hash:
				TempStats.remove_stat(temp_stat[0], temp_stat[1], player_index)


func reset_weapons_cd() -> void :
	for weapon in current_weapons:
		if is_instance_valid(weapon):
			weapon.reset_cooldown()


func disable_hurtbox() -> void :
	_hurtbox.disable()


func enable_hurtbox() -> void :
	_hurtbox.enable()


# Gourmet DLC - Girly panic-teleport (driven by main.gd girly_panic_teleport).
# begin: freeze move+shoot, go invincible, hold chasers on `origin`, fade out.
func begin_panic_teleport(origin: Vector2) -> void :
	_panic_frozen = true
	_current_movement = Vector2.ZERO
	panic_target_override = origin
	disable_hurtbox()
	_panic_fade(1.0, 0.0, 0.5)


func panic_fade_in() -> void :
	modulate = Color(1, 1, 1, 0)
	_panic_fade(0.0, 1.0, 0.5)


func end_panic_teleport() -> void :
	_panic_frozen = false
	panic_target_override = null
	modulate = Color(1, 1, 1, 1)
	enable_hurtbox()


func _panic_fade(from_a: float, to_a: float, dur: float) -> void :
	var tw: = Tween.new()
	add_child(tw)
	tw.interpolate_property(self, "modulate", Color(1, 1, 1, from_a), Color(1, 1, 1, to_a), dur)
	var _e = tw.connect("tween_all_completed", tw, "queue_free")
	tw.start()


func disable_gold_pickup() -> void :
	_item_attract_area.set_collision_mask_bit(6, false)
	_item_pickup_area.set_collision_mask_bit(6, false)


func get_nb_weapons() -> int:
	return current_weapons.size()


func get_remote_transform() -> RemoteTransform2D:
	return $RemoteTransform2D as RemoteTransform2D


func get_life_bar_remote_transform() -> RemoteTransform2D:
	return _life_bar_transform


func get_damage_value(dmg_value: int, _from_player_index: int, armor_applied: = true, dodgeable: = true, _is_crit: = false, _hitbox: Hitbox = null, _is_burning: = false) -> Unit.GetDamageValueResult:
	var result: = Unit.GetDamageValueResult.new()
	if dodgeable and randf() < current_stats.dodge:
		result.value = 0
		result.dodged = true
	elif _hit_protection > 0:
		result.value = 0
		result.protected = true
		_hit_protection -= 1
	else:
		var armor_coef = RunData.get_armor_coef(current_stats.armor)
		result.value = max(1, round(dmg_value * armor_coef)) as int if armor_applied else dmg_value
	return result


func apply_items_effects() -> void :

	
	var weapons = RunData.get_player_weapons_ref(player_index)
	for i in weapons.size():
		add_weapon(weapons[i], i)

	RunData.sort_appearances()
	var appearances_behind = []

	
	for appearance in RunData.get_player_appearances(player_index):
		var item_sprite = Sprite.new()
		item_sprite.texture = appearance.get_sprite()
		_animation_node.add_child(item_sprite)

		if appearance.depth < - 1:
			appearances_behind.push_back(item_sprite)

		_item_appearances.push_back(item_sprite)

	var popped = appearances_behind.pop_back()

	while popped != null:
		popped.show_behind_parent = true
		_animation_node.move_child(popped, 0)
		popped = appearances_behind.pop_back()

	_sprites = $Animation.get_children()

	# tint the legs to match a recoloured body (green/brown characters); default is no change
	var _lchar = RunData.get_player_character(player_index)
	if _lchar != null and _lchar.legs_modulate != Color(1, 1, 1):
		for leg in _legs.get_children():
			leg.get_node("Sprite").self_modulate = _lchar.legs_modulate


	update_player_stats(true)


func update_player_stats(reset_current_health: = false) -> void :
	var old_max_health = max_stats.health
	max_stats.health = RunData.get_player_max_health(player_index)
	max_stats.speed = stats.speed * (1 + (Utils.get_capped_stat(Keys.stat_speed_hash, player_index) / 100.0)) as float
	max_stats.armor = Utils.get_stat(Keys.stat_armor_hash, player_index) as int
	max_stats.dodge = Utils.get_capped_stat(Keys.stat_dodge_hash, player_index) / 100.0

	init_exploding_stats()

	current_stats.copy(max_stats, reset_current_health)


	if not reset_current_health and old_max_health < max_stats.health:
		var increased_health: int = max_stats.health - old_max_health
		current_stats.health += increased_health

	if old_max_health != max_stats.health:
		emit_signal("health_updated", self, current_stats.health, max_stats.health)

	check_hp_regen()


# Gourmet DLC - the Gourmet's fattening: grow the whole body at once. Everything parented
# to the player scales with it - sprite, movement collider, hurtbox (a bigger target, which
# is the real cost), both pickup areas and the weapon orbit distance - which is exactly the
# intended package. The HUD life bar is exempted so it does not balloon along with him.
func set_body_scale(body_scale: float) -> void :
	scale = Vector2.ONE * body_scale
	_life_bar_transform.update_scale = false


func add_weapon(weapon: WeaponData, pos: int) -> void :
	var instance = weapon.scene.instance()

	instance.weapon_pos = pos
	instance.stats = weapon.stats.duplicate()
	instance.weapon_id = weapon.weapon_id
	instance.weapon_id_hash = weapon.get_weapon_id_hash()
	instance.tier = weapon.tier
	instance.weapon_sets = weapon.sets
	instance.is_cursed = weapon.is_cursed
	instance.connect("tracked_value_updated", weapon, "on_tracked_value_updated")
	instance.connect("tracked_value_set", weapon, "on_tracked_value_set")
	instance.connect("wanted_to_break", self, "on_weapon_wanted_to_break")

	for effect in weapon.effects:
		instance.effects.push_back(effect.duplicate())

	_weapons_container.add_child(instance)
	instance.global_position = position
	current_weapons.push_back(instance)
	_weapons_container.update_weapons_positions(current_weapons)


func on_weapon_wanted_to_break(weapon: Weapon, gold_dropped: int) -> void :

	if not current_weapons.has(weapon):
		return

	emit_signal("wanted_to_spawn_gold", gold_dropped, weapon.global_position, 300)
	var _r = RunData.remove_weapon_by_index(weapon.weapon_pos, player_index)

	current_weapons.erase(weapon)

	for current_weapon in current_weapons:
		if current_weapon.weapon_pos > weapon.weapon_pos:
			current_weapon.weapon_pos -= 1

	SoundManager.play(Utils.get_rand_element(WeaponService.breaking_sounds), - 15, 0.1, true)

	weapon.queue_free()

func take_damage(value: int, args: TakeDamageArgs) -> Array:
	if dead:
		return [0, 0, false]

	check_chal_jellyshield(args)

	var hitbox = args.hitbox
	var dodgeable = args.dodgeable
	var bypass_invincibility = args.bypass_invincibility

	if hitbox and hitbox.is_healing:
		var _healed = on_healing_effect(value, hitbox.damage_tracking_key_hash, false, true)
		return [0, 0, false]

	if _invincibility_timer.is_stopped() or bypass_invincibility:

		var dmg_value_result = get_damage_value(value, args.from_player_index, args.armor_applied, dodgeable, false, hitbox, args.is_burning)
		var full_dmg_value = dmg_value_result.value
		var is_dodge = dmg_value_result.dodged
		var is_protected = dmg_value_result.protected

		# Gourmet DLC - Sunscreen: modifies burning damage taken
		if args.is_burning and full_dmg_value > 0:
			var burning_taken: int = RunData.get_player_effect(Keys.burning_damage_taken_hash, player_index)
			if burning_taken != 0:
				full_dmg_value = int(max(0, full_dmg_value * (100.0 + burning_taken) / 100.0))

		var dmg_taken = clamp(full_dmg_value, 0, current_stats.health)
		current_stats.health = max(0.0, current_stats.health - full_dmg_value) as int

		# Gourmet DLC - Nine Lives: survive lethal damage at 1 HP (once per wave and 9 per run)
		if current_stats.health <= 0:
			var nine_lives_effects = RunData.get_player_effects(player_index)
			if nine_lives_effects[Keys.nine_lives_hash] > 0 and not _nine_lives_used_this_wave and nine_lives_effects[Keys.nine_lives_used_hash] < 9:
				_nine_lives_used_this_wave = true
				nine_lives_effects[Keys.nine_lives_used_hash] += 1
				current_stats.health = 1
				RunData.add_tracked_value(player_index, Keys.generate_hash("item_nine_lives"), 1)
				disable_hurtbox()
				_invincibility_timer.start(1.0)
				Utils.gourmet_tracker.ev("nine_lives_save", {"p": player_index, "used": nine_lives_effects[Keys.nine_lives_used_hash]})

		# Gourmet DLC - Zombie: a hit that leaves him on exactly 1 HP rots him straight back
		# to full. Fires whether the 1 HP came from Nine Lives or from a plain hit (the Nine
		# Lives charge is still spent either way). Writes health directly rather than going
		# through heal(), so his own no_heal gate never sees it - the same trick Nine Lives
		# uses above. Checked AFTER the Nine Lives block so the two chain in one hit.
		if current_stats.health == 1:
			var undead_character = RunData.get_player_character(player_index)
			if undead_character != null and undead_character.my_id == "character_zombie" and max_stats.health > 1:
				current_stats.health = max_stats.health
				RunData.add_tracked_value(player_index, undead_character.get_my_id_hash(), 1)
				Utils.gourmet_tracker.ev("zombie_reanimate", {"p": player_index})

		emit_signal("health_updated", self, current_stats.health, max_stats.health)

		if dodgeable:
			disable_hurtbox()
			_invincibility_timer.start(get_iframes(dmg_taken))

		var sound = Utils.get_rand_element(hurt_sounds)
		if is_dodge:
			sound = Utils.get_rand_element(dodge_sounds)

			var dmg_on_dodge_effect = RunData.get_player_effect(Keys.dmg_on_dodge_hash, player_index)
			if dmg_on_dodge_effect.size() > 0 and hitbox != null and is_instance_valid(hitbox.from):
				var total_dmg_to_deal = 0
				for dmg_on_dodge in dmg_on_dodge_effect:
					if randf() >= dmg_on_dodge[2] / 100.0:
						continue
					assert (dmg_on_dodge[0] is int)
					var dmg_from_stat = max(1, (dmg_on_dodge[1] / 100.0) * Utils.get_stat(dmg_on_dodge[0], player_index))
					var dmg = WeaponService.apply_damage_bonus(dmg_from_stat, player_index) as int
					total_dmg_to_deal += dmg
				
				_dodge_damage_args._init(player_index)
				var dodge_dmg_dealt = hitbox.from.take_damage(total_dmg_to_deal, _dodge_damage_args)
				RunData.add_tracked_value(player_index, Keys.item_riposte_hash, dodge_dmg_dealt[1])

			var heal_on_dodge_effect = RunData.get_player_effect(Keys.heal_on_dodge_hash, player_index)
			if heal_on_dodge_effect.size() > 0:
				var total_to_heal = 0
				for heal_on_dodge in heal_on_dodge_effect:
					if randf() < heal_on_dodge[2] / 100.0:
						total_to_heal += heal_on_dodge[1]
				var _healed = on_healing_effect(total_to_heal, Keys.item_adrenaline_hash, false)

			var temp_stats_on_dodge_effect = RunData.get_player_effect(Keys.temp_stats_on_dodge_hash, player_index)
			for temp_stat_on_hit in temp_stats_on_dodge_effect:
				TempStats.add_stat(temp_stat_on_hit[0], temp_stat_on_hit[1], player_index)

		if dmg_taken > 0:
			flash()
			_attract_nearby_consumables()

			# Gourmet DLC - Caltrops: attackers in melee range take damage back
			var caltrops_count: int = RunData.get_player_effect(Keys.caltrops_hash, player_index)
			if caltrops_count > 0 and hitbox != null and is_instance_valid(hitbox.from) and hitbox.from is Unit and not hitbox.from.dead and hitbox.from != self:
				if global_position.distance_to(hitbox.from.global_position) <= 200.0:
					var caltrops_dmg: int = int((3.0 + 0.3 * Utils.get_stat(Keys.stat_melee_damage_hash, player_index)) * caltrops_count)
					_dodge_damage_args._init(player_index)
					var caltrops_result: Array = hitbox.from.take_damage(caltrops_dmg, _dodge_damage_args)
					RunData.add_tracked_value(player_index, Keys.generate_hash("item_caltrops"), caltrops_result[1])
					Utils.gourmet_tracker.count("caltrops_hits")

			# Gourmet DLC - Pocket Sand: attackers get slowed 20% per stack (max -60%) for 2 seconds
			var pocket_sand_stacks: int = RunData.get_player_effect(Keys.pocket_sand_slow_hash, player_index)
			if pocket_sand_stacks > 0 and hitbox != null and is_instance_valid(hitbox.from) and hitbox.from is Unit and not hitbox.from.dead and hitbox.from != self:
				hitbox.from.apply_gourmet_slow(int(min(60, 20 * pocket_sand_stacks)), 2.0)
				Utils.gourmet_tracker.count("pocket_sand_slows")

			var explode_on_hit_effects = RunData.get_player_effect(Keys.explode_on_hit_hash, player_index)
			var explode_when_below_hp_effects = RunData.get_player_effect(Keys.explode_when_below_hp_hash, player_index)
			var nb_explosions = explode_on_hit_effects.size() + explode_when_below_hp_effects.size()

			var die_in_one_hit = RunData.get_player_effect(Keys.die_in_one_hit_hash, player_index)
			if die_in_one_hit > 0:
				current_stats.health = 0
				emit_signal("health_updated", self, current_stats.health, max_stats.health)

			for effect in explode_on_hit_effects:
				explode(_explode_on_hit_stats[effect], effect, nb_explosions)

			for effect in explode_when_below_hp_effects:
				if current_stats.health <= max_stats.health * (effect.hp_threshold / 100.0) and _explode_when_below_hp_triggers[effect] > 0:
					explode(_explode_when_below_hp_stats[effect], effect, nb_explosions)
					_explode_when_below_hp_triggers[effect] -= 1

			var temp_stats_on_hit_effect = RunData.get_player_effect(Keys.temp_stats_on_hit_hash, player_index)
			for temp_stat_on_hit in temp_stats_on_hit_effect:
				TempStats.add_stat(temp_stat_on_hit[0], temp_stat_on_hit[1], player_index)

			if _health_regen_timer.is_stopped():
				_health_regen_timer.start()

			for stat in _remove_temp_stats_on_hit:
				var stat_value: int = _remove_temp_stats_on_hit[stat]
				TempStats.remove_stat(stat, stat_value, player_index)
				_remove_temp_stats_on_hit[stat] = 0

			
			var decaying_stats_on_hit_effects = RunData.get_player_effect(Keys.decaying_stats_on_hit_hash, player_index)
			for decaying_stats_on_hit_effect in decaying_stats_on_hit_effects:
				var decaying_stat_name = decaying_stats_on_hit_effect[0]
				var decaying_stat_value = decaying_stats_on_hit_effect[1]
				var decaying_stat_duration = decaying_stats_on_hit_effect[2]
				_start_decaying_stats_effect_timer(_decaying_stats_on_hit, decaying_stat_name, decaying_stat_value, decaying_stat_duration)

		SoundManager2D.play(sound, global_position, 0, 0.2, true)


		if current_stats.health <= 0:
			Utils.default_die_args.from = args.from
			Utils.default_die_args.knockback_vector = Vector2.ZERO
			Utils.default_die_args.cleaning_up = false
			Utils.default_die_args.enemy_killed_by_player = false
			Utils.default_die_args.killed_by_player_index = - 1
			Utils.default_die_args.killing_blow_dmg_value = 0
			Utils.default_die_args.is_burning = false
			die(Utils.default_die_args)



		emit_signal(
			"took_damage", 
			self, 
			full_dmg_value, 
			Vector2.ZERO, 
			false, 
			is_dodge, 
			is_protected, 
			false, 
			args, 
			HitType.NORMAL, 
			false
		)

		return [full_dmg_value, dmg_taken, is_dodge]

	return [0, 0, false]

func check_chal_jellyshield(args: TakeDamageArgs):
	if not ChallengeService.is_challenge_completed(ChallengeService.chal_jellyshield_hash):
		if args.hitbox != null and args.hitbox.get_parent() is Projectile:
			_chal_jellyshield += 1
			if _chal_jellyshield >= ChallengeService.get_chal(ChallengeService.chal_jellyshield_hash).value:
				ChallengeService.complete_challenge(ChallengeService.chal_jellyshield_hash)

func explode(stats: WeaponStats, effect: ExplodingEffect, nb_explosions: int) -> void :

	if not Utils.get_chance_success(effect.chance):
		return

	_explode_args_player.pos = Utils.get_random_offset_position(global_position, (nb_explosions - 1) * 20)
	_explode_args_player.damage = stats.damage + effect.get_additional_scaling_damage(player_index)
	_explode_args_player.accuracy = stats.accuracy
	_explode_args_player.crit_chance = stats.crit_chance
	_explode_args_player.crit_damage = stats.crit_damage
	_explode_args_player.burning_data = stats.burning_data
	_explode_args_player.scaling_stats = stats.scaling_stats
	_explode_args_player.from_player_index = player_index
	_explode_args_player.damage_tracking_key_hash = effect.tracking_key_hash

	if stats.shooting_sounds.size() > 0:
		SoundManager2D.play(Utils.get_rand_element(stats.shooting_sounds), global_position, stats.sound_db_mod, 0.2, true)

	var _inst = WeaponService.explode(effect, _explode_args_player)


func get_iframes(damage_taken: float) -> float:
	var pct_dmg_taken = (damage_taken / max_stats.health)

	var min_iframes = MIN_IFRAMES / (max(1.0, RunData.get_endless_factor()))
	var max_iframes = MAX_IFRAMES / (max(1.0, RunData.get_endless_factor()))

	var iframes = clamp((pct_dmg_taken * max_iframes) / 0.15, min_iframes, max_iframes)



	return iframes


func check_hp_regen() -> void :
	set_hp_regen_timer_value()

	var stat_hp_regeneration = Utils.get_stat(Keys.stat_hp_regeneration_hash, player_index)
	if RunData.get_player_effect(Keys.torture_hash, player_index) <= 0 and stat_hp_regeneration <= 0:
		_health_regen_timer.stop()
	elif _health_regen_timer.is_stopped() and current_stats.health < max_stats.health and not cleaning_up:
		_health_regen_timer.start()


func set_hp_regen_timer_value() -> void :
	if RunData.get_player_effect(Keys.torture_hash, player_index) > 0:
		_health_regen_timer.wait_time = 1
		return

	var stat_hp_regeneration = Utils.get_stat(Keys.stat_hp_regeneration_hash, player_index)
	_health_regen_timer.wait_time = RunData.get_hp_regeneration_timer(stat_hp_regeneration as int)


func play_step_sound() -> void :
	if DebugService.invisible:
		return

	SoundManager.play(Utils.get_rand_element(step_sounds), - 6, 0.1)


func land() -> void :
	_animation_player.playback_speed = 1
	_animation_player.play(animation_landing)

	
	var animation_node = $Animation / Sprite
	var parachute: Node = parachute_scene.instance()
	animation_node.add_child(parachute)
	parachute._play(RunData.current_zone == 1)

	yield(_animation_player, "animation_finished")
	_animation_player.play(animation_idle)
	_animation_player.play(animation_idle)


func die(args: = Utils.default_die_args) -> void :
	.die(args)

	for weapon in current_weapons:
		weapon.disable_hitbox()
		weapon.disable_target_tracking()
	Utils.disable_node(_weapons_container)

	highlight.hide()
	_legs.queue_free()
	_shadow.queue_free()
	_running_smoke.queue_free()
	for appearance in _item_appearances:
		appearance.queue_free()

	for jellyshield in jellyshields:
		jellyshield.queue_free()
	jellyshields.clear()

	_item_attract_area.monitoring = false
	_item_pickup_area.monitoring = false

	TempStats.reset_player(player_index)
	_clean_up()


func won() -> void :
	if not dead:
		yield(get_tree().create_timer(0.25), "timeout")
		_animation_player.playback_speed = 1
		_animation_player.play("won")
		yield(get_tree().create_timer(1.0), "timeout")

		var starship_beam: CPUParticles2D = starship_beam_scene.instance()
		add_child(starship_beam)
		var tween: Tween = starship_beam.get_node("Tween")
		tween.interpolate_property(starship_beam, "modulate", Color(1, 1, 1, 0), Color(1, 1, 1, 1), 0.1)
		tween.start()
	else:
		yield(get_tree().create_timer(0.25), "timeout")
		run_won_screen()



func dance() -> void :
	_animation_player.playback_speed = 1
	_animation_player.play("dance", 0.1)


func death_animation_finished() -> void :
	
	
	pass


func _physics_process(delta: float) -> void :

	var loop_count: = _health_regen_timer.try_loop(delta)
	if loop_count > 0:
		on_health_regen(loop_count)

	# Gourmet DLC - foods are magnet-attracted at a reduced pickup distance, so poll
	# distance instead of relying on the one-shot area_entered signal (which fires at the
	# full radius). 3 frames = 20Hz: fast enough that the magnet never visibly lags.
	_food_attract_frames += 1
	if _food_attract_frames >= 3:
		_food_attract_frames = 0
		_attract_nearby_foods()



func on_room_cleanup() -> void :
	
	
	
	if dead:
		return
	_running_smoke.stop()
	_animation_player.play(animation_idle)
	_clean_up()


func on_health_regen(loop_count: int) -> void :

	var bonus_hp_regen_effects = RunData.get_player_effect(Keys.hp_regen_bonus_hash, player_index)

	var hp_regen_val = _hp_regen_val

	if bonus_hp_regen_effects.size() > 0:
		var multiplier = 0
		for effect in bonus_hp_regen_effects:
			if current_stats.health < max_stats.health * (effect[1] / 100.0):
				multiplier += effect[0]
		hp_regen_val = _hp_regen_val * (1.0 + multiplier)

	var torture_effect = RunData.get_player_effect(Keys.torture_hash, player_index)
	var base_val = torture_effect if torture_effect > 0 else hp_regen_val
	base_val *= loop_count
	var value = min(base_val, max_stats.health - current_stats.health)

	if value < 0: value = 0
	var _healed = on_healing_effect(value, Keys.empty_hash, torture_effect > 0)

	if current_stats.health >= max_stats.health:
		_health_regen_timer.stop()


func on_damage_effect(value: int, armor_applied: bool, dodgeable: bool, from = null) -> void :
	_take_damage_args.armor_applied = armor_applied
	_take_damage_args.dodgeable = dodgeable
	_take_damage_args.from = from
	var _dmg_taken = take_damage(value, _take_damage_args)


func _has_vampire_fang() -> bool:
	for item in RunData.get_player_items(player_index):
		if item.my_id == "item_vampire_fang":
			return true
	return false


func on_lifesteal_effect(value: int) -> void :
	if _lifesteal_timer.is_stopped():
		_lifesteal_timer.start()
		var _healed = on_healing_effect(value, Keys.empty_hash, false, true)


func on_healing_effect(value: int, tracking_key: int = Keys.empty_hash, from_torture: bool = false, allow_overheal: bool = false) -> int:

	var heal_cap = max_stats.health
	if allow_overheal and _has_vampire_fang():
		heal_cap += int(max_stats.health * VAMPIRE_FANG_OVERHEAL_PCT)

	var actual_value = min(value, heal_cap - current_stats.health)
	if actual_value < 0:
		actual_value = 0
	var overheal_before: int = int(max(0, current_stats.health - max_stats.health))
	var value_healed = heal(actual_value, from_torture)
	if allow_overheal and value_healed > 0 and _has_vampire_fang():
		var overheal_gained: int = int(max(0, current_stats.health - max_stats.health)) - overheal_before
		if overheal_gained > 0:
			RunData.add_tracked_value(player_index, Keys.generate_hash("item_vampire_fang"), overheal_gained)

	if value_healed > 0:
		SoundManager.play(Utils.get_rand_element(hp_regen_sounds), get_heal_db(), 0.1)
		emit_signal("health_updated", self, current_stats.health, max_stats.health)
		emit_signal("healed", actual_value, player_index)

		if tracking_key != Keys.empty_hash:
			RunData.add_tracked_value(player_index, tracking_key, value_healed)

	return value_healed


func on_heal_over_time_effect(total_healing: int, duration: int) -> void :
	var interval: = float(duration) / total_healing

	for i in range(1, total_healing + 1):
		var timer: SceneTreeTimer = get_tree().create_timer(interval * i, false)
		var _hot_error: = timer.connect("timeout", self, "on_heal_over_time_timer_timeout")


func on_heal_over_time_timer_timeout() -> void :
	var _e = on_healing_effect(1)


func get_heal_db() -> float:
	if _health_regen_timer.wait_time < 2.5:
		return - 10.0
	elif _health_regen_timer.wait_time < 1.0:
		return - 15.0
	else:
		return 0.0


func heal(value: int, is_from_torture: bool = false) -> int:
	if dead or RunData.get_player_effect_bool(Keys.no_heal_hash, player_index):
		return 0

	
	
	var value_healed = 0
	if RunData.get_player_effect(Keys.torture_hash, player_index) <= 0 or is_from_torture or cleaning_up:
		current_stats.health += value
		value_healed = value

	_total_healed_this_wave += value_healed

	if _total_healed_this_wave >= _chal_medicine_value and not _chal_medicine_completed:
		_chal_medicine_completed = true
		ChallengeService.complete_challenge(ChallengeService.chal_medicine_hash)

	return value_healed


func init_exploding_stats(init_triggers: bool = false) -> void :
	var explode_on_hit = RunData.get_player_effect(Keys.explode_on_hit_hash, player_index)
	var explode_when_below_hp = RunData.get_player_effect(Keys.explode_when_below_hp_hash, player_index)
	if explode_on_hit.empty() and explode_when_below_hp.empty():
		return
	for effect in explode_on_hit:
		var args: = WeaponServiceInitStatsArgs.new()
		args.effects = [ExplodingEffect.new()]
		_explode_on_hit_stats[effect] = WeaponService.init_base_stats(effect.stats, player_index, args)
	for effect in explode_when_below_hp:
		var args: = WeaponServiceInitStatsArgs.new()
		args.effects = [ExplodingEffect.new()]
		_explode_when_below_hp_stats[effect] = WeaponService.init_base_stats(effect.stats, player_index, args)
		if init_triggers:
			_explode_when_below_hp_triggers[effect] = 1




func _clean_up() -> void :
	assert ( not cleaning_up)
	cleaning_up = true
	_can_move = false
	_current_movement = Vector2.ZERO
	for timer in [
		_health_regen_timer, 
		_lose_health_timer, 
		_moving_timer, 
		_not_moving_timer, 
		_invincibility_timer, 
		_one_second_timer, 
	]:
		timer.stop()
		timer.paused = true

	if _alien_eyes_timer:
		_alien_eyes_timer.stop()
		_alien_eyes_timer.paused = true
	set_physics_process(false)
	disable_hurtbox()


func _on_InvincibilityTimer_timeout() -> void :
	# Gourmet DLC - don't re-enable the hurtbox mid panic-teleport (Girly is invincible
	# for the full second); end_panic_teleport re-enables it when control returns.
	if not cleaning_up and not _panic_frozen:
		enable_hurtbox()


func _on_LoseHealthTimer_timeout() -> void :
	_take_damage_args.dodgeable = false
	_take_damage_args.armor_applied = false
	_take_damage_args.bypass_invincibility = true
	_take_damage_args.from = self
	var lose_hp_per_second = RunData.get_player_effect(Keys.lose_hp_per_second_hash, player_index)
	var _dmg_taken = take_damage(lose_hp_per_second, _take_damage_args)


func on_alien_eyes_available(instance: Node) -> void :
	if not cleaning_up:
		Utils.get_scene_node().call_deferred("remove_child", instance)
		
		
	else:
		instance.queue_free()

func on_alien_eyes_timeout() -> void :
	var alien_eyes_effect = RunData.get_player_effect(Keys.alien_eyes_hash, player_index)

	var alien_stats = WeaponService.init_ranged_stats(alien_eyes_effect[1], player_index, true)

	SoundManager.play(Utils.get_rand_element(alien_sounds), 0, 0.1)

	for i in alien_eyes_effect[0]:
		var direction = (2 * PI / alien_eyes_effect[0]) * i

		var auto_target_enemy: bool = alien_eyes_effect[2]
		

		
		
		
		
		
		
		

		var args: = WeaponServiceSpawnProjectileArgs.new()
		args.damage_tracking_key_hash = Keys.item_alien_eyes_hash
		
		args.from_player_index = player_index
		var _projectile = WeaponService.manage_special_spawn_projectile(
			self, 
			alien_stats, 
			direction, 
			auto_target_enemy, 
			_entity_spawner_ref, 
			self, 
			args
		)


func update_highlight():
	if dead: return

	var value = ProgressData.settings.character_highlighting
	if RunData.is_coop_run:
		var highlight_color = CoopService.get_player_color(player_index)
		highlight_color.a = 1.0 if value else 0.7
		highlight.modulate = highlight_color
		highlight.show()
	else:
		highlight.visible = value
		highlight.modulate = Utils.HIGHLIGHT_COLOR


func update_weapon_highlighting() -> void :
	for weapon in current_weapons:
		weapon.update_highlighting()


func on_consumable_picked_up(consumable_data: ConsumableData, food_age: float = - 1.0) -> void :

	# Gourmet DLC eat hooks: Gourmet's permanent Appetite, Butcher's per-steak damage
	var dlc_character = RunData.get_player_character(player_index)
	if dlc_character != null:
		if dlc_character.my_id == "character_gourmet":
			var dlc_effects = RunData.get_player_effects(player_index)
			dlc_effects[Keys.gourmet_foods_eaten_hash] += 1
			if int(dlc_effects[Keys.gourmet_foods_eaten_hash]) % 10 == 0:
				RunData.add_stat(Keys.stat_appetite_hash, 1, player_index)
				RunData.add_tracked_value(player_index, dlc_character.get_my_id_hash(), 1)
				Utils.gourmet_tracker.ev("gourmet_app_gain", {"p": player_index})

			# Gourmet DLC - his fat stacks are driven by how much he has eaten, so reconcile
			# them here rather than waiting for the next wave to start. main.reconcile_gourmet_
			# _fat derives the target from the eaten counter and applies only the difference,
			# so calling it here AND at wave start cannot double-charge the Speed.
			var main_node = Utils.get_scene_node()
			if main_node != null and main_node.has_method("reconcile_gourmet_fat"):
				main_node.reconcile_gourmet_fat(player_index)
				set_body_scale(1.0 + main_node.GOURMET_FAT_SIZE * int(dlc_effects[Keys.gourmet_fat_hash]))
		elif dlc_character.my_id == "character_butcher":
			TempStats.add_stat(Keys.stat_percent_damage_hash, 1, player_index)
			RunData.add_tracked_value(player_index, dlc_character.get_my_id_hash(), 1)
			# Gourmet DLC - Butcher: this wave's temp Damage is exactly 1% per consumable, so
			# the running count IS the bonus. main.gd banks 20% of it as permanent Appetite at
			# wave end. The Player node is rebuilt each wave, so this self-resets.
			_butcher_wave_damage += 1

	# Gourmet DLC - foods route through the shared-timer buff engine (duck-typed by id prefix,
	# never by class name: see the cyclic-dependency law)
	if consumable_data.my_id.begins_with("consumable_food_"):
		# per-food eaten counter (shown on the spawner's card). The food's my_id is seeded
		# in RunData.init_tracked_items so add_tracked_value accepts it. All gumball
		# colours count into the ONE base-gumball total (the machine card shows a single
		# "Gumball eaten" line; colour hashes are deliberately unseeded).
		var eaten_hash: int = consumable_data.get_my_id_hash()
		if consumable_data.my_id.begins_with("consumable_food_gumball"):
			eaten_hash = Keys.generate_hash("consumable_food_gumball")
		RunData.add_tracked_value(player_index, eaten_hash, 1)
		_apply_food_buff(consumable_data, food_age)

	var consumable_stats_while_max_effect = RunData.get_player_effect(Keys.consumable_stats_while_max_hash, player_index)

	if consumable_stats_while_max_effect.size() > 0 and current_stats.health >= max_stats.health:
		var max_consumable_stats_gained_this_wave = RunData.max_consumable_stats_gained_this_wave[player_index]
		for i in consumable_stats_while_max_effect.size():
			var stat = consumable_stats_while_max_effect[i]
			
			var has_max = stat.size() > 2
			var reached_max = has_max and max_consumable_stats_gained_this_wave[i][2] >= stat[2]
			if not has_max or not reached_max:
				RunData.add_stat(stat[0], stat[1], player_index)
				assert (stat[0] is int)
				if stat[0] == Keys.stat_max_hp_hash:
					RunData.add_tracked_value(player_index, Keys.item_extra_stomach_hash, stat[1])
				if has_max:
					max_consumable_stats_gained_this_wave[i][2] += stat[1]

	
	var decaying_stats_on_consumable_effects = RunData.get_player_effect(Keys.decaying_stats_on_consumable_hash, player_index)
	for decaying_stats_on_consumable_effect in decaying_stats_on_consumable_effects:
		var decaying_stat_name = decaying_stats_on_consumable_effect[0]
		var decaying_stat_value = decaying_stats_on_consumable_effect[1]
		var decaying_stat_duration = decaying_stats_on_consumable_effect[2]
		_start_decaying_stats_effect_timer(_decaying_stats_on_consumable, decaying_stat_name, decaying_stat_value, decaying_stat_duration)

	
	if not cleaning_up and current_stats.health >= max_stats.health:
		var consumable_temp_stats_while_max_effect = RunData.get_player_effect(Keys.temp_consumable_stats_while_max_hash, player_index)
		for stat in consumable_temp_stats_while_max_effect:
			
			
			TempStats.add_stat(stat[0], stat[1], player_index)

		
		if not Utils.is_on_console():
			if player_index == 0 and consumable_data.my_id_hash == Keys.consumable_fruit_hash:
				ProgressData.increment_stat("fruit_eaten_full_hp")
				ChallengeService.try_complete_challenge(ChallengeService.chal_fruit_basket_hash, ProgressData.data.fruit_eaten_full_hp)

	if consumable_data.my_id_hash == Keys.consumable_fruit_hash or consumable_data.my_id_hash == Keys.consumable_poisoned_fruit_hash:
		var stats_on_fruit_effects = RunData.get_player_effect(Keys.stats_on_fruit_hash, player_index)
		var stat_changed = false
		for stats_on_fruit_effect in stats_on_fruit_effects:
			
			
			
			var stat_value = stats_on_fruit_effect[1]

			if Utils.get_chance_success(stats_on_fruit_effect[2] / 100.0):
				assert (stats_on_fruit_effect[0] is int)
				RunData.add_stat(stats_on_fruit_effect[0], stat_value, player_index)
				RunData.add_tracked_value(player_index, Keys.character_druid_hash, stat_value)
				stat_changed = true

		if stat_changed:
			LinkedStats.reset_player(player_index)

	var player_data = RunData.players_data[player_index]
	player_data.consumables_picked_up_this_run += 1
	ChallengeService.try_complete_challenge(ChallengeService.chal_hungry_hash, player_data.consumables_picked_up_this_run)
	if RunData.current_wave <= 20:
		ChallengeService.try_complete_challenge(ChallengeService.chal_herbalist_hash, player_data.consumables_picked_up_this_run)


# Show (or refresh) a HUD chip for an item buff. Mirrors _start_decaying_stats_effect_timer's
# behaviour: refreshing does NOT create a second timer, it resets the existing one, so the
# timeout that erases the chip is never ambiguous.
func _set_item_buff_chip(item_id: String, stacks: int, duration: float) -> void :
	if cleaning_up or dead:
		return

	if _item_buff_chips.has(item_id):
		var existing: Dictionary = _item_buff_chips[item_id]
		existing["stacks"] = stacks
		existing["timer"].time_left = duration
		return

	var icon = null
	var item_data = ItemService.get_item_from_id(Keys.generate_hash(item_id))
	if item_data != null:
		icon = item_data.icon

	var chip_timer: SceneTreeTimer = Utils.get_tree().create_timer(duration, false)
	_item_buff_chips[item_id] = {"icon": icon, "stacks": stacks, "timer": chip_timer, "base_duration": duration}
	var _err = chip_timer.connect("timeout", self, "_on_item_buff_chip_expired", [item_id])


func _on_item_buff_chip_expired(item_id: String) -> void :
	var _erased = _item_buff_chips.erase(item_id)


func _start_decaying_stats_effect_timer(stats_array: Array, stat_hash: int, stat_value: int, stat_duration: int) -> void :

	if cleaning_up:
		return

	
	for existing_stat in stats_array:
		if existing_stat["id"] == stat_hash and existing_stat["duration"] == stat_duration:
			
			existing_stat["timer"].time_left = stat_duration
			if existing_stat["value"] != stat_value:
				
				TempStats.remove_stat(stat_hash, existing_stat["value"], player_index)
				TempStats.add_stat(stat_hash, stat_value, player_index)
				existing_stat["value"] = stat_value
			return
	var timer: SceneTreeTimer = Utils.get_tree().create_timer(stat_duration, false)
	var stat_item: = {"id": stat_hash, "timer": timer, "value": stat_value, "duration": stat_duration}
	stats_array.push_back(stat_item)
	TempStats.add_stat(stat_hash, stat_value, player_index)
	LinkedStats.reset_player(player_index)
	var _error = timer.connect("timeout", self, "_on_decaying_stats_timer_timeout", [stat_item, stats_array])


func _on_decaying_stats_timer_timeout(stat_item: Dictionary, stats_array: Array) -> void :

	if cleaning_up:
		return

	TempStats.remove_stat(stat_item["id"], stat_item["value"], player_index)
	stats_array.erase(stat_item)
	LinkedStats.reset_player(player_index)


# Gourmet DLC - food buff engine. One buff instance per food type per player:
# magnitude stacks up while the timer is shared. Stack 2 extends the timer by
# 50% of base duration, stack 3 and beyond by 25% (the floor). Everything is
# percentage based so duration modifiers scale base AND extensions together.
# Fractional seconds round down. Buffs live in TempStats so they reset on wave end.
const FOOD_GOLDEN_APPLE_STATS: = ["stat_percent_damage", "stat_attack_speed", "stat_crit_chance", "stat_dodge", "stat_speed"]

func _apply_food_buff(food_data, food_age: float = - 1.0) -> void :

	if cleaning_up or dead:
		return

	var appetite: float = max(0.0, Utils.get_stat(Keys.stat_appetite_hash, player_index))
	var buff_character = RunData.get_player_character(player_index)
	var character_id: String = buff_character.my_id if buff_character != null else ""
	var buff_effects = RunData.get_player_effects(player_index)
	var strength_bonus: int = buff_effects[Keys.food_buff_strength_hash]

	# Picky Eater: his selected spawner's food is +100% stronger
	if character_id == "character_picky_eater" and buff_effects[Keys.selected_spawner_hash] == Keys.generate_hash(food_data.my_id):
		strength_bonus += 100

	# Wine Cellar: food that sat on the ground WINE_CELLAR_AGE_SECONDS+ grants a stronger
	# buff. Only counted when the food actually has a buff to strengthen, so the card
	# counter never ticks on pure heal/special foods.
	if food_age >= WINE_CELLAR_AGE_SECONDS and (food_data.buff_stats.size() > 0 or not food_data.wave_stats.empty()):
		var wine_cellar_bonus: int = int(buff_effects[Keys.wine_cellar_hash])
		if wine_cellar_bonus > 0:
			strength_bonus += wine_cellar_bonus
			RunData.add_tracked_value(player_index, Keys.generate_hash("item_wine_cellar"), 1)
			Utils.gourmet_tracker.ev("wine_cellar_aged", {"p": player_index, "f": food_data.my_id})

	# Sugar Rush: eating any food grants a short Speed burst (decaying-stat primitive)
	if buff_effects[Keys.food_speed_burst_hash] > 0:
		var sugar_copies: int = int(buff_effects[Keys.food_speed_burst_hash])
		var sugar_value: int = int((5.0 + 0.1 * appetite) * sugar_copies)
		_start_decaying_stats_effect_timer(_decaying_stats_on_consumable, Keys.stat_speed_hash, sugar_value, 2)
		# HUD chip so the burst is visible while it is running, beside the food buffs
		_set_item_buff_chip("item_sugar_rush", sugar_copies, 2.0)
		Utils.gourmet_tracker.count("sugar_bursts")

	# Mint ADDS a flat MINT_EXTEND_SECONDS to every active food buff and does nothing else.
	# It used to reset each timer to that food's BASE duration, which was a nerf the moment a
	# buff was stacked: three Pizza Slices run one shared timer well past a single slice's
	# base, so "refreshing" it cut the time left instead of restoring it.
	if food_data.special_id == "mint":
		Utils.gourmet_tracker.ev("mint_extend", {"p": player_index, "n": _food_buffs.size()})
		for active_buff in _food_buffs.values():
			# rest-of-wave buffs have no timer to extend - Mint leaves them untouched
			if active_buff.has("timer"):
				active_buff["timer"].time_left += MINT_EXTEND_SECONDS
		return

	# Mystery Meat: 50/50 between its buff and losing 2 HP (Cast-Iron Stomach removes the risk)
	if food_data.special_id == "mystery_meat" and buff_effects[Keys.mystery_meat_safe_hash] <= 0 and randf() < 0.5:
		Utils.gourmet_tracker.ev("mystery_bad", {"p": player_index})
		on_damage_effect(2, false, false)
		return

	# Snail easter egg: Escargot grants him +1 permanent Armor on top of the buff
	if food_data.special_id == "escargot" and character_id == "character_snail":
		RunData.add_stat(Keys.stat_armor_hash, 1, player_index)
		RunData.add_tracked_value(player_index, Keys.generate_hash("character_snail"), 1)
		Utils.gourmet_tracker.ev("escargot_snail", {"p": player_index})

	# Chicken Soup adds flat healing to every food; Gourmet cannot heal from
	# consumables and several items disable food healing outright
	var food_heal: int = int(food_data.heal_base + food_data.heal_app_ratio * appetite) + buff_effects[Keys.food_bonus_heal_hash]
	# Character rule (Gourmet: no healing from consumables) overrides item effects, so this same
	# block also gates Buffet Insurance below - a character rule beats an item rule.
	var consumable_heal_blocked: bool = character_id == "character_gourmet" or buff_effects[Keys.food_heal_disabled_hash] > 0 or buff_effects[Keys.consumables_no_heal_hash] > 0
	if consumable_heal_blocked:
		food_heal = 0
	if food_heal > 0:
		var _healed = on_healing_effect(food_heal, Keys.empty_hash)

	# Gourmet DLC - Buffet Insurance: eating a consumable while critically low (<20% HP) gives a
	# clutch heal - unless a character forbids consumable healing (that rule wins).
	if buff_effects[Keys.buffet_insurance_hash] > 0 and not consumable_heal_blocked and current_stats.health < max_stats.health * 0.2:
		var _clutch_heal = on_healing_effect(buff_effects[Keys.buffet_insurance_hash], Keys.generate_hash("item_buffet_insurance"))

	# Rest-of-wave stats: routed through a timerless food-buff entry so they show in the
	# HUD (icon + stack count, no timer) and honor the per-food stack cap, instead of a
	# silent TempStats add. Cleared with the wave (node teardown resets _food_buffs).
	if not food_data.wave_stats.empty():
		var wave_magnitudes: = []
		for wave_stat in food_data.wave_stats:
			var wave_stat_value: int = int(wave_stat[1] + wave_stat[2] * appetite)
			if strength_bonus != 0:
				wave_stat_value = int(wave_stat_value * (100.0 + strength_bonus) / 100.0)
			if wave_stat_value != 0:
				wave_magnitudes.push_back([Keys.generate_hash(wave_stat[0]), wave_stat_value])
		if not wave_magnitudes.empty():
			_grant_wave_buff_stack(food_data.my_id, wave_magnitudes, int(food_data.buff_stack_cap), food_data.icon)

	for permanent_stat in food_data.permanent_stats:
		# Gourmet DLC - Fried Egg scales its permanent grant with Appetite:
		# base * (1 + ratio * Appetite), rounded (Fruit Salad keeps ratio 0 = flat).
		var perm_amount: int = permanent_stat[1]
		if food_data.permanent_app_ratio > 0.0:
			var perm_app: float = max(0.0, Utils.get_stat(Keys.stat_appetite_hash, player_index))
			perm_amount = int(round(permanent_stat[1] * (1.0 + food_data.permanent_app_ratio * perm_app)))
		RunData.add_stat(Keys.generate_hash(permanent_stat[0]), perm_amount, player_index)
		if food_data.tracking_item_id != "":
			RunData.add_tracked_value(player_index, Keys.generate_hash(food_data.tracking_item_id), perm_amount)

	if food_data.buff_duration <= 0:
		return

	var magnitudes: = []
	var golden_stat: String = ""
	if food_data.special_id == "golden_apple":
		var random_stat: String = Utils.get_rand_element(FOOD_GOLDEN_APPLE_STATS)
		golden_stat = random_stat
		magnitudes.push_back([Keys.generate_hash(random_stat), 20])  # Gourmet DLC - Victory Feast / Golden Apple: +20 random stat
	elif food_data.special_id == "chili":
		# chili grants no stats: it is a timed window where attacks burn.
		# buff_stats[0] holds [_, flat_base, app_ratio] for the burn damage
		pass
	else:
		for buff_stat in food_data.buff_stats:
			magnitudes.push_back([Keys.generate_hash(buff_stat[0]), int(buff_stat[1] + buff_stat[2] * appetite)])

	if magnitudes.empty() and food_data.special_id != "chili":
		return

	# Slow Cooker / Sous-Vide / Preservatives add flat base seconds; MSG-style
	# strength multiplies magnitudes; both stack with everything else
	if strength_bonus != 0:
		for magnitude in magnitudes:
			magnitude[1] = int(magnitude[1] * (100.0 + strength_bonus) / 100.0)

	# Gourmet DLC - there is NO hidden multiplier here. A x1.5 used to be applied after this
	# line, which meant every card that printed a duration understated it by 50%; the 1.5 is
	# baked into the authored buff_duration values instead, so the number on the card and the
	# number used here are the same number. Do not reintroduce a blanket multiplier.
	var base_duration: float = (food_data.buff_duration + food_data.duration_app_ratio * appetite + buff_effects[Keys.food_buff_duration_hash]) * (1.0 + appetite * 0.01)

	if character_id == "character_comp_eater":
		for magnitude in magnitudes:
			magnitude[1] *= 2
		base_duration *= 0.5

	# Gourmet DLC - Soul Food: every 20th consecutive stat-buff food buff becomes
	# permanent. Each buff first risks a FLAT 3% permanently-negative flip, which also
	# resets the streak. This was (5 - 0.1 x Luck)% until 2026-07-28, but it floored at
	# 0 so any build with 50+ Luck deleted the downside outright; the risk is now a flat
	# rate no stat can scale away, and it does NOT scale with copies owned (same as the
	# old chance). SOUL_FLIP_PCT below must stay in sync with soul_food_effect_1.tres's
	# value, which is what the card renders into EFFECT_SOUL_FOOD_RISK's {0}.
	# Only stat-buff foods count: chili and wave-stat foods never reach here with
	# magnitudes, Mint returned earlier. A consumed buff (banked or flipped) skips the
	# temp-buff grant and the Ruminant echo.
	if buff_effects[Keys.soul_food_hash] > 0 and not magnitudes.empty():
		var soul_flip_chance: float = SOUL_FLIP_PCT / 100.0
		if randf() < soul_flip_chance:
			var soul_flipped: int = 0
			for magnitude in magnitudes:
				RunData.add_stat(magnitude[0], -magnitude[1], player_index)
				soul_flipped += magnitude[1]
			buff_effects[Keys.soul_food_streak_hash] = 0
			RunData.add_tracked_value(player_index, Keys.generate_hash("item_soul_food"), soul_flipped, 1)
			Utils.gourmet_tracker.ev("soul_food_negative", {"p": player_index, "f": food_data.my_id, "v": soul_flipped})
			return
		buff_effects[Keys.soul_food_streak_hash] = int(buff_effects[Keys.soul_food_streak_hash]) + 1
		if buff_effects[Keys.soul_food_streak_hash] >= 20:
			buff_effects[Keys.soul_food_streak_hash] = 0
			var soul_banked: int = 0
			for magnitude in magnitudes:
				RunData.add_stat(magnitude[0], magnitude[1], player_index)
				soul_banked += magnitude[1]
			RunData.add_tracked_value(player_index, Keys.generate_hash("item_soul_food"), soul_banked, 0)
			Utils.gourmet_tracker.ev("soul_food_permanent", {"p": player_index, "f": food_data.my_id, "v": soul_banked})
			return

	_grant_food_buff_stack(food_data.my_id, magnitudes, base_duration, food_data.buff_stacks, food_data.buff_total_cap, int(food_data.buff_stack_cap), food_data.icon)

	if food_data.special_id == "chili" and _food_buffs.has(food_data.my_id) and food_data.buff_stats.size() > 0:
		var chili_damage: int = int(food_data.buff_stats[0][1] + food_data.buff_stats[0][2] * appetite)
		if strength_bonus != 0:
			chili_damage = int(chili_damage * (100.0 + strength_bonus) / 100.0)
		_food_buffs[food_data.my_id]["burn_damage"] = chili_damage

	# Gourmet DLC - telemetry: log the exact numbers this eat produced
	if _food_buffs.has(food_data.my_id):
		var logged_buff: Dictionary = _food_buffs[food_data.my_id]
		var logged_vals: = []
		for logged_mag in magnitudes:
			logged_vals.push_back(logged_mag[1])
		Utils.gourmet_tracker.ev("buff_apply", {"f": food_data.my_id, "p": player_index,
			"app": stepify(appetite, 0.1), "str": strength_bonus,
			"comp": character_id == "character_comp_eater", "vals": logged_vals,
			"stacks": logged_buff["stacks"], "tl": stepify(logged_buff["timer"].time_left, 0.1),
			"burn": logged_buff.get("burn_damage", 0), "gold": golden_stat})

	# Ruminant chews twice: the same buff lands again at 50% strength 5 seconds later
	# (Mint's refresh is exempt by balance law, special_id "mint")
	if character_id == "character_ruminant":
		_schedule_ruminant_echo(food_data.my_id, magnitudes, food_data.buff_total_cap, int(food_data.buff_stack_cap), 2)


# magnitudes: array of [stat_hash, value] applied together as one stack
func _grant_food_buff_stack(food_id: String, magnitudes: Array, base_duration: float, stacks: bool, total_cap: int, stack_cap: int = 20, icon: Texture = null) -> void :

	if cleaning_up or dead:
		return

	if _food_buffs.has(food_id):
		var buff: Dictionary = _food_buffs[food_id]
		# Defensive: a food is either timed OR rest-of-wave, never both. If a timerless
		# (wave) entry already holds this id, don't reach for a timer it does not have.
		if not buff.has("timer"):
			return
		if not stacks:
			buff["timer"].time_left = max(buff["timer"].time_left, buff["base_duration"])
			return
		# At the stack-count cap: extend the shared timer only - no more magnitude and no
		# stack growth (user rule: eating at max stack refreshes the timer, nothing else).
		# Elastic Waistband raises every food's cap; the card's max-stacks line reads the
		# same bonus (item_description.gd) so the shown cap always matches this gate.
		if buff["stacks"] >= stack_cap + int(RunData.get_player_effect(Keys.food_stack_cap_bonus_hash, player_index)):
			buff["timer"].time_left += floor(base_duration * 0.25)
			return
		buff["stacks"] += 1
		var extension_ratio: float = 0.5 if buff["stacks"] == 2 else 0.25
		buff["timer"].time_left += floor(base_duration * extension_ratio)
		_food_buff_add_magnitudes(buff, magnitudes, total_cap)
	else:
		var floored_duration: float = floor(base_duration)
		var timer: SceneTreeTimer = Utils.get_tree().create_timer(floored_duration, false)
		var buff: = {"stacks": 1, "applied": {}, "timer": timer, "base_duration": floored_duration, "icon": icon}
		_food_buffs[food_id] = buff
		_food_buff_add_magnitudes(buff, magnitudes, total_cap)
		var _error = timer.connect("timeout", self, "_on_food_buff_expired", [food_id])

	# Gourmet DLC - Competitive Eater momentum: every buff actually gained feeds his
	# wave-scoped ramp (all no-gain paths returned above, so the card line stays true)
	var _bchar = RunData.get_player_character(player_index)
	if _bchar != null and _bchar.my_id == "character_comp_eater":
		_gain_comp_momentum()

	_update_food_buff_bonuses()
	LinkedStats.reset_player(player_index)


# Gourmet DLC - rest-of-wave food buff: like _grant_food_buff_stack but with NO "timer"
# key, so it persists until wave end (node teardown clears _food_buffs) and renders in the
# HUD as a timerless chip (icon + stack count, no seconds). Stacks up to stack_cap; at the
# cap eating it again is a no-op (there is no timer to extend). Magnitudes live in TempStats
# and are cleared by the wave-start TempStats.reset. Readers that touch buff["timer"] must
# guard with buff.has("timer") (food_buffs_display.gd, unit.gd extend_buffs_on_hit).
func _grant_wave_buff_stack(food_id: String, magnitudes: Array, stack_cap: int, icon: Texture = null) -> void :

	if cleaning_up or dead:
		return

	if _food_buffs.has(food_id):
		var buff: Dictionary = _food_buffs[food_id]
		# Elastic Waistband raises the cap here exactly like the timed gate above
		if buff["stacks"] >= stack_cap + int(RunData.get_player_effect(Keys.food_stack_cap_bonus_hash, player_index)):
			return
		buff["stacks"] += 1
		_food_buff_add_magnitudes(buff, magnitudes, 0)
	else:
		var buff: = {"stacks": 1, "applied": {}, "base_duration": 0.0, "icon": icon}
		_food_buffs[food_id] = buff
		_food_buff_add_magnitudes(buff, magnitudes, 0)

	# Gourmet DLC - Competitive Eater momentum (wave buffs count too; capped
	# re-eats returned above and grant nothing)
	var _wchar = RunData.get_player_character(player_index)
	if _wchar != null and _wchar.my_id == "character_comp_eater":
		_gain_comp_momentum()

	_update_food_buff_bonuses()
	LinkedStats.reset_player(player_index)


# Gourmet DLC - Competitive Eater: +5% Speed and +5% Pickup Range per food buff
# gained, until the end of the wave. Speed lives in TempStats (wave-start reset
# clears it); the pickup bonus rides _comp_momentum_stacks on this wave-fresh node.
func _gain_comp_momentum() -> void :
	_comp_momentum_stacks += 1
	RunData.add_tracked_value(player_index, Keys.generate_hash("character_comp_eater"), 1)
	TempStats.add_stat(Keys.stat_speed_hash, 5, player_index)
	var momentum_pickup: int = int(RunData.get_player_effect(Keys.pickup_range_hash, player_index))
	_item_attract_area.apply_pickup_range_effect(momentum_pickup + 5 * _comp_momentum_stacks)
	Utils.gourmet_tracker.count("comp_momentum")


func _food_buff_add_magnitudes(buff: Dictionary, magnitudes: Array, total_cap: int) -> void :
	for magnitude in magnitudes:
		var stat_hash: int = magnitude[0]
		var value: int = magnitude[1]
		var already_applied: int = buff["applied"].get(stat_hash, 0)
		if total_cap > 0:
			value = int(min(value, max(0, total_cap - already_applied)))
		if value <= 0:
			continue
		TempStats.add_stat(stat_hash, value, player_index)
		buff["applied"][stat_hash] = already_applied + value


func _on_food_buff_expired(food_id: String) -> void :

	if cleaning_up:
		return

	if not _food_buffs.has(food_id):
		return

	var buff: Dictionary = _food_buffs[food_id]
	var removed_total: = 0
	for stat_hash in buff["applied"]:
		TempStats.remove_stat(stat_hash, buff["applied"][stat_hash], player_index)
		removed_total += buff["applied"][stat_hash]
	Utils.gourmet_tracker.ev("buff_expire", {"f": food_id, "p": player_index, "stacks": buff["stacks"], "removed": removed_total})
	_food_buffs.erase(food_id)
	_update_food_buff_bonuses()
	LinkedStats.reset_player(player_index)


# Gourmet DLC - Full Belly (+Armor while any food buff is active) and Food Coma
# (+15% Damage / -10% Speed while 5 or more distinct food buffs are active)
func _update_food_buff_bonuses() -> void :
	var buff_count: int = _food_buffs.size()
	var bonus_effects = RunData.get_player_effects(player_index)

	var wanted_belly: int = bonus_effects[Keys.full_belly_hash] if buff_count > 0 else 0
	if wanted_belly != _full_belly_applied:
		TempStats.add_stat(Keys.stat_armor_hash, wanted_belly - _full_belly_applied, player_index)
		_full_belly_applied = wanted_belly
		Utils.gourmet_tracker.ev("belly", {"p": player_index, "a": wanted_belly})

	var wanted_coma: bool = buff_count >= 5 and bonus_effects[Keys.food_coma_hash] > 0
	if wanted_coma != _food_coma_active:
		var coma_sign: int = 1 if wanted_coma else - 1
		TempStats.add_stat(Keys.stat_percent_damage_hash, 20 * coma_sign, player_index)  # Gourmet DLC - Food Coma: +20% Damage (no speed penalty)
		_food_coma_active = wanted_coma
		Utils.gourmet_tracker.ev("coma", {"p": player_index, "on": wanted_coma})

	# Picky Eater: -15% Damage while no food buff is active
	var picky_bonus_char = RunData.get_player_character(player_index)
	if picky_bonus_char != null and picky_bonus_char.my_id == "character_picky_eater":
		var wanted_penalty: bool = buff_count == 0
		if wanted_penalty != _picky_penalty_active:
			var penalty_sign: int = 1 if wanted_penalty else - 1
			TempStats.add_stat(Keys.stat_percent_damage_hash, - 15 * penalty_sign, player_index)
			_picky_penalty_active = wanted_penalty


# Gourmet DLC - Ruminant: the echo is PURE MAGNITUDE. It adds half-strength stats to the
# buff that is already running and never touches the shared timer, never spends a stack and
# never creates a buff of its own - "chews twice" is about strength, not uptime. Each echo
# then has a chance to chew again for half as much, up to RUMINANT_MAX_CHEWS total mouthfuls.
const RUMINANT_ECHO_DELAY: = 5.0
const RUMINANT_ECHO_CHAIN_CHANCE: = 0.25
const RUMINANT_MAX_CHEWS: = 4  # the eat itself is chew 1, so at most 3 echoes

func _schedule_ruminant_echo(food_id: String, magnitudes: Array, total_cap: int, stack_cap: int, chew: int) -> void :
	if chew > RUMINANT_MAX_CHEWS:
		return
	var echo_magnitudes: = []
	for magnitude in magnitudes:
		var halved: int = int(magnitude[1] / 2.0)
		if halved > 0:
			echo_magnitudes.push_back([magnitude[0], halved])
	if echo_magnitudes.empty():
		return
	var echo_timer: SceneTreeTimer = Utils.get_tree().create_timer(RUMINANT_ECHO_DELAY, false)
	var _error = echo_timer.connect("timeout", self, "_on_ruminant_echo_timeout", [food_id, echo_magnitudes, total_cap, stack_cap, chew])


func _on_ruminant_echo_timeout(food_id: String, magnitudes: Array, total_cap: int, stack_cap: int, chew: int) -> void :

	if cleaning_up or dead:
		return

	# the buff has to still be running - an echo never revives an expired one
	if not _food_buffs.has(food_id):
		return
	var buff: Dictionary = _food_buffs[food_id]
	if not buff.has("timer"):
		return
	# Gated on the same stack cap as a real eat (without consuming a stack), so eating at
	# max stacks - which grants no magnitude - cannot be farmed for free echo magnitude.
	if buff["stacks"] >= stack_cap + int(RunData.get_player_effect(Keys.food_stack_cap_bonus_hash, player_index)):
		return

	_food_buff_add_magnitudes(buff, magnitudes, total_cap)
	_update_food_buff_bonuses()
	LinkedStats.reset_player(player_index)
	RunData.add_tracked_value(player_index, Keys.generate_hash("character_ruminant"), 1)
	Utils.gourmet_tracker.count("ruminant_echoes")

	if randf() < RUMINANT_ECHO_CHAIN_CHANCE:
		_schedule_ruminant_echo(food_id, magnitudes, total_cap, stack_cap, chew + 1)


func _attract_nearby_consumables() -> void :
	if not _item_attract_area.monitoring: return

	for area in _item_attract_area.get_overlapping_areas():
		if not area is Consumable:
			continue

		if area.attracted_by == null and area.consumable_data and area.consumable_data.my_id_hash != Keys.consumable_poisoned_fruit_hash:
			area.attracted_by = self
			area.set_physics_process(true)


# Gourmet DLC - foods sit in the attract area like any consumable, but the Pickup Range
# stat only counts for 20% of its usual effect on them: food always magnets from the base
# radius, and stacking Pickup Range widens that at a fifth of the rate materials get.
# Derived from the area's live radius (not the raw stat) so the Competitive Eater's
# momentum bonus, which is written straight into the shape, feeds food pickup too:
#   area   = BASE * (1 + range/100)
#   food   = BASE * (1 + 0.2 * range/100) = BASE * 0.8 + area * 0.2
# Capped at the area radius so a negative Pickup Range can't make food out-reach gold.
const FOOD_PICKUP_RANGE_FACTOR: = 0.2

func _attract_nearby_foods() -> void :
	if dead or not _item_attract_area.monitoring:
		return

	var area_radius: float = _item_attract_area.get_node("CollisionShape2D").shape.radius
	var attract_radius: float = min(area_radius,
		ItemAttractArea.BASE_RADIUS * (1.0 - FOOD_PICKUP_RANGE_FACTOR) + area_radius * FOOD_PICKUP_RANGE_FACTOR)
	var attract_dist_sq: float = attract_radius * attract_radius

	for area in _item_attract_area.get_overlapping_areas():
		if not area is Consumable:
			continue
		if area.attracted_by != null or area.consumable_data == null:
			continue
		if not area.consumable_data.my_id.begins_with("consumable_food_"):
			continue
		if global_position.distance_squared_to(area.global_position) <= attract_dist_sq:
			area.attracted_by = self
			area.set_physics_process(true)


func _on_ItemAttractArea_area_entered(item: Item) -> void :
	var is_heal: = item is Consumable and (item as Consumable).has_healing_effect()
	var is_gold: = not item is Consumable
	var should_attract_item: = (is_heal and current_stats.health < max_stats.health) or is_gold
	if not should_attract_item:
		return

	if should_attract_item and item.attracted_by == null:
		item.attracted_by = self
		item.set_physics_process(true)
	
	if is_gold and global_position.distance_squared_to(item.global_position) < global_position.distance_squared_to(item.attracted_by.global_position):
		item.attracted_by = self
		item.set_physics_process(true)


func _on_ItemPickupArea_area_entered(area: Area2D) -> void :
	
	if area.attracted_by == null or area.attracted_by == self:
		area.pickup(player_index)


func _on_MovingTimer_timeout() -> void :
	assert ( not dead)
	handle_gold_stat(Keys.temp_stats_while_moving_hash)


func _on_NotMovingTimer_timeout() -> void :
	assert ( not dead)
	handle_gold_stat(Keys.temp_stats_while_not_moving_hash)


func handle_gold_stat(effect_key: int) -> void :
	for temp_stat in RunData.get_player_effect(effect_key, player_index):
		assert (temp_stat[0] is int)
		if temp_stat[0] == Keys.percent_materials_hash:
			var pct = temp_stat[1] / 100.0
			var val = pct * RunData.get_player_gold(player_index)
			var actual_val = max(1, abs(val))

			
			if temp_stat.size() >= 2:
				actual_val = min(actual_val, temp_stat[2])

			if val < 0.0:
				RunData.remove_gold(actual_val, player_index)
				RunData.emit_signal("stat_removed", Keys.stat_materials_hash, actual_val, - 15.0, player_index)
			else:
				RunData.add_gold(actual_val, player_index)
				RunData.emit_signal("stat_added", Keys.stat_materials_hash, actual_val, - 15.0, player_index)


func life_bar_effects() -> Dictionary:
	return {"hit_protection": _hit_protection}


func _on_OneSecondTimer_timeout() -> void :
	_one_second_timeouts += 1

	var effect: Array = RunData.get_player_effect(Keys.temp_stats_per_interval_hash, player_index)
	for sub_effect in effect:
		assert (sub_effect[0] is int)
		var stat_key: int = sub_effect[0]
		var value: int = sub_effect[1]
		var interval: int = sub_effect[2]
		var reset_on_hit: bool = sub_effect[3]

		if _one_second_timeouts % interval == 0:
			TempStats.add_stat(stat_key, value, player_index)

			if reset_on_hit == true:
				if _remove_temp_stats_on_hit.has(stat_key):
					_remove_temp_stats_on_hit[stat_key] += value
				else:
					_remove_temp_stats_on_hit[stat_key] = value


func _set_outlines(alpha: float = 1.0, desaturation: float = 0.0) -> void :
	._set_outlines(alpha, desaturation)
	for leg in _legs.get_children():
		var leg_sprite: Sprite = leg.get_node("Sprite")
		leg_sprite.material = sprite.material


func boost(boost_args: BoostArgs) -> void :
	if not can_be_boosted:
		return

	.boost(boost_args)
	_original_boost_args = boost_args
	_max_hp_before_boost = max_stats.health
	var health_increase: = int(max_stats.health * (boost_args.hp_boost / 100.0))
	TempStats.add_stat(Keys.stat_max_hp_hash, health_increase, player_index)
	current_stats.health += health_increase
	TempStats.add_stat(Keys.stat_speed_hash, boost_args.speed_boost, player_index)
	TempStats.add_stat(Keys.stat_attack_speed_hash, boost_args.attack_speed_boost, player_index)

	_boost_timer.start()


func boost_ended() -> void :
	.boost_ended()

	if cleaning_up:
		return

	TempStats.remove_stat(Keys.stat_max_hp_hash, max_stats.health - _max_hp_before_boost, player_index)
	if current_stats.health > Utils.get_stat(Keys.stat_max_hp_hash, player_index):
		current_stats.health = int(Utils.get_stat(Keys.stat_max_hp_hash, player_index))
	TempStats.remove_stat(Keys.stat_speed_hash, _original_boost_args.speed_boost, player_index)
	TempStats.remove_stat(Keys.stat_attack_speed_hash, _original_boost_args.attack_speed_boost, player_index)


func _on_BoostTimer_timeout() -> void :
	if not dead:
		boost_ended()


func run_won_screen() -> void :
	emit_signal("run_won_screen")
