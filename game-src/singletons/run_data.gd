extends Node

signal levelled_up(player_index)
signal gold_changed(new_value, player_index)
signal bonus_gold_changed(new_value)
signal xp_added(current_xp, max_xp, player_index)
signal stat_added(stat_name, value, db_mod, player_index)
signal stat_removed(stat_name, value, db_mod, player_index)
signal stats_updated(player_index)
signal enemy_charmed(enemy)
signal bonus_gold_converted(total_bonus_gold, nb_materials_per_conversion, nb_stats_added_per_conversion)

signal damage_effect(value, player_index, armor_applied, dodgeable)
signal lifesteal_effect(value, player_index)
signal healing_effect(value, player_index, tracking_key)
signal heal_over_time_effect(total_healing, duration, player_index)

const ENDLESS_HARVESTING_DECREASE: = 20
const BAN_MAX_TOKEN: = 8


const DUMMY_PLAYER_INDEX: = 123
enum PlayMode{SOLO, COOP, STREAMPLAY_LOCAL, STREAMPLAY_INTERNET}

var players_data: = []
var dummy_player_effects: Dictionary
var dummy_player_remove_speed_data: Dictionary
var _explode_args_node: = WeaponServiceExplodeArgs.new()
var _second_explode_args_node: = WeaponServiceExplodeArgs.new()
var _players_die_args: Array = [Utils.default_die_args, Utils.default_die_args, Utils.default_die_args, Utils.default_die_args]

var primary_stats_list = [
	Keys.generate_hash("stat_max_hp"), 
	Keys.generate_hash("stat_armor"), 
	Keys.generate_hash("stat_crit_chance"), 
	Keys.generate_hash("stat_luck"), 
	Keys.generate_hash("stat_attack_speed"), 
	Keys.generate_hash("stat_elemental_damage"), 
	Keys.generate_hash("stat_hp_regeneration"), 
	Keys.generate_hash("stat_lifesteal"), 
	Keys.generate_hash("stat_melee_damage"), 
	Keys.generate_hash("stat_percent_damage"), 
	Keys.generate_hash("stat_dodge"), 
	Keys.generate_hash("stat_engineering"), 
	Keys.generate_hash("stat_range"), 
	Keys.generate_hash("stat_ranged_damage"), 
	Keys.generate_hash("stat_speed"), 
	Keys.generate_hash("stat_harvesting")
]

var effect_keys_full_serialization = [
	Keys.generate_hash("burn_chance"), 
	Keys.generate_hash("structures"), 
	Keys.generate_hash("explode_on_hit"), 
	Keys.generate_hash("explode_when_below_hp"), 
	Keys.generate_hash("explode_on_death"), 
	Keys.generate_hash("explode_on_consumable"), 
	Keys.generate_hash("convert_stats_end_of_wave"), 
	Keys.generate_hash("convert_stats_half_wave"), 
	Keys.generate_hash("modify_every_x_projectile"), 
	Keys.generate_hash("explode_on_overkill"), 
	Keys.generate_hash("explode_on_consumable_burning"), 
	Keys.generate_hash("convert_bonus_gold"), 
	Keys.generate_hash("scale_materials_with_distance"), 
	Keys.generate_hash("pets")
]

var effect_keys_with_weapon_stats = [
	Keys.generate_hash("projectiles_on_death"), 
	Keys.generate_hash("alien_eyes")
]

var init_tracked_items: = {
	Keys.generate_hash("character_gourmet"): [0, 0],  # Gourmet DLC - Appetite gained, Speed lost to fat
	Keys.generate_hash("character_snail"): [0, 0],  # Gourmet DLC - Escargot armor, slime damage dealt
	Keys.generate_hash("character_girly"): 0,
	Keys.generate_hash("weapon_frying_pan"): 0,
	Keys.generate_hash("item_doggy_bag"): 0,
	Keys.generate_hash("item_farmers_market"): 0,
	Keys.generate_hash("item_compost_bin"): 0,
	Keys.generate_hash("item_loyalty_card"): 0,
	Keys.generate_hash("item_credit_card"): 0,  # Gourmet DLC - debt taken on via shop overspend
	Keys.generate_hash("item_soul_food"): [0, 0],
	Keys.generate_hash("item_overtime_pay"): 0,
	Keys.generate_hash("item_second_mortgage"): 0,
	Keys.generate_hash("item_snack_break"): 0,
	Keys.generate_hash("character_butcher"): [0, 0],  # Gourmet DLC - consumables eaten, permanent Appetite rendered
	Keys.generate_hash("character_dishwasher"): 0,
	Keys.generate_hash("character_zombie"): 0,
	# Gourmet DLC - fed but previously unseeded, so add_tracked_value printed and dropped them:
	# Food Fight on every projectile hit (main.gd -> hitbox.gd), Spyglass on every paid reroll.
	Keys.generate_hash("item_food_fight"): 0,
	Keys.generate_hash("item_spyglass"): 0,
	# Gourmet DLC - run-long accumulators that had no card counter until now. Array seeds are
	# characters that already tracked something else; index 1 is relabelled in item_parent_data.
	Keys.generate_hash("character_minimalist"): 0,
	Keys.generate_hash("character_comp_eater"): 0,
	Keys.generate_hash("character_ruminant"): 0,
	Keys.generate_hash("character_blacksmith"): 0,
	Keys.generate_hash("character_mime"): 0,
	Keys.generate_hash("item_vampire_fang"): 0,
	Keys.generate_hash("item_buffet_insurance"): 0,
	Keys.generate_hash("item_caltrops"): 0,
	Keys.generate_hash("item_grease_fire"): 0,
	Keys.generate_hash("item_static_cling"): 0,
	Keys.generate_hash("item_echo_chamber"): 0,
	Keys.generate_hash("item_second_helping"): 0,
	Keys.generate_hash("item_nine_lives"): 0,
	Keys.generate_hash("item_vigilante_ring"): 0,
	Keys.generate_hash("item_alien_eyes"): 0, 
	Keys.generate_hash("item_baby_elephant"): 0, 
	Keys.generate_hash("item_cyberball"): 0, 
	Keys.generate_hash("item_baby_with_a_beard"): 0, 
	Keys.generate_hash("item_bag"): 0, 
	Keys.generate_hash("item_crown"): 0, 
	Keys.generate_hash("item_cute_monkey"): 0, 
	Keys.generate_hash("item_dangerous_bunny"): 0, 
	Keys.generate_hash("item_hunting_trophy"): 0, 
	Keys.generate_hash("item_metal_detector"): 0, 
	Keys.generate_hash("item_piggy_bank"): 0, 
	Keys.generate_hash("item_rip_and_tear"): 0, 
	Keys.generate_hash("item_tree"): 0, 
	Keys.generate_hash("item_anvil"): 0, 
	Keys.generate_hash("item_grinds_magical_leaf"): 0, 
	Keys.generate_hash("item_scared_sausage"): 0, 
	Keys.generate_hash("item_recycling_machine"): 0, 
	Keys.generate_hash("item_coupon"): 0, 
	Keys.generate_hash("character_lich"): 0, 
	Keys.generate_hash("item_riposte"): 0, 
	Keys.generate_hash("item_adrenaline"): 0, 
	Keys.generate_hash("item_spicy_sauce"): 0, 
	Keys.generate_hash("item_tentacle"): 0, 
	Keys.generate_hash("item_giant_belt"): 0, 
	Keys.generate_hash("item_extra_stomach"): 0, 
	Keys.generate_hash("character_glutton"): 0, 
	Keys.generate_hash("item_greek_fire"): 0, 
	Keys.generate_hash("item_snowball"): 0, 
	Keys.generate_hash("item_goblet"): 0, 
	Keys.generate_hash("item_black_flag"): 0, 
	Keys.generate_hash("item_decomposing_flesh"): 0, 
	Keys.generate_hash("item_celery_tea"): 0, 
	Keys.generate_hash("item_robot_arm"): 0, 
	Keys.generate_hash("item_bone_dice"): [0, 0], 
	Keys.generate_hash("item_sunken_bell"): 0, 
	Keys.generate_hash("item_krakens_eye"): 0, 
	Keys.generate_hash("character_lucky"): 0, 
	Keys.generate_hash("item_turret"): 0, 
	Keys.generate_hash("item_turret_flame"): 0, 
	Keys.generate_hash("item_turret_healing"): 0, 
	Keys.generate_hash("item_tyler"): 0, 
	Keys.generate_hash("item_turret_laser"): 0, 
	Keys.generate_hash("item_turret_rocket"): 0, 
	Keys.generate_hash("item_landmines"): 0, 
	Keys.generate_hash("character_bull"): 0, 
	Keys.generate_hash("character_ogre"): 0, 
	Keys.generate_hash("character_hiker"): [0, 0], 
	Keys.generate_hash("character_builder"): 0, 
	Keys.generate_hash("item_builder_turret_0"): 0, 
	Keys.generate_hash("item_builder_turret_1"): 0, 
	Keys.generate_hash("item_builder_turret_2"): 0, 
	Keys.generate_hash("item_builder_turret_3"): 0, 
	Keys.generate_hash("character_druid"): 0, 
	Keys.generate_hash("item_barnacle"): 0, 
	Keys.generate_hash("item_baby_squid"): 0, 
	Keys.generate_hash("item_ashes"): 0, 
	Keys.generate_hash("character_chef"): 0, 
	Keys.generate_hash("item_treasure_map"): 0, 
	Keys.generate_hash("character_dwarf"): 0, 
	Keys.generate_hash("item_fish_hook"): 0, 
	Keys.generate_hash("item_candy_bag"): 0, 
	Keys.generate_hash("item_will_o_the_wisp"): 0, 
	Keys.generate_hash("item_fruit_basket"): 0, 
	Keys.generate_hash("item_catling_gun"): 0, 
	Keys.generate_hash("item_lootworm"): 0, 
	Keys.generate_hash("item_bonk_dog"): [0, 0], 
	Keys.generate_hash("item_jellyshield"): 0, 
	Keys.generate_hash("item_bot_o_mine"): [0, 0], 
	Keys.generate_hash("item_blazemander"): 0, 
	Keys.generate_hash("item_ratzilla"): 0, 
	Keys.generate_hash("item_doc_moth"): 0, 
	# Gourmet DLC - per-food eaten counters (shown on each spawner's item card)
	Keys.generate_hash("consumable_food_cake_slice"): 0, 
	Keys.generate_hash("consumable_food_cheese_cube"): 0, 
	Keys.generate_hash("consumable_food_chili_pepper"): 0, 
	Keys.generate_hash("consumable_food_escargot"): 0, 
	Keys.generate_hash("consumable_food_espresso"): 0, 
	Keys.generate_hash("consumable_food_fried_rice"): 0, 
	Keys.generate_hash("consumable_food_fries"): 0, 
	Keys.generate_hash("consumable_food_fruit_salad"): 0, 
	Keys.generate_hash("consumable_food_golden_apple"): 0, 
	Keys.generate_hash("consumable_food_honey_drop"): 0, 
	Keys.generate_hash("consumable_food_ice_cream"): 0, 
	Keys.generate_hash("consumable_food_leftovers"): 0, 
	Keys.generate_hash("consumable_food_mint"): 0, 
	Keys.generate_hash("consumable_food_mystery_meat"): 0, 
	Keys.generate_hash("consumable_food_pizza_slice"): 0, 
	Keys.generate_hash("consumable_food_popcorn"): 0, 
	Keys.generate_hash("consumable_food_protein_shake"): 0, 
	Keys.generate_hash("consumable_food_steak"): 0, 
	Keys.generate_hash("consumable_food_sushi_roll"): 0,
	Keys.generate_hash("consumable_food_warm_cookie"): 0,
	Keys.generate_hash("consumable_food_ribs"): 0,
	Keys.generate_hash("consumable_food_chili_dog"): 0,
	Keys.generate_hash("consumable_food_gumball"): 0,
	Keys.generate_hash("consumable_food_bloody_mary"): 0,
	Keys.generate_hash("consumable_food_fried_egg"): 0,
	Keys.generate_hash("item_wine_cellar"): 0,
	Keys.generate_hash("item_delivery_drone"): 0, 
}

var remove_speed_effect_cache: = [{}, {}, {}, {}]
var items_nb_cache: = [{}, {}, {}, {}]
var different_items_nb_cache: = [{}, {}, {}, {}]
var duplicate_items_cache: = [null, null, null, null]
var max_consumable_stats_gained_this_wave: = [[], [], [], []]
var tracked_item_effects: = [{}, {}, {}, {}]
var _are_player_stats_dirty: = [false, false, false, false]


var current_run_accessibility_settings: Dictionary
var constant_projectile: = 1

var current_living_enemies: = 0
var current_living_trees: = 0
var current_burning_enemies: = 0
var current_charmed_enemies: = [0, 0, 0, 0]
var steps_taken_this_wave: = [0, 0, 0, 0]

var start_wave_state: = {}
var last_saved_run_state: = {}
var wave_in_progress: = false
var resumed_from_state_in_shop: = false
var nb_of_waves: = 20

var elites_spawn: = []
var bosses_spawn: = []
var events_spawn: = []
var events_fog_of_war: = []
var events_bullet_hell: = []
var check_elite_generation: = []
var check_nightmare_event_generation: = []
var elites_killed_this_run: = []
var bosses_killed_this_run: = []
var loot_aliens_killed_this_run: = 0
var current_zone: = 0
var current_wave: int
var current_difficulty: int
var bonus_gold: int
var total_bonus_gold: int
var run_won: bool
var challenges_completed_this_run: = []
var reload_music = true
var retries: = 0
var all_last_wave_bosses_killed = false

var locked_shop_items: = [[], [], [], []]
var forced_shop_items: = []
var current_background = null

var shop_effects_checked = false

var instant_waves = false
var invulnerable = false

var difficulty_unlocked = - 1
var max_endless_wave_record_beaten = - 1
var is_endless_run = false
var is_ban_mode_active = false

var is_coop_run = false
var is_streamplay_run = false
var play_mode = 0
var enabled_dlcs = []
var menu_selection_back: = false

var wave_timer: WaveTimer = null

func _ready() -> void :
	if DebugService.unlock_all_challenges:
		ChallengeService._generate_hashes()
		for chal in ChallengeService.challenges:
			ChallengeService.complete_challenge(chal.get_my_id_hash())

	if DebugService.reinitialize_store_data:
		Platform.reinitialize_store_data()

	dummy_player_effects = PlayerRunData.init_effects()
	dummy_player_remove_speed_data = init_remove_speed_data(DUMMY_PLAYER_INDEX)


func _physics_process(_delta: float) -> void :
	call_deferred("_emit_stats_updated")

func set_coop_run(value: bool) -> void :
	is_coop_run = value
	if Utils.on_nintendo_nx:
		OS_Seaven.set_vsync_interval(2 if is_coop_run else 1)


func on_wave_start(timer: WaveTimer) -> void :
	_reset_per_wave_properties()
	start_wave_state = get_state()
	wave_in_progress = true
	shop_effects_checked = false
	wave_timer = timer

	for player_run_data in players_data:
		player_run_data.chal_will_o_the_wisp = 0
	for player_index in get_player_count():
		if get_player_effects(player_index).has(Keys.gain_stat_for_killed_enemies_while_burning_hash):
			var effects = get_player_effect(Keys.gain_stat_for_killed_enemies_while_burning_hash, player_index)
			for effect in effects:
				effect[4] = 0
				effect[5] = 0


func on_wave_end() -> void :
	wave_timer = null
	var max_steps_taken: = 0.0
	for steps_taken in steps_taken_this_wave:
		max_steps_taken = max(max_steps_taken, steps_taken)
	ProgressData.data["steps_taken"] += int(max_steps_taken)

	for player_index in get_player_count():
		var player_data = players_data[player_index]
		var has_overtime_pay = false
		var has_second_mortgage = false
		for item in get_player_items(player_index):
			if item.my_id == "item_overtime_pay":
				has_overtime_pay = true
			elif item.my_id == "item_second_mortgage":
				has_second_mortgage = true

		if has_overtime_pay:
			var attack_speed_gain: = min(6, int(player_data.overtime_pay_gold_this_wave / 80))
			if attack_speed_gain > 0:
				# The card says "permanent", so bank it permanently. Was TempStats.add_stat,
				# which is wiped by the wave-start TempStats.reset - it never actually persisted.
				add_stat(Keys.stat_attack_speed_hash, attack_speed_gain, player_index)
				add_tracked_value(player_index, Keys.generate_hash("item_overtime_pay"), attack_speed_gain)
		player_data.overtime_pay_gold_this_wave = 0

		if has_second_mortgage and player_data.gold > 0:
			var mortgage_gain: = int(round(player_data.gold * 0.15))
			add_gold(mortgage_gain, player_index)
			add_tracked_value(player_index, Keys.generate_hash("item_second_mortgage"), mortgage_gain)

	_reset_per_wave_properties()


func _reset_per_wave_properties() -> void :
	start_wave_state.clear()
	current_living_enemies = 0
	current_living_trees = 0
	current_burning_enemies = 0
	current_charmed_enemies = [0, 0, 0, 0]
	steps_taken_this_wave = [0, 0, 0, 0]
	wave_in_progress = false


func get_player_count() -> int:
	return players_data.size()


func reset_players_data_stats_and_effects() -> void :
	for player_data in players_data:
		player_data.effects = PlayerRunData.init_effects()


func set_player_count(count: int, reset: = false) -> void :
	if reset:
		players_data.clear()
	while players_data.size() < count:
		var player_data: PlayerRunData = PlayerRunData.new()
		player_data.gold = DebugService.starting_gold
		if DebugService.randomize_equipment:
			player_data.gold = Utils.randi_range(10, 500)
			player_data.current_level = Utils.randi_range(10, 26)
		players_data.push_back(player_data)
	players_data.resize(count)
	if Utils.on_nintendo_ounce:
		OS_Seaven.set_vsync_interval(2 if count > 2 else 1)


func get_player_character(player_index: int) -> CharacterData:
	assert (player_index >= 0)
	return players_data[player_index].current_character


func get_player_current_health(player_index: int) -> int:
	assert (player_index >= 0)
	
	return players_data[player_index].current_health if wave_in_progress else get_player_max_health(player_index)


func get_player_max_health(player_index: int) -> int:
	return max(1, Utils.get_capped_stat(Keys.stat_max_hp_hash, player_index)) as int


func get_player_missing_health(player_index: int) -> int:
	return get_player_max_health(player_index) - get_player_current_health(player_index)

func is_ban_active_in_current_run() -> bool:
	var test = players_data[0].uses_ban
	return test

func get_used_ban_count() -> int:
	var result: = 0
	for player_index in get_player_count():
		result += get_player_banned_items(player_index).size()

	return result

func get_player_level(player_index: int) -> int:
	assert (player_index >= 0)
	if player_index == DUMMY_PLAYER_INDEX:
		return 0
	return players_data[player_index].current_level


func get_player_xp(player_index: int) -> float:
	assert (player_index >= 0)
	return players_data[player_index].current_xp


func get_player_gold(player_index: int) -> int:
	assert (player_index >= 0)
	if player_index == DUMMY_PLAYER_INDEX:
		return 0
	return players_data[player_index].gold


func get_player_weapons(player_index: int) -> Array:
	assert (player_index >= 0)
	if player_index == DUMMY_PLAYER_INDEX:
		return []
	return players_data[player_index].weapons.duplicate()


func get_player_weapons_ref(player_index: int) -> Array:
	if player_index == DUMMY_PLAYER_INDEX:
		return []
	return players_data[player_index].weapons


func get_player_item(item_id: int, player_index: int) -> ItemData:
	for player_item in get_player_items(player_index):
		if player_item.my_id_hash == item_id:
			return player_item

	return null


func existing_weapon_has_effect(effect_key: int) -> bool:
	for i in players_data.size():
		var player_weapons = get_player_weapons_ref(i)
		for weapon in player_weapons:
			for effect in weapon.effects:
				
				
				
				

				if effect.key_hash == effect_key or effect.custom_key_hash == effect_key:
					return true

	return false


func get_player_sets(player_index: int) -> Array:
	assert (player_index >= 0)
	if player_index == DUMMY_PLAYER_INDEX:
		return []
	return players_data[player_index].active_sets.keys()


func get_player_appearances(player_index: int) -> Array:
	assert (player_index >= 0)
	return players_data[player_index].appearances.duplicate()


func get_player_items(player_index: int) -> Array:
	assert (player_index >= 0)
	if player_index == DUMMY_PLAYER_INDEX:
		return []
	return players_data[player_index].items.duplicate()


func get_player_banned_items(player_index: int) -> Array:
	assert (player_index >= 0)
	if player_index == DUMMY_PLAYER_INDEX:
		return []


	var all_banned: Array
	for item_id in players_data[player_index].banned_items:
		if item_id is String:
			var item_id_hash = Keys.generate_hash(item_id)
			if ItemService.is_item_id(item_id_hash):
				var item = ItemService.get_item_from_id(item_id_hash)
				all_banned.append(item)
		else:
			if ItemService.is_item_id(item_id):
				var item = ItemService.get_item_from_id(item_id)
				all_banned.append(item)

	return all_banned

func get_player_items_ref(player_index: int) -> Array:
	if player_index == DUMMY_PLAYER_INDEX:
		return []
	return players_data[player_index].items


func get_player_effects(player_index: int) -> Dictionary:
	assert (player_index >= 0)
	if player_index == DUMMY_PLAYER_INDEX:
		return dummy_player_effects
	return players_data[player_index].effects


func get_player_effect(key: int, player_index: int):
	assert (player_index >= 0, Keys.hash_to_string[key])
	return get_player_effects(player_index)[key]


func get_player_effect_bool(key: int, player_index: int) -> bool:
	assert (player_index >= 0, key)
	return get_player_effect(key, player_index) > 0


func sum_all_player_effects(key: int) -> int:
	var sum: = 0
	for player_data in players_data:
		sum += player_data.effects[key]
	return sum


func concat_all_player_effects(key: int) -> Array:
	var result: = []
	for player_data in players_data:
		result.append_array(player_data.effects.get(key, []))
	return result


func get_player_selected_weapon(player_index: int) -> WeaponData:
	assert (player_index >= 0)
	return players_data[player_index].selected_weapon


func get_player_locked_shop_items(player_index: int) -> Array:
	assert (player_index >= 0)
	return locked_shop_items[player_index].duplicate()


func lock_player_shop_item(item_data: ItemParentData, wave_value: int, player_index: int) -> void :
	locked_shop_items[player_index].push_back([item_data, wave_value])


func unlock_player_shop_item(item_data: ItemParentData, player_index: int) -> void :
	var player_locked_items = locked_shop_items[player_index]
	for locked_item in player_locked_items:
		if locked_item[0].my_id == item_data.my_id:
			player_locked_items.erase(locked_item)
			break


func reset(restart: bool = false) -> void :
	current_run_accessibility_settings = ProgressData.settings.enemy_scaling.duplicate()
	constant_projectile = ProgressData.settings.constant_projectile_option
	is_ban_mode_active = ProgressData.settings.ban_mode_toggled

	reset_background()
	reset_weapons_dmg_dealt()
	reset_weapons_tracked_value_this_wave()
	reset_wave_caches()
	reset_run_caches()

	for player_index in tracked_item_effects.size():
		tracked_item_effects[player_index] = init_tracked_effects()

	if not restart:
		set_player_count(1, true)
		set_coop_run(false)
		is_endless_run = false
		enabled_dlcs = ProgressData.get_active_dlc_ids()
		current_difficulty = 0
		ProgressData.reset_dlc_resources_to_active_dlcs()
	else:
		var characters: = []
		for player_data in players_data:
			characters.push_back(player_data.current_character)

		var selected_weapons: = []
		var selected_items: = []
		for player_data in players_data:
			selected_weapons.push_back(player_data.selected_weapon)
			selected_items.push_back(player_data.selected_item)


		set_player_count(get_player_count(), true)
		for i in characters.size():
			var character = characters[i]
			add_character(character, i)

		for i in selected_weapons.size():
			var selected_weapon = selected_weapons[i]
			if selected_weapon:
				add_weapon(selected_weapon, i, true)

		for i in selected_items.size():
			var selected_item = selected_items[i]
			if selected_item:
				add_item(selected_item, i, true)

		add_starting_items_and_weapons()

		var difficulty = ItemService.get_element(ItemService.difficulties, Keys.empty_hash, current_difficulty)

		
		for effect in difficulty.effects:
			effect.apply(0)

	_reset_per_wave_properties()
	DebugService.reset_for_new_run()

	reset_elites_spawn()
	reset_events_nightmare()
	init_elites_spawn()
	init_events_nightmare()
	init_bosses_spawn()

	resumed_from_state_in_shop = false
	shop_effects_checked = false
	bonus_gold = 0
	total_bonus_gold = 0
	retries = 0
	elites_killed_this_run = []
	bosses_killed_this_run = []
	loot_aliens_killed_this_run = 0
	challenges_completed_this_run = []
	run_won = false
	all_last_wave_bosses_killed = false
	locked_shop_items = [[], [], [], []]
	difficulty_unlocked = - 1
	max_endless_wave_record_beaten = - 1
	current_wave = DebugService.starting_wave

	if DebugService.randomize_waves:
		current_wave = Utils.randi_range(9, 20)

	
	instant_waves = DebugService.instant_waves
	invulnerable = DebugService.invulnerable

	for player_index in get_player_count():
		players_data[player_index].uses_ban = RunData.is_ban_mode_active
		players_data[player_index].remaining_ban_token = RunData.BAN_MAX_TOKEN

	TempStats.reset()
	LinkedStats.reset()
	ItemService.init_unlocked_pool()


func reset_wave_caches() -> void :
	for player_index in remove_speed_effect_cache.size():
		if player_index >= get_player_count():
			remove_speed_effect_cache[player_index].clear()
			continue
		remove_speed_effect_cache[player_index] = init_remove_speed_data(player_index)

	for player_index in max_consumable_stats_gained_this_wave.size():
		if player_index >= get_player_count():
			max_consumable_stats_gained_this_wave[player_index].clear()
			continue
		var consumable_stats_while_max = get_player_effect(Keys.consumable_stats_while_max_hash, player_index)
		var copied_array: = []
		for stat in consumable_stats_while_max:
			var copied_stat = stat.duplicate()
			if copied_stat.size() > 2:
				
				copied_stat[2] = 0
			copied_array.push_back(copied_stat)
		max_consumable_stats_gained_this_wave[player_index] = copied_array


func reset_run_caches() -> void :
	for cache in items_nb_cache:
		cache.clear()

	for cache in different_items_nb_cache:
		cache.clear()

	duplicate_items_cache = [null, null, null, null]


func init_bosses_spawn() -> void :
	bosses_spawn = get_bosses_to_spawn(sum_all_player_effects(Keys.double_boss_hash) > 0)


func get_bosses_to_spawn(double_boss: bool) -> Array:
	var new_bosses_spawn = []
	var possible_bosses = ItemService.get_bosses_from_zone(current_zone)
	var nb_bosses = 1

	if double_boss:
		nb_bosses = 2

	for i in nb_bosses:
		var boss_id = Utils.get_rand_element(possible_bosses).my_id

		for boss in possible_bosses:
			if boss.my_id == boss_id:
				possible_bosses.erase(boss)
				break

		new_bosses_spawn.push_back(boss_id)

	return new_bosses_spawn


func reset_elites_spawn():
	check_elite_generation = []
	elites_spawn = []

func reset_events_nightmare():
	check_nightmare_event_generation = []
	events_spawn = []
	events_fog_of_war = []
	events_bullet_hell = []

func init_events_nightmare(base_wave: int = 10) -> void :
	if check_nightmare_event_generation.has(base_wave):
		return

	var diff = current_difficulty
	if (diff > 5):

		if base_wave <= 10:
			var rand_fog1 = Utils.get_rand_element([5, 6, 7])
			events_fog_of_war = [rand_fog1]
			events_spawn.push_back([rand_fog1, "fog_of_war"])

			if constant_projectile == 1:
				var rand_bullet_hell1 = Utils.get_rand_element([1, 2])
				var rand_bullet_hell2 = Utils.get_rand_element([3, 4])
				var bullet_hell3_waves = [5, 6, 7]
				bullet_hell3_waves.erase(rand_fog1)
				var rand_bullet_hell3 = Utils.get_rand_element(bullet_hell3_waves)
				var rand_bullet_hell4 = Utils.get_rand_element([8, 9, 10])
				events_bullet_hell = [rand_bullet_hell1, rand_bullet_hell2, rand_bullet_hell3, rand_bullet_hell4]
				events_spawn.push_back([rand_bullet_hell1, "bullet_hell"])
				events_spawn.push_back([rand_bullet_hell2, "bullet_hell"])
				events_spawn.push_back([rand_bullet_hell3, "bullet_hell"])
				events_spawn.push_back([rand_bullet_hell4, "bullet_hell"])


		var potential_events_waves = []
		for i in range(9):
			potential_events_waves.push_back(base_wave + i + 1)

		for event in elites_spawn:
			potential_events_waves.erase(event[0])

		var fog_of_war_waves = []
		for i in range(2):
			var wave = Utils.get_rand_element(potential_events_waves)
			potential_events_waves.erase(wave)
			fog_of_war_waves.push_back(wave)
			events_spawn.push_back([wave, "fog_of_war"])
		events_fog_of_war.append_array(fog_of_war_waves)

		if constant_projectile == 1:
			var bullet_hell_waves = []
			for i in range(3):
				var wave = Utils.get_rand_element(potential_events_waves)
				potential_events_waves.erase(wave)
				bullet_hell_waves.push_back(wave)
				events_spawn.push_back([wave, "bullet_hell"])
			events_bullet_hell.append_array(bullet_hell_waves)

		check_nightmare_event_generation.push_back(base_wave)



func init_elites_spawn(base_wave: int = 10, horde_chance: float = 0.4) -> void :
	if check_elite_generation.has(base_wave):
		return
	var diff = current_difficulty
	var nb_elites = 0
	var possible_elites = ItemService.get_elites_from_zone(current_zone)

	for player_index in get_player_count():
		var current_character = get_player_character(player_index)
		if current_character != null:
			if current_character.my_id == "character_jack" or current_character.my_id == "character_gangster":
				horde_chance = 0.0
			elif get_player_count() == 1 and current_character.my_id == "character_ogre":
				horde_chance = 1.0

	if diff < 2:
		return
	elif diff < 4:
		nb_elites = 1
	else:
		nb_elites = 3

	var wave = Utils.randi_range(base_wave + 1, base_wave + 2)

	for i in nb_elites:

		var type = EliteType.HORDE if Utils.get_chance_success(horde_chance) else EliteType.ELITE

		if DebugService.spawn_specific_elite != "":
			type = EliteType.ELITE
			wave = DebugService.starting_wave
		elif DebugService.spawn_horde:
			type = EliteType.HORDE
			wave = DebugService.starting_wave

		if i == 1:
			wave = Utils.randi_range(base_wave + 4, base_wave + 5)
		elif i == 2:
			wave = Utils.randi_range(base_wave + 7, base_wave + 8)
			type = EliteType.ELITE

		var elite_id = Utils.get_rand_element(possible_elites).my_id_hash if type == EliteType.ELITE else Keys.empty_hash

		for elite in possible_elites:
			if elite.my_id_hash == elite_id:
				possible_elites.erase(elite)
				break

		elites_spawn.push_back([wave, type, elite_id])

	check_elite_generation.append(base_wave)


func is_elite_wave(type: int = - 1) -> bool:
	var is_elite = false

	for elite_spawn in elites_spawn:
		if elite_spawn[0] == current_wave and (type == - 1 or elite_spawn[1] == type):
			is_elite = true
			break

	return is_elite


func is_in_last_waves() -> bool:
	return current_wave >= nb_of_waves - 1


func remove_bonus_gold(value: int) -> void :
	set_bonus_gold(bonus_gold - value)


func add_bonus_gold(value: int, check_conversions: bool = true) -> void :
	var old_total: = total_bonus_gold
	var new_total: = old_total + value
	total_bonus_gold = new_total

	var is_bonus_gold_converted: = false

	if not check_conversions:
		set_bonus_gold(bonus_gold + value)
		return

	
	var nb_materials_per_conversion = 0
	var nb_stats_added_per_conversion = 0

	for player_index in range(get_player_count()):
		for effect in get_player_effect(Keys.convert_bonus_gold_hash, player_index):
			is_bonus_gold_converted = true

			nb_stats_added_per_conversion = 0
			nb_materials_per_conversion = effect.value

			for sub_effect in effect.sub_effects:
				nb_stats_added_per_conversion += sub_effect.value

			var already_converted_before = floor(old_total / get_player_count() / effect.value) as int
			var to_convert = new_total / get_player_count() - (already_converted_before * effect.value)

			while to_convert >= effect.value:
				to_convert -= effect.value
				var value_added = 0
				for sub_effect in effect.sub_effects:
					sub_effect.apply(player_index)
					value_added += sub_effect.value
				add_tracked_value(player_index, Keys.character_builder_hash, value_added, 1)

	emit_signal("bonus_gold_converted", total_bonus_gold, nb_materials_per_conversion, nb_stats_added_per_conversion)


	if not is_bonus_gold_converted:
		set_bonus_gold(bonus_gold + value)


func set_bonus_gold(value: int) -> void :
	bonus_gold = max(0, value) as int
	emit_signal("bonus_gold_changed", bonus_gold)


func add_xp(value: int, player_index: int) -> void :

	if value <= 0:
		return

	var player_data = players_data[player_index]
	player_data.current_xp += value * (1 + (Utils.get_stat(Keys.xp_gain_hash, player_index) / 100.0))

	var next_level_xp = get_next_level_xp_needed(player_index)
	emit_signal("xp_added", player_data.current_xp, next_level_xp, player_index)

	while player_data.current_xp >= next_level_xp:
		level_up(player_index)
		
		emit_signal("xp_added", player_data.current_xp, next_level_xp, player_index)
		next_level_xp = get_next_level_xp_needed(player_index)


func get_next_level_xp_needed(player_index) -> float:
	return get_xp_needed(get_player_level(player_index) + 1) * (1.0 + get_player_effect(Keys.next_level_xp_needed_hash, player_index) / 100.0)


func get_xp_needed(level: int) -> float:
	return pow(3 + level, 2)


func get_endless_factor(p_wave: int = - 1) -> float:

	var wave = p_wave if p_wave != - 1 else current_wave
	var endless_wave = max(0, wave - 20)
	var endless_mult = 2.0 + max(0.0, (wave - 35) * 0.2)
	var endless_factor = max(0.0, ((endless_wave * (endless_wave + 1)) / 2) / 100.0) * endless_mult

	return endless_factor


func get_additional_elites_endless() -> Array:
	var new_elites = []
	if current_wave > nb_of_waves:
		var nb_of_additional_elites = ceil((current_wave - 20.0) / 10.0)
		for i in nb_of_additional_elites:
			new_elites.push_back(ItemService.get_random_elite_id_hash_from_zone(ZoneService.current_zone.my_id))

	return new_elites


func level_up(player_index: int) -> void :
	var player_data = players_data[player_index]
	player_data.current_xp = max(0, player_data.current_xp - get_next_level_xp_needed(player_index))
	player_data.current_level += 1
	emit_signal("levelled_up", player_index)

	var chal_student = ChallengeService.get_chal(ChallengeService.chal_student_hash)
	if player_data.current_level >= chal_student.value:
		ChallengeService.complete_challenge(ChallengeService.chal_student_hash)

	var chal_fast_learner = ChallengeService.get_chal(ChallengeService.chal_fast_learner_hash)
	if player_data.current_level >= chal_fast_learner.value and current_wave < chal_fast_learner.additional_args[0]:
		ChallengeService.complete_challenge(ChallengeService.chal_fast_learner_hash)


func add_gold(value: int, player_index: int, ignore_debt: bool = false) -> void :
	if value == 0:
		return

	# Gourmet DLC - The Freeloader: materials grant no currency, only XP. Gating the single
	# add_gold entry point kills all 18 call sites at once (pickups, harvesting, recycling,
	# item boxes, trees, cursed-enemy payouts) and takes overtime_pay_gold_this_wave with it,
	# so Overtime Pay and Second Mortgage die for free without their own hooks. add_xp is a
	# separate call at every pickup site and is deliberately left untouched, which is what
	# keeps "materials only give XP" true.
	if is_freeloader(player_index):
		return

	var player_data = players_data[player_index]

	# Gourmet DLC - The Debtor: no spendable money, ever. Incoming materials repay debt 1:1 and
	# nothing lands in the wallet, even at 0 debt. XP is a separate add_xp call at each pickup
	# site (untouched), so pickups still level him - the same split the Freeloader uses.
	if is_debtor(player_index):
		if value > 0 and player_data.debt > 0:
			player_data.debt = int(max(0, player_data.debt - value))
			emit_signal("gold_changed", player_data.gold, player_index)
		return

	# Gourmet DLC - debt repayment: while in debt, ALL incoming materials go to the debt first
	# and you gain nothing until it clears. Each debt point costs 2 materials; debt_progress is
	# the half-material carry so 1-at-a-time gold pickups still repay at the true 2:1 rate.
	# ignore_debt=true is the Bank Loan's 500-material grant, which must land in the wallet
	# rather than instantly repaying the very debt the loan is about to create.
	if value > 0 and not ignore_debt and player_data.debt > 0:
		var owed_materials: int = player_data.debt * 2 - player_data.debt_progress
		var to_debt: int = int(min(value, owed_materials))
		value -= to_debt
		player_data.debt_progress += to_debt
		player_data.debt -= player_data.debt_progress / 2
		player_data.debt_progress = player_data.debt_progress % 2
		if player_data.debt <= 0:
			player_data.debt = 0
			player_data.debt_progress = 0
		emit_signal("gold_changed", player_data.gold, player_index)
		if value <= 0:
			return

	player_data.gold += value
	if value > 0:
		player_data.overtime_pay_gold_this_wave += value
	ChallengeService.try_complete_challenge(ChallengeService.chal_hoarder_hash, player_data.gold)

	emit_signal("gold_changed", player_data.gold, player_index)


func remove_gold(value: int, player_index: int) -> void :
	var player_data = players_data[player_index]
	player_data.gold = max(0, player_data.gold - value) as int
	emit_signal("gold_changed", player_data.gold, player_index)


# Gourmet DLC - debt helpers.
# Credit limit = total shop overspend allowed, in debt POINTS. It is the summed credit_limit
# effect (100 per Credit Card), so no card = 0 = no overspend for anyone else.
func get_credit_limit(player_index: int) -> int:
	return int(get_player_effect(Keys.credit_limit_hash, player_index))

# How much further into debt a shop overspend may go right now: the shared debt pool means a
# Bank Loan's 300 debt eats into this ceiling until repaid below the limit.
func get_available_credit(player_index: int) -> int:
	# Gourmet DLC - The Debtor buys on unlimited credit: no ceiling, so every purchase can turn
	# into debt no matter how deep he already is.
	if is_debtor(player_index):
		return 1000000000
	return int(max(0, get_credit_limit(player_index) - players_data[player_index].debt))

func get_player_debt(player_index: int) -> int:
	return players_data[player_index].debt

# Add debt directly (Bank Loan). Points, not materials; each point is 2 materials to repay.
func add_debt(points: int, player_index: int) -> void :
	if points <= 0:
		return
	players_data[player_index].debt += points
	emit_signal("gold_changed", players_data[player_index].gold, player_index)




func apply_common_gold_pickup_effects(value: int, player_index: int) -> int:
	var boost: = 1
	if Utils.get_chance_success(get_player_effect(Keys.chance_double_gold_hash, player_index) / 100.0):
		add_tracked_value(player_index, Keys.item_metal_detector_hash, value)
		boost = 2
	return boost


func add_character(character: CharacterData, player_index: int) -> void :
	players_data[player_index].current_character = character
	add_item(character, player_index)

func remove_character(character: CharacterData, player_index: int) -> void :
	players_data[player_index].current_character = null
	remove_item(character, player_index)



func add_item(item: ItemData, player_index: int, is_selection: bool = false) -> void :
	if is_selection:
		players_data[player_index].selected_item = item.duplicate()

	# Gourmet DLC - Bank Loan fires once, the moment it is acquired by ANY route (bought,
	# starting item, mirror-duplicated): +500 materials, then +300 debt. The 500 uses
	# ignore_debt so it lands in the wallet rather than instantly repaying the debt the loan
	# is about to create. The action effect carries value 1 while fresh; flipping it to 0
	# both prevents a re-fire and flips the card text to "Used" (effect.gd). Save-restore
	# rebuilds items directly (not via add_item) AND an owned loan is always already value 0,
	# so a reload can never re-trigger this.
	if item.my_id == "item_bank_loan":
		for loan_effect in item.effects:
			if loan_effect.custom_key == "bank_loan" and int(loan_effect.value) > 0:
				add_gold(500, player_index, true)
				add_debt(300, player_index)
				loan_effect.value = 0
				GourmetTracker.ev("bank_loan_used", {"p": player_index})
				break

	players_data[player_index].items.push_back(item)

	_update_item_caches(item, player_index)
	apply_item_effects(item, player_index)
	add_item_displayed(item, player_index)
	update_item_related_effects(player_index)
	LinkedStats.reset_player(player_index)
	_check_bait_chal(item.my_id_hash, player_index)
	check_scavenger_chal()
	add_item_to_item_count(item)
func add_item_next_shop(item: ItemData, player_index: int, is_selection: bool = false) -> void :
	var itemSet = [item, 16]
	forced_shop_items.append(itemSet)


func remove_item(item: ItemData, player_index: int, by_id: bool = false) -> void :
	for i in players_data[player_index].items.size():
		var cond = ItemService.is_same_item(item, players_data[player_index].items[i])

		if by_id:
			cond = item.my_id_hash == players_data[player_index].items[i].my_id_hash

		if cond:
			players_data[player_index].items.erase(players_data[player_index].items[i])
			break

	_update_item_caches(item, player_index)
	unapply_item_effects(item, player_index)
	remove_item_displayed(item, player_index)
	update_item_related_effects(player_index)
	LinkedStats.reset_player(player_index)

	if item.replaced_by:
		add_item(item.replaced_by, player_index)


func check_scavenger_chal() -> void :
	for player_data in players_data:
		var parsed_items = {}
		var nb_unique_commons = 0

		for item in player_data.items:
			if item.tier <= Tier.COMMON and not parsed_items.has(item.my_id_hash):
				parsed_items[item.my_id_hash] = true
				nb_unique_commons += 1

		if nb_unique_commons >= ChallengeService.get_chal(ChallengeService.chal_scavenger_hash).value:
			ChallengeService.complete_challenge(ChallengeService.chal_scavenger_hash)
			break


func _check_bait_chal(item_id: int, player_index: int) -> void :
	if item_id == Keys.item_bait_hash:
		var nb_baits = 0

		for player_item in get_player_items(player_index):
			if player_item.my_id_hash == Keys.item_bait_hash:
				nb_baits += 1

		if nb_baits >= ChallengeService.get_chal(ChallengeService.chal_baited_hash).value:
			ChallengeService.complete_challenge(ChallengeService.chal_baited_hash)


func add_weapon(weapon: WeaponData, player_index: int, is_selection: bool = false) -> WeaponData:
	var new_weapon = weapon.duplicate()
	if is_selection:
		players_data[player_index].selected_weapon = new_weapon

	players_data[player_index].weapons.push_back(new_weapon)
	_update_item_caches(weapon, player_index)
	apply_item_effects(new_weapon, player_index)
	update_sets(player_index)
	update_item_related_effects(player_index)
	LinkedStats.reset_player(player_index)

	check_bourgeoisie_chal()
	check_experimentation_chal()
	check_pet_chal(ChallengeService.chal_bonk_dog_hash, Keys.stat_melee_damage_hash, "stat_melee_damage")
	check_pet_chal(ChallengeService.chal_catling_gun_hash, Keys.stat_ranged_damage_hash, "stat_ranged_damage")
	check_pet_chal(ChallengeService.chal_bot_o_mine_hash, Keys.stat_engineering_hash, "stat_engineering")
	check_pet_chal(ChallengeService.chal_blazemander_hash, Keys.stat_elemental_damage_hash, "stat_elemental_damage")
	check_beast_master_chal()

	add_item_to_item_count(weapon)

	return new_weapon


func check_bourgeoisie_chal() -> void :
	for player_data in players_data:
		var legendaries = 0

		for weapon in player_data.weapons:
			if weapon.tier >= Tier.LEGENDARY:
				legendaries += 1

		if legendaries >= ChallengeService.get_chal(ChallengeService.chal_bourgeoisie_hash).value:
			ChallengeService.complete_challenge(ChallengeService.chal_bourgeoisie_hash)
			break


func check_experimentation_chal() -> void :
	for player_data in players_data:
		if player_data.weapons.size() >= ChallengeService.get_chal(ChallengeService.chal_experimentation_hash).value:
			var checked_weapons = {}
			for weapon in player_data.weapons:
				if not checked_weapons.has(weapon.weapon_id_hash):
					checked_weapons[weapon.weapon_id_hash] = 1
				else:
					checked_weapons[weapon.weapon_id_hash] += 1
			if checked_weapons.size() >= ChallengeService.get_chal(ChallengeService.chal_experimentation_hash).value:
				ChallengeService.complete_challenge(ChallengeService.chal_experimentation_hash)
				break

func check_pet_chal(chal_id: int, stat_hash: int, stat: String) -> void :
	if not ChallengeService.is_challenge_completed(chal_id):
		for player_data in players_data:
			if player_data.weapons.size() < 6:
				continue

			var melee_weapon_count = 0
			for weapon in player_data.weapons:
				var stats = weapon.stats
				if WeaponService.has_scaling_stats_hash(stats.scaling_stats, stat_hash):
					melee_weapon_count += 1

			if melee_weapon_count >= ChallengeService.get_chal(chal_id).value:
				ChallengeService.complete_challenge(chal_id)
				return

func check_beast_master_chal():
	if not ChallengeService.is_challenge_completed(ChallengeService.chal_paws_n_claws_hash):
		if (ChallengeService.is_challenge_completed(ChallengeService.chal_bonk_dog_hash)
		and ChallengeService.is_challenge_completed(ChallengeService.chal_catling_gun_hash)
		and ChallengeService.is_challenge_completed(ChallengeService.chal_bot_o_mine_hash)
		and ChallengeService.is_challenge_completed(ChallengeService.chal_blazemander_hash)
		and ChallengeService.is_challenge_completed(ChallengeService.chal_lootworm_hash)):
			ChallengeService.complete_challenge(ChallengeService.chal_paws_n_claws_hash)

func remove_weapon_by_index(index: int, player_index: int) -> int:
	var removed_weapon_tracked_value = 0
	var weapon = players_data[player_index].weapons[index]
	removed_weapon_tracked_value = weapon.tracked_value
	players_data[player_index].weapons.remove(index)
	after_weapon_removed(weapon, player_index)
	return removed_weapon_tracked_value


func remove_weapon(weapon: WeaponData, player_index: int) -> int:
	var removed_weapon_tracked_value = 0
	var weapons: Array = players_data[player_index].weapons
	for current_weapon in weapons:
		if ItemService.is_same_weapon(current_weapon, weapon):
			removed_weapon_tracked_value = current_weapon.tracked_value
			weapons.erase(current_weapon)
			break
	after_weapon_removed(weapon, player_index)
	return removed_weapon_tracked_value


func after_weapon_removed(weapon: WeaponData, player_index: int) -> void :
	_update_item_caches(weapon, player_index)
	unapply_item_effects(weapon, player_index)
	update_sets(player_index)
	update_item_related_effects(player_index)
	LinkedStats.reset_player(player_index)
	ChallengeService.check_stat_challenges(player_index)


func remove_all_weapons(player_index: int) -> void :
	var player_data = players_data[player_index]
	var weapons = player_data.weapons
	for weapon in player_data.weapons:
		unapply_item_effects(weapon, player_index)
	weapons.clear()

	_update_item_caches(WeaponData.new(), player_index)
	update_sets(player_index)
	update_item_related_effects(player_index)
	LinkedStats.reset_player(player_index)
	ChallengeService.check_stat_challenges(player_index)


func add_weapon_dmg_dealt(pos: int, dmg_dealt: int, player_index: int) -> void :
	var weapons: = get_player_weapons(player_index)
	if pos < weapons.size():
		weapons[pos].dmg_dealt_last_wave += dmg_dealt


func reset_weapons_dmg_dealt() -> void :
	for player_data in players_data:
		for weapon in player_data.weapons:
			weapon.dmg_dealt_last_wave = 0


func reset_weapons_tracked_value_this_wave() -> void :
	for player_data in players_data:
		for weapon in player_data.weapons:
			weapon.tracked_value_added_this_wave = 0


func update_sets(player_index: int) -> void :
	var player_data = players_data[player_index]
	var active_set_effects = player_data.active_set_effects
	var active_sets = player_data.active_sets

	for effect in active_set_effects:
		effect[1].unapply(player_index)

	active_sets.clear()
	active_set_effects.clear()

	var weapons: = get_player_weapons(player_index)
	for weapon in weapons:
		for set in weapon.sets:
			if get_player_effect_bool(Keys.all_weapons_count_for_sets_hash, player_index):
				active_sets[set.my_id_hash] = weapons.size()
			elif active_sets.has(set.my_id_hash):
				active_sets[set.my_id_hash] += 1
			else:
				active_sets[set.my_id_hash] = 1

	for key in active_sets:
		assert (key is int)
		if active_sets[key] >= 2:
			var set = ItemService.get_set(key)
			var set_effects = set.set_bonuses[min(active_sets[key] - 2, set.set_bonuses.size() - 1)]

			for effect in set_effects:
				effect.apply(player_index)
				active_set_effects.push_back([key, effect])


func get_unique_weapon_ids(player_index: int) -> Dictionary:
	var unique_weapon_ids = {}

	var weapons: = get_player_weapons(player_index)
	for weapon in weapons:
		unique_weapon_ids[weapon.weapon_id] = weapon

	return unique_weapon_ids


func update_item_related_effects(player_index: int) -> void :
	update_unique_bonuses(player_index)
	update_additional_weapon_bonuses(player_index)
	update_tier_iv_weapon_bonuses(player_index)
	update_tier_i_weapon_bonuses(player_index)
	Utils.reset_stat_cache(player_index)


func update_unique_bonuses(player_index: int) -> void :
	var effects: = get_player_effects(player_index)
	
	var unique_effects = players_data[player_index].unique_effects

	for effect in unique_effects:
		assert (effect[0] is int)
		if effects.has(effect[0]):
			effects[effect[0]] -= effect[1]

	unique_effects.clear()
	var unique_weapon_ids = get_unique_weapon_ids(player_index)

	for i in unique_weapon_ids.size():
		for effect in effects[Keys.unique_weapon_effects_hash]:
			assert (effect[0] is int)
			effects[effect[0]] += effect[1]
			unique_effects.push_back([effect[0], effect[1]])


func update_additional_weapon_bonuses(player_index: int) -> void :
	var effects: = get_player_effects(player_index)
	for effect in players_data[player_index].additional_weapon_effects:
		assert (effect[0] is int)
		effects[effect[0]] -= effect[1]

	players_data[player_index].additional_weapon_effects = []

	var weapons: = get_player_weapons(player_index)
	for weapon in weapons:
		for effect in effects[Keys.additional_weapon_effects_hash]:
			assert (effect[0] is int)
			effects[effect[0]] += effect[1]
			players_data[player_index].additional_weapon_effects.push_back([effect[0], effect[1]])


func update_tier_iv_weapon_bonuses(player_index: int) -> void :
	var effects: = get_player_effects(player_index)
	var tier_iv_weapon_effects = players_data[player_index].tier_iv_weapon_effects

	for effect in tier_iv_weapon_effects:
		assert (effect[0] is int)
		effects[effect[0]] -= effect[1]

	tier_iv_weapon_effects.clear()

	var weapons: = get_player_weapons(player_index)
	for weapon in weapons:
		if weapon.tier >= Tier.LEGENDARY:
			for effect in effects[Keys.tier_iv_weapon_effects_hash]:
				assert (effect[0] is int)
				effects[effect[0]] += effect[1]
				tier_iv_weapon_effects.push_back([effect[0], effect[1]])


func update_tier_i_weapon_bonuses(player_index: int) -> void :
	var effects: = get_player_effects(player_index)
	var tier_i_weapon_effects = players_data[player_index].tier_i_weapon_effects

	for effect in tier_i_weapon_effects:
		assert (effect[0] is int)
		effects[effect[0]] -= effect[1]

	tier_i_weapon_effects.clear()

	var weapons: = get_player_weapons_ref(player_index)
	for weapon in weapons:
		if weapon.tier <= Tier.COMMON:
			for effect in effects[Keys.tier_i_weapon_effects_hash]:
				assert (effect[0] is int)
				effects[effect[0]] += effect[1]
				tier_i_weapon_effects.push_back([effect[0], effect[1]])


func apply_item_effects(item_data: ItemParentData, player_index: int) -> void :
	Utils.reset_stat_cache(player_index)
	var effects = get_player_effects(player_index)
	for effect in item_data.effects:
		
		

		
		
		if item_data is ItemData and not item_data is UpgradeData and Utils.is_stat_key(effect.key_hash):
			var value_before = effects[effect.key_hash]
			effect.apply(player_index)
			var value_after = effects[effect.key_hash]
			# Gourmet DLC guard: a numeric stat-gain delta only makes sense for numeric
			# effects. Some effect keys are Array-valued (e.g. projectiles_on_eat); never
			# subtract Arrays here or item purchases hard-crash.
			if (value_before is int or value_before is float) and (value_after is int or value_after is float):
				var value_change = value_after - value_before
				if value_change > 0:
					_apply_gain_stat_for_equipped_item_with_stat_effects(effect.key_hash, player_index)
		elif effect is ConsumableDamageEffect:
			effect.apply(player_index, item_data)
		else:
			effect.apply(player_index)
	ChallengeService.check_stat_challenges(player_index)

func apply_effects_array(effects: Array, player_index: int) -> void :
	Utils.reset_stat_cache(player_index)
	var player_effects = get_player_effects(player_index)
	for effect in effects:
		if Utils.is_stat_key(effect.key_hash):
			var value_before = effects[effect.key_hash]
			effect.apply(player_index)
			var value_after = effects[effect.key_hash]
			var value_change = value_after - value_before
			if value_change > 0:
				_apply_gain_stat_for_equipped_item_with_stat_effects(effect.key_hash, player_index)
		else:
			effect.apply(player_index)
	ChallengeService.check_stat_challenges(player_index)

func unapply_item_effects(item_data: ItemParentData, player_index: int) -> void :
	Utils.reset_stat_cache(player_index)
	for effect in item_data.effects:
		effect.unapply(player_index)
	ChallengeService.check_stat_challenges(player_index)

func unapply_effects_array(effects: Array, player_index: int) -> void :
	Utils.reset_stat_cache(player_index)
	for effect in effects:
		effect.unapply(player_index)
	ChallengeService.check_stat_challenges(player_index)


func add_item_displayed(new_item: ItemData, player_index: int) -> void :
	if get_nb_item(new_item.my_id_hash, player_index) > 1:
		return


	var player_appearances: Array = players_data[player_index].appearances
	for new_appearance in new_item.item_appearances:
		if new_appearance == null or (ProgressData.settings.no_item_appearance and not new_appearance.is_character_appearance):
			continue

		var display_appearance: = true

		if new_appearance.position != 0:
			var appearance_to_erase = null

			for appearance in player_appearances:
				if appearance.position != new_appearance.position or new_appearance.position == 0:
					continue

				if new_appearance.display_priority >= appearance.display_priority:
					appearance_to_erase = appearance
				else:
					display_appearance = false

				break

			if appearance_to_erase:
				player_appearances.erase(appearance_to_erase)

		if display_appearance:
			player_appearances.push_back(new_appearance)

		player_appearances.sort_custom(Sorter, "sort_depth_ascending")


func remove_item_displayed(removed_item: ItemData, player_index: int) -> void :
	var player_appearances: Array = players_data[player_index].appearances
	for appearance in removed_item.item_appearances:
		player_appearances.erase(appearance)


func get_free_weapon_slots(player_index: int) -> int:
	var effects: = get_player_effects(player_index)
	return effects[Keys.weapon_slot_hash] - get_player_weapons_ref(player_index).size()


func has_weapon_slot_available(shop_weapon: WeaponData, player_index: int) -> bool:
	var effects: = get_player_effects(player_index)
	var weapons: = get_player_weapons_ref(player_index)

	if get_player_effect_bool(Keys.no_duplicate_weapons_hash, player_index):
		if shop_weapon.weapon_id in get_unique_weapon_ids(player_index):
			return false

	if shop_weapon.type == - 1:
		return weapons.size() < effects[Keys.weapon_slot_hash]
	else:
		var nb = 0
		for weapon in weapons:
			if weapon.type == shop_weapon.type:
				nb += 1

		var max_slots = effects[Keys.max_melee_weapons_hash] if shop_weapon.type == WeaponType.MELEE else effects[Keys.max_ranged_weapons_hash]
		return weapons.size() < effects[Keys.weapon_slot_hash] and nb < min(effects[Keys.weapon_slot_hash], max_slots)


func some_player_has_weapon_slots() -> bool:
	for player_index in get_player_count():
		if player_has_weapon_slots(player_index) or player_has_starting_items(player_index):
			return true
	return false


func player_has_weapon_slots(player_index: int) -> bool:
	return get_player_effect(Keys.weapon_slot_hash, player_index) > 0

func player_has_starting_items(player_index: int) -> bool:
	var character_data = players_data[player_index].current_character
	return character_data.starting_items.size() > 0


func manage_life_steal(weapon_stats: WeaponStats, player_index: int) -> void :
	if randf() < weapon_stats.lifesteal:
		var value = 1
		if RunData.get_player_effects(player_index).has(Keys.stat_double_lifesteal_bonus_hash) and RunData.get_player_effect_bool(Keys.stat_double_lifesteal_bonus_hash, player_index):
			value = 2
		emit_signal("lifesteal_effect", value, player_index)


func get_stat(stat_hash: int, player_index: int) -> float:
	return get_player_effect(stat_hash, player_index) * get_stat_gain(stat_hash, player_index)


func get_stat_gain(stat_hash: int, player_index: int) -> float:
	var effect_hash = Keys.generate_hash("gain_" + Keys.hash_to_string[stat_hash])
	var effects = get_player_effects(player_index)
	if not effects.has(effect_hash):
		return 1.0
	return (1.0 + (effects[effect_hash] / 100.0))


# Gourmet DLC - Blacksmith: transient (never saved) per-player armed weapon for the
# two-step manual forge. player_index -> WeaponData.
var _forge_picks: = {}
# The shop's UI weapon instances (element.item) are NOT always the same objects as the
# data-side players_data.weapons entries, so identity checks against the data list fail.
# The shop syncs its live UI weapon list here; the forge logic runs against these instances
# (which is what the popup hands us). Falls back to the data list outside the shop.
var _forge_owned_weapons: = {}


func set_forge_owned_weapons(player_index: int, weapons: Array) -> void:
	_forge_owned_weapons[player_index] = weapons


func _forge_weapons_for(player_index: int) -> Array:
	# Blacksmith forge partner + pick self-heal checks must run against the LIVE
	# weapon list. The old UI mirror (_forge_owned_weapons, fed by _sync_forge_weapons
	# on elements_changed) went stale/empty whenever clear_elements() fired its
	# elements_changed mid-rebuild - the container is momentarily empty there - which
	# hid the Forge button for legitimately forgeable pairs (e.g. two Tier I Skewers).
	# get_player_weapons() only shallow-copies the array, so the shop UI holds these
	# very same WeaponData instances: the live list is identity-equivalent to the UI
	# elements (pick / element.item comparisons still hold) and can never be stale.
	return get_player_weapons_ref(player_index)


func is_blacksmith(player_index: int) -> bool:
	var forge_character = get_player_character(player_index)
	return forge_character != null and forge_character.my_id == "character_blacksmith"


func is_mime(player_index: int) -> bool:
	var mirror_character = get_player_character(player_index)
	return mirror_character != null and mirror_character.my_id == "character_mime"


# Gourmet DLC - Mime: can a mirrored weapon purchase actually fit?
# The shop gate cannot simply ask has_weapon_slot_available. Mirrors hand him 2+ copies at
# once, copies merge with EACH OTHER, and the result can merge again up the line - so a buy
# that looks impossible on a full inventory frequently is not. Vanilla's gate only allows a
# full-inventory buy when an EXACT my_id match is already owned, which wrongly blocked
# "3x Stick T2, buy Stick T1 with a mirror" even though the two new T1s merge into a T2 and
# then pair with an owned T2 for a T3.
# This simulates the same lowest-tier-first cascade base_shop._auto_merge_to_fit performs and
# reports whether it lands back inside the slot limit. Keep the two in sync.
func mime_purchase_fits(shop_weapon: WeaponData, player_index: int) -> bool:
	return mime_max_copies_that_fit(shop_weapon, player_index) > 0


# Largest number of total copies (purchase + mirrors) that the cascade can absorb, or 0 if
# even the bare purchase cannot fit. Mirrors are capped to this, exactly as the ITEM path
# already caps duplication with min(value, remaining_item_count - 1): taking every mirror is
# not always better. Owning 1x Stick T1 on a full inventory, a normal character can buy a
# Stick T1 and merge to T2, but forcing two mirrored copies leaves 1x T1 + 1x T2 and does not
# fit - so the Mime would be unable to make a purchase anyone else could. He takes as many
# mirrors as fit and no more.
func mime_max_copies_that_fit(shop_weapon: WeaponData, player_index: int) -> int:
	var mirrors: = 0
	for dup_effect in get_player_effect(Keys.duplicate_item_hash, player_index):
		mirrors += int(dup_effect[1])
	for copies in range(mirrors + 1, 0, -1):
		if _mime_copies_fit(shop_weapon, player_index, copies):
			return copies
	return 0


func _mime_copies_fit(shop_weapon: WeaponData, player_index: int, copies: int) -> bool:
	var effects: = get_player_effects(player_index)
	var slot_max: int = int(effects[Keys.weapon_slot_hash])
	var owned: = get_player_weapons_ref(player_index)

	var total: int = owned.size() + copies

	# only the bought weapon's own line can merge; everything else is immovable ballast
	var line: = {}
	for weapon in owned:
		if weapon.weapon_id == shop_weapon.weapon_id:
			line[weapon.tier] = int(line.get(weapon.tier, 0)) + 1
	line[shop_weapon.tier] = int(line.get(shop_weapon.tier, 0)) + copies

	# The real merge ceiling: a weapon can only combine while it HAS an upgrade to become.
	# Walk the shop weapon's upgrades_into chain to find the top tier of this line, and cap
	# that by the run's max_weapon_tier. WITHOUT this the loop ran to max_weapon_tier, which
	# DEFAULTS TO 99 - so it merged T4 pairs into an imaginary T5, T6, ... concluded that any
	# number of copies eventually fits, and offered "x62" on a full inventory. Buying that
	# then added 62 weapons the real cascade could not absorb.
	var chain_top: int = shop_weapon.tier
	var chain_walk = shop_weapon
	while chain_walk != null and chain_walk.upgrades_into != null:
		chain_walk = chain_walk.upgrades_into
		chain_top = chain_walk.tier
	var merge_ceiling: int = int(min(chain_top, int(effects[Keys.max_weapon_tier_hash])))

	var guard: = 0
	while total > slot_max:
		guard += 1
		if guard > 64:
			return false
		var merged: = false
		for tier in range(0, merge_ceiling):
			if int(line.get(tier, 0)) >= 2:
				line[tier] = int(line[tier]) - 2
				line[tier + 1] = int(line.get(tier + 1, 0)) + 1
				total -= 1
				merged = true
				break
		if not merged:
			return false
	return true


# Gourmet DLC - The Special (character #18): every wave rolls random modifiers.
func is_special(player_index: int) -> bool:
	var character = get_player_character(player_index)
	return character != null and character.my_id == "character_special"


# Gourmet DLC - The Freeloader (character #16). Single gate for his whole kit: 8 shop
# items / 8 upgrades, everything free, one purchase per shop, no reroll, no lock, no
# crate items, no gold economy, flat 25% curse roll. Every other rule checks this.
func is_freeloader(player_index: int) -> bool:
	var character = get_player_character(player_index)
	return character != null and character.my_id == "character_freeloader"


# True when ANY player in the run is the Freeloader. Needed by the few hooks that have
# no player_index in scope (the gold gate runs per-player, but the shop-width helper is
# asked for a layout before player context exists in coop).
func has_freeloader() -> bool:
	for i in get_player_count():
		if is_freeloader(i):
			return true
	return false


# Gourmet DLC - The Debtor (character_test_debt). No money economy: pickups give only XP and
# repay debt 1:1; buying goes on unlimited credit; debt takes +10% interest each wave. Enemy
# scaling from debt is GLOBAL (see get_total_debt); every other rule is gated on this.
func is_debtor(player_index: int) -> bool:
	var character = get_player_character(player_index)
	return character != null and character.my_id == "character_test_debt"


# Total outstanding debt across all active players. Enemies scale off this (+1% HP & damage per
# 20 debt) - a GLOBAL rule, so anyone carrying debt makes the arena harder, not just the Debtor.
func get_total_debt() -> int:
	var total: = 0
	for i in get_player_count():
		total += players_data[i].debt
	return total


# Gourmet DLC - Debtor: debt compounds +10% at the end of every cleared wave (called from
# main.clean_up_room). Only the Debtor accrues interest.
func apply_debt_interest() -> void :
	for i in get_player_count():
		if is_debtor(i) and players_data[i].debt > 0:
			players_data[i].debt = int(ceil(players_data[i].debt * 1.1))
			emit_signal("gold_changed", players_data[i].gold, i)


# The weapon currently armed as the first half of a forge. Self-heals if that weapon
# has since left the inventory (recycled, forged away), so it can never dangle.
func get_forge_pick(player_index: int) -> WeaponData:
	var pick = _forge_picks.get(player_index)
	if pick != null and not (pick in _forge_weapons_for(player_index)):
		_forge_picks.erase(player_index)
		return null
	return pick


func set_forge_pick(player_index: int, weapon_data: WeaponData) -> void:
	if weapon_data == null:
		_forge_picks.erase(player_index)
	else:
		_forge_picks[player_index] = weapon_data


func clear_forge_pick(player_index: int) -> void:
	_forge_picks.erase(player_index)


# A legal Blacksmith pair: two DIFFERENT owned weapons of the same tier that share at
# least one class, where an unlocked next-tier weapon exists in that shared class.
# Identical duplicates qualify too (they share every class) - the decided design.
func is_valid_forge_pair(weapon_a: WeaponData, weapon_b: WeaponData, player_index: int) -> bool:
	if weapon_a == null or weapon_b == null or weapon_a == weapon_b:
		return false
	if weapon_a.tier != weapon_b.tier:
		return false
	if weapon_a.tier >= get_player_effect(Keys.max_weapon_tier_hash, player_index):
		return false
	var shared_sets: = []
	for set_a in weapon_a.sets:
		for set_b in weapon_b.sets:
			if set_a.my_id == set_b.my_id:
				shared_sets.push_back(set_a)
	if shared_sets.empty():
		return false
	return not get_blacksmith_forge_pool(weapon_a.tier + 1, shared_sets).empty()


# Does this weapon have at least one legal forge partner in the inventory?
func has_forge_partner(weapon_data: WeaponData, player_index: int) -> bool:
	for other_weapon in _forge_weapons_for(player_index):
		if is_valid_forge_pair(weapon_data, other_weapon, player_index):
			return true
	return false


func can_combine(weapon_data: WeaponData, player_index: int) -> bool:
	# Gourmet DLC - Blacksmith: no vanilla auto-merge. You arm one weapon, then pick a
	# legal partner; the forge button drives that two-step flow, so an illegal pair
	# simply never shows a button (the game refuses impossible merges by construction).
	if is_blacksmith(player_index):
		var pick = get_forge_pick(player_index)
		if pick == null:
			return has_forge_partner(weapon_data, player_index)
		elif pick == weapon_data:
			return true  # armed weapon: the button cancels the selection
		else:
			return is_valid_forge_pair(pick, weapon_data, player_index)

	var nb_duplicates = 0

	var weapons: = get_player_weapons_ref(player_index)
	for weapon in weapons:
		if weapon.my_id == weapon_data.my_id:
			nb_duplicates += 1

	var max_weapon_tier = get_player_effect(Keys.max_weapon_tier_hash, player_index)
	if nb_duplicates >= 2 and weapon_data.upgrades_into != null and weapon_data.tier < max_weapon_tier:
		return true

	return false


# forge pool: UNLOCKED weapons of the target tier carrying any of the given classes
func get_blacksmith_forge_pool(target_tier: int, class_sets: Array) -> Array:
	var pool: = []
	for weapon in ItemService.weapons:
		if weapon.tier != target_tier:
			continue
		if not ProgressData.weapons_unlocked.has(weapon.weapon_id_hash):
			continue
		var shares: = false
		for weapon_set in weapon.sets:
			for wanted_set in class_sets:
				if weapon_set.my_id == wanted_set.my_id:
					shares = true
		if shares:
			pool.push_back(weapon)
	return pool


func sort_appearances() -> void :
	for player_data in players_data:
		player_data.appearances.sort_custom(Sorter, "sort_depth_ascending")


func init_remove_speed_data(player_index: int) -> Dictionary:
	var effects: = get_player_effects(player_index)
	var data = {"value": 0, "max_value": 0}
	if effects[Keys.remove_speed_hash].size() > 0:
		for remove_speed_data in effects[Keys.remove_speed_hash]:
			data.value += remove_speed_data[0]
			data.max_value = max(data.max_value, remove_speed_data[1])

	return data


func get_remove_speed_data(player_index) -> Dictionary:
	if player_index == DUMMY_PLAYER_INDEX:
		return dummy_player_remove_speed_data
	return remove_speed_effect_cache[player_index]


func get_armor_coef(armor: int) -> float:
	var percent_dmg_taken = 10.0 / (10.0 + (abs(armor) / 1.5))





	if armor < 0:
		percent_dmg_taken = (1.0 - percent_dmg_taken) + 1.0

	return percent_dmg_taken


func get_hp_regeneration_timer(hp_regen: int) -> float:





	if hp_regen <= 0:
		return 99.0

	var timer_duration = 5.0 / (1.0 + (abs(hp_regen - 1) / 2.25))

	return timer_duration


func reset_background() -> void :
	if ProgressData.settings.background == 0 or ProgressData.settings.background > ItemService.backgrounds.size():
		var zone_data = ZoneService.zones[0]

		for zone in ZoneService.zones:
			if zone.my_id == current_zone:
				zone_data = zone
				break

		var backgrounds_from = zone_data.default_backgrounds if zone_data.default_backgrounds.size() > 0 else ItemService.backgrounds
		current_background = Utils.get_rand_element(backgrounds_from)
	else:
		current_background = ItemService.backgrounds[ProgressData.settings.background - 1]


func get_background() -> Resource:
	return current_background





func add_stat(stat_hsh: int, value: int, player_index: int) -> void :
	assert (Utils.is_stat_key(stat_hsh), "%s is not a stat key" % Keys.hash_to_string[stat_hsh])
	var effects: = get_player_effects(player_index)
	effects[stat_hsh] += value
	emit_signal("stat_added", stat_hsh, value, 0.0, player_index)
	_are_player_stats_dirty[player_index] = true
	Utils.reset_stat_cache(player_index)


func remove_stat(stat_hsh: int, value: int, player_index: int) -> void :
	assert (Utils.is_stat_key(stat_hsh), "%s is not a stat key" % Keys.hash_to_string[stat_hsh])
	var effects: = get_player_effects(player_index)
	effects[stat_hsh] -= value
	emit_signal("stat_removed", stat_hsh, value, 0.0, player_index)
	_are_player_stats_dirty[player_index] = true
	Utils.reset_stat_cache(player_index)


func _emit_stats_updated() -> void :
	for player_index in get_player_count():
		if _are_player_stats_dirty[player_index] or TempStats.are_player_stats_dirty[player_index] or LinkedStats.are_player_stats_dirty[player_index]:
			emit_signal("stats_updated", player_index)
			_are_player_stats_dirty[player_index] = false
			TempStats.are_player_stats_dirty[player_index] = false
			LinkedStats.are_player_stats_dirty[player_index] = false
			ChallengeService.check_stat_challenges(player_index)


func get_player_currency(player_index: int) -> int:
	var effects: = get_player_effects(player_index)
	return get_stat(Keys.stat_max_hp_hash, player_index) as int if effects[Keys.hp_shop_hash] else get_player_gold(player_index)


func remove_currency(value: int, player_index: int) -> void :
	var effects: = get_player_effects(player_index)
	if effects[Keys.hp_shop_hash]:
		remove_stat(Keys.stat_max_hp_hash, value, player_index)
		return

	# Gourmet DLC - Credit Card: a shop purchase may overspend the wallet, and the shortfall
	# becomes debt (1 material overspent = 1 debt point = 2 materials to repay). The affordability
	# gate (shop_items_container) already confirmed the overspend fits inside available credit, so
	# this only ever runs for a card holder buying beyond their materials. The card tracks the
	# debt it takes on. Rerolls and non-shop costs still use remove_gold and cannot go negative.
	var player_data = players_data[player_index]
	if value > player_data.gold and get_available_credit(player_index) > 0:
		var overspend: int = value - player_data.gold
		overspend = int(min(overspend, get_available_credit(player_index)))
		remove_gold(player_data.gold, player_index)  # empty the wallet
		if overspend > 0:
			player_data.debt += overspend
			add_tracked_value(player_index, Keys.generate_hash("item_credit_card"), overspend)
			emit_signal("gold_changed", player_data.gold, player_index)
		return

	remove_gold(value, player_index)


func get_nb_food_items(player_index: int) -> int:
	var result: = 0
	for item in get_player_items_ref(player_index):
		if item.tags.has("food"):
			result += 1
	return result


# Gourmet DLC - Minimalist tier ladder: items grant All Stats by tier
# (T0 +2, T1 +4, T2 +6, T3 +8 -> units 1/2/3/4 x scaler value 2). While all 6
# slots hold max-tier items, everything gives +12 instead (units x 1.5).
# Duck-typed on purpose: no item class references from a singleton the item
# chain feeds back into (cyclic-dependency law).
func get_nb_minimalist_items(player_index: int) -> float:
	var nb_items: = 0
	var units: = 0
	var all_max_tier: = true
	for item in get_player_items_ref(player_index):
		if item.my_id.begins_with("item_"):
			nb_items += 1
			units += item.tier + 1
			if item.tier < 3:
				all_max_tier = false
	if nb_items == 6 and all_max_tier:
		return units * 1.5
	return float(units)


# Gourmet DLC - Juggler: weapons attack one at a time, cycling left to right
var _juggler_pos: = {}

func is_juggler_cycling(player_index: int) -> bool:
	var character = get_player_character(player_index)
	return character != null and character.my_id == "character_juggler"


func get_juggler_active_pos(player_index: int) -> int:
	var nb = get_player_weapons_ref(player_index).size()
	if nb <= 0:
		return - 1
	return _juggler_pos.get(player_index, 0) % nb


func advance_juggler(player_index: int) -> void :
	_juggler_pos[player_index] = get_juggler_active_pos(player_index) + 1


func get_nb_structures(player_index: int) -> int:
	var result = get_player_effect(Keys.structures_hash, player_index).size() + get_nb_item(Keys.item_pocket_factory_hash, player_index)

	for pet in get_player_effect(Keys.stat_pets_hash, player_index):
		if pet.is_structure:
			result += 1

	return result

func get_nb_pets(player_index: int) -> int:
	var result = get_player_effect(Keys.stat_pets_hash, player_index).size() + get_player_effect(Keys.stat_jellyshield_count_hash, player_index)

	for structure in get_player_effect(Keys.structures_hash, player_index):
		if structure.is_pet:
			result += 1

	return result

func get_nb_item(item_id_hash: int, player_index: int, use_cache: bool = true) -> int:
	if use_cache and items_nb_cache.size() > player_index and items_nb_cache[player_index].has(item_id_hash):
		return items_nb_cache[player_index][item_id_hash]
	var nb: = 0
	for item in get_player_items_ref(player_index):
		if item_id_hash == item.my_id_hash:
			nb += 1
	if items_nb_cache.size() > player_index:
		items_nb_cache[player_index][item_id_hash] = nb
	return nb


# Gourmet DLC - the effective per-run cap on an item, and the single source of truth for
# it: shop gating, the loot pool and the "LIMITED (n/max)" card label all go through here.
# Picky Eater: only one food spawner TYPE ever fires for him, so he is allowed twice as
# many copies of that type (a limit-3 spawner becomes limit 6). Keyed on the "spawner"
# tag that build_food_system.py stamps on every spawner item, so non-spawner food items
# (Soul Food, Set Menu, Wine Cellar and the other unique diamonds) keep their own cap.
func get_item_max_nb(item_data, player_index: int) -> int:
	if item_data.max_nb <= 0:
		return item_data.max_nb

	if item_data.tags.has("spawner"):
		var picky_character = get_player_character(player_index)
		if picky_character != null and picky_character.my_id == "character_picky_eater":
			return item_data.max_nb * 2

	return item_data.max_nb


func get_remaining_max_nb_item(item_data: ItemData, player_index: int) -> int:
	if item_data.max_nb == - 1:
		return Utils.LARGE_NUMBER

	var existing_item_count: = get_nb_item(item_data.my_id_hash, player_index)
	return max(0, get_item_max_nb(item_data, player_index) - existing_item_count) as int


func get_nb_different_items_of_tier(tier: int, player_index: int, use_cache: = true) -> int:
	if use_cache and different_items_nb_cache.size() > player_index and different_items_nb_cache[player_index].has(tier):
		return different_items_nb_cache[player_index][tier]
	var nb = 0
	var parsed_items = {}
	for item in get_player_items_ref(player_index):
		if (item.tier == tier or tier == - 1) and not parsed_items.has(item.my_id_hash) and not item.my_id.begins_with("character_"):
			parsed_items[item.my_id_hash] = true
			nb += 1
	if different_items_nb_cache.size() > player_index:
		different_items_nb_cache[player_index][tier] = nb
	return nb


func get_duplicate_items_count(player_index: int, use_cache: = true) -> int:
	if use_cache and duplicate_items_cache.size() > player_index and duplicate_items_cache[player_index] != null:
		return duplicate_items_cache[player_index]

	var duplicate_count: = 0
	var item_counts: = {}
	for item in get_player_items(player_index):
		if item_counts.has(item.my_id_hash):
			item_counts[item.my_id_hash] += 1
			duplicate_count += 1
		else:
			item_counts[item.my_id_hash] = 1

	for weapon in get_player_weapons(player_index):
		if item_counts.has(weapon.weapon_id_hash):
			item_counts[weapon.weapon_id_hash] += 1
			duplicate_count += 1
		else:
			item_counts[weapon.weapon_id_hash] = 1

	if duplicate_items_cache.size() > player_index:
		duplicate_items_cache[player_index] = duplicate_count
	return duplicate_count


func _update_item_caches(item: ItemParentData, player_index: int) -> void :
	if item is ItemData:
		assert (item.my_id_hash != Keys.empty_hash)
		get_nb_item(item.my_id_hash, player_index, false)
		get_nb_different_items_of_tier( - 1, player_index, false)
		get_nb_different_items_of_tier(item.tier, player_index, false)
		get_duplicate_items_count(player_index, false)

	if item is WeaponData:
		get_duplicate_items_count(player_index, false)


func add_recycled(player_index: int) -> void :
	var player_data = players_data[player_index]
	player_data.chal_recycling_current += 1
	ChallengeService.try_complete_challenge(ChallengeService.chal_recycling_hash, player_data.chal_recycling_current)


func revert_all_selections() -> void :
	set_player_count(get_player_count(), true)


func add_starting_items_and_weapons() -> void :
	for player_index in players_data.size():
		var effects: = get_player_effects(player_index)

		if effects[Keys.starting_item_hash].size() > 0:
			for item_id in effects[Keys.starting_item_hash]:
				for i in item_id[1]:
					assert (item_id[0] is int)
					var item = ItemService.get_element(ItemService.items, item_id[0])
					add_item(item, player_index)

		if effects[Keys.starting_weapon_hash].size() > 0:
			for weapon_id in effects[Keys.starting_weapon_hash]:
				for i in weapon_id[1]:
					assert (weapon_id[0] is int)

					var weapon = ItemService.get_element(ItemService.weapons, weapon_id[0])
					var _weapon = add_weapon(weapon, player_index)

		if effects[Keys.cursed_starting_item_hash].size() > 0 and ProgressData.is_dlc_available_and_active("abyssal_terrors"):
			var dlc = ProgressData.get_dlc_data("abyssal_terrors")

			for item_id in effects[Keys.cursed_starting_item_hash]:
				for i in item_id[1]:
					var item = ItemService.get_element(ItemService.items, item_id[0])
					if dlc:
						item = dlc.curse_item(item, player_index, true)
					add_item(item, player_index)

		if effects[Keys.cursed_starting_weapon_hash].size() > 0 and ProgressData.is_dlc_available_and_active("abyssal_terrors"):
			var dlc = ProgressData.get_dlc_data("abyssal_terrors")

			for weapon_id in effects[Keys.cursed_starting_weapon_hash]:
				for i in weapon_id[1]:
					assert (weapon_id[0] is int)
					var weapon = ItemService.get_element(ItemService.weapons, weapon_id[0])
					if dlc:
						weapon = dlc.curse_item(weapon, player_index, true)
					var _weapon = add_weapon(weapon, player_index)


func add_item_to_item_count(item: ItemParentData):
	if not ProgressData.items_bought.has(item.my_id_hash):
		ProgressData.items_bought[item.my_id_hash] = 1
	else:
		ProgressData.items_bought[item.my_id_hash] += 1



func handle_explode_effect(key: int, position: Vector2, player_index: int, use_second_args: = false) -> void :
	var effect = get_player_effects(player_index)[key]

	var explosion_chance: = 0.0
	for explosion in effect:
		explosion_chance += explosion.chance
	if not Utils.get_chance_success(explosion_chance):
		return

	var dmg = 0
	for explosion in effect:
		dmg += WeaponService.get_explosion_damage(explosion.stats, player_index)

	var first_effect = effect[0]
	var first_stats = first_effect.stats

	if first_effect is ItemExplodingAndBurnEffect:
		var scaled_burning_data: BurningData = WeaponService.init_burning_data(first_effect.burning_data, player_index)
		first_stats.burning_data = scaled_burning_data

	
	position = Utils.get_random_offset_position(position, 10)

	if not use_second_args:
		_explode_args_node.pos = position
		_explode_args_node.damage = dmg
		_explode_args_node.accuracy = first_stats.accuracy
		_explode_args_node.crit_chance = first_stats.crit_chance + Utils.get_capped_stat(Keys.stat_crit_chance_hash, player_index) / 100.0
		_explode_args_node.crit_damage = first_stats.crit_damage
		_explode_args_node.burning_data = first_stats.burning_data
		_explode_args_node.scaling_stats = first_stats.scaling_stats
		_explode_args_node.damage_tracking_key_hash = first_effect.tracking_key_hash
		_explode_args_node.from_player_index = player_index
		WeaponService.call_deferred("explode", first_effect, _explode_args_node)
	else:
		_second_explode_args_node.pos = position
		_second_explode_args_node.damage = dmg
		_second_explode_args_node.accuracy = first_stats.accuracy
		_second_explode_args_node.crit_chance = first_stats.crit_chance + Utils.get_capped_stat(Keys.stat_crit_chance_hash, player_index) / 100.0
		_second_explode_args_node.crit_damage = first_stats.crit_damage
		_second_explode_args_node.burning_data = first_stats.burning_data
		_second_explode_args_node.scaling_stats = first_stats.scaling_stats
		_second_explode_args_node.damage_tracking_key_hash = first_effect.tracking_key_hash
		_second_explode_args_node.from_player_index = player_index
		WeaponService.call_deferred("explode", first_effect, _second_explode_args_node)



func update_recycling_tracking_value(item_data: ItemParentData, player_index: int) -> void :
	if get_nb_item(Keys.item_recycling_machine_hash, player_index) > 0:
		var value = ItemService.get_value(current_wave, item_data.value, player_index, true, true, item_data.my_id_hash)
		var recycling_gains = get_player_effect(Keys.recycling_gains_hash, player_index)
		
		add_tracked_value(player_index, Keys.item_recycling_machine_hash, (value * (recycling_gains / 100.0)) as int)


func should_show_endless_button() -> bool:
	return current_wave == 19 and not is_endless_run


func get_state() -> Dictionary:
	var players_data_copy: = []
	for player_data in players_data:
		players_data_copy.push_back(player_data.duplicate())

	return {
		"players_data": players_data_copy, 

		"enemy_scaling": current_run_accessibility_settings.duplicate(), 
		"constant_projectile": constant_projectile, 
		"nb_of_waves": nb_of_waves, 
		"current_zone": current_zone, 
		"current_wave": current_wave, 
		"current_difficulty": current_difficulty, 
		"bonus_gold": bonus_gold, 
		"total_bonus_gold": total_bonus_gold, 
		"retries": retries, 
		"elites_spawn": elites_spawn.duplicate(), 
		"bosses_spawn": bosses_spawn.duplicate(), 
		"events_spawn": events_spawn.duplicate(), 
		"events_fog_of_war": events_fog_of_war.duplicate(), 
		"events_bullet_hell": events_bullet_hell.duplicate(), 
		"shop_effects_checked": shop_effects_checked, 
		"elites_killed_this_run": elites_killed_this_run.duplicate(), 
		"bosses_killed_this_run": bosses_killed_this_run.duplicate(), 
		"loot_aliens_killed_this_run": loot_aliens_killed_this_run, 

		"challenges_completed_this_run": challenges_completed_this_run.duplicate(), 
		"locked_shop_items": locked_shop_items.duplicate(true), 
		"current_background": current_background, 

		"max_endless_wave_record_beaten": max_endless_wave_record_beaten, 
		"is_endless_run": is_endless_run, 
		"is_coop_run": is_coop_run, 
		"play_mode": PlayMode.SOLO, 
		"is_streamplay_run": false, 
		"enabled_dlcs": enabled_dlcs, 

		"tracked_item_effects": tracked_item_effects.duplicate(true)
	}


func reset_to_start_wave_state() -> void :

	for player_data in players_data:
		for weapon in player_data.weapons:
			weapon.tracked_value -= weapon.tracked_value_added_this_wave
	resume_from_state(start_wave_state)

	var run_state = ProgressData.last_saved_run_state if ProgressData.last_saved_run_state else ProgressData._get_empty_run_state()
	ProgressData.reset_and_save_run_state(run_state)


func continue_current_run_in_shop() -> void :
	resume_from_state(ProgressData.saved_run_state)
	resumed_from_state_in_shop = true


func resume_from_state(state: Dictionary) -> void :

	ProgressData.update_dlc_resources_based_on_run_state(state)

	var players_data_copy: = []
	for player_data in state.players_data:
		players_data_copy.push_back(player_data.duplicate())
	players_data = players_data_copy

	current_run_accessibility_settings = state.enemy_scaling.duplicate()
	if state.has("constant_projectile"):
		constant_projectile = int(state.constant_projectile)

	nb_of_waves = state.nb_of_waves
	retries = state.retries
	current_zone = state.current_zone
	current_wave = state.current_wave
	current_difficulty = state.current_difficulty
	bonus_gold = state.bonus_gold
	total_bonus_gold = state.total_bonus_gold if "total_bonus_gold" in state else 0

	elites_spawn = state.elites_spawn.duplicate()
	for e in elites_spawn:
		match typeof(e[2]):
			TYPE_STRING:
				e[2] = Keys.generate_hash((e[2]))
			TYPE_REAL:
				e[2] = int(e[2])

	bosses_spawn = state.bosses_spawn.duplicate()
	if state.has("events_spawn"):
		events_spawn = state.events_spawn.duplicate()
	if state.has("events_fog_of_war"):
		events_fog_of_war = state.events_fog_of_war.duplicate()
	if state.has("events_bullet_hell"):
		events_bullet_hell = state.events_bullet_hell.duplicate()
	shop_effects_checked = state.shop_effects_checked
	elites_killed_this_run = state.elites_killed_this_run
	bosses_killed_this_run = state.bosses_killed_this_run
	loot_aliens_killed_this_run = state.loot_aliens_killed_this_run

	for challenge in state.challenges_completed_this_run:
		if not challenges_completed_this_run.has(challenge):
			challenges_completed_this_run.append(challenge)
	locked_shop_items = state.locked_shop_items.duplicate(true)
	current_background = state.current_background

	max_endless_wave_record_beaten = state.max_endless_wave_record_beaten
	is_endless_run = state.is_endless_run
	set_coop_run(state.is_coop_run)
	play_mode = RunData.PlayMode.COOP if state.is_coop_run else state.get("play_mode", RunData.PlayMode.SOLO)
	is_streamplay_run = play_mode == RunData.PlayMode.STREAMPLAY_LOCAL or play_mode == RunData.PlayMode.STREAMPLAY_INTERNET
	enabled_dlcs = state.enabled_dlcs

	tracked_item_effects = Utils.convert_to_hash_array(state.tracked_item_effects.duplicate())

	ZoneService.current_zone = ZoneService.get_zone_data(current_zone).duplicate()

	LinkedStats.reset()


func get_shop_scene_path() -> String:
	return "res://ui/menus/shop/coop_shop.tscn" if is_coop_run else "res://ui/menus/shop/shop.tscn"


func get_end_run_scene_path() -> String:
	return "res://ui/menus/run/coop_end_run.tscn" if is_coop_run else "res://ui/menus/run/end_run.tscn"


func is_last_wave() -> bool:
	var is_last_wave = current_wave == ZoneService.get_zone_data(current_zone).waves_data.size()
	if is_endless_run: is_last_wave = false
	return is_last_wave



func apply_end_run() -> void :
	DebugService.log_data("end run...")

	var nb_waves = ZoneService.get_zone_data(current_zone).waves_data.size()

	if all_last_wave_bosses_killed:
		run_won = true
	else:
		run_won = current_wave > nb_waves or (current_wave >= nb_of_waves and not wave_in_progress)

	if run_won:
		apply_run_won()
	else:
		ProgressData.reset_and_save_new_run_state()

	var scene = get_end_run_scene_path()
	var _e = get_tree().change_scene(scene)
	get_tree().paused = false


func apply_run_won() -> void :
	DebugService.log_data("is_run_won")
	for player_index in get_player_count():
		var player_character = get_player_character(player_index)
		var character_chal_name = "chal_" + player_character.name.to_lower().replace("character_", "")

		if not ChallengeService.is_challenge_completed(ChallengeService.chal_candy_bag_hash) and not get_player_effect_bool(Keys.used_item_locking_hash, player_index):
			ChallengeService.complete_challenge(ChallengeService.chal_candy_bag_hash)

		if Platform.get_type() == PlatformType.STEAM:
			ChallengeService.complete_challenge(Keys.generate_hash(character_chal_name), false)

			if not ProgressData.is_unlock_all_save() and not Utils.on_nintendo_nx_or_ounce:
				if current_zone == 0:
					Platform.complete_challenge(Keys.generate_hash(character_chal_name))
				elif current_zone == 1:
					if character_chal_name == "chal_beast_master" or character_chal_name == "chal_wounded":
						Platform.complete_challenge(Keys.generate_hash(character_chal_name))
					else:
						Platform.complete_challenge(Keys.generate_hash(character_chal_name + "_abyss"))
		else:
			ChallengeService.complete_challenge(Keys.generate_hash(character_chal_name))

		var character_difficulty = ProgressData.get_character_difficulty_info(player_character.my_id_hash, current_zone)
		if character_difficulty.max_selectable_difficulty < current_difficulty + 1 and current_difficulty + 1 <= ProgressData.MAX_DIFFICULTY - 1:
			
			difficulty_unlocked = current_difficulty + 1

		character_difficulty.max_difficulty_beaten.set_info(
			current_difficulty, 
			current_wave, 
			current_run_accessibility_settings.health, 
			current_run_accessibility_settings.damage, 
			current_run_accessibility_settings.speed, 
			retries, 
			0 if not is_ban_mode_active else get_used_ban_count(), 
			constant_projectile, 
			is_coop_run, 
			false
		)

		if Keys.stat_curse_hash in get_player_effects(player_index):
			var curse_stat = max(0, Utils.get_max_capped_stat(Keys.stat_curse_hash, player_index)) as int
			ChallengeService.try_complete_challenge(ChallengeService.chal_uncorrupted_hash, curse_stat, true)

	ChallengeService.complete_challenge(Keys.generate_hash("chal_difficulty_" + String(current_difficulty)))
	if current_difficulty >= ChallengeService.get_chal(ChallengeService.chal_banned_items_hash).value:
		ChallengeService.complete_challenge(ChallengeService.chal_banned_items_hash)

	if ProgressData.difficulties_unlocked[0].zones_difficulty_info[0].max_selectable_difficulty < current_difficulty + 1 and current_difficulty + 1 <= ProgressData.MAX_DIFFICULTY - 1:
		for char_diff in ProgressData.difficulties_unlocked:
			for zone_difficulty_info in char_diff.zones_difficulty_info:
				zone_difficulty_info.max_selectable_difficulty = clamp(current_difficulty + 1, zone_difficulty_info.max_selectable_difficulty, ProgressData.MAX_DIFFICULTY - 1)

	try_unlock_nightmare()

	ProgressData.reset_and_save_new_run_state()


func try_unlock_nightmare():
	if ProgressData.difficulties_unlocked.size() > 0 and ProgressData.difficulties_unlocked[0].zones_difficulty_info[0].max_selectable_difficulty != ProgressData.MAX_DIFFICULTY - 1:
		return

	var danger_5_won_characters: = 10
	var counter: = 0
	for char_diff in ProgressData.difficulties_unlocked:
		for zone_difficulty_info in char_diff.zones_difficulty_info:
			if zone_difficulty_info.max_difficulty_beaten.difficulty_value >= ProgressData.MAX_DIFFICULTY - 1:
				counter += 1
				if counter >= danger_5_won_characters:
					break

		if counter >= danger_5_won_characters:
			break

	if counter >= danger_5_won_characters:
		
		for char_diff in ProgressData.difficulties_unlocked:
			for zone_difficulty_info in char_diff.zones_difficulty_info:
				zone_difficulty_info.max_selectable_difficulty = ProgressData.MAX_DIFFICULTY

		difficulty_unlocked = ProgressData.MAX_DIFFICULTY

func cancel_resume() -> void :
	resumed_from_state_in_shop = false


func init_tracked_effects() -> Dictionary:
	return init_tracked_items.duplicate(true)


func get_scaling_bonus(value: int, stat_scaled: String, nb_stat_scaled: int, perm_stats_only: bool, player_index: int) -> int:
	assert ( not stat_scaled.is_valid_integer())
	var stat_scaled_hash: int = Keys.generate_hash(stat_scaled)
	var actual_nb_scaled: = 0.0
	if stat_scaled_hash == Keys.materials_hash:
		actual_nb_scaled = get_player_gold(player_index)
	elif stat_scaled_hash == Keys.structure_hash:
		actual_nb_scaled = get_nb_structures(player_index)
	elif stat_scaled_hash == Keys.pet_hash:
		actual_nb_scaled = get_nb_pets(player_index)
	elif stat_scaled == "living_enemy":
		actual_nb_scaled = current_living_enemies
	elif stat_scaled_hash == Keys.burning_enemy_hash:
		actual_nb_scaled = current_burning_enemies
	elif stat_scaled_hash == Keys.different_item_hash:
		actual_nb_scaled = get_nb_different_items_of_tier( - 1, player_index)
	elif stat_scaled_hash == Keys.common_item_hash:
		actual_nb_scaled = get_nb_different_items_of_tier(Tier.COMMON, player_index)
	elif stat_scaled_hash == Keys.legendary_item_hash:
		actual_nb_scaled = get_nb_different_items_of_tier(Tier.LEGENDARY, player_index)
	elif stat_scaled_hash == Keys.duplicate_item_hash:
		actual_nb_scaled = get_duplicate_items_count(player_index)
	elif stat_scaled.begins_with("item_"):
		actual_nb_scaled = get_nb_item(stat_scaled_hash, player_index)
	elif stat_scaled_hash == Keys.living_tree_hash:
		actual_nb_scaled = current_living_trees
	elif stat_scaled_hash == Keys.percent_player_missing_health_hash:
		var current_health = get_player_current_health(player_index)
		var max_health = get_player_max_health(player_index)
		actual_nb_scaled = WeaponService.apply_inverted_health_bonus(1, 1, current_health, max_health)
	elif stat_scaled_hash == Keys.free_weapon_slots_hash:
		actual_nb_scaled = get_free_weapon_slots(player_index)
	elif stat_scaled_hash == Keys.food_item_hash:
		actual_nb_scaled = get_nb_food_items(player_index)
	elif stat_scaled_hash == Keys.minimalist_item_hash:
		actual_nb_scaled = get_nb_minimalist_items(player_index)
	elif perm_stats_only:
		actual_nb_scaled = get_stat(stat_scaled_hash, player_index)
	else:
		actual_nb_scaled = get_stat(stat_scaled_hash, player_index) + TempStats.get_stat(stat_scaled_hash, player_index)

	return int(value * (actual_nb_scaled / nb_stat_scaled))


const snowball_effect = preload("res://items/all/snowball/effects/snowball_effect_0.tres")

func _apply_gain_stat_for_equipped_item_with_stat_effects(stat_hsh: int, player_index: int) -> void :
	var effects = get_player_effects(player_index)
	var gain_stat_effects = effects[Keys.gain_stat_for_equipped_item_with_stat_hash]
	for gain_stat_effect in gain_stat_effects:
		assert (gain_stat_effect[2] is int)
		var item_stat: = int(gain_stat_effect[2])
		if item_stat != stat_hsh:
			continue
		assert (gain_stat_effect[0] is int)
		var stat_to_gain: = int(gain_stat_effect[0])
		var stat_to_gain_value = gain_stat_effect[1]
		effects[stat_to_gain] += stat_to_gain_value
		if stat_to_gain == snowball_effect.key_hash:
			add_tracked_value(player_index, Keys.item_snowball_hash, stat_to_gain_value)
		emit_signal("stat_added", stat_to_gain, stat_to_gain_value, 0.0, player_index)


func add_tracked_value(player_index: int, tracking_key: int, value: float, index: int = 0) -> void :
	if not tracked_item_effects[player_index].has(tracking_key):
		print("tracking key %s does not exist" % tracking_key)
		return

	if tracked_item_effects[player_index][tracking_key] is Array:
		tracked_item_effects[player_index][tracking_key][index] += value as int
	else:
		tracked_item_effects[player_index][tracking_key] += value as int


func set_tracked_value(player_index: int, tracking_key: int, value: float, index: int = 0) -> void :
	if not tracked_item_effects[player_index].has(tracking_key):
		print("tracking key %s does not exist" % tracking_key)
		return

	if tracked_item_effects[player_index][tracking_key] is Array:
		tracked_item_effects[player_index][tracking_key][index] = value as int
	else:
		tracked_item_effects[player_index][tracking_key] = value as int

func get_random_primary_stats() -> int:
	return primary_stats_list[randi() % primary_stats_list.size()]
