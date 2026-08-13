class_name Main
extends Node

signal gold_spawned()

export (PackedScene) var gold_bag_scene: PackedScene
export (PackedScene) var gold_scene: PackedScene
export (PackedScene) var consumable_scene: PackedScene
export (Resource) var turret_effect: Resource
export (Resource) var landmines_effect: Resource
export (Array) var gold_sprites: Array
export (Array, Resource) var gold_pickup_sounds: Array
export (Array, Resource) var gold_alt_pickup_sounds: Array
export (Resource) var level_up_sound: Resource
export (Array, Resource) var run_won_sounds: Array
export (Array, Resource) var run_lost_sounds: Array
export (Array, Resource) var end_wave_sounds: Array
export (PackedScene) var mimic_scene: PackedScene


const EDGE_SIZE = 96
const MAX_GOLDS = 50
const MIN_GOLD_CHANCE = 0.5
const MIN_MAP_SIZE = 12

const CROSSHAIR_DIST_FROM_PLAYER_MANUAL_AIM = 200

var _cleaning_up: = false
var _active_golds: = []
var _consumables: = []
var _upgrades_to_process: = [[], [], [], []]
var _consumables_to_process: = [[], [], [], []]

# Gourmet DLC - food spawner trigger state (thresholds filled in _ready)
# Ground foods rot after FOOD_EXPIRY_SECONDS (blinking near the end); a
# Dishwasher in the run halves that. Expired food feeds Doggy Bag's Leftovers.
const FOOD_EXPIRY_SECONDS: = 15.0
const FOOD_EXPIRY_BLINK_SECONDS: = 3.0
const SLIME_TRAIL_LIFETIME: = 7.5  # was 2.5 - Slug trail lingers 3x as long
const SLIME_TRAIL_RADIUS: = 45.0   # base slow radius at level 0 (scales with level below)
const SLIME_TRAIL_SLOW: = 30       # base slow % at level 0 (scales with level below)
# Slug trail scales with the player's current level:
const SLIME_TRAIL_BASE_WIDTH: = 26.0     # visual width at level 0
const SLIME_TRAIL_SIZE_PER_LEVEL: = 0.06 # +6% trail width & slow radius per level
const SLIME_TRAIL_SLOW_PER_LEVEL: = 2    # +2 slow-% per level
const SLIME_TRAIL_SLOW_MAX: = 90         # cap so enemies never fully freeze / reverse
# Gourmet DLC - Slug: "slimed", a corrosive tick applied by standing in the trail. It is a
# separate status from burning and is dealt as plain damage rather than through BurningData,
# so an enemy can be burning AND slimed at once and take both. Deliberately small: it is a
# constant drip on everything walking through, not a damage source you build around.
# Card mirror: effect.gd EFFECT_SLUG_SLIME renders int(base + ratio x Elemental Damage).
const SLIME_DAMAGE_BASE: = 1.0
const SLIME_DAMAGE_ELEMENTAL_RATIO: = 0.15
const SLIME_DAMAGE_TICK: = 0.5           # seconds between ticks, tracked per enemy
const SLIME_META: = "gourmet_slime_next_tick"  # per-enemy next-tick stamp
# Gourmet DLC - Butcher: share of the wave's temp Damage % that is banked as permanent
# Appetite when the wave ends. Card mirror: EFFECT_BUTCHER_RENDER in build_pantry_items.py.
const BUTCHER_APPETITE_SHARE: = 0.2
# Gourmet DLC - Tourist: XP Gain swing, negative on every Danger except 0 where it is
# positive. Card mirror: EFFECT_TOURIST_XP in build_pantry_items.py.
const TOURIST_XP_GAIN: = 15
# Gourmet DLC - Gourmet fattens up as the run goes: every wave costs him 3% Speed and
# makes his body 1% bigger, compounding all run. Scaling the Player node grows the sprite,
# the hurtbox (a bigger target - the real cost), both pickup areas and the weapon orbit
# in one move. Card mirror: EFFECT_GOURMET_FAT in build_pantry_items.py.
const GOURMET_FAT_SPEED: = 3
const GOURMET_FAT_SIZE: = 0.02
# Size is capped at +80%, so 40 stacks. The speed penalty rides the same stack count and is
# therefore capped with it, at -120% Speed modifications at full size.
const GOURMET_FAT_MAX_STACKS: = 40
const GOURMET_FAT_PER_FOODS: = 50
# Gourmet DLC - Street Vendor servings per wave, per copy owned. Flat by design: the card
# prints these two numbers and nothing shifts them. Card mirror: EFFECT_STREET_VENDOR.
const STREET_VENDOR_MIN_SERVINGS: = 3
const STREET_VENDOR_MAX_SERVINGS: = 6
var _food_trigger_thresholds: = {}
var _chili_burning_data: = [null, null, null, null]
# per player: food_id_hash -> ARRAY of its anchor structures (foods pop out of these). One
# entry per stand actually standing on the map, so owning three carts gives three real
# dispensing points instead of three servings out of whichever one registered last.
var _food_structures: = [{}, {}, {}, {}]
var _food_fasting_counters: = [0, 0, 0, 0]
# Gourmet DLC - Gourmet: whether his once-per-wave doubled food has already been served.
# main is rebuilt per wave, so this self-resets.
var _gourmet_first_food_done: = [false, false, false, false]
var _ate_food_this_wave: = [false, false, false, false]
var _static_cling_counters: = [0, 0, 0, 0]
var _space_heater_applied: = [0, 0, 0, 0]
var _slime_trail_points: = []
var _slime_trail_line: Line2D = null
var _snail_player_index: = - 1
var _food_trigger_counters: = [{}, {}, {}, {}]
var _food_trigger_cooldowns: = [{}, {}, {}, {}]
var _food_timer_accums: = [{}, {}, {}, {}]
var _food_scheduled_spawns: = [[], [], [], []]
var _food_prev_steps: = [0, 0, 0, 0]
var _food_prev_positions: = [null, null, null, null]
var _food_wave_time: = 0.0

var _end_wave_timer_timedout: = false

var _players: = []
var _next_gold_player: int
var _players_ui: = []
var _things_to_process_player_containers: = []

var _is_run_lost: bool
var _is_wave_failed: bool
var _is_run_won: bool
var _gold_bag: Node

var _is_chal_ui_displayed = false

var _proj_on_death_stat_caches: = [null, null, null, null]
var _items_spawned_this_wave: = 0
var _player_is_under_half_health: = [false, false, false, false]

var _is_horde_wave: = false
var _is_elite_wave: = false
var _is_fog_wave: = false
var _is_bullet_hell_wave: = false

var _elite_killed_bonus: = 0
var override_gold_bag_pos: = Vector2.ZERO

var _pool: = {}
var _pool_parent: = {}
var _skip_pause_check = false
var _crosshair_cursor_active: = false
var _current_pool_id: int = Keys.empty_hash
var _current_pool = null

var _spawn_projectile_args: = WeaponServiceSpawnProjectileArgs.new()
var _take_damage_args: = TakeDamageArgs.new( - 1)

onready var _entities_container: YSort = $"%Entities"
onready var _entity_spawner = $EntitySpawner
onready var _effects_manager = $EffectsManager
onready var _stats_manager = $"%StatsManager"
onready var _wave_manager = $WaveManager
onready var _floating_text_manager = $FloatingTextManager
onready var _effect_behaviors: = $EffectBehaviors
onready var _camera: MyCamera = $Camera
onready var _screenshaker = $Camera / Screenshaker
onready var _materials_container: Node2D = $"%Materials"
onready var _consumables_container: Node2D = $"%Consumables"
onready var _births_container: Node2D = $"%Births"
onready var _pause_menu = $UI / PauseMenu
onready var _end_wave_timer = $EndWaveTimer
onready var _upgrades_ui: UpgradesUI = $UI / UpgradesUI
onready var _coop_upgrades_ui: UpgradesUI = $UI / CoopUpgradesUI
onready var _wave_timer = $WaveTimer

onready var _wave_cleared_label = $UI / WaveClearedLabel
onready var _hud = $UI / HUD
onready var _ui_bonus_gold = $UI / HUD / LifeContainerP1 / UIBonusGold
onready var _ui_bonus_gold_pos = $UI / HUD / LifeContainerP1 / UIBonusGold / Position2D
onready var _current_wave_label = $UI / HUD / WaveContainer / CurrentWaveLabel
onready var _wave_timer_label = $UI / HUD / WaveContainer / WaveTimerLabel
onready var _ui_wave_container = $UI / HUD / WaveContainer
onready var _ui_things_to_process_margin_container: MarginContainer = $"%ThingsToProcessMarginContainer"
onready var _ui_dim_screen = $UI / DimScreen
onready var _tile_map = $TileMap
onready var _tile_map_limits = $"%TileMapLimits"
onready var _background = $CanvasLayer / Background
onready var _harvesting_timer = $HarvestingTimer
onready var _challenge_completed_ui = $UI / ChallengeCompletedUI
onready var _retry_wave = $UI / RetryWave

onready var _damage_vignette = $UI / DamageVignette
onready var _info_popup = $UI / InfoPopup
onready var _fps_label = $"%FPSLabel"
onready var _explosions: Node2D = $"Explosions"
onready var _effects: Node2D = $"Effects"
onready var _floating_texts: Node2D = $"%FloatingTexts"
onready var _player_projectiles: Node2D = $"%PlayerProjectiles"
onready var _enemy_projectiles: Node2D = $"%EnemyProjectiles"
onready var _half_second_timers: Node2D = $"%HalfSecondTimers"
onready var _crosshair: Sprite = $"%Crosshair"
onready var _fog_viewport: FogViewport = $"%fog_viewport"

signal end_of_the_wave
var _consumable_pool_id: int = Keys.empty_hash
var _gold_pool_id: int = Keys.empty_hash


func _ready() -> void :
	# Gourmet DLC - Butcher meat reskin (fruit/tree items show as meat)
	ButcherSkin.apply()
	if DebugService.display_fps:
		_fps_label.show()

	# Gourmet DLC - events needed per food spawn for each counter-based trigger
	_food_trigger_thresholds = {
		Keys.kill_foods_hash: 40,
		Keys.burning_kill_foods_hash: 8,
		Keys.crit_foods_hash: 12,
		Keys.burning_tick_foods_hash: 10,
		Keys.explosion_foods_hash: 1,
		Keys.material_foods_hash: 30,
		Keys.level_up_foods_hash: 1,
		Keys.damage_taken_foods_hash: 1,
		Keys.elite_kill_foods_hash: 1,
		Keys.consumable_count_foods_hash: 8,
		Keys.step_foods_hash: 180,
		Keys.close_kill_foods_hash: 15,
		Keys.far_kill_foods_hash: 15,
		Keys.turret_kill_foods_hash: 5,
	}

	if consumable_scene != null:
		_consumable_pool_id = Keys.generate_hash(consumable_scene.resource_path)

	if gold_scene != null:
		_gold_pool_id = Keys.generate_hash(gold_scene.resource_path)

	var _e = _entity_spawner.connect("players_spawned", self, "_on_EntitySpawner_players_spawned")

	MusicManager.tween(0)
	_pause_menu.enabled = true
	_updatehidingHUD()

	RunData.on_wave_start(_wave_timer)
	_next_gold_player = Utils.randi() % RunData.get_player_count()

	var _popup = _challenge_completed_ui.connect("started", self, "on_chal_popup")
	var _popout = _challenge_completed_ui.connect("finished", self, "on_chal_popout")

	_background.texture.gradient.colors[1] = ItemService.get_background_gradient_color()
	_tile_map.tile_set.tile_set_texture(0, RunData.get_background().get_tiles_sprite())
	_tile_map.outline.modulate = RunData.get_background().outline_color

	TempStats.reset()

	# Gourmet DLC - The Special: apply this wave's modifiers FIRST, before anything samples the
	# effects dict. Everything below reads it: the zone sizing (map_size), the wave timer
	# (special_wave_duration), the fog / bullet-hell gates (special_force_*), and the entity
	# spawner (player max_stats, enemy factors). Applying at the old, later position silently
	# no-opped every modifier consumed before it - map_size was read ~90 lines earlier, which
	# is exactly how Walk-In Freezer and Banquet Hall shipped dead. The ids were rolled and
	# stored at the END of the previous wave, so what the shop previewed is exactly what lands,
	# and a mid-wave reload re-applies rather than re-rolls. Applying before the players spawn
	# also keeps current health under a reduced max and avoids the stats_manager Nil flush
	# crash documented on the original block.
	for special_index in RunData.get_player_count():
		if not RunData.is_special(special_index):
			continue
		var sp_pending: Array = SpecialModifiers.stored_ids(Keys.special_next_mods_hash, special_index)
		if sp_pending.empty():
			continue
		var sp_effects: Dictionary = RunData.get_player_effects(special_index)
		sp_effects[Keys.special_active_mods_hash] = sp_pending.duplicate()
		sp_effects[Keys.special_next_mods_hash] = []
		SpecialModifiers.apply_ids(SpecialModifiers.ids_of_life(sp_pending, SpecialModifiers.LIFE_WAVE), special_index)

	var _stats = RunData.connect("stats_updated", self, "on_stats_updated")

	_gold_bag = Utils.instance_scene_on_main(gold_bag_scene, get_gold_bag_pos())
	var current_zone = ZoneService.get_zone_data(RunData.current_zone).duplicate()
	var current_wave_data = ZoneService.get_wave_data(RunData.current_zone, RunData.current_wave)

	var map_size_coef = (1 + (RunData.sum_all_player_effects(Keys.map_size_hash) / 100.0))
	current_zone.width = max(MIN_MAP_SIZE, (current_zone.width * map_size_coef)) as int
	current_zone.height = max(MIN_MAP_SIZE, (current_zone.height * map_size_coef)) as int

	ZoneService.set_current_zone(current_zone)
	_tile_map.init(current_zone)
	_tile_map_limits.init(current_zone)

	_current_wave_label.text = Text.text("WAVE", [str(RunData.current_wave)]).to_upper()

	_wave_timer.wait_time = 1 if RunData.instant_waves else current_wave_data.wave_duration

	# Gourmet DLC - Wildcard (Overtime / Blitz): stretch or shrink the wave by a percent.
	# Skipped for instant waves; the debug override below still wins. Floored so a stacked
	# negative can never produce a zero/negative timer.
	# Plain `var x =`, never `var x: =` - sum_all_player_effects has no declared return type,
	# so the inferring form is a PARSE error in Godot 3 and takes all of main.gd down with it.
	var special_wave_duration = RunData.sum_all_player_effects(Keys.special_wave_duration_hash)
	if special_wave_duration != 0 and not RunData.instant_waves:
		_wave_timer.wait_time = max(10.0, _wave_timer.wait_time * (1.0 + special_wave_duration / 100.0))

	if DebugService.custom_wave_duration != - 1:
		_wave_timer.wait_time = DebugService.custom_wave_duration

	_wave_timer.start()
	_wave_timer_label.wave_timer = _wave_timer
	var _error_wave_timer = _wave_timer.connect("tick_started", self, "on_tick_started")

	var _error_group_spawn = _wave_manager.connect("group_spawn_timing_reached", _entity_spawner, "on_group_spawn_timing_reached")
	_wave_manager.init(_wave_timer, current_zone, current_wave_data)

	var _error_connect = _coop_upgrades_ui.connect("upgrade_selected", self, "on_upgrade_selected")
	_error_connect = _coop_upgrades_ui.connect("item_take_button_pressed", self, "on_item_box_take_button_pressed")
	_error_connect = _coop_upgrades_ui.connect("item_discard_button_pressed", self, "on_item_box_discard_button_pressed")
	_error_connect = _coop_upgrades_ui.connect("item_ban_button_pressed", self, "on_item_box_ban_button_pressed")

	_error_connect = _upgrades_ui.connect("upgrade_selected", self, "on_upgrade_selected")
	_error_connect = _upgrades_ui.connect("item_take_button_pressed", self, "on_item_box_take_button_pressed")
	_error_connect = _upgrades_ui.connect("item_discard_button_pressed", self, "on_item_box_discard_button_pressed")
	_error_connect = _upgrades_ui.connect("item_ban_button_pressed", self, "on_item_box_ban_button_pressed")

	var _error_level_up = RunData.connect("levelled_up", self, "on_levelled_up")
	var _error_level_up_floating_text = RunData.connect("levelled_up", _floating_text_manager, "on_levelled_up")
	var _error_xp_added = RunData.connect("xp_added", self, "on_xp_added")
	var _error_gold_changed = RunData.connect("gold_changed", self, "on_gold_changed")
	var _error_bonus_gold_ui = RunData.connect("bonus_gold_changed", _ui_bonus_gold, "update_value")
	var _error_bonus_gold = RunData.connect("bonus_gold_changed", self, "on_bonus_gold_changed")
	on_bonus_gold_changed(RunData.bonus_gold)
	var _error_damage_effect = RunData.connect("damage_effect", self, "on_damage_effect")
	var _error_lifesteal_effect = RunData.connect("lifesteal_effect", self, "on_lifesteal_effect")
	var _error_healing_effect = RunData.connect("healing_effect", self, "on_healing_effect")
	var _error_heal_over_time_effect = RunData.connect("heal_over_time_effect", self, "on_heal_over_time_effect")

	var _error_gamepad = InputService.connect("game_lost_focus", self, "_on_game_lost_focus")

	
	var max_bounds = ZoneService.get_current_zone_rect().grow_individual(EDGE_SIZE, EDGE_SIZE * 2, EDGE_SIZE, EDGE_SIZE)
	_camera.init(max_bounds, float(EDGE_SIZE))
	on_lock_coop_camera_changed(ProgressData.settings.lock_coop_camera)
	ZoneService.current_zone_max_camera_rect = _camera.get_max_camera_bounds()

	_ui_dim_screen.color.a = 0

	var _error_options_1 = _pause_menu._menu_options.connect("character_highlighting_changed", self, "on_character_highlighting_changed")
	var _error_options_2 = _pause_menu._menu_options.connect("hp_bar_on_character_changed", self, "on_hp_bar_on_character_changed")
	var _error_options_3 = _pause_menu._menu_options.connect("weapon_highlighting_changed", self, "on_weapon_highlighting_changed")
	var _error_options_4 = _pause_menu._menu_options.connect("darken_screen_changed", self, "on_darken_screen_changed")
	var _error_options_5 = _pause_menu._menu_options.connect("lock_coop_camera_changed", self, "on_lock_coop_camera_changed")

	for player_index in CoopService.get_max_players():
		var player_idx_string = str(player_index + 1)
		var things_to_process_player_container = get_node("%%UIThingsToProcessPlayerContainer%s" % player_idx_string)
		
		things_to_process_player_container.hide()
		if not RunData.is_coop_run:
			
			things_to_process_player_container.horizontal_alignment = UIThingsToProcessPlayerContainer.Alignment.END
		_things_to_process_player_containers.push_back(things_to_process_player_container)

	_is_horde_wave = RunData.is_elite_wave(EliteType.HORDE)
	_is_elite_wave = RunData.is_elite_wave(EliteType.ELITE)
	var could_be_bullet_hell = RunData.get_player_effect(Keys.bullet_hell_event_hash, 0) and RunData.constant_projectile != 0
	var could_be_fog_wave = RunData.get_player_effect(Keys.fog_of_war_event_hash, 0)

	if not RunData.is_coop_run:
		
		
		_ui_things_to_process_margin_container.add_constant_override("margin_right", 0)

	for effect_behavior_data in EffectBehaviorService.scene_effect_behaviors:
		var effect_behavior: SceneEffectBehavior = effect_behavior_data.scene.instance()
		_effect_behaviors.add_child(effect_behavior.init(_entity_spawner, _wave_manager))

	# Gourmet DLC - The Special: modifiers were applied at the very top of _ready (before the
	# zone sizing) so every consumer below - including this spawner init - sees them.
	_entity_spawner.init(
		ZoneService.current_zone_min_position, 
		ZoneService.current_zone_max_position, 
		current_wave_data, 
		_wave_timer
	)
	_stats_manager.init(_entity_spawner)

	EntityService.reset_cache()
	InputService.set_gamepad_echo_processing(false)
	_coop_upgrades_ui.propagate_call("set_process_input", [false])

	
	if RunData.current_wave == 1:
		for player_index in RunData.get_player_count():
			var player: Player = _players[player_index]
			player.land()

	for player_index in RunData.get_player_count():
		var effects = RunData.get_player_effects(player_index)
		if effects.has(Keys.gain_random_primary_stats_on_go_to_next_wave_hash):
			var gain_stats = effects[Keys.gain_random_primary_stats_on_go_to_next_wave_hash]
			for gain_stat in gain_stats:
				var chance = gain_stat[1]
				if Utils.get_chance_success(float(chance) / 100):
					for _i in range(gain_stat[0]):
						var stat = RunData.get_random_primary_stats()
						RunData.add_stat(stat, 1, player_index)
						RunData.add_tracked_value(player_index, Keys.item_candy_bag_hash, 1)

	var _wave = RunData.current_wave
	var events_fog_of_war = RunData.events_fog_of_war
	if (_wave in events_fog_of_war and could_be_fog_wave):
		_is_fog_wave = true

	# Gourmet DLC - Mole: fog of war covers every wave
	for fog_player_index in RunData.get_player_count():
		var fog_character = RunData.get_player_character(fog_player_index)
		if fog_character != null and fog_character.my_id == "character_mole":
			_is_fog_wave = true
			GourmetTracker.ev("mole_fog", {})
			break

	# Gourmet DLC - Wildcard (Blackout): the modifier forces fog on, same path as the Mole.
	# The roll blocks the VISION axis on natural fog waves, so this never doubles one up.
	if RunData.sum_all_player_effects(Keys.special_force_fog_hash) > 0:
		_is_fog_wave = true
		GourmetTracker.ev("wildcard_fog", {})

	_fog_viewport._initialize()

	var events_bullet_hell = RunData.events_bullet_hell
	# Gourmet DLC - Wildcard (Meteor Shower): the modifier forces a bullet hell. Natural
	# bullet-hell waves block the BULLET_HELL axis, so the two can never stack. The fog guard
	# stays: fog + bullet hell together is unreadable, and fog wins (vanilla's own rule).
	var special_forced_bullet_hell: bool = RunData.sum_all_player_effects(Keys.special_force_bullet_hell_hash) > 0
	if ((RunData.constant_projectile == 2 or (_wave in events_bullet_hell)) and could_be_bullet_hell or special_forced_bullet_hell) and _is_fog_wave == false:
		# Track it so the Wildcard roll's BULLET_HELL axis block (main.gd wave-end) sees
		# natural bullet-hell waves - this flag was declared but never set before.
		_is_bullet_hell_wave = true
		if special_forced_bullet_hell:
			GourmetTracker.ev("wildcard_bullet_hell", {})
		if (_wave > 20):
			_wave = 20
		var rand_bullet_hell: BulletHell = ZoneService.bullets_hell.pick_random().instance()
		rand_bullet_hell._update_bullet_hell_parameters(_wave, _is_elite_wave, _is_horde_wave)
		_enemy_projectiles.add_child(rand_bullet_hell)


	_init_half_second_timers()


func _updatehidingHUD() -> void :
	if DebugService.hide_wave_timer:
		_ui_wave_container.hide()
	else:
		_ui_wave_container.show()
	if DebugService.hide_hud:
		_hud.hide()
		$WorldUI.hide()
	else:
		_hud.show()
		$WorldUI.show()
	if DebugService.hide_floating_text:
		_floating_texts.hide()
		$WorldUI.hide()
	else:
		_floating_texts.show()
		$WorldUI.show()


func _init_half_second_timers() -> void :
	var timer_wait_time: = 0.5
	var player_count: int = RunData.get_player_count()
	var timer_delay: = timer_wait_time / player_count
	for player_index in player_count:
		if LinkedStats.update_for_player_every_half_sec[player_index]:
			var timer: = Timer.new()
			timer.wait_time = timer_wait_time
			timer.autostart = true
			_half_second_timers.add_child(timer)
			timer.connect("timeout", self, "_on_HalfSecondTimer_timeout", [player_index])
			if not get_tree().current_scene.name == "GutRunner":
				
				yield(get_tree().create_timer(timer_delay), "timeout")


func on_ui_element_mouse_entered(ui_element: Node, text: String) -> void :
	if _cleaning_up:
		_info_popup.display(ui_element, tr(text))


func on_ui_element_mouse_exited(_ui_element: Node) -> void :
	_info_popup.hide()


func on_character_highlighting_changed(_value: bool) -> void :
	for player in _players:
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		player.update_highlight()


func on_weapon_highlighting_changed(_value: bool) -> void :
	for player in _players:
		if not is_instance_valid(player) or not player.is_inside_tree():
			continue
		player.update_weapon_highlighting()


func on_darken_screen_changed(_value: int) -> void :
	_damage_vignette.update_from_hp()


func on_lock_coop_camera_changed(value: int) -> void :
	_camera.dynamic_camera_enabled = not value


func on_hp_bar_on_character_changed(_value: int) -> void :
	for i in _players.size():
		if not is_instance_valid(_players[i]) or not _players[i].is_inside_tree(): return
		_on_player_health_updated(_players[i], _players[i].current_stats.health, _players[i].max_stats.health)


func on_stats_updated(player_index: int) -> void :
	_stats_manager.reload_stats(_players[player_index])
	_proj_on_death_stat_caches[player_index] = null


func _process(_delta: float) -> void :
	if DebugService.enable_time_scale_buttons:
		if Input.is_physical_key_pressed(KEY_1):
			Engine.time_scale = 0.5
		if Input.is_physical_key_pressed(KEY_2):
			Engine.time_scale = 1.0
		if Input.is_physical_key_pressed(KEY_3):
			Engine.time_scale = 2.0

	_handle_manual_aim_visuals()

	_check_for_pause()

	# Gourmet DLC - timer and scheduled food triggers
	_process_food_triggers(_delta)


func _handle_manual_aim_visuals() -> void :
	if RunData.is_coop_run:
		return

	_crosshair.hide()
	var crosshair_cursor: = false

	if not _cleaning_up:
		if Utils.is_manual_aim(0):
			if Utils.is_player_using_gamepad(0):
				_crosshair.show()
				Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)
				var player_pos = _players[0].global_position
				player_pos.y -= 32
				_crosshair.global_position = player_pos + CROSSHAIR_DIST_FROM_PLAYER_MANUAL_AIM * _players[0].gamepad_attack_vector
			else:
				crosshair_cursor = true
				Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		elif ProgressData.settings.manual_aim_on_mouse_press and ProgressData.settings.manual_aim:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)
		else:
			Input.set_mouse_mode(Input.MOUSE_MODE_HIDDEN)

		if ProgressData.settings.mouse_only:
			Input.set_mouse_mode(Input.MOUSE_MODE_VISIBLE)

	_set_crosshair_cursor(crosshair_cursor)


func _set_crosshair_cursor(enable: bool) -> void :
	if enable and not _crosshair_cursor_active:
		Input.set_custom_mouse_cursor(_crosshair.texture, Input.CURSOR_ARROW, Vector2(35, 35))
		_crosshair_cursor_active = true
	elif not enable and _crosshair_cursor_active:
		Utils.set_default_cursor()
		_crosshair_cursor_active = false


func _check_for_pause() -> void :
	if _skip_pause_check:
		_skip_pause_check = false
		return

	if RunData.is_coop_run:
		if RunData.is_streamplay_run:
			var remapped_device = CoopService.get_remapped_player_device(0)
			if Input.is_action_just_released("ui_pause_%s" % remapped_device):
				_pause_menu.pause(0)
		else:
			for player_index in RunData.get_player_count():
				var remapped_device = CoopService.get_remapped_player_device(player_index)
				if Input.is_action_just_released("ui_pause_%s" % remapped_device):
					_pause_menu.pause(player_index)
					break
	else:
		if Input.is_action_just_released("ui_pause"):
			_pause_menu.pause(0)


func _physics_process(_delta: float) -> void :
	if _cleaning_up:
		_gold_bag.global_position = get_gold_bag_pos()

	for player_index in RunData.get_player_count():
		var life_bar_effects = _players[player_index].life_bar_effects()
		var player_ui: PlayerUIElements = _players_ui[player_index]
		player_ui.life_bar.update_color_from_effects(life_bar_effects)
		player_ui.player_life_bar.update_color_from_effects(life_bar_effects)

	if not _cleaning_up:
		for player_index in RunData.get_player_count():
			if not Utils.is_manual_aim(player_index) or not Utils.is_player_using_gamepad(player_index):
				continue
			var rjoy = Utils.get_player_rjoy_vector(player_index)
			if rjoy != Vector2.ZERO:
				_players[player_index].gamepad_attack_vector = rjoy.normalized()


func on_tick_started() -> void :
	_wave_timer_label.modulate = Color(ProgressData.settings.color_negative)


func on_bonus_gold_changed(value: int) -> void :
	if value == 0:
		_ui_bonus_gold.hide()


func _on_player_died(p_player: Player, _args: Entity.DieArgs) -> void :
	if (_args.from is BulletHell):
		_args.is_bullet_hell = true
	else:
		_args.is_bullet_hell = false
	RunData._players_die_args[p_player.player_index] = _args
	var player_ui: PlayerUIElements = _players_ui[p_player.player_index]
	player_ui.player_life_bar.hide()
	if RunData.is_coop_run:
		player_ui.life_bar.set_value(100)
		player_ui.life_bar.progress_color = Color.white
		player_ui.life_bar.hide_with_flash()

	p_player.highlight.hide()

	SoundManager.play(Utils.get_rand_element(run_lost_sounds), - 5, 0, true)

	var live_players: = _get_live_players()
	if not live_players.empty():
		return

	clean_up_room()

	ProgressData.reset_and_save_new_run_state()

	ChallengeService.complete_challenge(ChallengeService.chal_rookie_hash)

	if _args.from != null and _args.from is Enemy:
		if ProgressData.killed_by_enemies.has(_args.from.enemy_id_hash):
			ProgressData.killed_by_enemies[_args.from.enemy_id_hash] += 1
		else:
			ProgressData.killed_by_enemies[_args.from.enemy_id_hash] = 1

		if _args.from.enemy_id == "evil_mob":
			ProgressData.increment_stat("evil_mob_killed_by")


func _on_enemy_died(enemy: Enemy, args: Entity.DieArgs) -> void :
	RunData.current_living_enemies -= 1

	if not _cleaning_up and args.enemy_killed_by_player:
		if enemy is Boss:

			
			if _entity_spawner.get_nb_bosses_and_elites_alive() <= 1 and RunData.current_wave == RunData.nb_of_waves:

				if RunData.is_endless_run:
					var additional_groups = ZoneService.get_additional_groups(int((RunData.current_wave / 10.0) * 3), 90)
					for i in additional_groups.size():
						additional_groups[i].spawn_timing = _wave_timer.wait_time - _wave_timer.time_left + i
					_wave_manager.add_groups(additional_groups)
					RunData.all_last_wave_bosses_killed = true

				else:
					_wave_timer.wait_time = 0.1
					_wave_timer.start()

		var live_players: = _get_shuffled_live_players()

		for player in live_players:
			var player_index = player.player_index
			var dmg_when_death = RunData.get_player_effect(Keys.dmg_when_death_hash, player_index)
			if dmg_when_death.size() > 0:
				var _dmg_taken = handle_stat_damages(dmg_when_death, player_index)

		for player in live_players:
			var player_index = player.player_index
			var projectiles_on_death = RunData.get_player_effect(Keys.projectiles_on_death_hash, player_index)
			if projectiles_on_death.empty():
				continue

			for i in projectiles_on_death[0]:
				var stats = projectiles_on_death[1]
				if _proj_on_death_stat_caches[player_index] != null:
					stats = _proj_on_death_stat_caches[player_index]
				else:
					stats = WeaponService.init_ranged_stats(projectiles_on_death[1], player_index, true)
					_proj_on_death_stat_caches[player_index] = stats

				var auto_target_enemy: bool = projectiles_on_death[2]
				var from = player
				_spawn_projectile_args.damage_tracking_key_hash = Keys.item_baby_with_a_beard_hash
				_spawn_projectile_args.from_player_index = player_index
				var _projectile = WeaponService.manage_special_spawn_projectile(
					enemy, 
					stats, 
					rand_range( - PI, PI), 
					auto_target_enemy, 
					_entity_spawner, 
					from, 
					_spawn_projectile_args
				)

		for player in live_players:
			var player_index = player.player_index
			RunData.handle_explode_effect(Keys.explode_on_death_hash, enemy.global_position, player_index)

		for player in live_players:
			if args.is_burning or enemy._is_burning:
				var effects = RunData.get_player_effect(Keys.gain_stat_for_killed_enemies_while_burning_hash, player.player_index)
				for effect in effects:
					if effect[5] < effect[3]:
						effect[4] += 1
						if effect[4] %int(effect[1]) == 0:
							effect[5] += 1
							RunData.add_stat(effect[0], effect[2], player.player_index)
							RunData.add_tracked_value(player.player_index, Keys.item_will_o_the_wisp_hash, 1, 0)

		spawn_loot(enemy, EntityType.ENEMY, args)

		# Gourmet DLC - kill-triggered food spawners. Kills credit the killer;
		# burning deaths and elite kills count for every live player (the vanilla
		# gain_stat_for_killed_enemies_while_burning precedent just above)
		if args.killed_by_player_index >= 0:
			count_food_trigger(Keys.kill_foods_hash, args.killed_by_player_index)
			# BBQ Grill / Hot Dog Cart: the same kill also counts as close or far,
			# split at 300 range from the killer (every kill lands in exactly one)
			if args.killed_by_player_index < _players.size():
				var killer_player = _players[args.killed_by_player_index]
				if is_instance_valid(killer_player):
					if enemy.global_position.distance_to(killer_player.global_position) <= 300.0:
						count_food_trigger(Keys.close_kill_foods_hash, args.killed_by_player_index)
					else:
						count_food_trigger(Keys.far_kill_foods_hash, args.killed_by_player_index)
			# Gumball Machine: kills BY a turret (args.from is the turret) count separately
			if is_instance_valid(args.from) and args.from is Turret and args.from.player_index >= 0:
				count_food_trigger(Keys.turret_kill_foods_hash, args.from.player_index)
		for player in live_players:
			if args.is_burning or enemy._is_burning:
				count_food_trigger(Keys.burning_kill_foods_hash, player.player_index)
			if enemy is Boss:
				count_food_trigger(Keys.elite_kill_foods_hash, player.player_index)

		# Gourmet DLC - Echo Chamber: chance for on-kill effects to trigger twice
		# (covers stat damage and death explosions; on-death projectiles excluded)
		for player in live_players:
			var echo_chance: int = RunData.get_player_effect(Keys.echo_chamber_hash, player.player_index)
			if echo_chance > 0 and randf() < echo_chance / 100.0:
				RunData.add_tracked_value(player.player_index, Keys.generate_hash("item_echo_chamber"), 1)
				GourmetTracker.ev("echo_proc", {"p": player.player_index})
				var echo_dmg_when_death = RunData.get_player_effect(Keys.dmg_when_death_hash, player.player_index)
				if echo_dmg_when_death.size() > 0:
					var _echo_dmg = handle_stat_damages(echo_dmg_when_death, player.player_index)
				RunData.handle_explode_effect(Keys.explode_on_death_hash, enemy.global_position, player.player_index)

		ProgressData.increment_stat("enemies_killed")

		if ProgressData.killed_enemies.has(enemy.enemy_id_hash):
			ProgressData.killed_enemies[enemy.enemy_id_hash] += 1
		else:
			ProgressData.killed_enemies[enemy.enemy_id_hash] = 1

		if enemy.enemy_id == "evil_mob":
			ProgressData.increment_stat("evil_mob_killed")


func _on_enemy_took_damage(
	enemy: Enemy, 
	_value: int, 
	_knockback_direction: Vector2, 
	_is_crit: bool, 
	_is_dodge: bool, 
	_is_protected: bool, 
	_armor_did_something: bool, 
	args: TakeDamageArgs, 
	_hit_type: int, 
	_is_one_shot: bool
	) -> void :
	if enemy.dead and WeaponService.should_spawn_landmines_on_enemy_death(args.hitbox, args.is_burning, args.from_player_index):
		var pos = _entity_spawner.get_spawn_pos_in_area(enemy.global_position, 200)
		var queue = _entity_spawner.queues_to_spawn_structures[args.from_player_index]
		queue.push_back([EntityType.STRUCTURE, landmines_effect.scene, pos, landmines_effect])

	# Gourmet DLC - crit (Sushi Bar) and burning-tick (Chili Greenhouse) counters
	if args.from_player_index >= 0 and not _is_dodge:
		if _is_crit:
			count_food_trigger(Keys.crit_foods_hash, args.from_player_index)
		if args.is_burning:
			count_food_trigger(Keys.burning_tick_foods_hash, args.from_player_index)

		# Static Cling: every 8th landed hit zaps the 3 nearest enemies
		if RunData.get_player_effect(Keys.static_cling_hash, args.from_player_index) > 0:
			_static_cling_counters[args.from_player_index] += 1
			if _static_cling_counters[args.from_player_index] >= 8:
				_static_cling_counters[args.from_player_index] = 0
				var cling_dmg: int = int(6.0 + Utils.get_stat(Keys.stat_elemental_damage_hash, args.from_player_index))
				var zapped: = 0
				for cling_enemy in _entity_spawner.enemies:
					if zapped >= 3:
						break
					if is_instance_valid(cling_enemy) and not cling_enemy.dead and enemy.global_position.distance_to(cling_enemy.global_position) <= 350.0:
						var cling_args: = TakeDamageArgs.new(args.from_player_index)
						var cling_result: Array = cling_enemy.take_damage(cling_dmg, cling_args)
						RunData.add_tracked_value(args.from_player_index, Keys.generate_hash("item_static_cling"), cling_result[1])
						zapped += 1
						GourmetTracker.count("static_cling_zaps")

		# Chili Pepper buff: your hits ignite enemies; flat part scales with
		# Appetite (computed at eat time) and the burn itself carries 0.3x
		# Elemental through the vanilla burning scaling stats
		# Gourmet DLC - from_player_index is -1 for unowned damage (enemy-on-enemy,
		# environmental) and -1 < size() passes, so the lower bound is needed too.
		if not args.is_burning and not enemy.dead and args.from_player_index >= 0 and args.from_player_index < _players.size():
			var chili_player: Player = _players[args.from_player_index]
			if chili_player._food_buffs.has("consumable_food_chili_pepper"):
				if _chili_burning_data[args.from_player_index] == null:
					var new_burning_data: = BurningData.new()
					new_burning_data.chance = 1.0
					new_burning_data.duration = 3
					new_burning_data.scaling_stats = [[Keys.stat_elemental_damage_hash, 0.3]]
					_chili_burning_data[args.from_player_index] = new_burning_data
				var chili_burn: BurningData = _chili_burning_data[args.from_player_index]
				chili_burn.damage = chili_player._food_buffs["consumable_food_chili_pepper"].get("burn_damage", 0)
				chili_burn.from = chili_player
				enemy.apply_burning(chili_burn)
				GourmetTracker.count("chili_ignites")


func _on_neutral_died(neutral: Neutral, args: Entity.DieArgs) -> void :
	RunData.current_living_trees -= 1

	if not _cleaning_up:
		call_deferred("spawn_loot", neutral, EntityType.NEUTRAL, args)

		for player in _get_shuffled_live_players():
			var player_index = player.player_index
			for _i in RunData.get_player_effect(Keys.tree_turrets_hash, player_index):
				var pos = _entity_spawner.get_spawn_pos_in_area(neutral.global_position, 200)
				var queue = _entity_spawner.queues_to_spawn_structures[player_index]
				queue.push_back([EntityType.STRUCTURE, turret_effect.scene, pos, turret_effect])


# Gourmet DLC - Grandma's Cookbook: food on taking damage, 2 second cooldown.
# Dodged and protection-blocked hits are not damage taken.
func _on_player_took_damage_food(unit: Unit, _value: int, _knockback_direction: Vector2, _is_crit: bool, is_dodge: bool, is_protected: bool, _armor_did_something: bool, _args, _hit_type: int, _is_one_shot: bool) -> void :
	# Gourmet DLC - Girly: panics on ANY hit incl. dodged/armor-nullified (this
	# fires before the is_dodge/is_protected return), teleports to the safest spot
	# and drops a food burst. 10s cooldown via the _food_trigger_cooldowns dict.
	if not unit.dead:
		var girly_char = RunData.get_player_character(unit.player_index)
		if girly_char != null and girly_char.my_id == "character_girly":
			var girly_now: int = OS.get_ticks_msec()
			var girly_key: int = Keys.generate_hash("girly_panic")
			var girly_last: int = _food_trigger_cooldowns[unit.player_index].get(girly_key, - 10000)
			if girly_now - girly_last >= 10000:
				_food_trigger_cooldowns[unit.player_index][girly_key] = girly_now
				girly_panic_teleport(unit)

	if is_dodge or is_protected:
		return
	count_food_trigger_with_cooldown(Keys.damage_taken_foods_hash, unit.player_index, 2000)

	# Gourmet DLC - Panic Button: below 30% HP a knockback burst fires (10s cooldown)
	if RunData.get_player_effect(Keys.panic_button_hash, unit.player_index) > 0:
		if unit.current_stats.health <= unit.max_stats.health * 0.3 and not unit.dead:
			var now: int = OS.get_ticks_msec()
			var last: int = _food_trigger_cooldowns[unit.player_index].get(Keys.panic_button_hash, - 10000)
			if now - last >= 10000:
				_food_trigger_cooldowns[unit.player_index][Keys.panic_button_hash] = now
				knockback_burst(unit.global_position, 30.0, 350.0)
				GourmetTracker.ev("panic_button", {"p": unit.player_index})


func on_player_wanted_to_spawn_gold(value: int, pos: Vector2, spread: int) -> void :
	var actual_value = get_gold_value(EntityType.NEUTRAL, Utils.default_die_args, value)
	spawn_gold(actual_value, pos, spread)


func spawn_loot(unit: Unit, entity_type: int, args: Entity.DieArgs) -> void :
	if not unit.can_drop_loot:
		return

	if unit.stats.can_drop_consumables:
		spawn_consumables(unit)

	var wave_factor = RunData.current_wave * 0.015


	var spawn_chance = 1.0 if RunData.current_wave < 5 else max(0.5, (1.0 - wave_factor))

	if _is_horde_wave:
		spawn_chance *= 0.65

	if unit.stats.always_drop_consumables:
		spawn_chance = 1.0

	if entity_type == EntityType.ENEMY and not Utils.get_chance_success(spawn_chance):
		return

	var value: float = get_gold_value(entity_type, args, unit.get_stats_value(), unit)
	var gold_spread = clamp((value - 1) * 25, unit.stats.gold_spread, 200)

	spawn_gold(value, unit.global_position, gold_spread)


func spawn_consumables(unit: Unit) -> void :
	var luck: = 0.0

	for player_index in RunData.get_player_count():
		luck += Utils.get_stat(Keys.stat_luck_hash, player_index) / 100.0

	var item_chance: float = (unit.stats.item_drop_chance * (1.0 + luck)) / (1.0 + _items_spawned_this_wave)

	var total_chance_change: float = RunData.sum_all_player_effects(Keys.crate_chance_hash) / 100.0
	item_chance = item_chance + item_chance * total_chance_change

	if unit.stats.always_drop_consumables and unit.stats.item_drop_chance >= 1.0 and RunData.current_wave <= RunData.nb_of_waves:
		item_chance = 1.0

	var consumable_to_spawn: ConsumableData = ItemService.get_consumable_to_drop(unit, item_chance)

	# Gourmet DLC - The Freeloader gets no items from crates at all: his single shop pick is
	# his only acquisition all run. Suppressed here at the drop site rather than at the Take
	# button, so he never crosses the arena for a box that turns out to be empty. Uses
	# has_freeloader() because crates belong to no player index; in coop this denies his
	# partners too, which is a known limitation of the solo-first design. Food and fruit are
	# deliberately untouched: they are consumables but not item boxes, so the whole food
	# layer still works for him.
	if consumable_to_spawn != null and RunData.has_freeloader():
		if consumable_to_spawn.my_id_hash == Keys.consumable_item_box_hash or consumable_to_spawn.my_id_hash == Keys.consumable_legendary_item_box_hash:
			consumable_to_spawn = null

	if consumable_to_spawn != null:
		var pos: = unit.global_position
		var dist: = rand_range(50, 100 + unit.stats.gold_spread)

		if consumable_to_spawn.my_id_hash == Keys.consumable_item_box_hash or consumable_to_spawn.my_id_hash == Keys.consumable_legendary_item_box_hash:
			
				
				
				
				
				
			_items_spawned_this_wave += 1

		var consumable: Consumable = get_node_from_pool(_consumable_pool_id, _consumables_container)
		if consumable == null:
			consumable = consumable_scene.instance()
			_consumables_container.call_deferred("add_child", consumable)
			var _error = consumable.connect("picked_up", self, "on_consumable_picked_up")
			yield(consumable, "ready")

		consumable_to_spawn = convert_fruit_consumable(consumable_to_spawn)
		consumable.already_picked_up = false
		consumable.consumable_data = consumable_to_spawn
		consumable.set_texture(consumable_to_spawn.icon)
		# Gourmet DLC - P2W: in his runs, item crates ARE lootboxes. Roll the rarity
		# at spawn (boss crates roll the top band) and dress the ground drop in it.
		# Pooled nodes: always reset the meta so stale rungs never leak.
		consumable.set_meta("p2w_rung", - 1)
		if RunData.has_p2w() and (consumable_to_spawn.my_id_hash == Keys.consumable_item_box_hash or consumable_to_spawn.my_id_hash == Keys.consumable_legendary_item_box_hash):
			var p2w_crate_rung: int
			if consumable_to_spawn.my_id_hash == Keys.consumable_legendary_item_box_hash:
				var p2w_leg_roll: int = Utils.randi_range(0, 99)
				p2w_crate_rung = 6 if p2w_leg_roll < 70 else (7 if p2w_leg_roll < 90 else 8)
			else:
				p2w_crate_rung = ItemService.get_p2w_rung_for_wave(RunData.current_wave, RunData.first_p2w_index(), 0)
			consumable.set_meta("p2w_rung", p2w_crate_rung)
			consumable.set_texture(load("res://items/custom/p2w/chest_%d/chest_%d.png" % [p2w_crate_rung, p2w_crate_rung]))
		if consumable_to_spawn.my_id.begins_with("consumable_food_"):
			consumable.modulate.a = 1.0
			consumable.set_meta("food_spawned_at", _food_wave_time)
		var push_back_destination: Vector2 = ZoneService.get_rand_pos_in_area(pos, dist, 0)
		consumable.drop(pos, 0, push_back_destination)
		_consumables.push_back(consumable)

		# Gourmet DLC - Second Helping / Butcher doubling on the enemy-drop path,
		# which bypasses spawn_food: real FOOD drops (incl. Butcher's fruit->Steak
		# and Gourmet's fruit->random-food) can double; plain vanilla fruit and
		# item boxes stay single. The bonus copy is exempt from re-doubling.
		if consumable_to_spawn.my_id.begins_with("consumable_food_"):
			var doubling_chance: = 0
			for di in RunData.get_player_count():
				doubling_chance = int(max(doubling_chance, RunData.get_player_effects(di)[Keys.second_helping_hash]))
			if doubling_chance > 0 and randf() < doubling_chance / 100.0:
				GourmetTracker.count("enemy_drop_food_doubled")
				for shi in RunData.get_player_count():
					if RunData.get_player_effects(shi)[Keys.second_helping_hash] > 0:
						RunData.add_tracked_value(shi, Keys.generate_hash("item_second_helping"), 1)
				spawn_food(consumable_to_spawn, pos, - 1.0, - 1, true)


# Gourmet DLC - spawner items drop their food through here: same pooled consumable
# machinery as enemy drops but with no drop-chance roll and no tier reroll.
# Foods land in a ring between MIN and MAX distance from the spawn position so the
# player never swallows one instantly; pass an angle to spread multiple spawns.
const FOOD_SPAWN_MIN_DIST: = 150.0
const FOOD_SPAWN_MAX_DIST: = 300.0

func get_food_spawn_destination(pos: Vector2, angle: float) -> Vector2:
	var dist: = rand_range(FOOD_SPAWN_MIN_DIST, FOOD_SPAWN_MAX_DIST)
	# get_rand_pos_in_area with area 0 is a pure clamp inside the zone bounds
	var destination: Vector2 = ZoneService.get_rand_pos_in_area(pos + Vector2(dist, 0).rotated(angle), 0)
	if pos.distance_to(destination) < FOOD_SPAWN_MIN_DIST:
		# clamped into a corner on top of the player: aim the opposite way instead
		destination = ZoneService.get_rand_pos_in_area(pos + Vector2(dist, 0).rotated(angle + PI), 0)
	return destination


func spawn_food(food_data: ConsumableData, pos: Vector2, angle: float = - 1.0, player_index: int = - 1, is_bonus: bool = false) -> void :
	if angle < 0:
		angle = rand_range(0, TAU)

	# Gourmet DLC - Picky Eater: only his selected spawner is active at all
	if player_index >= 0:
		var picky_gate_char = RunData.get_player_character(player_index)
		if picky_gate_char != null and picky_gate_char.my_id == "character_picky_eater":
			var picky_selected: int = RunData.get_player_effect(Keys.selected_spawner_hash, player_index)
			if picky_selected != 0 and picky_selected != Keys.generate_hash(food_data.my_id):
				GourmetTracker.count("picky_gated_spawns")
				return

	# Gourmet DLC - Intermittent Fasting halves spawns; Second Helping can double
	# them (a bonus serving is exempt from both)
	if player_index >= 0 and not is_bonus:
		var spawn_effects = RunData.get_player_effects(player_index)
		if spawn_effects[Keys.food_spawns_halved_hash] > 0:
			_food_fasting_counters[player_index] += 1
			if _food_fasting_counters[player_index] % 2 == 0:
				GourmetTracker.count("fasting_skips")
				return
		if spawn_effects[Keys.second_helping_hash] > 0 and randf() < spawn_effects[Keys.second_helping_hash] / 100.0:
			RunData.add_tracked_value(player_index, Keys.generate_hash("item_second_helping"), 1)
			spawn_food(food_data, pos, - 1.0, player_index, true)

		# Gourmet DLC - Gourmet: the FIRST food to spawn each wave is served twice. Rides the
		# same is_bonus recursion guard as Second Helping above, so the extra serving cannot
		# re-trigger this (or anything else) and the flag is set before the call regardless.
		if not _gourmet_first_food_done[player_index]:
			var first_food_char = RunData.get_player_character(player_index)
			if first_food_char != null and first_food_char.my_id == "character_gourmet":
				_gourmet_first_food_done[player_index] = true
				GourmetTracker.count("gourmet_doubled_first_food")
				spawn_food(food_data, pos, - 1.0, player_index, true)

	var consumable: Consumable = get_node_from_pool(_consumable_pool_id, _consumables_container)
	if consumable == null:
		consumable = consumable_scene.instance()
		_consumables_container.call_deferred("add_child", consumable)
		var _error = consumable.connect("picked_up", self, "on_consumable_picked_up")
		yield(consumable, "ready")

	consumable.already_picked_up = false
	consumable.consumable_data = food_data
	consumable.set_texture(food_data.icon)
	# Gourmet DLC - gumballs ship a dedicated 40px ARENA sprite per colour (thick
	# border); the 80px icon stays for card/codex/HUD chip. Colour is decided at
	# dispense (each colour is its own food), so no modulate trickery here.
	consumable.modulate = Color(1, 1, 1, 1)
	if food_data.my_id.begins_with("consumable_food_gumball"):
		var gb_slug: String = food_data.my_id.replace("consumable_food_", "")
		var gb_small = load("res://items/foods/%s/%s_small.png" % [gb_slug, gb_slug])
		if gb_small != null:
			consumable.set_texture(gb_small)
	consumable.set_meta("food_spawned_at", _food_wave_time)
	consumable.drop(pos, 0, get_food_spawn_destination(pos, angle))
	_consumables.push_back(consumable)
	GourmetTracker.ev("food_spawn", {"f": food_data.my_id, "p": player_index, "b": is_bonus})


# Gourmet DLC - an uneaten food rots away; players owning a Doggy Bag bank it
# as a Leftover for the next wave start
func expire_food(consumable: Consumable) -> void :
	GourmetTracker.ev("food_expire", {"f": consumable.consumable_data.my_id})
	# Gourmet DLC - a Leftover must NOT bank another Leftover: the bank never resets and
	# every bank is served back next wave, so self-feeding would compound into an unbounded
	# pile of scraps within a few waves. _process_food_expiry already skips Leftovers
	# outright, so this is belt-and-braces for any future caller. Read BEFORE reset()/
	# pooling, which is where consumable_data stops being trustworthy.
	var is_leftover: bool = consumable.consumable_data.my_id == "consumable_food_leftovers"

	consumable.already_picked_up = true
	_consumables.erase(consumable)
	consumable.reset()
	consumable.modulate.a = 1.0
	add_node_to_pool(consumable, _consumable_pool_id)

	for i in RunData.get_player_count():
		var expiry_effects = RunData.get_player_effects(i)
		var expiry_character = RunData.get_player_character(i)
		var is_dishwasher: bool = expiry_character != null and expiry_character.my_id == "character_dishwasher"
		if expiry_effects[Keys.doggy_bag_hash] > 0 and not is_leftover:
			var leftovers_gained: int = 2 if is_dishwasher else 1
			expiry_effects[Keys.banked_leftovers_hash] += leftovers_gained
			RunData.add_tracked_value(i, Keys.generate_hash("item_doggy_bag"), leftovers_gained)
		# Dishwasher: expired food refunds a material
		if is_dishwasher:
			RunData.add_gold(1, i)
			RunData.add_tracked_value(i, Keys.generate_hash("character_dishwasher"), 1)
			GourmetTracker.count("dishwasher_refunds")
		# Compost Bin turns rot into permanent Harvesting
		if expiry_effects[Keys.compost_bin_hash] > 0:
			RunData.add_stat(Keys.stat_harvesting_hash, expiry_effects[Keys.compost_bin_hash], i)
			RunData.add_tracked_value(i, Keys.generate_hash("item_compost_bin"), expiry_effects[Keys.compost_bin_hash])


func _process_food_expiry() -> void :
	# Cooler Box: foods on the ground never expire
	if RunData.sum_all_player_effects(Keys.cooler_box_hash) > 0:
		return

	var expiry_seconds: float = FOOD_EXPIRY_SECONDS
	for i in _players.size():
		var expiry_character = RunData.get_player_character(i)
		if expiry_character != null and expiry_character.my_id == "character_dishwasher":
			expiry_seconds *= 0.5
			break

	for j in range(_consumables.size() - 1, - 1, - 1):
		var ground_consumable = _consumables[j]
		if ground_consumable.already_picked_up or ground_consumable.consumable_data == null:
			continue
		if not ground_consumable.consumable_data.my_id.begins_with("consumable_food_"):
			continue
		# Gourmet DLC - Leftovers never rot. They ARE the rot: they are what the Doggy Bag
		# bank serves back, so letting them expire would either feed the bank a second time
		# or quietly delete banked stacks the player never got to collect. They sit on the
		# ground until eaten or until the wave ends.
		if ground_consumable.consumable_data.my_id == "consumable_food_leftovers":
			continue
		if not ground_consumable.has_meta("food_spawned_at"):
			continue
		var food_age: float = _food_wave_time - ground_consumable.get_meta("food_spawned_at")
		if food_age >= expiry_seconds:
			expire_food(ground_consumable)
		elif food_age >= expiry_seconds - FOOD_EXPIRY_BLINK_SECONDS:
			ground_consumable.modulate.a = 0.4 + 0.6 * abs(sin(food_age * 6.0))


# Gourmet DLC - Slug: the trail is a fading list of recent positions; enemies
# touching any fresh point are slowed via the timed-slow primitive
func _process_slime_trail() -> void :
	if _snail_player_index < 0 or _slime_trail_line == null:
		return
	var snail_player: Player = _players[_snail_player_index]
	if snail_player.dead:
		return

	var now: float = _food_wave_time
	if _slime_trail_points.empty() or _slime_trail_points[_slime_trail_points.size() - 1][0].distance_to(snail_player.global_position) > 14.0:
		_slime_trail_points.push_back([snail_player.global_position, now])

	while not _slime_trail_points.empty() and now - _slime_trail_points[0][1] > SLIME_TRAIL_LIFETIME:
		_slime_trail_points.pop_front()

	var line_points: = PoolVector2Array()
	for trail_point in _slime_trail_points:
		line_points.push_back(trail_point[0])
	_slime_trail_line.points = line_points

	# Trail width, slow radius and slow strength all scale with the Slug's current level
	var level: int = RunData.get_player_level(_snail_player_index)
	var size_scale: float = 1.0 + level * SLIME_TRAIL_SIZE_PER_LEVEL
	_slime_trail_line.width = SLIME_TRAIL_BASE_WIDTH * size_scale
	var slow_pct: int = int(min(SLIME_TRAIL_SLOW_MAX, SLIME_TRAIL_SLOW + level * SLIME_TRAIL_SLOW_PER_LEVEL))
	var scaled_radius: float = SLIME_TRAIL_RADIUS * size_scale
	var radius_sq: float = scaled_radius * scaled_radius
	# slimed damage per tick, recomputed each frame so Elemental Damage picked up mid-wave counts
	var slime_elemental: float = max(0.0, Utils.get_stat(Keys.stat_elemental_damage_hash, _snail_player_index))
	var slime_damage: int = int(max(1.0, SLIME_DAMAGE_BASE + SLIME_DAMAGE_ELEMENTAL_RATIO * slime_elemental))
	for trail_enemy in _entity_spawner.enemies:
		if not is_instance_valid(trail_enemy) or trail_enemy.dead:
			continue
		for trail_point in _slime_trail_points:
			if trail_enemy.global_position.distance_squared_to(trail_point[0]) <= radius_sq:
				trail_enemy.apply_gourmet_slow(slow_pct, 0.4)
				# slimed: an independent DoT, so a burning enemy takes this on top of the burn.
				# The next-tick stamp rides the enemy node, so it dies with it (no bookkeeping).
				# Godot 3 get_meta takes no default, hence the has_meta guard.
				var slime_next: float = float(trail_enemy.get_meta(SLIME_META)) if trail_enemy.has_meta(SLIME_META) else - 1.0
				if now >= slime_next:
					trail_enemy.set_meta(SLIME_META, now + SLIME_DAMAGE_TICK)
					var slime_args: = TakeDamageArgs.new(_snail_player_index)
					# take_damage returns [full_damage, damage_taken, dodged]; index 1 is what
					# the enemy actually lost, which is what "Damage dealt" should report.
					var slimed_result: Array = trail_enemy.take_damage(slime_damage, slime_args)
					RunData.add_tracked_value(_snail_player_index, Keys.generate_hash("character_snail"), slimed_result[1], 1)
					GourmetTracker.count("slime_ticks")
				break


# Gourmet DLC - food trigger framework. Trigger effect entries are
# [food_id_hash, spawn_count]: owning two copies of a spawner doubles the food
# per fire and never the threshold. Counters and timers are per player and
# reset each wave (main is rebuilt per wave).
func count_food_trigger(trigger_hash: int, player_index: int, amount: int = 1) -> void :
	if _cleaning_up or player_index < 0 or player_index >= _players.size():
		return

	var entries = RunData.get_player_effect(trigger_hash, player_index)
	if entries.empty():
		return

	var threshold: int = _food_trigger_thresholds[trigger_hash]
	# Michelin Star: spawners trigger faster; Set Menu: the daily special 40%
	# faster and everything else 20% slower
	var trigger_speed: int = RunData.get_player_effect(Keys.spawner_trigger_speed_hash, player_index)
	trigger_speed += get_set_menu_speed(entries, player_index)
	if trigger_speed != 0:
		threshold = int(max(1, round(threshold * 100.0 / (100.0 + trigger_speed))))
	var count: int = _food_trigger_counters[player_index].get(trigger_hash, 0) + amount
	GourmetTracker.count("prog_" + GourmetTracker.trigger_name(trigger_hash), amount)
	while count >= threshold:
		count -= threshold
		fire_food_trigger(trigger_hash, player_index)
	_food_trigger_counters[player_index][trigger_hash] = count


func count_food_trigger_with_cooldown(trigger_hash: int, player_index: int, cooldown_msec: int) -> void :
	if player_index < 0 or player_index >= _players.size():
		return

	var now: int = OS.get_ticks_msec()
	var last: int = _food_trigger_cooldowns[player_index].get(trigger_hash, - cooldown_msec)
	if now - last < cooldown_msec:
		return
	_food_trigger_cooldowns[player_index][trigger_hash] = now
	count_food_trigger(trigger_hash, player_index)


func fire_food_trigger(trigger_hash: int, player_index: int) -> void :
	if player_index < 0 or player_index >= _players.size():
		return

	var player: Player = _players[player_index]
	if player.dead:
		return

	GourmetTracker.ev("trigger_fire", {"tr": GourmetTracker.trigger_name(trigger_hash), "p": player_index})
	for entry in RunData.get_player_effect(trigger_hash, player_index):
		var food_data = ItemService.get_food_from_hash(entry[0])
		if food_data != null:
			for _j in range(entry[1]):
				# Gumball Machine dispenses a random colour; each colour is its
				# own food (own buff, own HUD chip), rolled per ball
				var rolled_food = food_data
				if food_data.my_id == "consumable_food_gumball":
					var gb_ids: Array = ["consumable_food_gumball", "consumable_food_gumball_red", "consumable_food_gumball_blue"]
					var gb_pick = ItemService.get_food_from_hash(Keys.generate_hash(gb_ids[randi() % 3]))
					if gb_pick != null:
						rolled_food = gb_pick
				spawn_food(rolled_food, get_food_spawn_origin(entry[0], player_index), - 1.0, player_index)


# Gourmet DLC - Gourmet: all fruit becomes food (a random real food replaces the
# drop); Butcher: fruit keeps healing but shows as raw steak. Gourmet wins when
# both are in a coop run.
func convert_fruit_consumable(consumable_data: ConsumableData) -> ConsumableData:
	if consumable_data.my_id_hash != Keys.consumable_fruit_hash:
		return consumable_data
	var has_butcher: = false
	for i in RunData.get_player_count():
		var fruit_character = RunData.get_player_character(i)
		if fruit_character == null:
			continue
		if fruit_character.my_id == "character_gourmet":
			# Gourmet turns fruit into a RANDOM food (wins over Butcher in co-op)
			var food_pool: = []
			for food in ItemService.foods:
				if food.my_id != "consumable_food_leftovers":
					food_pool.push_back(food)
			if food_pool.size() > 0:
				GourmetTracker.count("gourmet_fruit_conversions")
				return Utils.get_rand_element(food_pool)
		elif fruit_character.my_id == "character_butcher":
			has_butcher = true
	# Butcher: every fruit becomes an actual Steak (the real buff food, not a
	# fruit reskin) - eating it grants the Steak damage buff like any other Steak.
	if has_butcher:
		var steak = ItemService.get_food_from_hash(Keys.generate_hash("consumable_food_steak"))
		if steak != null:
			GourmetTracker.count("butcher_fruit_to_steak")
			return steak
	return consumable_data




# Gourmet DLC - Set Menu: +40% trigger speed for the selected spawner's food,
# -20% for every other spawner (entries are [food_id_hash, count])
func get_set_menu_speed(entries, player_index: int) -> int:
	if RunData.get_player_effect(Keys.set_menu_hash, player_index) <= 0:
		return 0
	var selected: int = RunData.get_player_effect(Keys.selected_spawner_hash, player_index)
	if selected == 0:
		return 0
	for entry in entries:
		if entry[0] == selected:
			return 40
	return - 20


# Gourmet DLC - knockback burst primitive (Burp of Power, Panic Button; Culinary
# weapons later): shoves every live enemy in radius away from pos, using the same
# knockback_vector mechanism weapon hits use
func knockback_burst(pos: Vector2, amount: float, radius: float) -> void :
	for burst_enemy in _entity_spawner.enemies:
		if is_instance_valid(burst_enemy) and not burst_enemy.dead and pos.distance_to(burst_enemy.global_position) <= radius:
			burst_enemy.knockback_vector = pos.direction_to(burst_enemy.global_position) * amount


# Gourmet DLC - foods anchored to a structure (greenhouse, wok, cart, stall) pop
# out of it; everything else pops out of the player. Every copy of a spawner item puts its
# own stand on the map, so pick a live one at random per serving - the stands share the
# item's output rather than three of them idling behind one.
func get_food_spawn_origin(food_id_hash: int, player_index: int) -> Vector2:
	var anchors = _food_structures[player_index].get(food_id_hash)
	if anchors is Array and not anchors.empty():
		var live_anchors: = []
		for anchor in anchors:
			if anchor != null and is_instance_valid(anchor) and not anchor.dead:
				live_anchors.push_back(anchor)
		# Stands can be destroyed mid-wave; drop the dead ones so the list does not grow
		# stale across a long wave, then serve from whatever is still standing.
		_food_structures[player_index][food_id_hash] = live_anchors
		if not live_anchors.empty():
			return live_anchors[Utils.randi() % live_anchors.size()].global_position
	return _players[player_index].global_position


func _accumulate_food_timer(trigger_hash: int, player_index: int, delta: float, period: float) -> void :
	if RunData.get_player_effect(trigger_hash, player_index).empty():
		return

	# Michelin Star: spawners trigger faster; Set Menu adjusts per selection
	var timer_speed: int = RunData.get_player_effect(Keys.spawner_trigger_speed_hash, player_index)
	timer_speed += get_set_menu_speed(RunData.get_player_effect(trigger_hash, player_index), player_index)
	if timer_speed != 0:
		period = period * 100.0 / (100.0 + timer_speed)

	var accum: float = _food_timer_accums[player_index].get(trigger_hash, 0.0) + delta
	while accum >= period:
		accum -= period
		fire_food_trigger(trigger_hash, player_index)
	_food_timer_accums[player_index][trigger_hash] = accum


func _process_food_triggers(delta: float) -> void :
	if _cleaning_up or _players.empty():
		return

	_food_wave_time += delta

	for i in _players.size():
		var player: Player = _players[i]
		if player.dead:
			continue

		# Beehive: unconditional drip
		_accumulate_food_timer(Keys.timer_foods_hash, i, delta, 10.0)

		# Fancy Restaurant: time at full HP; leaving full HP resets progress
		if player.current_stats.health >= player.max_stats.health:
			_accumulate_food_timer(Keys.full_hp_timer_foods_hash, i, delta, 6.0)
		else:
			_food_timer_accums[i][Keys.full_hp_timer_foods_hash] = 0.0

		# Fondue Set: time standing still (any movement resets progress)
		var pos: Vector2 = player.global_position
		if _food_prev_positions[i] != null and pos.distance_squared_to(_food_prev_positions[i]) < 4.0:
			_accumulate_food_timer(Keys.standstill_timer_foods_hash, i, delta, 3.0)
		else:
			_food_timer_accums[i][Keys.standstill_timer_foods_hash] = 0.0
		_food_prev_positions[i] = pos

		# Gym Membership: vanilla per-wave step counter
		var steps: int = RunData.steps_taken_this_wave[i]
		if steps > _food_prev_steps[i]:
			count_food_trigger(Keys.step_foods_hash, i, steps - _food_prev_steps[i])
		_food_prev_steps[i] = steps

		# Pizza Delivery / Street Vendor / Leftovers: precomputed wave times
		var scheduled: Array = _food_scheduled_spawns[i]
		for j in range(scheduled.size() - 1, - 1, - 1):
			if _food_wave_time >= scheduled[j][0]:
				var food_data = ItemService.get_food_from_hash(scheduled[j][1])
				if food_data != null:
					for _k in range(scheduled[j][2]):
						# Leftovers are scraps left lying around, so they turn up ANYWHERE in
						# the arena rather than in the usual ring around the player/anchor.
						var origin: Vector2 = get_food_spawn_origin(scheduled[j][1], i)
						if scheduled[j][1] == Keys.generate_hash("consumable_food_leftovers"):
							origin = ZoneService.get_rand_pos()
						spawn_food(food_data, origin, - 1.0, i)
				scheduled.remove(j)

	_process_food_expiry()
	_process_slime_trail()

	# Gourmet DLC - Space Heater: +HP Regen per burning enemy (live count)
	var burning_enemy_count: = 0
	for heater_enemy in _entity_spawner.enemies:
		if is_instance_valid(heater_enemy) and not heater_enemy.dead and heater_enemy._is_burning:
			burning_enemy_count += 1
	for i in _players.size():
		var heater_value: int = RunData.get_player_effect(Keys.regen_per_burning_enemy_hash, i)
		var wanted_regen: int = heater_value * burning_enemy_count
		if wanted_regen != _space_heater_applied[i]:
			TempStats.add_stat(Keys.stat_hp_regeneration_hash, wanted_regen - _space_heater_applied[i], i)
			_space_heater_applied[i] = wanted_regen
			GourmetTracker.ev("space_heater", {"p": i, "applied": wanted_regen})


func on_consumable_picked_up(consumable: Node, player_index: int) -> void :
	if consumable.already_picked_up:
		return

	consumable.already_picked_up = true
	_consumables.erase(consumable)
	add_node_to_pool(consumable, _consumable_pool_id)

	var item_box_gold_effect = RunData.get_player_effect(Keys.item_box_gold_hash, player_index)
	if consumable.consumable_data.my_id_hash == Keys.consumable_item_box_hash or consumable.consumable_data.my_id_hash == Keys.consumable_legendary_item_box_hash and item_box_gold_effect != 0:
		RunData.add_gold(item_box_gold_effect, player_index)
		RunData.add_tracked_value(player_index, Keys.item_bag_hash, item_box_gold_effect)

	var consumable_data = consumable.consumable_data
	if consumable_data.to_be_processed_at_end_of_wave:
		var consumable_to_process = UpgradesUI.ConsumableToProcess.new()
		consumable_to_process.consumable_data = consumable_data

		var player_index_to_add_to = player_index

		if ProgressData.settings.share_coop_loot:

			player_index_to_add_to = randi() % RunData.get_player_count()

			for i in RunData.get_player_count():
				if _consumables_to_process[i].size() < _consumables_to_process[player_index_to_add_to].size():
					player_index_to_add_to = i

		consumable_to_process.player_index = player_index_to_add_to
		# Gourmet DLC - P2W lootboxes carry their rolled rarity into the wave-end
		# queue, and the pickup HUD shows the rung-colored crate rather than the
		# vanilla green box (display duplicate; the data is otherwise identical)
		var display_consumable = consumable_data
		if consumable.has_meta("p2w_rung") and int(consumable.get_meta("p2w_rung")) > 0:
			consumable_to_process.p2w_rung = int(consumable.get_meta("p2w_rung"))
			display_consumable = consumable_data.duplicate()
			display_consumable.icon = load("res://items/custom/p2w/chest_%d/chest_%d.png" % [consumable_to_process.p2w_rung, consumable_to_process.p2w_rung])
			consumable_to_process.consumable_data = display_consumable
		_consumables_to_process[player_index_to_add_to].push_back(consumable_to_process)
		_things_to_process_player_containers[player_index_to_add_to].consumables.add_element(display_consumable)

	# Gourmet DLC - After-Dinner Mints count FOOD and fruit only. Item crates are consumables
	# too, and counting those meant the Mints ticked on shop loot rather than on eating.
	if consumable_data.my_id.begins_with("consumable_food_") or consumable_data.my_id == "consumable_fruit":
		count_food_trigger(Keys.consumable_count_foods_hash, player_index)

	# Gourmet DLC - on-eat item effects for foods: Snack Break materials, Grease
	# Fire melee-range ignition, Food Fight projectile, Buffet Insurance tracking
	if consumable_data.my_id.begins_with("consumable_food_"):
		_ate_food_this_wave[player_index] = true
		GourmetTracker.ev("food_pickup", {"f": consumable_data.my_id, "p": player_index})
		var eat_effects = RunData.get_player_effects(player_index)
		var eat_player: Player = _players[player_index]

		for _s in range(eat_effects[Keys.snack_break_hash]):
			if randf() < 0.1:
				RunData.add_gold(RunData.current_wave, player_index)
				RunData.add_tracked_value(player_index, Keys.generate_hash("item_snack_break"), RunData.current_wave)
				GourmetTracker.ev("snack_break", {"p": player_index, "mats": RunData.current_wave})

		if eat_effects[Keys.grease_fire_hash] > 0 and not eat_player.dead:
			var grease_appetite: float = max(0.0, Utils.get_stat(Keys.stat_appetite_hash, player_index))
			var grease_burn: = BurningData.new()
			grease_burn.chance = 1.0
			grease_burn.duration = 3
			grease_burn.damage = int((2.0 + 0.2 * grease_appetite) * eat_effects[Keys.grease_fire_hash])
			grease_burn.scaling_stats = [[Keys.stat_elemental_damage_hash, 0.5]]
			grease_burn.from = eat_player
			for grease_enemy in _entity_spawner.enemies:
				if is_instance_valid(grease_enemy) and not grease_enemy.dead and eat_player.global_position.distance_to(grease_enemy.global_position) <= 150.0:
					grease_enemy.apply_burning(grease_burn)
					RunData.add_tracked_value(player_index, Keys.generate_hash("item_grease_fire"), 1)
					GourmetTracker.count("grease_ignites")

		# Burp of Power: eating shoves nearby enemies away
		if eat_effects[Keys.burp_of_power_hash] > 0 and not eat_player.dead:
			knockback_burst(eat_player.global_position, eat_effects[Keys.burp_of_power_hash], 250.0)
			GourmetTracker.count("burp_bursts")

		var projectiles_on_eat = eat_effects[Keys.projectiles_on_eat_hash]
		if projectiles_on_eat.size() > 0 and not eat_player.dead:
			GourmetTracker.count("food_fight_projectiles", projectiles_on_eat[0])
			var eat_proj_stats = WeaponService.init_ranged_stats(projectiles_on_eat[1], player_index, true)
			for _p in projectiles_on_eat[0]:
				_spawn_projectile_args.damage_tracking_key_hash = Keys.generate_hash("item_food_fight")
				_spawn_projectile_args.from_player_index = player_index
				var _eat_projectile = WeaponService.manage_special_spawn_projectile(
					eat_player,
					eat_proj_stats,
					rand_range( - PI, PI),
					projectiles_on_eat[2],
					_entity_spawner,
					eat_player,
					_spawn_projectile_args
				)

	# Wine Cellar: how long this food sat on the ground decides its aged bonus
	var picked_food_age: float = - 1.0
	if consumable.has_meta("food_spawned_at"):
		picked_food_age = _food_wave_time - consumable.get_meta("food_spawned_at")
	_players[player_index].on_consumable_picked_up(consumable_data, picked_food_age)

	if not _cleaning_up:
		RunData.handle_explode_effect(Keys.explode_on_consumable_hash, consumable.global_position, player_index)
		RunData.handle_explode_effect(Keys.explode_on_consumable_burning_hash, consumable.global_position, player_index)

	RunData.apply_item_effects(consumable.consumable_data, player_index)


func spawn_gold(value: float, pos: Vector2, spread: int) -> void :
	var value_floored: = int(value)
	var residual_chance: = value - value_floored
	var spawn_count: = (value_floored + 1) if Utils.get_chance_success(residual_chance) else value_floored
	for _i in range(spawn_count):

		if _active_golds.size() >= MAX_GOLDS:
			var gold_boosted = Utils.get_rand_element(_active_golds)
			gold_boosted.value += Gold.INITIAL_VALUE
			gold_boosted.scale = Vector2(
				min(gold_boosted.scale.x + Gold.INITIAL_VALUE * 0.05, Gold.MAX_SIZE), 
				min(gold_boosted.scale.y + Gold.INITIAL_VALUE * 0.05, Gold.MAX_SIZE)
			)
			continue

		var gold = get_node_from_pool(_gold_pool_id, _materials_container)
		if gold == null:
			gold = gold_scene.instance()
			_materials_container.call_deferred("add_child", gold)
			var _error = gold.connect("picked_up", self, "on_gold_picked_up")
			_error = gold.connect("picked_up", _effects_manager, "on_gold_picked_up")
			_error = gold.connect("picked_up", _floating_text_manager, "on_gold_picked_up")
			yield(gold, "ready")

		if RunData.bonus_gold > 0:
			var gold_value = gold.value
			gold.value += min(gold.value, RunData.bonus_gold)
			gold.boosted = 2
			gold.scale.x = 1.25
			gold.scale.y = 1.25
			RunData.remove_bonus_gold(gold_value)

		gold.set_texture(gold_sprites.pick_random())
		gold.already_picked_up = false
		var dist = rand_range(50, 100 + spread)
		var push_back_destination = ZoneService.get_rand_pos_in_area(pos, dist, 0)
		gold.drop(pos, rand_range(0, 2 * PI), push_back_destination)
		_active_golds.push_back(gold)

		for player in _get_shuffled_live_players():
			var instant_gold_attracting = RunData.get_player_effect(Keys.instant_gold_attracting_hash, player.player_index)
			if instant_gold_attracting != 0 and randf() < instant_gold_attracting / 100.0:
				if RunData.get_player_effect_bool(Keys.stat_has_lootworm_hash, player.player_index) and _entity_spawner.lootworms[player.player_index] != null:
					gold.attracted_by = _entity_spawner.lootworms[player.player_index]
				else:
					gold.attracted_by = player
				gold.set_physics_process(true)
				break
	emit_signal("gold_spawned")


func get_gold_value(entity_type: int, args: Entity.DieArgs, base_value: float, unit: Unit = null) -> float:
	var value = base_value
	var coop_factor: float = CoopService.get_coop_materials_factor()
	value += value * coop_factor

	var nb_players = RunData.get_player_count()
	var gold_drops: int = RunData.sum_all_player_effects(Keys.gold_drops_hash) / nb_players
	var enemy_gold_drops: int = RunData.sum_all_player_effects(Keys.enemy_gold_drops_hash) / nb_players
	var neutral_gold_drops: int = RunData.sum_all_player_effects(Keys.neutral_gold_drops_hash) / nb_players

	if entity_type == EntityType.ENEMY:
		var total_effect: = gold_drops + enemy_gold_drops
		value += value * total_effect / 100.0

	elif entity_type == EntityType.NEUTRAL:
		var total_effect: = gold_drops + neutral_gold_drops
		value += value * total_effect / 100.0

	else:
		value += value * gold_drops / 100.0

	value = max(value, MIN_GOLD_CHANCE * base_value)

	if not unit:
		return value

	var value_modifier_from_effect_behaviors = 0.0
	for effect_behavior in unit.effect_behaviors.get_children():
		value_modifier_from_effect_behaviors += effect_behavior.get_gold_value_modifier()
	value *= 1.0 + value_modifier_from_effect_behaviors

	if args.killed_by_player_index >= 0 and args.killed_by_player_index < _players.size() and is_instance_valid(_players[args.killed_by_player_index]):
		var scale_gold_effect: Array = RunData.get_player_effect(Keys.scale_materials_with_distance_hash, args.killed_by_player_index)
		if entity_type != EntityType.NEUTRAL and args.enemy_killed_by_player and scale_gold_effect.size() > 0:
			var dist_to_player: = unit.global_position.distance_to(_players[args.killed_by_player_index].global_position)
			var scaling_percentage: int = scale_gold_effect[0].get_scaling_value(dist_to_player)
			value *= 1.0 + scaling_percentage / 100.0

	return value


func on_gold_picked_up(gold: Node, player_index: int) -> void :
	if gold.already_picked_up:
		return

	gold.already_picked_up = true
	_active_golds.erase(gold)
	add_node_to_pool(gold, _gold_pool_id)

	# Gourmet DLC - Deep Fryer counts materials collected
	if player_index >= 0:
		count_food_trigger(Keys.material_foods_hash, player_index, int(gold.value))

	if player_index >= 0:
		if ProgressData.settings.alt_gold_sounds:
			SoundManager.play(Utils.get_rand_element(gold_alt_pickup_sounds), - 5, 0.2)
		else:
			SoundManager.play(Utils.get_rand_element(gold_pickup_sounds), 0, 0.2)

		var increase_effect: int = RunData.get_player_effect(Keys.increase_material_value_hash, player_index)
		var value = gold.value
		value += value * (increase_effect / 100.0)

		var boost = RunData.apply_common_gold_pickup_effects(gold.value, player_index)
		value *= boost
		gold.boosted *= boost

		if Utils.get_chance_success(RunData.get_player_effect(Keys.heal_when_pickup_gold_hash, player_index) / 100.0):
			RunData.emit_signal("healing_effect", 1, player_index, Keys.item_cute_monkey_hash)

		var dmg_when_pickup_gold_effect = RunData.get_player_effect(Keys.dmg_when_pickup_gold_hash, player_index)
		if dmg_when_pickup_gold_effect.size() > 0:
			handle_stat_damages(dmg_when_pickup_gold_effect, player_index)

		var highest_cd_weapon_that_should_reload = null

		for weapon in _players[player_index].current_weapons:
			for effect in weapon.effects:
				if effect.key_hash == Keys.reload_when_pickup_gold_hash:
					if not weapon._is_shooting and (highest_cd_weapon_that_should_reload == null or weapon._current_cooldown > highest_cd_weapon_that_should_reload._current_cooldown):
						highest_cd_weapon_that_should_reload = weapon

		if highest_cd_weapon_that_should_reload:
			highest_cd_weapon_that_should_reload._current_cooldown = 0

		for structure in _entity_spawner.structures:
			if structure is BuilderTurret:
				for effect in structure.effects:
					if effect.key_hash == Keys.reload_when_pickup_gold_hash:
						structure._cooldown = 0

		if RunData.get_player_effect_bool(Keys.reload_when_pickup_gold_hash, player_index):
			for weapon in _players[player_index].current_weapons:
				weapon._current_cooldown = 0


		
		var player_gold: = [0, 0, 0, 0]
		var player_xp: = [0, 0, 0, 0]
		while value > 0:
			player_gold[_next_gold_player] += 1
			player_xp[_next_gold_player] += 1
			value -= 1
			_next_gold_player = (_next_gold_player + 1) % RunData.get_player_count()

		for i in RunData.get_player_count():
			RunData.add_gold(player_gold[i], i)
			RunData.add_xp(player_xp[i], i)

		ProgressData.increment_stat("materials_collected")
		return

	if _cleaning_up:
		RunData.add_bonus_gold(gold.value)



func on_levelled_up(player_index: int) -> void :
	SoundManager.play(level_up_sound, 0, 0, true)
	# Gourmet DLC - Baker's Oven bakes on every level up
	count_food_trigger(Keys.level_up_foods_hash, player_index)
	var level = RunData.get_player_level(player_index)
	_things_to_process_player_containers[player_index].upgrades.add_element(ItemService.get_icon(Keys.icon_upgrade_to_process_hash), level)

	var upgrade_to_process = UpgradesUI.UpgradeToProcess.new()
	upgrade_to_process.level = level
	upgrade_to_process.player_index = player_index
	_upgrades_to_process[player_index].push_back(upgrade_to_process)

	_players_ui[player_index].update_level_label()

	RunData.add_stat(Keys.stat_max_hp_hash, 1, player_index)
	for stat_level_up in RunData.get_player_effect(Keys.stats_on_level_up_hash, player_index):
		assert (stat_level_up[0] is int)
		RunData.add_stat(stat_level_up[0], stat_level_up[1], player_index)

		if stat_level_up[0] == Keys.stat_lifesteal_hash:
			RunData.add_tracked_value(player_index, Keys.item_decomposing_flesh_hash, stat_level_up[1])
		elif stat_level_up[0] == Keys.stat_hp_regeneration_hash:
			RunData.add_tracked_value(player_index, Keys.item_baby_squid_hash, stat_level_up[1])
		elif stat_level_up[0] == Keys.stat_curse_hash:
			var val = stat_level_up[1]

			
			

			if RunData.get_player_character(player_index).my_id_hash == Keys.character_creature_hash:
				val -= 1

			if val > 0:
				RunData.add_tracked_value(player_index, Keys.item_barnacle_hash, 1)


func on_xp_added(current_xp: float, max_xp: float, player_index: int) -> void :
	var player_ui: PlayerUIElements = _players_ui[player_index]
	var display_xp = int(current_xp) % int(ceil(max_xp))
	player_ui.xp_bar.update_value(display_xp, int(max_xp))


func connect_visual_effects(unit: Unit) -> void :
	var _error_effects = unit.connect("took_damage", _effects_manager, "_on_unit_took_damage")
	var _error_floating_text = unit.connect("took_damage", _floating_text_manager, "_on_unit_took_damage")
	var _error_crit_effect = unit.connect("crit_effect", _effects_manager, "_on_weapon_did_crit")
	var _error_one_shot_effect = unit.connect("one_shot_effect", _effects_manager, "on_one_shot")


func clean_up_room() -> void :
	_set_run_states()

	# Gourmet DLC - Debtor: debt takes +10% interest at the end of each cleared wave (before the
	# shop). Skipped on a lost run - no point compounding into a game over.
	if not _is_run_lost:
		RunData.apply_debt_interest()

	_ui_dim_screen.dim()
	_wave_timer.stop()
	for timer in _half_second_timers.get_children():
		if timer is Timer:
			timer.stop()


	_enemy_projectiles.queue_free()

	if _is_run_lost:
		_end_wave_timer.wait_time = 0.5
		DebugService.log_data("is_run_lost")

	elif _is_run_won:
		_end_wave_timer.wait_time = 4
		RunData.apply_run_won()

	if _is_wave_failed:
		MusicManager.tween( - 20)
		if RunData.current_wave > 1:
			_end_wave_timer.wait_time = 0.5

	_end_wave_timer.start()

	if RunData.current_wave % 10 == 0 and RunData.current_wave >= 10:
		RunData.init_elites_spawn(RunData.current_wave + 10, 0.0)
		RunData.init_events_nightmare(RunData.current_wave + 10)

	if RunData.is_endless_run:

		DebugService.log_data("is_endless_run")

		if RunData.current_wave >= 20:
			for player_index in RunData.get_player_count():
				var character_difficulty = ProgressData.get_character_difficulty_info(RunData.players_data[player_index].current_character.my_id_hash, RunData.current_zone)

				character_difficulty.max_endless_wave_beaten.set_info(
					RunData.current_difficulty, 
					RunData.current_wave, 
					RunData.current_run_accessibility_settings.health, 
					RunData.current_run_accessibility_settings.damage, 
					RunData.current_run_accessibility_settings.speed, 
					RunData.retries, 
					0 if not RunData.is_ban_active_in_current_run() else RunData.get_used_ban_count(), 
					RunData.constant_projectile, 
					RunData.is_coop_run, 
					true
				)

	ProgressData.save()

	SoundManager.play(Utils.get_rand_element(end_wave_sounds))
	_cleaning_up = true
	_effects_manager.clean_up_room()
	_floating_text_manager.clean_up_room()

	DebugService.log_data("attract bonus_gold and consumables...")
	if _active_golds.size() > 0:
		var attracted_by = null

		_ui_bonus_gold.show()
		attracted_by = _gold_bag

		for player in _players:
			player.disable_gold_pickup()

		var nb_builders = 0
		var indexes_builder = []

		for player_id in RunData.players_data.size():
			if RunData.get_player_character(player_id).my_id_hash == Keys.character_builder_hash:
				nb_builders += 1
				indexes_builder.push_back(player_id)

		if nb_builders > 0:
			for structure in _entity_spawner.structures:
				if structure is BuilderTurret:
					override_gold_bag_pos = structure.global_position
					var _e = RunData.connect("bonus_gold_converted", structure, "on_bonus_gold_converted")
					_e = structure.connect("stat_added", _floating_text_manager, "on_turret_stat_added")
					structure.main_ref = self

		if ProgressData.settings.optimize_end_waves:
			var bonus_gold_value = 0
			var player_count = RunData.get_player_count()
			for i in _active_golds.size():
				var gold = _active_golds[i]
				var player_index = i % player_count
				var boost = RunData.apply_common_gold_pickup_effects(gold.value, player_index)
				bonus_gold_value += gold.value * boost
				gold.boosted *= boost
				gold.visible = false

			RunData.add_bonus_gold(bonus_gold_value)
		else:
			for gold in _active_golds:
				gold.collision_layer = Utils.BONUS_GOLD_BIT
				gold.attracted_by = attracted_by
				gold.set_physics_process(true)

	var live_players: = _get_shuffled_live_players()
	if not live_players.empty():
		for i in _consumables.size():
			var player = live_players[i % live_players.size()]
			var consumable: Consumable = _consumables[i]
			if not consumable.has_damage_effect():
				consumable.attracted_by = player
				consumable.set_physics_process(true)

	DebugService.log_data("clean_up other objects...")
	_entity_spawner.clean_up_room()
	_wave_manager.clean_up_room()

	for player in _players:
		if is_instance_valid(player):
			player.on_room_cleanup()

	
	if _is_run_won:
		for player_index in RunData.get_player_count():
			var player: Player = _players[player_index]
			player.won()
		yield(_players[0], "run_won_screen")
		SoundManager.play(Utils.get_rand_element(run_won_sounds), - 5, 0, true)

	DebugService.log_data("start wave_cleared_label...")
	_wave_cleared_label.start(_is_wave_failed, _is_run_lost, _is_run_won)
	DebugService.log_data("wave_cleared_label started...")


func _set_run_states() -> void :
	var live_players: = _get_live_players()
	var all_players_dead: = live_players.empty()

	_is_wave_failed = all_players_dead
	if RunData.current_wave < RunData.nb_of_waves:
		if all_players_dead:
			_is_run_lost = true

	if RunData.current_wave == RunData.nb_of_waves:
		if RunData.is_endless_run:
			if all_players_dead and RunData.all_last_wave_bosses_killed:
				_is_run_won = true
			elif all_players_dead:
				_is_run_lost = true
		else:
			if all_players_dead:
				_is_run_lost = true
			else:
				_is_run_won = true

	if RunData.current_wave > RunData.nb_of_waves:
		if all_players_dead:
			_is_run_won = true

	RunData.run_won = _is_run_won
	if _is_run_won:
		ProgressData.increment_stat("run_won")


func get_gold_bag_pos() -> Vector2:

	if override_gold_bag_pos != Vector2.ZERO:
		return override_gold_bag_pos

	return get_viewport().get_canvas_transform().affine_inverse().xform(_ui_bonus_gold_pos.global_position)


func _on_EndWaveTimer_timeout() -> void :
	GourmetTracker.flush_counters("wave_end")
	for i in _players.size():
		var end_effects = RunData.get_player_effects(i)
		GourmetTracker.ev("wave_end", {"p": i, "ate": _ate_food_this_wave[i], "bank": end_effects[Keys.banked_leftovers_hash], "buys": end_effects[Keys.shop_purchases_hash], "s": GourmetTracker.stat_snapshot(i)})

		# Gourmet DLC - Butcher: 20% of the temp Damage he built this wave (1% per consumable
		# eaten) is rendered down into PERMANENT Appetite. His per-wave counter resets with the
		# wave either way, so this is the only thing that carries the meal forward.
		var butcher_character = RunData.get_player_character(i)
		if butcher_character != null and butcher_character.my_id == "character_butcher":
			var butcher_player: Player = _players[i]
			if is_instance_valid(butcher_player) and butcher_player._butcher_wave_damage > 0:
				var rendered_appetite: int = int(butcher_player._butcher_wave_damage * BUTCHER_APPETITE_SHARE)
				if rendered_appetite > 0:
					RunData.add_stat(Keys.stat_appetite_hash, rendered_appetite, i)
					RunData.add_tracked_value(i, butcher_character.get_my_id_hash(), rendered_appetite, 1)
					GourmetTracker.ev("butcher_render", {"p": i, "dmg": butcher_player._butcher_wave_damage, "app": rendered_appetite})
				butcher_player._butcher_wave_damage = 0

	_coop_upgrades_ui.propagate_call("set_process_input", [true])
	DebugService.log_data("_on_EndWaveTimer_timeout")
	SoundManager.clear_queue()
	SoundManager2D.clear_queue()
	InputService.set_gamepad_echo_processing(true)

	_end_wave_timer_timedout = true

	if _is_wave_failed and RunData.current_wave > 0:
		_retry_wave.show()
		_pause_menu.enabled = false
		return

	_wave_cleared_label.hide()
	_wave_timer_label.hide()

	_camera.move_speed_factor = 0.0
	_camera.zoom_in_speed_factor = 0.0
	_camera.zoom_out_speed_factor = 0.0

	RunData.on_wave_end()
	LinkedStats.reset()

	var scene: String
	var _args: Entity.DieArgs = Utils.default_die_args
	if _is_run_lost or _is_run_won:
		DebugService.log_data("end run...")
		scene = RunData.get_end_run_scene_path()
	else:
		DebugService.log_data("process consumables and upgrades...")
		MusicManager.tween( - 8)

		if RunData.is_coop_run:
			
			_hud.hide()
			if _coop_upgrades_ui.show_options(_consumables_to_process, _upgrades_to_process):
				yield(_coop_upgrades_ui, "options_processed")
			_coop_upgrades_ui.hide()
		else:
			if _upgrades_ui.show_options(_consumables_to_process, _upgrades_to_process):
				var things_to_process_player_container = _things_to_process_player_containers[0]
				var ui_consumables_to_process = things_to_process_player_container.consumables
				var ui_upgrades_to_process = things_to_process_player_container.upgrades
				while not ui_consumables_to_process.is_empty():
					var consumable = yield(_upgrades_ui, "consumable_selected")
					ui_consumables_to_process.remove_element(consumable.consumable_data)
				while not ui_upgrades_to_process.is_empty():
					var args = yield(_upgrades_ui, "upgrade_selected")
					var upgrade = args[1]
					ui_upgrades_to_process.remove_element(upgrade.level)
				yield(_upgrades_ui, "options_processed")
			_upgrades_ui.hide()

		DebugService.log_data("display challenge ui...")
		if _is_chal_ui_displayed:
			yield(_challenge_completed_ui, "finished")

		scene = RunData.get_shop_scene_path()

	_change_scene(scene)


func on_upgrade_selected(upgrade_data: UpgradeData, upgrade: UpgradesUI.UpgradeToProcess) -> void :
	RunData.apply_item_effects(upgrade_data, upgrade.player_index)


func on_item_box_take_button_pressed(item_data: ItemParentData, consumable: UpgradesUI.ConsumableToProcess) -> void :
	# Gourmet DLC - P2W lootboxes can hold weapons; vanilla crates never did. The
	# choice screen hides Take when no slot is free, so this is the happy path;
	# the gold fallback is belt-and-braces only.
	if item_data is WeaponData:
		var p2w_wpi: int = consumable.player_index
		if RunData.get_player_weapons_ref(p2w_wpi).size() < int(RunData.get_player_effect(Keys.weapon_slot_hash, p2w_wpi)):
			var _p2w_w = RunData.add_weapon(item_data, p2w_wpi)
		else:
			RunData.add_gold(item_data.value, p2w_wpi)
		return
	RunData.add_item(item_data, consumable.player_index)


func on_item_box_discard_button_pressed(item_data: ItemParentData, consumable: UpgradesUI.ConsumableToProcess) -> void :
	var player_index = consumable.player_index
	var value = ItemService.get_recycling_value(RunData.current_wave, item_data.value, player_index)
	RunData.add_gold(value, player_index)
	RunData.update_recycling_tracking_value(item_data, player_index)


func on_item_box_ban_button_pressed(item_data: ItemParentData, consumable: UpgradesUI.ConsumableToProcess) -> void :
	var player_index = consumable.player_index
	var value = floor(ItemService.get_recycling_value(RunData.current_wave, item_data.value, player_index))
	var player_run_data = RunData.players_data[player_index]
	player_run_data.banned_items.push_back(item_data.my_id_hash)
	player_run_data.remaining_ban_token -= 1
	RunData.add_gold(value, player_index)
	RunData.update_recycling_tracking_value(item_data, player_index)


func _on_PauseMenu_paused() -> void :
	InputService.set_gamepad_echo_processing(true)


func _on_PauseMenu_unpaused() -> void :
	_skip_pause_check = true

	if not _end_wave_timer_timedout:
		InputService.set_gamepad_echo_processing(false)

	elif _upgrades_ui.visible:
		
		
		_upgrades_ui.focus()


func _on_WaveTimer_timeout() -> void :
	DebugService.log_run_info(_upgrades_to_process, _consumables_to_process)
	ChallengeService.check_counted_challenges()
	check_lootworm_chal()

	for player_index in RunData.get_player_count():
		if _players[player_index] != null and is_instance_valid(_players[player_index]) and _players[player_index].current_stats.health == ChallengeService.get_chal(ChallengeService.chal_reckless_hash).value:
			ChallengeService.complete_challenge(ChallengeService.chal_reckless_hash)
			break

	if _entity_spawner.neutrals.size() >= ChallengeService.get_chal(ChallengeService.chal_forest_hash).value:
		ChallengeService.complete_challenge(ChallengeService.chal_forest_hash)

	for player_index in RunData.get_player_count():
		var stats_end_of_wave = RunData.get_player_effect(Keys.stats_end_of_wave_hash, player_index)
		var hsh: int = Keys.empty_hash
		for stat_end_of_wave in stats_end_of_wave:
			assert (stat_end_of_wave[0] is int)
			hsh = stat_end_of_wave[0]
			RunData.add_stat(hsh, stat_end_of_wave[1], player_index)

			if hsh == Keys.stat_percent_damage_hash:
				RunData.add_tracked_value(player_index, Keys.item_vigilante_ring_hash, stat_end_of_wave[1])
			elif hsh == Keys.stat_max_hp_hash:
				var leaf_value = 0
				var items = RunData.get_player_items_ref(player_index)
				for item in items:
					if item.my_id_hash == Keys.item_grinds_magical_leaf_hash:
						for effect in item.effects:
							if effect.key_hash != Keys.stat_curse_hash:
								leaf_value += effect.value
				RunData.add_tracked_value(player_index, Keys.item_grinds_magical_leaf_hash, leaf_value)
			elif hsh == Keys.stat_melee_damage_hash:
				var robot_arm_value = 0
				var items = RunData.get_player_items_ref(player_index)
				for item in items:
					if item.my_id_hash == Keys.item_robot_arm_hash:
						for effect in item.effects:
							if effect.key_hash != Keys.stat_curse_hash and effect.value > 0:
								robot_arm_value += effect.value
				RunData.add_tracked_value(player_index, Keys.item_robot_arm_hash, robot_arm_value)
			elif hsh == Keys.xp_gain_hash and stat_end_of_wave[1] > 0:
				RunData.add_tracked_value(player_index, Keys.item_celery_tea_hash, stat_end_of_wave[1])
			elif hsh == Keys.stat_armor_hash and stat_end_of_wave[1] < 0:
				RunData.add_tracked_value(player_index, Keys.item_ashes_hash, abs(stat_end_of_wave[1]) as int)

	for player_index in RunData.get_player_count():
		Utils.convert_stats(RunData.get_player_effect(Keys.convert_stats_end_of_wave_hash, player_index), player_index)

	# Gourmet DLC - The Special: tear the wave's modifiers back off, then roll the NEXT wave's
	# set so the shop can preview it. Teardown is the exact inverse of the wave-start apply.
	# LIFE_SHOP modifiers are deliberately NOT removed here: they exist to affect the shop that
	# is about to open, and are stripped when it closes (base_shop).
	for special_index in RunData.get_player_count():
		if not RunData.is_special(special_index):
			continue

		var sp_effects: Dictionary = RunData.get_player_effects(special_index)
		var active: Array = SpecialModifiers.stored_ids(Keys.special_active_mods_hash, special_index)
		if not active.empty():
			SpecialModifiers.unapply_ids(SpecialModifiers.ids_of_life(active, SpecialModifiers.LIFE_WAVE), special_index)
			sp_effects[Keys.special_active_mods_hash] = []

		# Never hand the player an event the wave was already going to run: two fog of wars, or
		# a "horde" roll on a wave that is already a horde, reads as broken.
		var blocked: = []
		var next_wave: int = RunData.current_wave + 1
		# The roll is for the NEXT wave, and the event schedules are fixed at run start - so
		# block against what the NEXT wave will actually run, not what this one did. (Current-
		# wave flags still matter for ENEMY_COUNT, whose elite/horde schedule lives in
		# RunData.elites_spawn keyed by wave.)
		# Fog and bullet hell are mutually exclusive in-engine (fog wins), so a natural wave
		# of EITHER kind blocks BOTH axes: forcing fog onto a bullet-hell wave would cancel
		# the bullet hell, and forcing a bullet hell onto a fog wave would silently no-op.
		var next_is_fog: bool = next_wave in RunData.events_fog_of_war and bool(RunData.get_player_effect(Keys.fog_of_war_event_hash, 0))
		var next_is_bullet_hell: bool = (RunData.constant_projectile == 2 or next_wave in RunData.events_bullet_hell)\
			 and bool(RunData.get_player_effect(Keys.bullet_hell_event_hash, 0)) and RunData.constant_projectile != 0
		# A Mole in the lobby means EVERY wave is fog - both event axes are dead all run.
		for mole_index in RunData.get_player_count():
			var mole_character = RunData.get_player_character(mole_index)
			if mole_character != null and mole_character.my_id == "character_mole":
				next_is_fog = true
				break
		if next_is_fog or next_is_bullet_hell:
			blocked.push_back("VISION")
			blocked.push_back("BULLET_HELL")
		if _is_elite_wave or _is_horde_wave:
			blocked.push_back("ENEMY_COUNT")
		var rolled: Array = SpecialModifiers.roll_for_wave(next_wave, special_index, blocked)
		sp_effects[Keys.special_next_mods_hash] = rolled

		# shop-scoped ones apply NOW so they are live in the shop that follows this wave
		var shop_ids: Array = SpecialModifiers.ids_of_life(rolled, SpecialModifiers.LIFE_SHOP)
		if not shop_ids.empty():
			SpecialModifiers.apply_ids(shop_ids, special_index)
			sp_effects[Keys.special_shop_mods_hash] = shop_ids.duplicate()

	emit_signal("end_of_the_wave")

	manage_harvesting()

	DebugService.log_data("start clean_up_room...")
	clean_up_room()

	TempStats.reset()

func check_lootworm_chal():
	if not ChallengeService.is_challenge_completed(ChallengeService.chal_lootworm_hash):
		var value: = 0
		for gold in _active_golds:
			value += gold.value

		if value >= ChallengeService.get_chal(ChallengeService.chal_lootworm_hash).value:
			ChallengeService.complete_challenge(ChallengeService.chal_lootworm_hash)
			RunData.check_beast_master_chal()

# Gourmet DLC - bring the Gourmet's fat stacks in line with how much he has eaten. Safe to call
# from anywhere and as often as you like: it derives the target from the eaten counter and only
# applies the DIFFERENCE, so it can never double-charge.
func reconcile_gourmet_fat(player_index: int) -> void :
	var effects: Dictionary = RunData.get_player_effects(player_index)
	var eaten: int = int(effects[Keys.gourmet_foods_eaten_hash])
	var wanted_fat: int = int(min(GOURMET_FAT_MAX_STACKS, eaten / GOURMET_FAT_PER_FOODS))
	var applied_fat: int = int(effects[Keys.gourmet_fat_hash])

	if wanted_fat == applied_fat:
		return

	var character = RunData.get_player_character(player_index)
	var fat_speed_lost: int = GOURMET_FAT_SPEED * (wanted_fat - applied_fat)
	RunData.add_stat(Keys.stat_speed_hash, - fat_speed_lost, player_index)
	if character != null:
		RunData.add_tracked_value(player_index, character.get_my_id_hash(), fat_speed_lost, 1)
	effects[Keys.gourmet_fat_hash] = wanted_fat


func manage_harvesting() -> void :
	for player_index in RunData.get_player_count():
		# Gourmet DLC - Freeloader: harvesting grants him nothing at all. add_gold is already
		# gated for him, but the add_xp paired with it on the next line would quietly make
		# Harvesting his single best stat, a hidden scaling stat this character is explicitly
		# not supposed to have. Skipping the whole block also suppresses the misleading
		# floating harvest number and the pointless harvest-timer restart.
		if RunData.is_freeloader(player_index):
			continue

		var pacifist_effect = RunData.get_player_effect(Keys.pacifist_hash, player_index)
		var cryptid_effect = RunData.get_player_effect(Keys.cryptid_hash, player_index)
		var materials_per_living_enemy_effect = RunData.get_player_effect(Keys.materials_per_living_enemy_hash, player_index)
		var charmed_enemy_bonus = 0

		for enemy in _entity_spawner.enemies:
			if enemy.get_charmed_by_player_index() != - 1:
				charmed_enemy_bonus += get_gold_value(EntityType.ENEMY, Utils.default_die_args, enemy.stats.value)

		var harvesting_stat = Utils.get_stat(Keys.stat_harvesting_hash, player_index)
		if harvesting_stat != 0 or pacifist_effect != 0 or _elite_killed_bonus != 0\
		or (cryptid_effect != 0 and RunData.current_living_trees != 0) or materials_per_living_enemy_effect != 0 or charmed_enemy_bonus > 0:
			var pacifist_bonus = round((_entity_spawner.get_all_enemies().size() + _entity_spawner.enemies_removed_for_perf) * (pacifist_effect / 100.0))
			var cryptid_bonus = RunData.current_living_trees * cryptid_effect
			var living_enemy_bonus = _entity_spawner.enemies.size() * materials_per_living_enemy_effect

			if _is_horde_wave:
				pacifist_bonus = (pacifist_bonus / 2) as int

			var val = harvesting_stat + pacifist_bonus + cryptid_bonus + _elite_killed_bonus + living_enemy_bonus + charmed_enemy_bonus

			if val >= 0:
				RunData.add_gold(val, player_index)
				RunData.add_xp(val, player_index)
			else:
				RunData.remove_gold(abs(val) as int, player_index)

			_floating_text_manager.on_harvested(val, player_index)

			if harvesting_stat > 0:
				_harvesting_timer.start()

			RunData.add_xp(0, player_index)


func _get_live_players() -> Array:
	var live_players: = []
	for player in _players:
		if not player.dead:
			live_players.append(player)

	return live_players




func _get_shuffled_live_players() -> Array:
	var live_players: = _get_live_players()
	live_players.shuffle()
	return live_players



func _change_scene(path: String) -> void :
	if Utils.is_on_console():
		OS_Seaven.set_fast_cpu_mode(true)
	var _error = get_tree().change_scene(path)
	if Utils.is_on_console():
		OS_Seaven.set_fast_cpu_mode(false)


func _on_UIBonusGold_mouse_entered() -> void :
	if _cleaning_up:
		_info_popup.display(_ui_bonus_gold, Text.text("INFO_BONUS_GOLD", [str(RunData.bonus_gold)]))


func _on_UIBonusGold_mouse_exited() -> void :
	_info_popup.hide()


func _on_EntitySpawner_players_spawned(players: Array) -> void :
	_players = players
	_camera.targets = players
	_floating_text_manager.players = _players
	_floating_text_manager.players_add_stats_count = []
	for player in _players:
		_floating_text_manager.players_add_stats_count.push_back(0)

	
	EffectBehaviorService.update_active_effect_behaviors()

	if _players.size() > 1:
		_damage_vignette.active = false

	_players_ui.clear()
	for i in _players.size():
		var effects = RunData.get_player_effects(i)

		var player_ui: = PlayerUIElements.new()
		var player_idx_string = str(i + 1)

		player_ui.player_index = i
		player_ui.player_life_bar = get_node("%%PlayerLifeBarContainerP%s/PlayerLifeBarP%s" % [player_idx_string, player_idx_string])
		player_ui.player_life_bar_container = get_node("%%PlayerLifeBarContainerP%s" % player_idx_string)
		player_ui.hud_container = get_node("%%LifeContainerP%s" % player_idx_string)
		player_ui.life_bar = get_node("%%UILifeBarP%s" % player_idx_string)
		player_ui.life_label = get_node("%%UILifeBarP%s/MarginContainer/LifeLabel" % player_idx_string)
		player_ui.hit_protection = get_node("%%LifeContainerP%s/UIHitProtection" % player_idx_string)
		player_ui.xp_bar = get_node("%%UIXPBarP%s" % player_idx_string)
		player_ui.level_label = get_node("%%UIXPBarP%s/MarginContainer/LevelLabel" % player_idx_string)
		player_ui.gold = get_node("%%UIGoldP%s" % player_idx_string)

		
		player_ui.life_label.set_message_translation(false)
		player_ui.level_label.set_message_translation(false)

		_players_ui.push_back(player_ui)

		player_ui.update_hud(_players[i])
		player_ui.hud_visible = true
		player_ui.set_hud_position(i)

		_players[i].get_life_bar_remote_transform().remote_path = player_ui.player_life_bar_container.get_path()
		_players[i].current_stats.health = max(1, _players[i].max_stats.health * (effects[Keys.hp_start_wave_hash] / 100.0)) as int

		if effects[Keys.hp_start_next_wave_hash] != 100:
			_players[i].current_stats.health = max(1, _players[i].max_stats.health * (effects[Keys.hp_start_next_wave_hash] / 100.0)) as int
			effects[Keys.hp_start_next_wave_hash] = 100

		_players[i].check_hp_regen()

		# Gourmet DLC - Gourmet: one fat stack per GOURMET_FAT_PER_FOODS consumables eaten
		# (was one per wave). Still DERIVED from the running total and reconciled against what
		# was already applied rather than incremented, so it is idempotent: retrying a wave, or
		# running this alongside the live update in player.gd, cannot double-charge the Speed.
		var fat_character = RunData.get_player_character(i)
		if fat_character != null and fat_character.my_id == "character_gourmet":
			reconcile_gourmet_fat(i)
			_players[i].set_body_scale(1.0 + GOURMET_FAT_SIZE * int(effects[Keys.gourmet_fat_hash]))

		# Gourmet DLC - Tourist: +10% to all stat modifications per Danger level, once per run
		var tourist_character = RunData.get_player_character(i)
		if tourist_character != null and tourist_character.my_id == "character_tourist" and effects[Keys.tourist_danger_done_hash] == 0:
			effects[Keys.tourist_danger_done_hash] = 1
			# Gourmet DLC - Tourist XP: -15% XP Gain on any run except Danger 0, where the
			# sightseer gets +15% instead. Applied here rather than as a card stat effect
			# because its SIGN depends on the run's Danger, which a static tres cannot express.
			# Card mirror: the EFFECT_TOURIST_XP line states both halves of the rule.
			# Sits outside the danger_gain > 0 guard below: Danger 0 is exactly when it flips.
			effects[Keys.xp_gain_hash] += TOURIST_XP_GAIN if RunData.current_difficulty == 0 else - TOURIST_XP_GAIN
			var danger_gain = RunData.current_difficulty * 10
			if danger_gain > 0:
				for tourist_stat in ["stat_max_hp", "stat_hp_regeneration", "stat_lifesteal", "stat_percent_damage", "stat_melee_damage", "stat_ranged_damage", "stat_elemental_damage", "stat_attack_speed", "stat_crit_chance", "stat_engineering", "stat_range", "stat_armor", "stat_dodge", "stat_speed", "stat_luck", "stat_harvesting"]:
					effects[Keys.generate_hash("gain_" + tourist_stat)] += danger_gain
				effects[Keys.generate_hash("enemy_health")] += 5 * RunData.current_difficulty
				effects[Keys.enemy_attack_speed_hash] += 5 * RunData.current_difficulty
			_players[i].update_player_stats()

		# Gourmet DLC - food buff HUD row, sits under the player's life container
		var food_buffs_display = preload("res://ui/hud/food_buffs_display.gd").new()
		food_buffs_display.player = _players[i]
		# bottom-screen players (positions 2/3): the buff grid sits ABOVE their
		# bars and its columns grow upward instead of down
		food_buffs_display.grow_up = i >= 2
		player_ui.hud_container.add_child(food_buffs_display)
		if i >= 2:
			player_ui.hud_container.move_child(food_buffs_display, 0)

		# Gourmet DLC - wave-start food spawners (e.g. Espresso Machine): each owned spawner
		# appended [food_id_hash, count] into wave_start_foods via its KEY_VALUE effect
		for wave_start_food in effects[Keys.wave_start_foods_hash]:
			var wave_start_food_data = ItemService.get_food_from_hash(wave_start_food[0])
			if wave_start_food_data != null:
				for food_index in range(wave_start_food[1]):
					# evenly spread angles with jitter so spawns never stack on each other
					# (wrapped positive so the -1 random-angle sentinel never triggers)
					var spawn_angle: float = wrapf(TAU * food_index / wave_start_food[1] + rand_range(-0.4, 0.4), 0.0, TAU)
					spawn_food(wave_start_food_data, _players[i].global_position, spawn_angle, i)

		# Gourmet DLC - Delivery Drone: every owned food spawner (identified by its
		# consumable_food_* display effect, one per spawner item) serves its food
		# once per drone at wave start. Doggy Bag is excluded: Leftovers are a
		# banked bonus, not a ground food.
		var drone_count: int = int(effects[Keys.delivery_drone_hash])
		if drone_count > 0:
			var drone_delivered: int = 0
			for drone_item in RunData.get_player_items_ref(i):
				for drone_effect in drone_item.effects:
					if drone_effect.custom_key.begins_with("consumable_food_") and drone_effect.custom_key != "consumable_food_leftovers":
						var drone_food = ItemService.get_food_from_hash(Keys.generate_hash(drone_effect.custom_key))
						if drone_food != null:
							for _drone_serving in range(drone_count):
								spawn_food(drone_food, _players[i].global_position, - 1.0, i)
								drone_delivered += 1
						break
			if drone_delivered > 0:
				RunData.add_tracked_value(i, Keys.generate_hash("item_delivery_drone"), drone_delivered)
				GourmetTracker.ev("drone_deliveries", {"p": i, "n": drone_delivered})

		# Gourmet DLC - schedule mid-wave foods (Pizza Delivery once; Street Vendor 1 to 3 times)
		var food_wave_duration: float = _wave_timer.wait_time
		for mid_wave_food in effects[Keys.mid_wave_foods_hash]:
			for _j in range(mid_wave_food[1]):
				_food_scheduled_spawns[i].push_back([rand_range(0.3, 0.7) * food_wave_duration, mid_wave_food[0], 1])
		for random_times_food in effects[Keys.random_times_foods_hash]:
			# Gourmet DLC - Street Vendor: a FLAT 3 to 6 servings per wave per copy owned.
			# Appetite used to shift both ends by 0.3 each, which made the item's whole output
			# a function of a stat you may not be building; the range is now what the card says.
			for _j in range(random_times_food[1]):
				for _k in range(Utils.randi_range(STREET_VENDOR_MIN_SERVINGS, STREET_VENDOR_MAX_SERVINGS)):
					_food_scheduled_spawns[i].push_back([rand_range(0.15, 0.85) * food_wave_duration, random_times_food[0], 1])

		# Gourmet DLC - Farmers' Market: shop rerolls banked last shop become Fruit Salads now
		var banked_rerolls: int = effects[Keys.banked_rerolls_hash]
		if banked_rerolls > 0:
			for reroll_banked_food in effects[Keys.reroll_banked_foods_hash]:
				if ItemService.get_food_from_hash(reroll_banked_food[0]) != null:
					# scheduled slightly into the wave so the market stall exists as anchor
					_food_scheduled_spawns[i].push_back([0.5, reroll_banked_food[0], banked_rerolls * reroll_banked_food[1]])
		effects[Keys.banked_rerolls_hash] = 0

		# Gourmet DLC - Doggy Bag: every banked Leftover is SERVED BACK as a real Leftovers
		# food, one per bank, scattered across the whole wave and anywhere on the field. The
		# damage is no longer automatic - you have to go and eat your own scraps, and each one
		# eaten is +1% Damage for the rest of the wave (uncapped, see the food's stack cap).
		# The bank itself never resets, so a run-long hoard means a wave-long scavenger hunt.
		if effects[Keys.doggy_bag_hash] > 0 and effects[Keys.banked_leftovers_hash] > 0:
			var leftovers_hash: int = Keys.generate_hash("consumable_food_leftovers")
			if ItemService.get_food_from_hash(leftovers_hash) != null:
				var leftovers_due: int = int(effects[Keys.banked_leftovers_hash])
				for _leftover in range(leftovers_due):
					_food_scheduled_spawns[i].push_back([rand_range(0.05, 0.9) * food_wave_duration, leftovers_hash, 1])
				GourmetTracker.ev("leftovers_served", {"p": i, "n": leftovers_due})

		# Gourmet DLC - Grandma's Cookbook needs to know when this player takes damage
		var _error_food_dmg = _players[i].connect("took_damage", self, "_on_player_took_damage_food")

		# Gourmet DLC - Slug: create the slime trail visual once
		var snail_character = RunData.get_player_character(i)
		if snail_character != null and snail_character.my_id == "character_snail" and _slime_trail_line == null:
			_snail_player_index = i
			_slime_trail_line = Line2D.new()
			_slime_trail_line.width = SLIME_TRAIL_BASE_WIDTH
			_slime_trail_line.default_color = Color(0.45, 0.75, 0.4, 0.35)
			_slime_trail_line.joint_mode = Line2D.LINE_JOINT_ROUND
			_slime_trail_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
			_slime_trail_line.end_cap_mode = Line2D.LINE_CAP_ROUND
			_tile_map.add_child(_slime_trail_line)

		# Gourmet DLC - telemetry snapshot at wave start
		var tracked_items: = []
		for owned in RunData.get_player_items(i):
			tracked_items.push_back(owned.my_id)
		var wave_char = RunData.get_player_character(i)
		GourmetTracker.flush_counters("wave_start")
		GourmetTracker.ev("wave_start", {"p": i, "ch": wave_char.my_id if wave_char != null else "", "items": tracked_items, "s": GourmetTracker.stat_snapshot(i)})

		_on_player_health_updated(_players[i], _players[i].current_stats.health, _players[i].max_stats.health)

		var _error = _players[i].connect("health_updated", self, "_on_player_health_updated")
		_error = _players[i].connect("healed", _floating_text_manager, "_on_player_healed")
		_error = _players[i].connect("died", self, "_on_player_died")
		_error = _players[i].connect("took_damage", _screenshaker, "_on_player_took_damage")
		_error = _players[i].connect("healed", self, "on_player_healed")
		_error = _players[i].connect("wanted_to_spawn_gold", self, "on_player_wanted_to_spawn_gold")

		var things_to_process_player_container: UIThingsToProcessPlayerContainer = _things_to_process_player_containers[i]
		things_to_process_player_container.show()
		_error = things_to_process_player_container.upgrades.connect("ui_element_mouse_entered", self, "on_ui_element_mouse_entered")
		_error = things_to_process_player_container.upgrades.connect("ui_element_mouse_exited", self, "on_ui_element_mouse_exited")
		_error = things_to_process_player_container.consumables.connect("ui_element_mouse_entered", self, "on_ui_element_mouse_entered")
		_error = things_to_process_player_container.consumables.connect("ui_element_mouse_exited", self, "on_ui_element_mouse_exited")

		connect_visual_effects(_players[i])

		var pct_val = RunData.get_player_effect(Keys.gain_pct_gold_start_wave_hash, i)
		var apply_pct_gold_wave = (pct_val > 0 and RunData.current_wave <= RunData.nb_of_waves) or pct_val < 0

		
		
		if pct_val < 0 and RunData.current_wave > RunData.nb_of_waves:
			pct_val = - 100.0

		if apply_pct_gold_wave:
			var val = RunData.get_player_gold(i) * (pct_val / 100.0)
			RunData.add_gold(val, i)

			if pct_val > 0:
				RunData.add_tracked_value(i, Keys.item_piggy_bank_hash, val)

	for player_index in _players.size():
		var effects = RunData.get_player_effects(player_index)
		if effects[Keys.stats_next_wave_hash].size() > 0:
			for stat_next_wave in effects[Keys.stats_next_wave_hash]:
				assert (stat_next_wave[0] is int)
				TempStats.add_stat(stat_next_wave[0], stat_next_wave[1], player_index)
			effects[Keys.stats_next_wave_hash].clear()

		check_half_health_stats(player_index)

	DebugService.log_run_info()
	RunData.reset_weapons_dmg_dealt()
	RunData.reset_weapons_tracked_value_this_wave()
	RunData.reset_wave_caches()


func _on_EntitySpawner_enemy_spawned(enemy: Enemy) -> void :
	var _error_died = enemy.connect("died", self, "_on_enemy_died")
	var _error_took_damage = enemy.connect("took_damage", self, "_on_enemy_took_damage")
	_error_took_damage = enemy.connect("took_damage", _screenshaker, "_on_unit_took_damage")
	var _error_stats_boost = enemy.connect("stats_boosted", _effects_manager, "on_unit_stats_boost")
	var _error_heal = enemy.connect("healed", _effects_manager, "on_enemy_healed")
	var _error_speed_removed = enemy.connect("speed_removed", _effects_manager, "on_enemy_speed_removed")
	var _error_state_changed = enemy.connect("state_changed", _floating_text_manager, "on_enemy_state_changed")
	connect_visual_effects(enemy)


func _on_EntitySpawner_enemy_respawned(_enemy: Enemy) -> void :
	RunData.current_living_enemies += 1


func _on_EntitySpawner_neutral_spawned(neutral: Neutral) -> void :
	var _error_died = neutral.connect("died", self, "_on_neutral_died")
	var _error_took_damage = neutral.connect("took_damage", _screenshaker, "_on_unit_took_damage")
	connect_visual_effects(neutral)


func _on_EntitySpawner_neutral_respawned(_neutral: Neutral) -> void :
	RunData.current_living_trees += 1


func _on_EntitySpawner_structure_spawned(structure: Structure) -> void :
	var _error_fruit = structure.connect("wanted_to_spawn_fruit", self, "on_structure_wanted_to_spawn_fruit")
	# Gourmet DLC - Ice Cream Truck serves food through the structure signal
	var _error_food = structure.connect("wanted_to_spawn_food", self, "on_structure_wanted_to_spawn_food", [structure])
	# Gourmet DLC - food structures register as a spawn anchor for their food. They APPEND:
	# an owned copy each spawns its own stand, and assigning here would have left every copy
	# but the last one decorative.
	if "anchored_food" in structure and structure.anchored_food != "" and structure.player_index >= 0:
		var anchor_hash: int = Keys.generate_hash(structure.anchored_food)
		var player_anchors: Dictionary = _food_structures[structure.player_index]
		if not player_anchors.has(anchor_hash):
			player_anchors[anchor_hash] = []
		player_anchors[anchor_hash].push_back(structure)
		GourmetTracker.ev("structure_anchor", {"f": structure.anchored_food, "p": structure.player_index})


func _on_EntitySpawner_structure_respawned(structure):
	if _is_fog_wave:
		_fog_viewport._on_spawn_structure_or_pet(structure)

func _on_EntitySpawner_pet_spawned(pet):
	if _is_fog_wave:
		_fog_viewport._on_spawn_structure_or_pet(pet)


func _on_EntitySpawner_enemy_charmed(enemy):
	if _is_fog_wave:
		_fog_viewport._on_spawn_structure_or_pet(enemy)

# Gourmet DLC - structures (Ice Cream Truck) drop foods through the same ring spawn
func on_structure_wanted_to_spawn_food(food_id_hash: int, pos: Vector2, structure: Structure = null) -> void :
	var food_data = ItemService.get_food_from_hash(food_id_hash)
	if food_data != null:
		var structure_player: int = structure.player_index if structure != null else - 1
		spawn_food(food_data, pos, - 1.0, structure_player)


func on_structure_wanted_to_spawn_fruit(pos: Vector2) -> void :
	var consumable_to_spawn = convert_fruit_consumable(ItemService.get_consumable_for_tier(Tier.COMMON))
	var consumable: Consumable = get_node_from_pool(_consumable_pool_id, _consumables_container)
	if consumable == null:
		consumable = consumable_scene.instance()
		_consumables_container.call_deferred("add_child", consumable)
		var _error = consumable.connect("picked_up", self, "on_consumable_picked_up")
		yield(consumable, "ready")

	consumable.consumable_data = consumable_to_spawn
	consumable.already_picked_up = false
	consumable.set_texture(consumable_to_spawn.icon)
	var dist = rand_range(100, 150)
	var push_back_destination = Vector2(rand_range(pos.x - dist, pos.x + dist), rand_range(pos.y - dist, pos.y + dist))
	consumable.drop(pos, 0, push_back_destination)
	_consumables.push_back(consumable)


func _on_HarvestingTimer_timeout() -> void :
	for player_index in RunData.get_player_count():
		var harvesting_stat = Utils.get_stat(Keys.stat_harvesting_hash, player_index)
		if harvesting_stat <= 0:
			continue
		if RunData.current_wave > RunData.nb_of_waves:
			var val = ceil(harvesting_stat * (RunData.ENDLESS_HARVESTING_DECREASE / 100.0))
			RunData.remove_stat(Keys.stat_harvesting_hash, val, player_index)
		else:
			var harvesting_growth = RunData.get_player_effect(Keys.harvesting_growth_hash, player_index)
			var val = ceil(harvesting_stat * (harvesting_growth / 100.0))

			var has_crown = false
			var crown_value = 0

			var items = RunData.get_player_items_ref(player_index)
			for item in items:
				
				
				if item.my_id_hash == Keys.item_crown_hash:
					has_crown = true
					crown_value = item.effects[0].value
					break

			if has_crown:
				RunData.add_tracked_value(player_index, Keys.item_crown_hash, ceil(harvesting_stat * (crown_value / 100.0)) as int)

			if val > 0:
				RunData.add_stat(Keys.stat_harvesting_hash, val, player_index)


func on_player_healed(_value: int, player_index: int) -> void :
	var dmg_when_heal_effect = RunData.get_player_effect(Keys.dmg_when_heal_hash, player_index)
	var _dmg_taken = handle_stat_damages(dmg_when_heal_effect, player_index)

func handle_stat_damages(stat_damages: Array, player_index: int) -> Array:
	var total_dmg_to_deal = 0
	var dmg_taken = [0, 0]
	var tracking_values: Dictionary = {}

	if stat_damages.empty():
		return dmg_taken

	var include_charmed_enemies = false
	var enemies: Array = _entity_spawner.get_all_enemies(include_charmed_enemies)
	var other_enemy = Utils.get_rand_element(enemies)
	if other_enemy == null or not is_instance_valid(other_enemy) or other_enemy.current_stats.health == 0:
		return dmg_taken

	var stat_dict = {}
	var percent_dmg_bonus = 1 + Utils.get_stat(Keys.stat_percent_damage_hash, player_index) / 100.0
	for stat_dmg in stat_damages:

		if randf() >= stat_dmg[2] / 100.0:
			continue

		assert (stat_dmg[0] is int)
		var dmg_dict = stat_dict.get(stat_dmg[0])
		if not dmg_dict:
			dmg_dict = {Keys.stat_hash: Utils.get_stat(stat_dmg[0], player_index)}
			stat_dict[stat_dmg[0]] = dmg_dict
		var dmg = dmg_dict.get(stat_dmg[1])
		if not dmg:
			var base_dmg: = floor(max(1, stat_dmg[1] / 100.0 * dmg_dict[Keys.stat_hash]))
			dmg = round(base_dmg * percent_dmg_bonus) as int
			dmg_dict[stat_dmg[1]] = dmg
		total_dmg_to_deal += dmg

		
		if stat_damages.size() == 1 and total_dmg_to_deal <= 0:
			return dmg_taken

		var tracking_key: int = stat_dmg[3] if stat_dmg.size() == 4 else - 1
		if tracking_key != - 1:
			if tracking_values.has(tracking_key):
				tracking_values[tracking_key] += dmg
			else:
				tracking_values[tracking_key] = dmg

	if total_dmg_to_deal <= 0:
		return dmg_taken

	
	_take_damage_args._init(player_index)
	dmg_taken = other_enemy.take_damage(total_dmg_to_deal, _take_damage_args)

	var remaining_damage_to_track: int = dmg_taken[1]
	for tracking_key in tracking_values.keys():
		var tracking_value = tracking_values[tracking_key]

		if tracking_value <= remaining_damage_to_track:
			RunData.add_tracked_value(player_index, tracking_key, tracking_value)
			remaining_damage_to_track -= tracking_value

		else:
			RunData.add_tracked_value(player_index, tracking_key, remaining_damage_to_track)
			break

	return dmg_taken


func check_half_health_stats(player_index: int) -> void :
	var stats_below_half_health = RunData.get_player_effect(Keys.stats_below_half_health_hash, player_index)
	if stats_below_half_health.size() == 0:
		return

	var current_val = _players[player_index].current_stats.health
	var max_val = _players[player_index].max_stats.health
	if current_val < (max_val / 2.0) and not _player_is_under_half_health[player_index]:
		_player_is_under_half_health[player_index] = true
		for stat in stats_below_half_health:
			assert (stat[0] is int)
			TempStats.add_stat(stat[0], stat[1], player_index)
			RunData.emit_signal("stat_added", stat[0], stat[1], 0.0, player_index)

	elif current_val >= max_val / 2.0 and _player_is_under_half_health[player_index]:
		_player_is_under_half_health[player_index] = false
		for stat in stats_below_half_health:
			assert (stat[0] is int)
			TempStats.remove_stat(stat[0], stat[1], player_index)
			RunData.emit_signal("stat_removed", stat[0], stat[1], 0.0, player_index)


func _on_player_health_updated(player: Player, current_val: int, max_val: int) -> void :
	var player_index = player.player_index
	RunData.players_data[player_index].current_health = current_val

	if player.player_index == 0 and not RunData.is_coop_run:
		_damage_vignette.update_from_hp(current_val, max_val)

	check_half_health_stats(player_index)

	var player_ui: PlayerUIElements = _players_ui[player_index]
	var life_bar = player_ui.life_bar
	life_bar.update_value(current_val, max_val)

	var player_life_bar = player_ui.player_life_bar
	player_life_bar.visible = ProgressData.settings.hp_bar_on_character and current_val != max_val and not player.dead
	if player_life_bar.visible:
		player_life_bar.update_value(current_val, max_val)

	var die_in_one_hit = RunData.get_player_effect(Keys.die_in_one_hit_hash, player_index)
	if die_in_one_hit == 1:
		player_ui.hide_life_label(player)
	else:
		player_ui.update_life_label(player)
	var hit_protection_count = player._hit_protection
	player_ui.update_hit_protection_count(player, hit_protection_count)


func on_gold_changed(new_value: int, player_index: int) -> void :
	var player_ui: PlayerUIElements = _players_ui[player_index]
	player_ui.gold.update_value(new_value)
	# Gourmet DLC - refresh the debt readout on the SAME live signal as gold. update_hud (the
	# other place that sets it) only runs at wave setup, which is why debt used to look frozen
	# mid-wave: add_gold repays it per gem, but nothing repainted the label until the next
	# round. gold_changed fires on every add_gold / add_debt / overspend, so this tracks it live.
	player_ui.gold.update_debt(RunData.get_player_debt(player_index))


func on_damage_effect(value: int, player_index: int, armor_applied: bool, dodgeable: bool, from = null) -> void :
	_players[player_index].on_damage_effect(value, armor_applied, dodgeable, from)


func on_lifesteal_effect(value: int, player_index: int) -> void :
	var player: Player = _players[player_index]
	player.on_lifesteal_effect(value)


func on_healing_effect(value: int, player_index: int, tracking_key: int = Keys.empty_hash) -> void :
	_players[player_index].on_healing_effect(value, tracking_key)


func on_heal_over_time_effect(total_healing: int, duration: int, player_index: int) -> void :
	_players[player_index].on_heal_over_time_effect(total_healing, duration)


func on_chal_popup() -> void :
	_is_chal_ui_displayed = true


func on_chal_popout() -> void :
	_is_chal_ui_displayed = false


func _on_HalfSecondTimer_timeout(player_index: int) -> void :
	if LinkedStats.update_for_player_every_half_sec[player_index]:
		LinkedStats.reset_player(player_index)


func _on_game_lost_focus() -> void :
	if not _retry_wave.visible:
		_pause_menu.on_game_lost_focus()


func _on_emit_fire_particle(burning_particle):
	if _is_fog_wave:
		_fog_viewport._on_emit_fire_particle(burning_particle)


func get_node_from_pool(id: int, parent: Node) -> Node:
	if _current_pool_id != id:
		_current_pool_id = id
		if _pool.has(id):
			_current_pool = _pool[id]
		else:
			_pool[id] = []
			_current_pool = _pool[id]
			return null

	if _current_pool.empty():
		return null

	var node = _current_pool.pop_back()
	if is_instance_valid(node):
		parent.add_child(node)
		return node

	return null



func is_pool_empty(id: int) -> bool:
	if _pool.has(id):
		return _pool[id].empty()

	return true


func add_node_to_pool(node: Node, id: int) -> void :
	assert (_pool.has(id))
	_add_node_to_pool(node, id)


func is_in_pool(node: Node) -> bool:
	for key in _pool.keys():
		var pool = _pool[key]
		for n in pool:
			if node == n:
				return true
	return false



func _add_node_to_pool(node: Node, id: int) -> void :
	if node.get_parent() == null:
		return
	
	_pool[id].push_back(node)
	node.get_parent().remove_child(node)



func add_explosion(instance: PlayerExplosion) -> void :
	_explosions.add_child(instance)


# Gourmet DLC - Popcorn Machine: each explosion has a 5% * (1 + 0.10 * Appetite) chance to
# pop a Popcorn. Called from WeaponService.explode once the explosion's player_index is
# actually assigned. This used to sit inside add_explosion(), which was wrong twice over:
#   1. add_explosion only runs when a FRESH node is instanced - every pooled explosion (which
#      is nearly all of them after the first) skipped the check entirely, so the Popcorn
#      Machine barely ever fired.
#   2. it ran BEFORE weapon_service assigns instance.player_index, so it always read the -1
#      default from player_explosion.gd and tripped get_player_effect's player_index >= 0
#      assert - a hard crash in any debug build.
# Enemy and unowned explosions legitimately carry no player, hence the guard.
func on_explosion_spawned(player_index: int) -> void :
	if _cleaning_up or player_index < 0 or player_index >= _players.size():
		return
	var pop_entries = RunData.get_player_effect(Keys.explosion_foods_hash, player_index)
	if pop_entries.empty():
		return
	var pop_app: float = max(0.0, Utils.get_stat(Keys.stat_appetite_hash, player_index))
	if Utils.get_chance_success(0.05 * (1.0 + 0.10 * pop_app)):
		count_food_trigger(Keys.explosion_foods_hash, player_index)


# Gourmet DLC - Corn Cannon: every corn blast has a small chance to pop a free
# Popcorn onto the ground. Base 3%, and each point of Appetite raises that by 15%
# of the base (chance = 0.03 * (1 + 0.15 * appetite)). Spawned with player_index
# -1 so it ignores spawner gating (Picky Eater / Fasting) - it is a weapon proc,
# not a spawner tick.
# Gourmet DLC - Girly: pink "PANIC" text, teleport to the point furthest from
# every enemy (9x9 grid maximising nearest-enemy distance), then a 2 Fries +
# 2 Fried Rice burst around her. She is a food source (card shows both foods).
func girly_panic_teleport(unit: Unit) -> void :
	if _cleaning_up:
		return
	var girly_index: int = unit.player_index

	# pink "PANICK!!!" above her the instant she is hit (same floating-text system as damage numbers)
	if _floating_text_manager != null:
		_floating_text_manager.display("PANICK!!!", unit.global_position + Vector2(0, - 44), Color(1.0, 0.42, 0.72), null, 0.8, true, Vector2(0, - 60), false)

	var girly_origin: Vector2 = unit.global_position
	var girly_rect: Rect2 = ZoneService.get_current_zone_rect()
	# Sample inside a 15%-per-side inset so she never hugs a corner/edge. The margin is
	# a FRACTION of the map, so it scales with Map Size and can never over-inset a tiny
	# map (inset region stays 70% of the map either way).
	var girly_mx: float = girly_rect.size.x * 0.15
	var girly_my: float = girly_rect.size.y * 0.15
	var girly_ix: float = girly_rect.position.x + girly_mx
	var girly_iy: float = girly_rect.position.y + girly_my
	var girly_iw: float = girly_rect.size.x - 2.0 * girly_mx
	var girly_ih: float = girly_rect.size.y - 2.0 * girly_my
	var girly_enemies: Array = _entity_spawner.get_all_enemies()
	var girly_best: Vector2 = girly_rect.position + girly_rect.size / 2.0
	if girly_enemies.size() > 0:
		var girly_best_score: float = - 1.0
		for gx in range(9):
			for gy in range(9):
				var cand: = Vector2(girly_ix + girly_iw * (gx + 0.5) / 9.0,
									girly_iy + girly_ih * (gy + 0.5) / 9.0)
				var girly_nearest: float = 1e20
				for girly_enemy in girly_enemies:
					if girly_enemy == null or not is_instance_valid(girly_enemy):
						continue
					var girly_dsq: float = cand.distance_squared_to(girly_enemy.global_position)
					if girly_dsq < girly_nearest:
						girly_nearest = girly_dsq
				if girly_nearest > girly_best_score:
					girly_best_score = girly_nearest
					girly_best = cand
	# phase 1 (0.5s): freeze move+shoot, go invincible, fade out AT the origin. Chasers keep
	# pathing to girly_origin (panic_target_override) for the whole teleport, so enemies
	# don't follow her across - they head to the old spot until she regains control.
	unit.begin_panic_teleport(girly_origin)
	yield(get_tree().create_timer(0.5), "timeout")
	if _cleaning_up or not is_instance_valid(unit) or unit.dead:
		return

	# arrive: teleport to the safe spot, fade back in, drop the food burst there
	unit.global_position = girly_best
	unit.panic_fade_in()
	var girly_drops: = [["consumable_food_fries", Vector2(- 60, - 60)], ["consumable_food_fries", Vector2(60, - 60)],
						["consumable_food_fried_rice", Vector2(- 60, 60)], ["consumable_food_fried_rice", Vector2(60, 60)]]
	for girly_drop in girly_drops:
		var girly_food: ConsumableData = ItemService.get_food_from_hash(Keys.generate_hash(girly_drop[0]))
		if girly_food != null:
			spawn_food(girly_food, girly_best + girly_drop[1], - 1.0, girly_index, true)
	RunData.add_tracked_value(girly_index, Keys.generate_hash("character_girly"), 1)
	GourmetTracker.ev("girly_panic", {"p": girly_index})

	# phase 2 (0.5s): still frozen + invincible + fading in, enemies still on the old spot
	yield(get_tree().create_timer(0.5), "timeout")
	if is_instance_valid(unit):
		unit.end_panic_teleport()


func add_effect(instance: Node) -> void :
	_effects.add_child(instance)


func add_floating_text(instance: FloatingText) -> void :
	_floating_texts.add_child(instance)


func add_player_projectile(instance: PlayerProjectile) -> void :
	_player_projectiles.add_child(instance)


func add_enemy_projectile(instance: Projectile) -> void :
	_enemy_projectiles.add_child(instance)


func add_birth(instance: EntityBirth) -> void :
	_births_container.add_child(instance)


func add_entity(instance: Entity) -> void :
	_entities_container.add_child(instance)


func _exit_tree() -> void :
	InputService.set_gamepad_echo_processing(true)
	if _pool != null:
		for key in _pool.keys():
			var pool = _pool[key]
			for node in pool:
				node.queue_free()


func _on_HalfWaveTimer_timeout() -> void :
	for player_index in RunData.get_player_count():
		Utils.convert_stats(RunData.get_player_effect(Keys.convert_stats_half_wave_hash, player_index), player_index, false)

	if RunData.concat_all_player_effects(Keys.convert_stats_half_wave_hash).size() > 0:
		_wave_timer_label.change_color(Color.deepskyblue)
