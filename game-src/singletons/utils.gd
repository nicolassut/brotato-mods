extends Node

const BOOST_COLOR = Color("a30000")
const CURSE_COLOR = Color("ca61ff")
const CHARM_COLOR = Color("9bc6dd")
const DAMAGE_INC_COLOR = Color("bfebff")
const HIGHLIGHT_COLOR = Color("72fff2")
const SECONDARY_FONT_COLOR = Color("eae2b0")
const SECONDARY_FONT_COLOR_HTML = "#eae2b0"
const CATEGORY_COLOR = Color("faf4cc")
const GOLD_COLOR = Color("76ff76")
const GRAY_COLOR_STR = "#555555"
const POS_COLOR_STR = "#00ff00"
const NEG_COLOR_STR = "red"
const DLC_BUTTON_TEXT_COLOR = Color("FFD700")


const NO_COLLISION_BIT: = 0
const NEUTRAL_BIT: = 1
const PLAYER_BIT: = 2
const ENEMIES_BIT: = 4
const PLAYER_PROJECTILES_BIT: = 8
const ENEMY_PROJECTILES_BIT: = 16
const ITEMS_BIT: = 32
const GOLD_BIT: = 64
const OBSTACLES_BIT: = 128
const BONUS_GOLD_BIT: = 256
const PETS_BIT: = 512
const PET_PROJECTILES_BIT: = 1024
const STRUCTURES_BIT: = 2048

const EDGE_MAP_DIST = 64
const TILE_SIZE = 64

const CHARM_DURATION: = 8


const LARGE_NUMBER: = 99999999
const BASE_INVENTORY_ELEMENT_SIZE: = Vector2(96, 96)
const TEST_SCENE_GROUP: = "GUT-test-scene"



const TICKS_PER_SECOND: = 60

const empty_hash: = 5381

var default_die_args = Entity.DieArgs.new()

var physics_fps: int setget set_physics_fps, get_physics_fps
func set_physics_fps(_value: int) -> void :
	printerr("physics_fps is readonly")
func get_physics_fps() -> int:
	return Engine.iterations_per_second

var project_width: int = ProjectSettings.get_setting("display/window/size/width")
var project_height: int = ProjectSettings.get_setting("display/window/size/height")

var projectile_outline_shadermat = preload("res://resources/shaders/projectile_outline_shadermat.tres")
var last_elt_selected = [null, null, null, null]

var _rng: = RandomNumberGenerator.new()
var _stat_keys: = {}
var _primary_stat_keys: = []
var _stat_caches: = [{}, {}, {}, {}]
var _manual_aim_cache: = [null, null, null, null]
var _popup: Popup

var on_console: bool = false
var on_editor: bool = false
var on_gdk_desktop: bool = false
var on_gdk_xbox: bool = false
var on_gdk: bool = false
var on_nintendo_nx: bool = false
var on_nintendo_ounce: bool = false
var on_nintendo_nx_or_ounce: bool = false
var on_playstation: bool = false
var on_ps4: bool = false
var on_ps5: bool = false


func _init() -> void :
	if OS.has_feature("editor"):
		on_editor = true

	if OS.get_name().begins_with("Seaven"):
		on_console = true

	if OS.get_name() == "Seaven GDK Desktop":
		on_gdk_desktop = true
		on_gdk = true

	if OS.get_name() == "Seaven GDK Xbox":
		on_gdk_xbox = true
		on_gdk = true

	if OS.get_name() == "Seaven NX":
		on_nintendo_nx = true
		on_nintendo_nx_or_ounce = true

	if OS.get_name() == "Seaven Ounce":
		on_nintendo_ounce = true
		on_nintendo_nx_or_ounce = true

	if OS.get_name() == "Seaven PS4":
		on_playstation = true
		on_ps4 = true

	if OS.get_name() == "Seaven PS5":
		on_playstation = true
		on_ps5 = true


func _ready() -> void :
	_rng.randomize()

	
	
	for stat in ItemService.stats:
		stat.generate_hashes()

	reset_stat_keys()


func _process(_delta: float) -> void :
	set_deferred("_manual_aim_cache", [null, null, null, null])


func reset_stat_keys() -> void :
	_stat_keys = PlayerRunData.init_stats()
	_primary_stat_keys.clear()
	for stat in ItemService.stats:
		if stat.is_primary_stat:
			_primary_stat_keys.push_back(stat.stat_hash)
	RunData.reset_players_data_stats_and_effects()


func is_on_console() -> bool:
	return on_console


func physics_one(delta: float) -> float:
	return get_physics_fps() * delta


func convert_to_hash_array( var input_array, var remove_duplicates: = false) -> Array:
	var output_array: = []

	for i in range(input_array.size()):
		var val = input_array[i]
		if val is float:
			if val == int(val):
				output_array.push_back(int(val))
			else:
				output_array.push_back(val)
		elif val is int:
			output_array.push_back(val)
		elif val is String and val.is_valid_html_color():
			output_array.push_back(val)
		elif val is String and val.begins_with("res://"):
			output_array.push_back(val)
		elif val is String and val.is_valid_integer():
			output_array.push_back(int(val))
		elif val is Dictionary:
			output_array.push_back(convert_dictionary_to_hash(val, true))
		elif val is String:
			output_array.push_back(Keys.generate_hash(val))
		elif val is Array:
			output_array.push_back(convert_to_hash_array(val.duplicate(), false))
		else:
			output_array.push_back(val)

	if remove_duplicates:
		var output_array_no_dup: = []
		for i in range(output_array.size()):
			if not output_array[i] in output_array_no_dup:
				output_array_no_dup.push_back(output_array[i])

		return output_array_no_dup

	return output_array


func convert_dictionary_to_hash( var input_dictionary: Dictionary, var recursive = false) -> Dictionary:
	var output_dictionary: = {}
	var dictionary_keys = input_dictionary.keys()

	
	for i in range(dictionary_keys.size()):
		var key = dictionary_keys[i]
		if key is String and not key.is_valid_integer():
			output_dictionary[Keys.generate_hash(key)] = input_dictionary[key]

	for i in range(dictionary_keys.size()):
		var key = dictionary_keys[i]
		if key is float:
			output_dictionary[int(key)] = input_dictionary[key]

	for i in range(dictionary_keys.size()):
		var key = dictionary_keys[i]
		if key is String and key.is_valid_integer():
			output_dictionary[int(key)] = input_dictionary[key]

	
	for i in range(dictionary_keys.size()):
		var key = dictionary_keys[i]
		if key is int:
			output_dictionary[key] = input_dictionary[key]

	if recursive:
		for key in output_dictionary.keys():
			var element = output_dictionary[key]
			if element is Dictionary:
				element = convert_dictionary_to_hash(element.duplicate(), true)
			elif element is Array:
				
				if element.size() > 0:
					element = convert_to_hash_array(element.duplicate())
			output_dictionary[key] = element

	return output_dictionary


func instance_scene_on_main(scene: PackedScene, position: Vector2) -> Node:
	var main = get_scene_node()
	var instance = scene.instance()
	main.add_child(instance)

	if "global_position" in instance:
		instance.global_position = position
	elif "rect_position" in instance:
		instance.rect_position = position

	return instance


func get_scene_node() -> Node:
	var scene = get_tree().current_scene
	if scene.name == "GutRunner":
		
		var scene_nodes: = get_tree().get_nodes_in_group(TEST_SCENE_GROUP)
		assert ( not scene_nodes.empty(), "Scene was not added to test with add_scene_node")
		return scene_nodes.front()
	return scene


func is_facing_right(rotation_degrees: float) -> bool:
	return rotation_degrees > - 90 and rotation_degrees < 90


func get_nearest(targets: Array, from: Vector2, min_distance: = 0, max_range: int = LARGE_NUMBER) -> Array:
	var nearest_target: = []
	min_distance = min_distance * min_distance
	max_range = max_range * max_range

	for target in targets:
		var dist_to_target = target.global_position.distance_squared_to(from)
		if is_between(dist_to_target, min_distance, max_range) and (nearest_target.size() == 0 or dist_to_target < nearest_target[1]):
			nearest_target = [target, dist_to_target]

	
	if nearest_target.size() > 0:
		nearest_target[1] = sqrt(nearest_target[1])
	return nearest_target

func get_nearest_no_max(targets: Array, from: Vector2, min_distance: = 0) -> Array:
	var nearest_target: = [null, LARGE_NUMBER]
	var dist_to_target: = 0
	
	min_distance = min_distance * min_distance

	for target in targets:
		dist_to_target = target.global_position.distance_squared_to(from)
		if dist_to_target > min_distance and dist_to_target < nearest_target[1]:
			nearest_target = [target, dist_to_target]

	
	if nearest_target.size() > 0:
		nearest_target[1] = sqrt(nearest_target[1])
	return nearest_target

func get_nearest_no_max_no_dist(targets: Array, from: Vector2, min_distance: = 0):
	var nearest_target = null
	var dist_to_target: = 0
	var current_dist: = LARGE_NUMBER
	
	min_distance = min_distance * min_distance

	for target in targets:
		dist_to_target = target.global_position.distance_squared_to(from)
		if dist_to_target > min_distance and dist_to_target < current_dist:
			nearest_target = target
			current_dist = dist_to_target

	return nearest_target


func is_between(number: int, min_value: int, max_value: int, including: = true) -> bool:
	if including:
		return number >= min_value and number <= max_value
	else:
		return number > min_value and number < max_value


func get_effect_distance(unit: Unit) -> float:
	return unit.sprite.texture.get_width() * 0.25


func set_rng_seed(v: int) -> void :
	_rng.seed = v


func randi_range(from: int, to: int) -> int:
	return _rng.randi_range(from, to)


func randi() -> int:
	return _rng.randi()


func vectors_approx_equal(a: Vector2, b: Vector2, precision: float) -> bool:
	return a.distance_to(b) <= precision


func get_direction_from_pos(pos: Vector2, min_pos: Vector2, max_pos: Vector2, distance: int) -> int:
	var direction = Direction.NONE

	if pos.x <= min_pos.x + distance:
		direction = get_direction_from_side(Direction.LEFT, pos, min_pos, max_pos, distance)
	elif pos.x >= max_pos.x - distance:
		direction = get_direction_from_side(Direction.RIGHT, pos, min_pos, max_pos, distance)
	elif pos.y <= min_pos.y + distance:
		direction = Direction.TOP
	elif pos.y >= max_pos.y - distance:
		direction = Direction.BOTTOM

	return direction


func get_direction_from_side(side_checked: int, pos: Vector2, min_pos: Vector2, max_pos: Vector2, distance: int) -> int:
	if pos.y <= min_pos.y + distance:
		return Direction.TOP if randf() > 0.5 else side_checked
	elif pos.y >= max_pos.y - distance:
		return Direction.BOTTOM if randf() > 0.5 else side_checked
	else:
		return side_checked


func get_rand_pos_from_direction_at_distance(direction: int, min_pos: Vector2, max_pos: Vector2, distance: int) -> Vector2:
	var pos: Vector2 = Vector2.ZERO

	if direction == Direction.TOP:
		pos.x = rand_range(min_pos.x + distance, max_pos.x - distance)
		pos.y = min_pos.y + distance
	elif direction == Direction.BOTTOM:
		pos.x = rand_range(min_pos.x + distance, max_pos.x - distance)
		pos.y = max_pos.y - distance
	elif direction == Direction.RIGHT:
		pos.x = max_pos.x - distance
		pos.y = rand_range(min_pos.y + distance, max_pos.y - distance)
	elif direction == Direction.LEFT:
		pos.x = min_pos.x + distance
		pos.y = rand_range(min_pos.y + distance, max_pos.y - distance)

	return pos


func get_rand_pos_from_direction_within_distance(direction: int, min_pos: Vector2, max_pos: Vector2, distance: int) -> Vector2:
	var pos: Vector2 = Vector2.ZERO
	var min_distance = EDGE_MAP_DIST / 2.0

	if direction == Direction.NONE:
		direction = get_rand_element([Direction.BOTTOM, Direction.RIGHT, Direction.LEFT, Direction.TOP])

	if direction == Direction.TOP:
		pos.x = rand_range(min_pos.x + min_distance, max_pos.x - min_distance)
		pos.y = rand_range(min_pos.y + min_distance, min_pos.y + distance)
	elif direction == Direction.BOTTOM:
		pos.x = rand_range(min_pos.x + min_distance, max_pos.x - min_distance)
		pos.y = rand_range(max_pos.y - min_distance, max_pos.y - distance)
	elif direction == Direction.RIGHT:
		pos.x = rand_range(max_pos.x - distance, max_pos.x - min_distance)
		pos.y = rand_range(min_pos.y + min_distance, max_pos.y - min_distance)
	elif direction == Direction.LEFT:
		pos.x = rand_range(min_pos.x + min_distance, min_pos.x + distance)
		pos.y = rand_range(min_pos.y + min_distance, max_pos.y - min_distance)

	return pos


func get_rand_element(array: Array):
	if array.empty():
		return null
	return array.pick_random()


func get_chance_success(chance: float) -> bool:
	
	
	if chance == 0.0:
		return false
	
	return randf() <= chance


func get_curse_factor(value: float, max_val: float = 100.0) -> float:

	if DebugService.always_curse:
		return LARGE_NUMBER as float

	return max_val * (1.0 - 1.0 / (1.0 + value / 50.0))


func merge_dictionaries(a: Dictionary, b: Dictionary) -> Dictionary:
	var c = a.duplicate(true)

	for key in b:
		if key in c:
			if a[key] is Dictionary and b[key] is Dictionary:
				c[key] = merge_dictionaries(a[key], b[key])
			else:
				c[key] = b[key]
		else:
			c[key] = b[key]

	return c


func merge_dictionaries_take_max(a: Dictionary, b: Dictionary) -> Dictionary:
	var c = a.duplicate(true)

	for key in b:
		if key in c:
			if a[key] is Dictionary and b[key] is Dictionary:
				c[key] = merge_dictionaries(a[key], b[key])
			else:
				if ((b[key] is int) or (b[key] is float)):
					print("merge_dictionaries_take_max : took max value for key " + key)
					c[key] = max(b[key], c[key])
				else:
					c[key] = b[key]
		else:
			c[key] = b[key]

	return c


func reset_stat_cache(player_index: int) -> void :
	assert (0 <= player_index and player_index < _stat_caches.size())
	_stat_caches[player_index].clear()


func reset_stat_caches() -> void :
	_stat_caches = [{}, {}, {}, {}]


func get_lang_key(lang: String) -> String:
	return "LANGUAGE_" + lang.to_upper()


func get_stat(stat_hsh: int, player_index: int) -> float:
	var stat = _stat_caches[player_index].get(stat_hsh)
	if stat == null:
		stat = RunData.get_stat(stat_hsh, player_index) + TempStats.get_stat(stat_hsh, player_index) + LinkedStats.get_stat(stat_hsh, player_index)
		_stat_caches[player_index][stat_hsh] = stat
	return stat


func get_capped_stat(stat_hsh: int, player_index) -> float:
	var stat: = get_stat(stat_hsh, player_index)
	var cap_key: int
	match stat_hsh:
		Keys.stat_max_hp_hash:
			cap_key = Keys.hp_cap_hash
		Keys.stat_speed_hash:
			cap_key = Keys.speed_cap_hash
		Keys.stat_dodge_hash:
			cap_key = Keys.dodge_cap_hash
		Keys.stat_curse_hash:
			cap_key = Keys.curse_cap_hash
		Keys.stat_crit_chance_hash:
			cap_key = Keys.crit_chance_cap_hash
		_:
			printerr("stat %s has no associated cap" % Keys.hash_to_string[stat_hsh])

	var cap = RunData.get_player_effect(cap_key, player_index)

	# Gourmet DLC - Zombie: anything raising his 10% dodge cap is 50% less effective
	if stat_hsh == Keys.stat_dodge_hash:
		var zombie_char = RunData.get_player_character(player_index)
		if zombie_char != null and zombie_char.my_id == "character_zombie" and cap > 10:
			cap = 10 + (cap - 10) / 2.0

	return min(stat, cap)

func get_max_capped_stat(stat_hsh: int, player_index) -> float:
	var stat: = get_stat(stat_hsh, player_index)
	var cap_key: int
	match stat_hsh:
		Keys.stat_max_hp_hash:
			cap_key = Keys.hp_cap_hash
		Keys.stat_speed_hash:
			cap_key = Keys.speed_cap_hash
		Keys.stat_dodge_hash:
			cap_key = Keys.dodge_cap_hash
		Keys.stat_curse_hash:
			cap_key = Keys.curse_cap_hash
		Keys.stat_crit_chance_hash:
			cap_key = Keys.crit_chance_cap_hash
		_:
			printerr("stat %s has no associated cap" % Keys.hash_to_string[stat_hsh])

	var cap = RunData.get_player_effect(cap_key, player_index)
	return max(stat, cap)

func is_stat_key(key: int) -> bool:
	return _stat_keys.has(key)


func get_primary_stat_keys() -> Array:
	return _primary_stat_keys.duplicate()


func average_all_player_stats(stat_hsh: int) -> float:
	return sum_all_player_stats(stat_hsh) / RunData.get_player_count()


func sum_all_player_stats(stat_hsh: int) -> float:
	var sum: = 0.0
	for player_index in RunData.get_player_count():
		sum += get_stat(stat_hsh, player_index)
	return sum


func multiply_all_player_stats(stat_hsh: int) -> float:
	var total: = 0.0
	for player_index in RunData.get_player_count():
		var factor: = 1.0 + total / 100.0
		total += get_stat(stat_hsh, player_index) * factor
	return total


func get_enemy_scaling_text(
	enemy_health: float, 
	enemy_damage: float, 
	enemy_speed: float, 
	retries: int, 
	is_coop: bool = false, 
	ban_count: int = 0, 
	nightmare_proj: int = 1, 
	with_hyphen: bool = true
	) -> String:
	var health = (enemy_health * 100) as int
	var damage = (enemy_damage * 100) as int
	var speed = (enemy_speed * 100) as int

	var text = " - " if with_hyphen else ""

	if nightmare_proj == 0:
		text += "NP"
	elif nightmare_proj == 2:
		text += "FP"
	else:
		text = ""

	if not (health == 100 and damage == 100 and speed == 100):
		var difficulty_val = round(pow(health * damage * speed, 1 / 3.0))
	
	
		text += " - " + str(difficulty_val) + "%"

	if is_coop:
		text += " - C"

	if retries > 0:
		text += " - R" + str(retries)

	if ban_count > 0:
		text += " - B" + str(ban_count)

	return text


func get_scaling_stat_icon_text(stat_hsh: int, scaling: float = 1.0, show_plus_prefix: bool = true) -> String:
	var w = 15 * ProgressData.settings.font_size
	var prefix = "+" if show_plus_prefix and scaling > 0.0 else ""
	var color = "white" if scaling > 0.0 else "#f6617c"
	var scaling_text = "[color=%s]%s%s%%[/color]" % [color, prefix, str(round(scaling * 100.0))]
	var small_icon: Texture = ItemService.get_stat_small_icon(stat_hsh)
	return "%s[img=%sx%s]%s[/img]" % [scaling_text, w, w, small_icon.resource_path]



func convert_stats(stats: Array, player_index: int, permanent: bool = true) -> void :
	if stats.empty():
		return
	for stat_to_convert in stats:
		var pct = stat_to_convert.pct_converted / 100.0
		var stat_to_remove = stat_to_convert.key_hash
		var stat_to_add = stat_to_convert.to_stat_hash

		var stat_to_remove_value = RunData.get_player_gold(player_index) if stat_to_remove == Keys.materials_hash else RunData.get_stat(stat_to_remove, player_index) as int
		var nb_chunks_stat_removed = max(0, floor((stat_to_remove_value * pct) / stat_to_convert.value))

		if nb_chunks_stat_removed == 0:
			break

		var stat_removed_gain = RunData.get_stat_gain(stat_to_remove, player_index)
		var stat_added_gain = RunData.get_stat_gain(stat_to_add, player_index)

		var base_nb_stat_removed = nb_chunks_stat_removed * stat_to_convert.value
		var base_nb_stat_added = stat_to_convert.to_value * nb_chunks_stat_removed
		var actual_nb_stat_removed = base_nb_stat_removed
		var actual_nb_stat_added = base_nb_stat_added

		if stat_removed_gain > 0.0:
			actual_nb_stat_removed = round(base_nb_stat_removed / stat_removed_gain) as int
		if stat_added_gain > 0.0:
			actual_nb_stat_added = round(base_nb_stat_added / stat_added_gain) as int

		if stat_to_remove == Keys.materials_hash:
			RunData.remove_gold(actual_nb_stat_removed, player_index)
		else:
			if permanent:
				RunData.remove_stat(stat_to_remove, actual_nb_stat_removed, player_index)
			else:
				TempStats.remove_stat(stat_to_remove, actual_nb_stat_removed, player_index)

		if stat_to_add == Keys.materials_hash:
			RunData.add_gold(actual_nb_stat_added, player_index)
		else:
			if permanent:
				RunData.add_stat(stat_to_add, actual_nb_stat_added, player_index)
			else:
				TempStats.add_stat(stat_to_add, actual_nb_stat_added, player_index)
				RunData.emit_signal("stat_added", stat_to_add, base_nb_stat_added, 0.0, player_index)

func shuffled_range(n: int) -> Array:
	var arr = range(n)
	arr.shuffle()
	return arr


func is_valid_joypad_motion_event(event: InputEvent) -> bool:
	
	return event is InputEventJoypadMotion and abs(event.axis_value) > InputService.joystick_deadzone



func is_maybe_action(event: InputEvent, action: String) -> bool:
	return InputMap.has_action(action) and event.is_action(action)



func is_maybe_action_pressed(event: InputEvent, action: String) -> bool:
	return is_maybe_action(event, action) and event.is_action_pressed(action)


func reset_last_elt_selected() -> void :
	last_elt_selected = [null, null, null, null]


func get_focus_emulator(player_index: int, root = get_scene_node()) -> FocusEmulator:
	return root.get_node_or_null("FocusEmulator%s" % (player_index + 1))


func focus_player_control(control: Control, player_index: int, focus_emulator: FocusEmulator = null) -> void :
	if not is_instance_valid(control) or not control.is_visible_in_tree():
		return
	if focus_emulator == null:
		focus_emulator = get_focus_emulator(player_index)
	if RunData.is_coop_run:
		focus_emulator.set_deferred("focused_control", control)
	else:
		control.call_deferred("grab_focus")


func get_player_focused_control(some_control: Control, player_index: int, focus_emulator: FocusEmulator = null) -> Control:
	if focus_emulator == null:
		focus_emulator = get_focus_emulator(player_index)
	if RunData.is_coop_run:
		return focus_emulator.focused_control
	return some_control.get_focus_owner()


func is_player_cancel_pressed(event: InputEvent, player_index: int) -> bool:
	return is_player_action_pressed(event, player_index, "ui_cancel")

func is_player_cancel_released(event: InputEvent, player_index: int) -> bool:
	return is_player_action_released(event, player_index, "ui_cancel")

func is_player_pause_released(event: InputEvent, player_index: int) -> bool:
	return is_player_action_released(event, player_index, "ui_pause")

func is_player_select_pressed(event: InputEvent, player_index: int) -> bool:
	return is_player_action_pressed(event, player_index, "ui_select")

func is_player_ui_coop_ban_pressed(event: InputEvent, player_index: int) -> bool:
	return is_player_action_pressed(event, player_index, "ui_ban")

func is_player_ui_coop_ban_released(event: InputEvent, player_index: int) -> bool:
	return is_player_action_released(event, player_index, "ui_ban")

func is_player_info_pressed(event: InputEvent, player_index: int) -> bool:
	return is_player_action_pressed(event, player_index, "ui_info")


func is_player_action_pressed(event: InputEvent, player_index: int, action: String) -> bool:
	if not RunData.is_coop_run:
		return event.is_action_pressed(action)
	var remapped_device = CoopService.get_remapped_player_device(player_index)
	if remapped_device < 0:
		return false
	return is_maybe_action_pressed(event, "%s_%s" % [action, remapped_device])


func is_player_action_released(event: InputEvent, player_index: int, action: String) -> bool:
	if not RunData.is_coop_run:
		return event.is_action_released(action)
	var remapped_device = CoopService.get_remapped_player_device(player_index)
	if remapped_device < 0:
		return false
	return event.is_action_released("%s_%s" % [action, remapped_device])


func is_player_using_gamepad(player_index: int) -> bool:
	if on_gdk:
		return CoopService.is_player_using_gamepad(player_index) if RunData.is_coop_run else true

	if on_console:
		return true

	return CoopService.is_player_using_gamepad(player_index) if RunData.is_coop_run else InputService.using_gamepad


func get_player_rjoy_vector(player_index: int) -> Vector2:
	if not is_player_using_gamepad(player_index):
		return Vector2.ZERO
	if not RunData.is_coop_run:
		return Input.get_vector("rjoy_left", "rjoy_right", "rjoy_up", "rjoy_down")
	var remapped_device = CoopService.get_remapped_player_device(player_index)
	if remapped_device < 0:
		return Vector2.ZERO
	return Input.get_vector("rjoy_left_%s" % remapped_device, "rjoy_right_%s" % remapped_device, "rjoy_up_%s" % remapped_device, "rjoy_down_%s" % remapped_device)


func disable_node(node: Node) -> void :
	
	node.visible = false
	node.propagate_call("set_process", [false])
	node.propagate_call("set_physics_process", [false])
	node.propagate_call("set_process_input", [false])
	node.propagate_call("set_process_unhandled_input", [false])
	node.propagate_call("set_process_unhandled_key_input", [false])


func filter_out_freed_objects(array: Array) -> Array:
	var filtered_array: = []
	for object in array:
		if not object.is_queued_for_deletion():
			filtered_array.append(object)
	return filtered_array


func get_random_offset_position(position: Vector2, max_offset: int) -> Vector2:
	var offset_x = - max_offset + self.randi() % (2 * max_offset + 1)
	var offset_y = - max_offset + self.randi() % (2 * max_offset + 1)
	return position + Vector2(offset_x, offset_y)


func get_game_dir() -> String:
	var game_install_directory: = OS.get_executable_path().get_base_dir()

	if OS.get_name() == "OSX":
		game_install_directory = game_install_directory.get_base_dir().get_base_dir()
		if game_install_directory.ends_with(".app"):
			game_install_directory = game_install_directory.get_base_dir()

	if OS.has_feature("editor"):
		game_install_directory = "res://"

	return game_install_directory


func get_startup_arguments() -> Dictionary:
	var arguments = {}
	for argument in OS.get_cmdline_args():
		if argument.find("=") > - 1:
			var key_value = argument.split("=")
			arguments[key_value[0].lstrip("--")] = key_value[1]
		else:
			
			
			arguments[argument.lstrip("--")] = ""

	return arguments



func disconnect_all_signals(object: Object) -> void :
	for object_signal in object.get_signal_list():
		for connection in object.get_signal_connection_list(object_signal.name):
			object.disconnect(connection.signal , connection.target, connection.method)


func disconnect_all_signal_connections(object: Object, signal_name: String) -> void :
	for connection in object.get_signal_connection_list(signal_name):
		object.disconnect(connection.signal , connection.target, connection.method)


func get_first_scaling_stat(scaling_stats: Array) -> int:
	if scaling_stats == null or scaling_stats.size() <= 0:
		printerr("scaling stat not provided")
		return Keys.empty_hash

	assert (scaling_stats[0][0] is int)
	return scaling_stats[0][0]


func is_manual_aim(player_index: int) -> bool:
	var is_manual = _manual_aim_cache[player_index]
	if is_manual != null:
		return is_manual

	if ProgressData.settings.manual_aim_on_mouse_press or (Utils.on_console and ProgressData.settings.manual_aim):
		
		var is_mouse_pressed = not RunData.is_coop_run and Input.is_mouse_button_pressed(BUTTON_LEFT)
		var is_gamepad_pressed = is_player_using_gamepad(player_index) and get_player_rjoy_vector(player_index).length_squared() > 0.05
		is_manual = is_mouse_pressed or is_gamepad_pressed
	elif ProgressData.settings.manual_aim:
		
		is_manual = not RunData.is_coop_run or is_player_using_gamepad(player_index)

	_manual_aim_cache[player_index] = is_manual
	return is_manual


func set_default_cursor() -> void :
	var cursor_image = load(ProjectSettings.get_setting("display/mouse_cursor/custom_image"))
	var cursor_hotspot = ProjectSettings.get_setting("display/mouse_cursor/custom_image_hotspot")
	Input.set_custom_mouse_cursor(cursor_image, Input.CURSOR_ARROW, cursor_hotspot)




func duplicate_and_cast_id(array: Array):
	var clone: = [];
	for e in array:
		if (typeof(e) == TYPE_ARRAY):
			var e1 = e.duplicate()
			e1[0] = int(e[0])
			clone.push_back(e1)
		else:
			clone.push_back(e)
	return clone


# Gourmet ecosystem - service accessors (Phase 8). In this tree the five
# services are real autoloads; in the Workshop build GourmetCore root-injects
# nodes carrying the SAME names. Either way they live at /root/<Name>, so all
# engine code reaches them through these accessors instead of the bare
# autoload identifier - a bare identifier is PARSE-FATAL on installs without
# the autoload (probe-proven 2026-08-18, 655 cascade errors).
var _gourmet_services: = {}

var packs setget , get_packs
var game_modes setget , get_game_modes
var gourmet_tracker setget , get_gourmet_tracker
var special_modifiers setget , get_special_modifiers
var butcher_skin setget , get_butcher_skin


func _gourmet_service(service_name: String) -> Node:
	var svc = _gourmet_services.get(service_name)
	if svc == null or not is_instance_valid(svc):
		svc = get_node_or_null("/root/" + service_name)
		if svc == null:
			# Workshop build: services cannot be added to /root during the
			# autoload cascade (add_node fails while root is busy), so
			# GourmetCore parents them under its own mod node instead
			var mod_loader = get_node_or_null("/root/ModLoader")
			if mod_loader != null:
				svc = mod_loader.find_node(service_name, true, false)
		_gourmet_services[service_name] = svc
	return svc


func get_packs() -> Node:
	return _gourmet_service("Packs")


func get_game_modes() -> Node:
	return _gourmet_service("GameModes")


func get_gourmet_tracker() -> Node:
	return _gourmet_service("GourmetTracker")


func get_special_modifiers() -> Node:
	return _gourmet_service("SpecialModifiers")


func get_butcher_skin() -> Node:
	return _gourmet_service("ButcherSkin")
