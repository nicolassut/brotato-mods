extends Node

signal dlc_activated(dlc_id)
signal dlc_deactivated(dlc_id)
signal language_changed()
signal change_keyart()

const VERSION = "1.1.15.4"
const BETA = false
const VERSION_SWITCH = "1.1.13.2"

const DLC_1_APP_ID = 2868390

var smallest_text_font = preload("res://resources/fonts/actual/base/font_smallest_text.tres")

var languages = [
	"en", "fr", "zh", "zh_TW", "ja", "ko", "ru", "pl", "es", "pt", "de", "tr", "it"
]

var current_profile_id: = 0
var profile_count: = 3
const SETTINGS_FILE_NAME: = "/settings.json"

const MAX_DIFFICULTY: = 6
const SMALLEST_FONT_BASE_SIZE: = 21
const FPS_LIMIT: = 60

const DEFAULT_TIER_COLOR_0 = Color(230.0 / 255, 230.0 / 255, 230.0 / 255, 1)
const DEFAULT_TIER_COLOR_1 = Color(90.0 / 255, 190.0 / 255, 255.0 / 255, 1)
const DEFAULT_TIER_COLOR_2 = Color(173.0 / 255, 90.0 / 255, 255.0 / 255, 1)
const DEFAULT_TIER_COLOR_3 = Color(255.0 / 255, 59.0 / 255, 59.0 / 255, 1)
const DEFAULT_TIER_COLOR_4 = Color(255.0 / 255, 119.0 / 255, 59.0 / 255, 1)
const DEFAULT_TIER_COLOR_5 = Color(208.0 / 255, 193.0 / 255, 66.0 / 255, 1)

var SAVE_DIR: = ""
var SAVE_PATH: = ""
var LOG_PATH: = ""
var fallback_dir_name: String = "user"

var activity_started: bool = false
var need_activity: bool = false
var need_activity_reset: bool = true


var load_status = LoadStatus.SAVE_OK

var available_dlcs: = []

var zones_unlocked: = []
var characters_unlocked: = []

var upgrades_unlocked: = []
var consumables_unlocked: = []

var weapons_unlocked: = []
var items_unlocked: = []
var challenges_completed: = []
var systems_unlocked: = []

var difficulties_unlocked: = []
var inactive_mods: = []

var read_announcements: = []

var show_main_title_mod_warning_popup: = false
var show_main_title_beta_save_warning_popup: = false

var saved_run_state: Dictionary
var last_saved_run_state: Dictionary
var settings: Dictionary = {}
var data: Dictionary = {}
var killed_enemies: Dictionary = {}
var killed_by_enemies: Dictionary = {}
var items_bought: Dictionary = {}

func start_activity() -> void :
	if need_activity:
		activity_started = true
		print("start_activity")
		OS_Seaven.start_activity("Activity1")

func reset_activity() -> void :
	if need_activity_reset:
		need_activity_reset = false
		terminate_activity()

func terminate_activity() -> void :
	if need_activity:
		activity_started = false
		print("terminate_activity")
		OS_Seaven.terminate_activity("Activity1")

func end_activity(completed: bool) -> void :
	if need_activity:
		activity_started = false
		print("end_activity with " + str(completed))
		OS_Seaven.end_activity("Activity1", completed)

func is_activity_started() -> bool:
	if need_activity:
		return activity_started
	else:
		return false

func get_pending_activity() -> String:
	if need_activity:
		return OS_Seaven.get_pending_activity()
	else:
		return ""

func get_pending_dlc_change() -> bool:
	if Utils.is_on_console():
		return OS_Seaven.has_dlc_updates();
	return false

func _ready() -> void :
	init_save_paths()
	load_dlc_pcks()
	check_for_available_dlcs()

	init_settings()
	load_settings()
	check_settings_version()

	init_data()
	randomize()
	saved_run_state = _get_empty_run_state()

	
	for available_dlc in available_dlcs:
		available_dlc.add_resources()

	RunData.reset()

	if DebugService.generate_full_unlocked_save_file:
		unlock_all()
		save()
	else:
		load_game_file()
		add_unlocked_by_default()

	set_max_selectable_difficulty()

	for available_dlc in available_dlcs:
		if settings.deactivated_dlcs.has(available_dlc.my_id) or get_tree().current_scene.name == "GutRunner":
			available_dlc.remove_resources()

	if Utils.on_ps5:
		print("PS5 platform : activate activity")
		need_activity = true


func init_settings() -> void :
	settings = {"version": VERSION, "endless_mode_toggled": false, "play_mode": RunData.PlayMode.SOLO, "ban_mode_toggled": true, "zone_selected": 0, "zone_is_random": false}
	settings.merge(init_general_options())
	settings.merge(init_gameplay_options())
	settings.merge(init_accessibilities_options())
	settings.language = Platform.get_language()

func check_settings_version() -> void :
	if settings["version"] == VERSION:
		return

	var old_version = settings["version"]
	if are_major_versions_different(old_version, VERSION):
		show_main_title_mod_warning_popup = true

	settings["version"] = VERSION

func are_major_versions_different(v1: String, v2: String) -> bool:
	var a = v1.split(".")
	var b = v2.split(".")

	
	if a.size() < 3 or b.size() < 3:
		push_error("Invalid version format")
		return true

	for i in range(3):
		if int(a[i]) != int(b[i]):
			return true

	return false

func should_show_mod_warning_popup() -> bool:
	return show_main_title_mod_warning_popup and ModLoaderMod.get_mod_data_all().size() > 0


func init_data() -> void :
	data = get_fresh_data()


func get_fresh_data() -> Dictionary:
	return {
		"fruit_eaten_full_hp": 0, 
		"chal_hourglass_quit_wave": 0, 
		"is_unlock_all_save": 0, 
		"run_won": 0, 
		"run_started": 0, 
		"enemies_killed": 0, 
		"materials_collected": 0, 
		"trees_killed": 0, 
		"steps_taken": 0, 
		"enemies_killed_far_away": 0, 
		"evil_mob_killed": 0, 
		"evil_mob_killed_by": 0
	}


func reset() -> void :
	saved_run_state = _get_empty_run_state()
	zones_unlocked.clear()
	characters_unlocked.clear()
	upgrades_unlocked.clear()
	consumables_unlocked.clear()
	weapons_unlocked.clear()
	items_unlocked.clear()
	challenges_completed.clear()
	difficulties_unlocked.clear()
	init_data()
	killed_enemies.clear()
	killed_by_enemies.clear()
	items_bought.clear()
	add_unlocked_by_default()

func reset_save_profile(id: int) -> void :
	if BETA:
		var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, id)
		loader_beta.add_unlocked_by_default_from_blank_save()
		loader_beta.run_state_deserialized = _get_empty_run_state()
		loader_beta.save()
		if current_profile_id == id:
			load_with_generic_loader(loader_beta)
	else:
		var loader = ProgressDataLoaderV3.new(SAVE_DIR, id)
		loader.add_unlocked_by_default_from_blank_save()
		loader.run_state_deserialized = _get_empty_run_state()
		loader.save()
		if current_profile_id == id:
			load_with_generic_loader(loader)

func unlock_all_save_profile(id: int) -> void :
	if BETA:
		var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, id)
		loader_beta.load_game_file()
		loader_beta.unlock_all()
		loader_beta.run_state_deserialized = _get_empty_run_state()
		loader_beta.save()
		if current_profile_id == id:
			load_with_generic_loader(loader_beta)
	else:
		var loader = ProgressDataLoaderV3.new(SAVE_DIR, id)
		loader.load_game_file()
		loader.unlock_all()
		loader.run_state_deserialized = _get_empty_run_state()
		loader.save()
		if current_profile_id == id:
			load_with_generic_loader(loader)

func is_unlock_all_save() -> bool:
	if data.has("is_unlock_all_save"):
		return data.is_unlock_all_save == 1
	return false

func copy_save_profile(from_id: int, to_id: int) -> void :
	if BETA:
		var from_loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, from_id)
		from_loader_beta.load_game_file()
		if from_loader_beta.load_status != LoadStatus.SAVE_OK:
			printerr("Could not copy save profile from id %s because it could not be loaded" % from_id)
			return

		var to_loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, to_id)
		to_loader_beta.zones_unlocked = from_loader_beta.zones_unlocked.duplicate()
		to_loader_beta.characters_unlocked = from_loader_beta.characters_unlocked.duplicate()
		to_loader_beta.upgrades_unlocked = from_loader_beta.upgrades_unlocked.duplicate()
		to_loader_beta.consumables_unlocked = from_loader_beta.consumables_unlocked.duplicate()
		to_loader_beta.weapons_unlocked = from_loader_beta.weapons_unlocked.duplicate()
		to_loader_beta.items_unlocked = from_loader_beta.items_unlocked.duplicate()
		to_loader_beta.challenges_completed = from_loader_beta.challenges_completed.duplicate()
		to_loader_beta.difficulties_unlocked_serialized.clear()
		for difficulty_unlocked in from_loader_beta.difficulties_unlocked_serialized:
			to_loader_beta.difficulties_unlocked_serialized.push_back(difficulty_unlocked)
		to_loader_beta.inactive_mods = from_loader_beta.inactive_mods.duplicate()
		to_loader_beta.read_announcements = from_loader_beta.read_announcements.duplicate()
		to_loader_beta.run_state_deserialized = from_loader_beta.run_state_deserialized.duplicate()
		to_loader_beta.data = from_loader_beta.data.duplicate()
		to_loader_beta.killed_enemies = from_loader_beta.killed_enemies.duplicate()
		to_loader_beta.killed_by_enemies = from_loader_beta.killed_by_enemies.duplicate()
		to_loader_beta.items_bought = from_loader_beta.items_bought.duplicate()
		to_loader_beta.save()

		if current_profile_id == to_id:
			load_with_generic_loader(to_loader_beta)
	else:
		var from_loader = ProgressDataLoaderV3.new(SAVE_DIR, from_id)
		from_loader.load_game_file()
		if from_loader.load_status != LoadStatus.SAVE_OK:
			printerr("Could not copy save profile from id %s because it could not be loaded" % from_id)
			return

		var to_loader = ProgressDataLoaderV3.new(SAVE_DIR, to_id)
		to_loader.zones_unlocked = from_loader.zones_unlocked.duplicate()
		to_loader.characters_unlocked = from_loader.characters_unlocked.duplicate()
		to_loader.upgrades_unlocked = from_loader.upgrades_unlocked.duplicate()
		to_loader.consumables_unlocked = from_loader.consumables_unlocked.duplicate()
		to_loader.weapons_unlocked = from_loader.weapons_unlocked.duplicate()
		to_loader.items_unlocked = from_loader.items_unlocked.duplicate()
		to_loader.challenges_completed = from_loader.challenges_completed.duplicate()
		to_loader.difficulties_unlocked_serialized.clear()
		for difficulty_unlocked in from_loader.difficulties_unlocked_serialized:
			to_loader.difficulties_unlocked_serialized.push_back(difficulty_unlocked)
		to_loader.inactive_mods = from_loader.inactive_mods.duplicate()
		to_loader.read_announcements = from_loader.read_announcements.duplicate()
		to_loader.run_state_deserialized = from_loader.run_state_deserialized.duplicate()
		to_loader.data = from_loader.data.duplicate()
		to_loader.killed_enemies = from_loader.killed_enemies.duplicate()
		to_loader.killed_by_enemies = from_loader.killed_by_enemies.duplicate()
		to_loader.items_bought = from_loader.items_bought.duplicate()
		to_loader.save()

		if current_profile_id == to_id:
			load_with_generic_loader(to_loader)

func init_general_options() -> Dictionary:
	return {
		"volume": {
			"master": 0.5, 
			"sound": 0.75, 
			"music": 0.25
		}, 
		"fullscreen": true, 
		"screenshake": true, 
		"language": "en", 
		"main_screen_keyart": 0, 
		"background": 0, 
		"visual_effects": true, 
		"damage_display": true, 
		"optimize_end_waves": false, 
		"limit_fps": false, 
		"mute_on_focus_lost": false, 
		"pause_on_focus_lost": true, 
		"on_lost_focus": 1, 
		"streamer_mode_tracks": true, 
		"legacy_tracks": false, 
		"deactivated_dlc_tracks": [], 
		"sort_inventory_presset": [], 
		"sort_inventory_presset_reverse": []
	}


func init_gameplay_options() -> Dictionary:
	return {
		"mouse_only": false, 
		"manual_aim": false, 
		"manual_aim_on_mouse_press": false, 
		"movement_with_gamepad": true, 
		"hp_bar_on_character": true, 
		"hp_bar_on_bosses": true, 
		"keep_lock": true, 
		"lock_coop_camera": false, 
		"random_zone": false, 
		"endless_score_storing": 0, 
		"share_coop_loot": true, 
		"deactivated_dlcs": [], 
		"deactivated_skin_sets": [], 
		"no_item_appearance": false, 
		"holding_button": true, 
	}


func init_accessibilities_options() -> Dictionary:
	if not Utils.is_on_console() or Utils.on_gdk_desktop:
		return {
			"enemy_scaling": {
				"health": 1.0, 
				"damage": 1.0, 
				"speed": 1.0
			}, 
			"constant_projectile_option": 1, 
			"explosion_opacity": 1.0, 
			"projectile_opacity": 1.0, 
			"pet_opacity": 1.0, 
			"font_size": 1.0, 
			"character_highlighting": false, 
			"weapon_highlighting": false, 
			"projectile_highlighting": false, 
			"turret_highlighting": false, 
			"pet_highlighting": false, 
			"effects_icons_in_description": true, 
			"alt_gold_sounds": false, 
			"darken_screen": true, 
			"retry_wave": false, 
			"color_positive": Color.green.to_html(), 
			"color_negative": Color.red.to_html(), 
			"tier_0_color": DEFAULT_TIER_COLOR_0.to_html(), 
			"tier_1_color": DEFAULT_TIER_COLOR_1.to_html(), 
			"tier_2_color": DEFAULT_TIER_COLOR_2.to_html(), 
			"tier_3_color": DEFAULT_TIER_COLOR_3.to_html(), 
			"tier_4_color": DEFAULT_TIER_COLOR_4.to_html(), 
			"tier_5_color": DEFAULT_TIER_COLOR_5.to_html(), 
			"tier_0_color_dark": Color(0.0 / 255, 0.0 / 255, 0.0 / 255, 1).to_html(), 
			"tier_1_color_dark": Color(15.0 / 255, 32.0 / 255, 40.0 / 255, 1).to_html(), 
			"tier_2_color_dark": Color(16.0 / 255, 10.0 / 255, 27.0 / 255, 1).to_html(), 
			"tier_3_color_dark": Color(36.0 / 255, 9.0 / 255, 9.0 / 255, 1).to_html(), 
			"tier_4_color_dark": Color(36.0 / 255, 17.0 / 255, 8.0 / 255, 1).to_html(), 
			"tier_5_color_dark": Color(26.0 / 255, 24.0 / 255, 8.0 / 255, 1).to_html(), 
		}
	else:
		return {
			"enemy_scaling": {
				"health": 1.0, 
				"damage": 1.0, 
				"speed": 1.0
			}, 
			"constant_projectile_option": 1, 
			"explosion_opacity": 1.0, 
			"projectile_opacity": 1.0, 
			"pet_opacity": 1.0, 
			"font_size": 1.2, 
			"character_highlighting": false, 
			"weapon_highlighting": false, 
			"projectile_highlighting": false, 
			"turret_highlighting": false, 
			"pet_highlighting": false, 
			"effects_icons_in_description": true, 
			"alt_gold_sounds": false, 
			"darken_screen": true, 
			"retry_wave": false, 
			"color_positive": Color.green.to_html(), 
			"color_negative": Color.red.to_html(), 
			"tier_0_color": DEFAULT_TIER_COLOR_0.to_html(), 
			"tier_1_color": DEFAULT_TIER_COLOR_1.to_html(), 
			"tier_2_color": DEFAULT_TIER_COLOR_2.to_html(), 
			"tier_3_color": DEFAULT_TIER_COLOR_3.to_html(), 
			"tier_4_color": DEFAULT_TIER_COLOR_4.to_html(), 
			"tier_5_color": DEFAULT_TIER_COLOR_5.to_html(), 
			"tier_0_color_dark": Color(0.0 / 255, 0.0 / 255, 0.0 / 255, 1).to_html(), 
			"tier_1_color_dark": Color(15.0 / 255, 32.0 / 255, 40.0 / 255, 1).to_html(), 
			"tier_2_color_dark": Color(16.0 / 255, 10.0 / 255, 27.0 / 255, 1).to_html(), 
			"tier_3_color_dark": Color(36.0 / 255, 9.0 / 255, 9.0 / 255, 1).to_html(), 
			"tier_4_color_dark": Color(36.0 / 255, 17.0 / 255, 8.0 / 255, 1).to_html(), 
			"tier_5_color_dark": Color(26.0 / 255, 24.0 / 255, 8.0 / 255, 1).to_html(), 
		}


func load_dlc_pcks() -> void :
	var dlc_pck_names: = ["BrotatoAbyssalTerrors.pck"]
	for dlc_name in dlc_pck_names:
		var file = File.new()
		var dlc_path: String = Utils.get_game_dir() + "/" + dlc_name
		if file.file_exists(dlc_path):
			var success = ProjectSettings.load_resource_pack(dlc_path)
			if success:
				DebugService.log_data("Loaded DLC package: " + dlc_name)
			else:
				DebugService.log_data("Could not load DLC package: " + dlc_name)


func check_for_available_dlcs() -> void :
	var dir = Directory.new()
	var dir_path = "res://dlcs/"

	DebugService.log_data(dir_path + " exists: " + str(dir.dir_exists(dir_path)))

	if not Utils.is_on_console() or Utils.on_editor:
		if not dir.dir_exists(dir_path):
			return
	else:
		if not SteamPlatform.steam.isDLCInstalled(DLC_1_APP_ID):
			return

		var dlc_data: = load(dir_path + "dlc_1/dlc_data.tres") as DLCData

		if dlc_data != null:
			DebugService.log_data("Found dlc file, loading resources from: " + str(dlc_data.my_id))
			available_dlcs.push_back(dlc_data)
			return ;

	DebugService.log_data("Open " + dir_path)

	dir.open(dir_path)
	dir.list_dir_begin(true)

	var dlc_dirs: Array = []

	var dir_name = dir.get_next()
	while dir_name != "":
		if dir.current_is_dir():
			dlc_dirs.push_back(dir_path + dir_name)
		dir_name = dir.get_next()

	for path in dlc_dirs:
		dir.open(path)
		dir.list_dir_begin(true)
		var file_name = dir.get_next()
		while file_name != "":
			if file_name == "dlc_data.tres":
				var dlc_data: = load(path + "/" + file_name) as DLCData
				if Platform.is_dlc_owned(dlc_data.my_id):
					DebugService.log_data("Found dlc file for: " + str(dlc_data.my_id))
					available_dlcs.push_back(dlc_data)
				else:
					DebugService.log_data("Dlc is not owned: " + str(dlc_data.my_id))

			file_name = dir.get_next()

	dir.list_dir_end()


func save_run_state(
	shop_items: = [], 
	reroll_count: = [], 
	paid_reroll_count: = [], 
	initial_free_rerolls: = [], 
	free_rerolls: = [], 
	item_steals: = []
) -> void :
	saved_run_state = get_run_state(
		shop_items, 
		reroll_count, 
		paid_reroll_count, 
		initial_free_rerolls, 
		free_rerolls, 
		item_steals
	)
	last_saved_run_state = saved_run_state
	save()


func reset_and_save_new_run_state() -> void :
	reset_and_save_run_state(_get_empty_run_state())


func reset_and_save_run_state(run_state: Dictionary) -> void :
	saved_run_state = run_state
	if Utils.on_nintendo_nx_or_ounce:
		settings.version = VERSION_SWITCH
	else:
		settings.version = VERSION
	save()

func check_dlc_valid_for_saved_run_state() -> bool:
	if ProgressData.saved_run_state.has_run_state == false:
		return true

	if saved_run_state.has("current_zone"):
		var current_zone = saved_run_state.current_zone
		if current_zone > 0:
			if not ProgressData.is_dlc_available("abyssal_terrors") and current_zone == 1:
				print("Not valid because save has DLC and DLC is not available")
				return false

	
	if not ProgressData.is_dlc_available("abyssal_terrors"):
		if saved_run_state.has("players_data"):
			for player in saved_run_state.players_data:
				var foundChar = false
				for character in ItemService.characters:
					if player.current_character != null and player.current_character.my_id == character.my_id:
						foundChar = true
				if foundChar == false:
					print("couldn't find player in list, probably in dlc, disable save")
					return false

	return true

func get_run_state(
	shop_items: = [], 
	reroll_count: = [], 
	paid_reroll_count: = [], 
	initial_free_rerolls: = [], 
	free_rerolls: = [], 
	item_steals: = []
) -> Dictionary:
	var run_state = RunData.get_state()
	run_state["has_run_state"] = true
	run_state["shop_items"] = shop_items.duplicate(true)
	run_state["reroll_count"] = reroll_count.duplicate()
	run_state["paid_reroll_count"] = paid_reroll_count.duplicate()
	run_state["initial_free_rerolls"] = initial_free_rerolls.duplicate()
	run_state["free_rerolls"] = free_rerolls.duplicate()
	run_state["item_steals"] = item_steals.duplicate()

	return run_state


func init_save_paths(user_dir_override: = "user://") -> void :
	var dir = Directory.new()
	var dir_path = user_dir_override + Platform.get_user_id()
	var directory_exists = dir.dir_exists(dir_path)
	if not directory_exists:
		var err = dir.make_dir(dir_path)
		if err != OK:
			printerr("Could not create the directory %s. Error code: %s" % [dir_path, err])
			return

	SAVE_DIR = dir_path
	if BETA:
		SAVE_PATH = ProgressDataLoaderBeta.new(SAVE_DIR, current_profile_id).save_path
	else:
		SAVE_PATH = ProgressDataLoaderV3.new(SAVE_DIR, current_profile_id).save_path
	LOG_PATH = dir_path + "/log.txt"
	print("LOG_PATH: " + str(LOG_PATH))
	var file = File.new()
	file.open(LOG_PATH, File.WRITE)
	file.close()

	if not Utils.is_on_console() and not directory_exists:
		_copy_files_from_fallback_dir(user_dir_override)

func set_current_profile_id(profile_id: int) -> void :
	current_profile_id = profile_id
	save_settings()
	print("ProgressData: Set current profile id to %s." % [current_profile_id])

func load_settings():
	var file = File.new()
	var file_path = SAVE_DIR + SETTINGS_FILE_NAME
	var error_read = file.open(file_path, File.READ)
	if error_read != OK:
		printerr("ProgressData: Could not read %s." % [file_path])
		set_current_profile_id(0)
		return

	var parse_result: = JSON.parse(file.get_as_text())
	if parse_result.error != OK:
		
		printerr("ProgressData: Settings are corrupted. Use default settings instead.")
		set_current_profile_id(0)
		return

	if parse_result.result.has("current_profile_id"):
		current_profile_id = parse_result.result.get("current_profile_id", 0)
	else:
		current_profile_id = 0
	settings = Utils.merge_dictionaries(settings, parse_result.result.settings)
	file.close()

	set_current_profile_id(current_profile_id)
	if current_profile_id < 0 or current_profile_id >= profile_count:
		printerr("ProgressData: Invalid profile id %s. Resetting to 0." % [current_profile_id])
		set_current_profile_id(0)

func save_settings() -> void :
	var file = File.new()
	var file_path = SAVE_DIR + SETTINGS_FILE_NAME
	var error_write = file.open(file_path, File.WRITE)
	if error_write != OK:
		printerr("ProgressData: Could not write %s." % [file_path])
		return

	var json_data = {"current_profile_id": current_profile_id, "settings": settings}

	var sort_keys: = true
	var indent = ""
	if OS.has_feature("editor"):
		indent = "  "
	var json_string: = JSON.print(json_data, indent, sort_keys)
	file.store_string(json_string)
	file.close()
	print("ProgressData: Saved current profile id %s to %s." % [current_profile_id, file_path])

func load_profile_save(profile_id: int) -> void :
	if profile_id < 0 or profile_id >= profile_count:
		printerr("ProgressData: Invalid profile id %s. Resetting to 0." % [profile_id])
		profile_id = 0
	set_current_profile_id(profile_id)
	reset()
	difficulties_unlocked.clear()
	load_game_file()
	add_unlocked_by_default()
	set_max_selectable_difficulty()
	RunData.reset()
	print("ProgressData: Loaded profile id %s." % [current_profile_id])

func _copy_files_from_fallback_dir(user_dir_override: String) -> void :
	var dir: Directory = Directory.new()
	var dir_path: String = user_dir_override + fallback_dir_name
	if dir.dir_exists(dir_path) and dir_path != SAVE_DIR:
		print("fallback save dir found at %s. Copying files into %s" % [dir_path, SAVE_DIR])
		var err: int = dir.open(dir_path)
		if err != OK:
			printerr("Could not change directory to %s. Error code: %s" % [dir_path, err])
			return

		err = dir.list_dir_begin(false)
		if err != OK:
			printerr("Could not list directory %s. Error code: %s" % [dir_path, err])
			return

		var filename: String = dir.get_next()
		while filename != "":
			if not dir.current_is_dir():
				var file_path: String = dir.get_current_dir() + "/" + filename
				err = dir.copy(file_path, SAVE_DIR + "/" + filename)
				if err != OK:
					printerr("Could not copy file %s. Error code: %s" % [file_path, err])
			filename = dir.get_next()


func load_game_file(try_fallback: = true) -> void :
	if DebugService.reinitialize_save:
		save()
		return

	if BETA:
		var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, current_profile_id)
		load_with_generic_loader(loader_beta)
		show_main_title_beta_save_warning_popup = loader_beta.show_main_title_beta_save_warning_popup
		if load_status == LoadStatus.SAVE_OK:
			return
		if load_status != LoadStatus.SAVE_MISSING:
			
			return


	print("--- Load game file ---")
	print("Try to load save v3")
	var loader_v3 = ProgressDataLoaderV3.new(SAVE_DIR, current_profile_id)
	load_with_generic_loader(loader_v3)
	if load_status == LoadStatus.SAVE_OK:
		return
	if load_status != LoadStatus.SAVE_MISSING:
		
		return

	
	if current_profile_id > 0:
		load_status = LoadStatus.SAVE_OK
		save()
		return

	print("No save v3. Try to load save v2")
	var loader_v2 = ProgressDataLoaderV2.new(SAVE_DIR)
	load_with_generic_loader(loader_v2)
	if load_status == LoadStatus.SAVE_OK:
		print("Save v2 OK, try to merge old V1")
		merge_old_v1_save()
		return
	if load_status != LoadStatus.SAVE_MISSING:
		
		print("Save v2 corrupted. Not trying v1")
		return

	var loader_v1 = null

	print("No save v2. Try to load save v1")
	if Utils.is_on_console():
		loader_v1 = ProgressDataLoaderV1.new("user:/")
	else:
		loader_v1 = ProgressDataLoaderV1.new(SAVE_DIR)

	load_with_generic_loader(loader_v1)
	if load_status == LoadStatus.SAVE_OK:
		print("Migrating v1 save to v3")
		save()
		return
	elif load_status != LoadStatus.SAVE_MISSING:
		
		print("Save v1 corrupted")
	else:
		if try_fallback and not Utils.is_on_console():
			print("No save found, trying to copy from fallback")
			_use_fallback_save()
			return
		print("No save found, creating new save")
		load_status = LoadStatus.SAVE_OK
		save()


func _use_fallback_save() -> void :
	var split: = SAVE_DIR.split("//")
	_copy_files_from_fallback_dir(split[0] + "//")
	load_game_file(false)


func load_with_generic_loader(loader, path: = "") -> void :
	loader.load_game_file(path)
	load_status = loader.load_status

	if load_status == LoadStatus.CORRUPTED_ALL_SAVES:
		return
	if load_status == LoadStatus.SAVE_MISSING:
		return

	_append_without_duplicates(zones_unlocked, loader.zones_unlocked)
	_append_without_duplicates(characters_unlocked, loader.characters_unlocked)
	_append_without_duplicates(upgrades_unlocked, loader.upgrades_unlocked)
	_append_without_duplicates(consumables_unlocked, loader.consumables_unlocked)
	_append_without_duplicates(weapons_unlocked, loader.weapons_unlocked)
	_append_without_duplicates(items_unlocked, loader.items_unlocked)

	var challenges_completed_hash: Array = Utils.convert_to_hash_array(loader.challenges_completed)

	_append_without_duplicates(challenges_completed, challenges_completed_hash)

	for difficulty_json in loader.difficulties_unlocked_serialized:
		var difficulty: = CharacterDifficultyInfo.new()
		difficulty.deserialize_and_merge(difficulty_json)
		difficulties_unlocked.append(difficulty)

	_dedublicate_difficulties_unlocked()

	inactive_mods = loader.inactive_mods.duplicate()
	read_announcements = loader.read_announcements.duplicate()

	saved_run_state = Utils.merge_dictionaries(saved_run_state, loader.run_state_deserialized)
	
	for k in ["nb_of_waves", "current_wave", "current_difficulty", "bonus_gold", "retries"]:
		if saved_run_state.has(k) and typeof(saved_run_state[k]) == TYPE_REAL:
			saved_run_state[k] = int(saved_run_state[k])
	for k in ["reroll_count", "paid_reroll_count", "initial_free_rerolls", "free_rerolls"]:
		if saved_run_state.has(k) and typeof(saved_run_state[k]) == TYPE_ARRAY:
			for i in saved_run_state[k].size():
				if typeof(saved_run_state[k][i]) == TYPE_REAL:
					saved_run_state[k][i] = int(saved_run_state[k][i])

	if loader is ProgressDataLoaderV1 or loader is ProgressDataLoaderV2:
		settings = Utils.merge_dictionaries(settings, loader.settings)

	data = Utils.merge_dictionaries(data, loader.data)
	for k in ["enemies_killed", "materials_collected", "trees_killed", "steps_taken", "enemies_killed_far_away"]:
		if data.has(k):
			
			data[k] = int(data[k])

	if not (loader is ProgressDataLoaderV1) and not (loader is ProgressDataLoaderV2):
		killed_enemies = Utils.merge_dictionaries(killed_enemies, loader.killed_enemies)
		for k in killed_enemies.keys():
			killed_enemies[k] = int(killed_enemies[k])

		killed_by_enemies = Utils.merge_dictionaries(killed_by_enemies, loader.killed_by_enemies)
		for k in killed_by_enemies.keys():
			killed_by_enemies[k] = int(killed_by_enemies[k])

		items_bought = Utils.merge_dictionaries(items_bought, loader.items_bought)
		for k in items_bought.keys():
			items_bought[k] = int(items_bought[k])


func _dedublicate_difficulties_unlocked() -> void :
	var processed_characters: = {}
	var new_difficulties_unlocked: = []
	for difficulty in difficulties_unlocked:
		if not difficulty.character_id in processed_characters:
			new_difficulties_unlocked.append(difficulty)
			processed_characters[difficulty.character_id] = true

		var processed_zones: = {}
		var new_zones_difficulty_info: = []
		for zone_diff_info in difficulty.zones_difficulty_info:
			if not zone_diff_info.zone_id in processed_zones:
				new_zones_difficulty_info.append(zone_diff_info)
				processed_zones[zone_diff_info.zone_id] = true

		difficulty.zones_difficulty_info = new_zones_difficulty_info
	difficulties_unlocked = new_difficulties_unlocked


func save() -> void :
	if DebugService.disable_saving:
		return
	if load_status == LoadStatus.CORRUPTED_ALL_SAVES_NO_STEAM or load_status == LoadStatus.CORRUPTED_ALL_SAVES_NO_EPIC:
		printerr("Aborting save due to unrecoverable corruption")
		return
	save_settings()

	if BETA:
		var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, current_profile_id)
		_set_loader_properties_beta(loader_beta, saved_run_state)
		loader_beta.show_main_title_beta_save_warning_popup = show_main_title_beta_save_warning_popup
		loader_beta.save()
	else:
		var loader_v3 = ProgressDataLoaderV3.new(SAVE_DIR, current_profile_id)
		_set_loader_properties(loader_v3, saved_run_state)
		loader_v3.save()



func get_current_save_object() -> Dictionary:
	if BETA:
		var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, current_profile_id)
		_set_loader_properties_beta(loader_beta, _get_current_run_state())
		return loader_beta.get_save_object()

	var loader_v3 = ProgressDataLoaderV3.new(SAVE_DIR, current_profile_id)
	_set_loader_properties(loader_v3, _get_current_run_state())
	return loader_v3.get_save_object()


func add_unlocked_by_default() -> void :
	for zone in ZoneService.zones:
		if zone.unlocked_by_default and not zones_unlocked.has(zone.my_id):
			zones_unlocked.push_back(zone.my_id)

	for item in ItemService.items:
		
		
		item._generate_hashes()
		if item.unlocked_by_default and not items_unlocked.has(item.my_id_hash):
			items_unlocked.push_back(item.my_id_hash)

	for weapon in ItemService.weapons:
		
		
		weapon._generate_hashes()
		if weapon.unlocked_by_default and not weapons_unlocked.has(weapon.weapon_id_hash):
			weapons_unlocked.push_back(weapon.weapon_id_hash)

	for upgrade in ItemService.upgrades:
		
		
		upgrade._generate_hashes()
		if upgrade.unlocked_by_default and not upgrades_unlocked.has(upgrade.upgrade_id_hash):
			upgrades_unlocked.push_back(upgrade.upgrade_id_hash)

	for character in ItemService.characters:
		
		
		character._generate_hashes()
		if character.unlocked_by_default and not characters_unlocked.has(character.my_id_hash):
			characters_unlocked.push_back(character.my_id_hash)

	for consumable in ItemService.consumables:
		
		
		consumable._generate_hashes()
		if consumable.unlocked_by_default and not consumables_unlocked.has(consumable.my_id_hash):
			consumables_unlocked.push_back(consumable.my_id_hash)

	for character in ItemService.characters:
		var character_difficulty_info_exists = false
		var existing_zones_difficulty_info = []
		var char_diff_info_to_modify: = CharacterDifficultyInfo.new(character.my_id)

		for difficulty_unlocked in difficulties_unlocked:
			if difficulty_unlocked.character_id == character.my_id:
				character_difficulty_info_exists = true
				char_diff_info_to_modify = difficulty_unlocked
				for zone_diff_info in difficulty_unlocked.zones_difficulty_info:
					existing_zones_difficulty_info.push_back(zone_diff_info.zone_id)

		for zone in ZoneService.zones:
			if zone.unlocked_by_default:
				var already_has_zone_diff_info = existing_zones_difficulty_info.has(zone.my_id)

				if not already_has_zone_diff_info:
					char_diff_info_to_modify.zones_difficulty_info.push_back(ZoneDifficultyInfo.new(zone.my_id))

		if not character_difficulty_info_exists:
			difficulties_unlocked.push_back(char_diff_info_to_modify)


func unlock_all() -> void :
	for zone in ZoneService.zones:
		if zone.unlocked_by_default:
			zones_unlocked.push_back(zone.my_id)

	unlock_all_items()
	unlock_all_weapoons()
	unlock_all_characters()
	unlock_all_enemies()
	unlock_all_difficulties()

	ChallengeService.complete_all_challenges()


func unlock_all_items() -> void :
	for item in ItemService.items:
		items_unlocked.push_back(item.get_my_id_hash())
		items_bought[item.my_id_hash] = 10

	for upgrade in ItemService.upgrades:
		if not upgrades_unlocked.has(upgrade.upgrade_id_hash):
			upgrades_unlocked.push_back(upgrade.upgrade_id_hash)

	for consumable in ItemService.consumables:
		if consumable.unlocked_by_default and not consumables_unlocked.has(consumable.get_my_id_hash()):
			consumables_unlocked.push_back(consumable.get_my_id_hash())

func unlock_all_weapoons() -> void :
	for weapon in ItemService.weapons:
		if not weapons_unlocked.has(weapon.get_weapon_id_hash()):
			weapons_unlocked.push_back(weapon.my_id_hash)
		items_bought[weapon.my_id_hash] = 10

func unlock_all_characters() -> void :
	for character in ItemService.characters:
		characters_unlocked.push_back(character.get_my_id_hash())

func unlock_all_enemies() -> void :
	for enemy in ItemService.entities:
		killed_enemies[enemy.my_id_hash] = 1000



func unlock_all_difficulties() -> void :
	difficulties_unlocked = []
	for character in ItemService.characters:
		var character_diff_info = CharacterDifficultyInfo.new(character.my_id)

		for zone in ZoneService.zones:
			if zone.unlocked_by_default:
				var info = ZoneDifficultyInfo.new(zone.my_id)
				info.max_selectable_difficulty = MAX_DIFFICULTY
				character_diff_info.zones_difficulty_info.push_back(info)

		difficulties_unlocked.push_back(character_diff_info)

func lock_all() -> void :
	lock_all_items()
	lock_all_weapons()
	lock_all_characters()
	lock_all_enemies()
	lock_all_difficulties()
	ProgressData.challenges_completed.clear()

func lock_all_items() -> void :
	items_bought.clear()
	upgrades_unlocked.clear()
	consumables_unlocked.clear()

func lock_all_weapons() -> void :
	items_bought.clear()

func lock_all_characters() -> void :
	for character in ItemService.characters:
		if character.unlocked_by_default:
			characters_unlocked.push_back(character.my_id)
	characters_unlocked.clear()

func lock_all_enemies() -> void :
	killed_enemies.clear()

func lock_all_difficulties() -> void :
	difficulties_unlocked.clear()

func set_max_selectable_difficulty() -> void :
	var overall_max_selectable_difficulty: = 0
	for difficulty_info in difficulties_unlocked:
		for zone_difficulty_info in difficulty_info.zones_difficulty_info:
			overall_max_selectable_difficulty = int(max(overall_max_selectable_difficulty, zone_difficulty_info.max_selectable_difficulty))

	for difficulty in difficulties_unlocked:
		for zone_difficulty_info in difficulty.zones_difficulty_info:
			if zone_difficulty_info.max_selectable_difficulty < overall_max_selectable_difficulty:
				zone_difficulty_info.max_selectable_difficulty = overall_max_selectable_difficulty

			if zone_difficulty_info.max_difficulty_beaten.difficulty_value > MAX_DIFFICULTY:
				zone_difficulty_info.max_difficulty_beaten.difficulty_value = MAX_DIFFICULTY

			if zone_difficulty_info.max_endless_wave_beaten.difficulty_value > MAX_DIFFICULTY:
				zone_difficulty_info.max_endless_wave_beaten.difficulty_value = MAX_DIFFICULTY

func apply_settings() -> void :
	_apply_sounds_settings()

	TranslationServer.set_locale(settings.language)

	if not DebugService.no_fullscreen_on_launch:
		OS.window_fullscreen = settings.fullscreen

	if Utils.is_on_console() and not Utils.on_gdk_desktop:
		
		settings.font_size = 1.2


	smallest_text_font.size = SMALLEST_FONT_BASE_SIZE * settings.font_size
	RunData.reset_background()
	set_fps_limit(settings.limit_fps)


func _apply_sounds_settings() -> void :
	if settings.has("volume"):
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Master"), linear2db(settings.volume.master ))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Sound"), linear2db(settings.volume.sound))
		AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear2db(settings.volume.music))


func set_font_size(value: float) -> void :
	if Utils.is_on_console() and not Utils.on_gdk_desktop:
		
		value = 1.2

	smallest_text_font.size = SMALLEST_FONT_BASE_SIZE * value
	settings.font_size = value


func set_fps_limit(enabled: bool) -> void :
	Engine.target_fps = FPS_LIMIT if enabled else 0
	settings.limit_fps = enabled


func get_all_available_dlc_ids() -> Array:
	var ids = []

	for dlc in available_dlcs:
		ids.push_back(dlc.my_id)

	return ids


func update_dlc_resources_based_on_run_state(state: Dictionary) -> void :
	for enabled_dlc_id in state.enabled_dlcs:
		if enabled_dlc_id in settings.deactivated_dlcs:
			var dlc_data = get_dlc_data(enabled_dlc_id)

			if dlc_data:
				dlc_data.add_resources()

	for active_dlc_id in get_active_dlc_ids():
		if not active_dlc_id in state.enabled_dlcs:
			var dlc_data = get_dlc_data(active_dlc_id)

			if dlc_data:
				dlc_data.remove_resources()


func get_active_dlc_ids() -> Array:
	if get_tree().current_scene.name == "GutRunner":
		return []

	var active_dlcs = get_all_available_dlc_ids()

	for deactivated_dlc_id in settings.deactivated_dlcs:
		active_dlcs.erase(deactivated_dlc_id)

	return active_dlcs


func get_active_dlc_tracks() -> Array:
	var ids = get_all_available_dlc_ids()

	for deactivated_dlc_id in settings.deactivated_dlc_tracks:
		ids.erase(deactivated_dlc_id)

	return ids


func reset_dlc_resources_to_active_dlcs() -> void :
	if get_tree().current_scene.name == "GutRunner":
		return

	for dlc in available_dlcs:
		dlc.remove_resources()

	for dlc_id in get_active_dlc_ids():
		var dlc_data = get_dlc_data(dlc_id)
		if dlc_data:
			dlc_data.add_resources()


func get_dlc_data(dlc_id: String) -> DLCData:
	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			return dlc

	return null


func force_activate_dlc(dlc_id: String) -> void :
	print("force activate dlc " + dlc_id)

	
	
	
	

	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			dlc.add_resources()

	add_unlocked_by_default()
	RunData.reset()
	emit_signal("dlc_activated", dlc_id)


func force_deactivate_dlc(dlc_id: String) -> void :

	print("force deactivate dlc " + dlc_id)

	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			print("remove resources for dlc " + dlc.my_id)
			dlc.remove_resources()

	RunData.current_zone = 0
	RunData.reset()
	emit_signal("dlc_deactivated", dlc_id)


func activate_dlc(dlc_id: String) -> void :

	print("activate dlc " + dlc_id)

	if get_active_dlc_ids().has(dlc_id) and not get_tree().current_scene.name == "GutRunner":
		print(dlc_id + " already exists")
		return

	settings.deactivated_dlcs.erase(dlc_id)

	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			dlc.add_resources()

	add_unlocked_by_default()
	RunData.reset()
	emit_signal("dlc_activated", dlc_id)


func deactivate_dlc(dlc_id: String) -> void :

	print("deactivate dlc " + dlc_id)

	if settings.deactivated_dlcs.has(dlc_id):
		print(dlc_id + " doesn't exist")
		return

	settings.deactivated_dlcs.push_back(dlc_id)
	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			dlc.remove_resources()

	RunData.current_zone = 0
	RunData.reset()
	emit_signal("dlc_deactivated", dlc_id)


func is_dlc_available(dlc_id: String) -> bool:
	for dlc in available_dlcs:
		if dlc.my_id == dlc_id:
			return true
	return false


func is_colors_tier_by_default() -> bool:
	if not _color_distance(DEFAULT_TIER_COLOR_0, Color(settings.tier_0_color)) < 0.05:
		return false
	if not _color_distance(DEFAULT_TIER_COLOR_1, Color(settings.tier_1_color)) < 0.05:
		return false
	if not _color_distance(DEFAULT_TIER_COLOR_2, Color(settings.tier_2_color)) < 0.05:
		return false
	if not _color_distance(DEFAULT_TIER_COLOR_3, Color(settings.tier_3_color)) < 0.05:
		return false
	if not _color_distance(DEFAULT_TIER_COLOR_4, Color(settings.tier_4_color)) < 0.05:
		return false
	if not _color_distance(DEFAULT_TIER_COLOR_5, Color(settings.tier_5_color)) < 0.05:
		return false
	return true


func _color_distance(color_1: Color, color_2: Color) -> float:
	var vector_1: = Vector3(color_1.r, color_1.g, color_1.b)
	var vector_2: = Vector3(color_2.r, color_2.g, color_2.b)
	return vector_1.distance_to(vector_2)


func is_dlc_available_and_active(dlc_id: String) -> bool:
	var is_available = is_dlc_available(dlc_id)

	if not is_available:
		return false

	return not settings.deactivated_dlcs.has(dlc_id)


func get_character_difficulty_info(character_id: int, zone_id: int, is_random_zone: bool = false) -> ZoneDifficultyInfo:

	for character_difficulty_info in difficulties_unlocked:
		assert (character_difficulty_info.character_id_hash != Keys.empty_hash)
		if character_difficulty_info.character_id_hash != character_id: continue

		if is_random_zone:
			var lowest_difficulty = 999
			var current_zone_difficulty_info
			for zone_difficulty_info in character_difficulty_info.zones_difficulty_info:
				if (zone_difficulty_info.max_difficulty_beaten.difficulty_value < lowest_difficulty):
					lowest_difficulty = zone_difficulty_info.max_difficulty_beaten.difficulty_value
					current_zone_difficulty_info = zone_difficulty_info
			if (lowest_difficulty == 999): continue
			return current_zone_difficulty_info
		else:
			for zone_difficulty_info in character_difficulty_info.zones_difficulty_info:
				if zone_difficulty_info.zone_id != zone_id: continue
				return zone_difficulty_info

	return ZoneDifficultyInfo.new(zone_id)


func increment_stat(key: String) -> void :
	data[key] += 1


func _set_loader_properties_beta(loader_v3: ProgressDataLoaderBeta, run_state: Dictionary) -> void :
	loader_v3.zones_unlocked = zones_unlocked.duplicate()
	loader_v3.characters_unlocked = characters_unlocked.duplicate()
	loader_v3.upgrades_unlocked = upgrades_unlocked.duplicate()
	loader_v3.consumables_unlocked = consumables_unlocked.duplicate()
	loader_v3.weapons_unlocked = weapons_unlocked.duplicate()
	loader_v3.items_unlocked = items_unlocked.duplicate()
	loader_v3.challenges_completed = challenges_completed.duplicate()
	loader_v3.difficulties_unlocked_serialized.clear()
	for difficulty_unlocked in difficulties_unlocked:
		loader_v3.difficulties_unlocked_serialized.push_back(difficulty_unlocked.serialize())
	loader_v3.inactive_mods = inactive_mods.duplicate()
	loader_v3.read_announcements = read_announcements.duplicate()
	loader_v3.run_state_deserialized = run_state.duplicate()
	loader_v3.data = data.duplicate()
	loader_v3.killed_enemies = killed_enemies.duplicate()
	loader_v3.killed_by_enemies = killed_by_enemies.duplicate()
	loader_v3.items_bought = items_bought.duplicate()

func _set_loader_properties(loader_v3: ProgressDataLoaderV3, run_state: Dictionary) -> void :
	loader_v3.zones_unlocked = zones_unlocked.duplicate()

	
	loader_v3.characters_unlocked = Utils.convert_to_hash_array(characters_unlocked.duplicate())
	loader_v3.upgrades_unlocked = Utils.convert_to_hash_array(upgrades_unlocked.duplicate())
	loader_v3.consumables_unlocked = Utils.convert_to_hash_array(consumables_unlocked.duplicate())
	loader_v3.weapons_unlocked = Utils.convert_to_hash_array(weapons_unlocked.duplicate())
	loader_v3.items_unlocked = Utils.convert_to_hash_array(items_unlocked.duplicate())
	loader_v3.challenges_completed = Utils.convert_to_hash_array(challenges_completed.duplicate())
	loader_v3.difficulties_unlocked_serialized.clear()
	for difficulty_unlocked in difficulties_unlocked:
		loader_v3.difficulties_unlocked_serialized.push_back(difficulty_unlocked.serialize())
	loader_v3.inactive_mods = inactive_mods.duplicate()
	loader_v3.read_announcements = read_announcements.duplicate()
	loader_v3.run_state_deserialized = run_state.duplicate()
	loader_v3.data = data.duplicate()
	loader_v3.killed_enemies = killed_enemies.duplicate()
	loader_v3.killed_by_enemies = killed_by_enemies.duplicate()
	loader_v3.items_bought = items_bought.duplicate()


func _get_current_run_state() -> Dictionary:
	if saved_run_state.has_run_state:
		
		return get_run_state(
			saved_run_state.shop_items, 
			saved_run_state.reroll_count, 
			saved_run_state.paid_reroll_count, 
			saved_run_state.initial_free_rerolls, 
			saved_run_state.free_rerolls, 
			saved_run_state.item_steals
		)
	else:
		return get_run_state()


func _get_empty_run_state() -> Dictionary:
	return {"has_run_state": false}


func _append_without_duplicates(array: Array, array_to_append: Array) -> void :
	var dict: = {}
	for item in array:
		dict[item] = true
	for item in array_to_append:
		if not dict.has(item):
			array.push_back(item)
			dict[item] = true

func get_profile_stats() -> Array:
	var result = []
	for i in range(3):
		if BETA:
			var loader_beta = ProgressDataLoaderBeta.new(SAVE_DIR, i)
			var stats = loader_beta.load_profile_stats()
			result.push_back(stats)
		else:
			var loader = ProgressDataLoaderV3.new(SAVE_DIR, i)
			var stats = loader.load_profile_stats()
			result.push_back(stats)
	return result

func change_language(new_language: String) -> void :
	if not new_language in languages:
		printerr("Language %s is not a valid language option" % new_language)
		return

	settings.language = new_language
	TranslationServer.set_locale(new_language)
	emit_signal("language_changed")


func get_percent_challenges_unlocked() -> float:
	var all_challenge_counter: int = 0
	for challenge in ChallengeService.challenges:
		if challenge.reward_type == RewardType.DIFFICULTY:
			continue
		all_challenge_counter += 1
	var all_challenges_unlocked: int = get_profile_stats()[current_profile_id].challenges_completed
	return float(all_challenges_unlocked) / float(all_challenge_counter)


func get_percent_items_unlocked() -> float:
	var all_items: int = ItemService.items.size()
	var all_items_unlocked: int = 0
	for item in ItemService.items:
		if items_bought.has(item.my_id_hash):
			all_items_unlocked += 1
	return float(all_items_unlocked) / float(all_items)


func get_percent_weapons_unlocked() -> float:
	var all_weapons: int = ItemService.weapons.size()
	var all_weapons_unlocked: int = 0
	for weapon in ItemService.weapons:
		if items_bought.has(weapon.my_id_hash):
			all_weapons_unlocked += 1
	return float(all_weapons_unlocked) / float(all_weapons)


func get_percent_enemies_unlocked() -> float:
	var all_entities: int = ItemService.entities.size() - 1
	var all_entities_unlocked: int = killed_enemies.size()
	return float(all_entities_unlocked) / float(all_entities)

func show_store_dlc1() -> void :
	if OS_Seaven.is_in_editor_mode():
		if not SteamPlatform.steam.isDLCInstalled(DLC_1_APP_ID):
			SteamPlatform.steam.debugAddDlc(DLC_1_APP_ID)

		return

	if not SteamPlatform.steam.isDLCInstalled(DLC_1_APP_ID):
		OS_Seaven.show_product_store(str(DLC_1_APP_ID))


func read_all_dlcs() -> void :
	print("read all dlcs")
	available_dlcs.clear()
	check_for_available_dlcs()


func merge_old_v1_save() -> void :

	var loader_v1 = null

	if Utils.is_on_console():
		loader_v1 = ProgressDataLoaderV1.new("user:/")
	else:
		loader_v1 = ProgressDataLoaderV1.new(SAVE_DIR)

	loader_v1.load_game_file("")
	load_status = loader_v1.load_status

	if load_status == LoadStatus.SAVE_MISSING:
		
		load_status = LoadStatus.SAVE_OK
		return
	if load_status == LoadStatus.CORRUPTED_ALL_SAVES:
		return

	print("Try to merge save version 1")

	_append_without_duplicates(zones_unlocked, loader_v1.zones_unlocked)
	_append_without_duplicates(characters_unlocked, loader_v1.characters_unlocked)
	_append_without_duplicates(upgrades_unlocked, loader_v1.upgrades_unlocked)
	_append_without_duplicates(consumables_unlocked, loader_v1.consumables_unlocked)
	_append_without_duplicates(weapons_unlocked, loader_v1.weapons_unlocked)
	_append_without_duplicates(items_unlocked, loader_v1.items_unlocked)

	var challenges_completed_hash: Array = Utils.convert_to_hash_array(loader_v1.challenges_completed)
	_append_without_duplicates(challenges_completed, challenges_completed_hash)

	var overall_max_selectable_difficulty: = 0
	for difficulty_json in loader_v1.difficulties_unlocked_serialized:
		for difficulty in difficulties_unlocked:
			if difficulty.character_id == difficulty_json.character_id:
				difficulty.deserialize_and_merge_take_max(difficulty_json)
				for zone_difficulty_info in difficulty.zones_difficulty_info:
					overall_max_selectable_difficulty = int(max(overall_max_selectable_difficulty, zone_difficulty_info.max_selectable_difficulty))

	for difficulty in difficulties_unlocked:
		for zone_difficulty_info in difficulty.zones_difficulty_info:
			if zone_difficulty_info.max_selectable_difficulty < overall_max_selectable_difficulty:
				zone_difficulty_info.max_selectable_difficulty = overall_max_selectable_difficulty

	

	
	data = Utils.merge_dictionaries_take_max(data, loader_v1.data)
	for k in ["enemies_killed", "materials_collected", "trees_killed", "steps_taken", "enemies_killed_far_away"]:
		if data.has(k):
			
			data[k] = int(data[k])
