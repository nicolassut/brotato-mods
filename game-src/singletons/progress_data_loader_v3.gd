class_name ProgressDataLoaderV3
extends Reference


const LOG_PREFIX: = "ProgressDataLoaderV3: "
const MAX_BACKUP_FILES: = 5

var version: = 3

var load_status = LoadStatus.SAVE_OK

var zones_unlocked: = []
var characters_unlocked: = []

var upgrades_unlocked: = []
var consumables_unlocked: = []

var weapons_unlocked: = []
var items_unlocked: = []
var challenges_completed: = []
# Gourmet ecosystem - persisted since Phase 4; OPTIONAL in the save (old saves
# lack it), so it must NEVER join the hard-fail property whitelist below
var systems_unlocked: = []

var difficulties_unlocked_serialized: = []
var inactive_mods: = []

var read_announcements: = []

var run_state_deserialized: Dictionary
var data: Dictionary = {}
var killed_enemies: Dictionary = {}
var killed_by_enemies: Dictionary = {}
var items_bought: Dictionary = {}

var save_path: = ""
var _tmp_path: = ""

var run_save_path: = ""
var _tmp_run_save_path: = ""

var profile_id: = 0

func _init(save_dir: = "", current_profile_id: int = 0) -> void :
	var dir: = Directory.new()
	var directory_exists: = not save_dir.empty() and dir.dir_exists(save_dir)
	if not directory_exists:
		return

	profile_id = current_profile_id
	save_path = save_dir + "/save_v3_" + String(profile_id) + ".json"
	_tmp_path = save_dir + "/save_v3_" + String(profile_id) + ".json.tmp"
	run_save_path = save_dir + "/run_v3_" + String(profile_id) + ".json"
	_tmp_run_save_path = save_dir + "/run_v3_" + String(profile_id) + ".json.tmp"
	
	print(LOG_PREFIX + "Save path: " + save_path)

func load_profile_stats(path: = "") -> Dictionary:
	load_game_file(path)

	var characters_unlocked_count: = characters_unlocked.size()
	if characters_unlocked_count <= 0:
		for character in ItemService.characters:
			if character.unlocked_by_default:
				characters_unlocked_count += 1

	var challenges_counter: int = 0
	for element in challenges_completed:
		match element:
			Keys.unlock_difficulty_1_hash, Keys.unlock_difficulty_2_hash, Keys.unlock_difficulty_3_hash, Keys.unlock_difficulty_4_hash, Keys.unlock_difficulty_5_hash, Keys.unlock_difficulty_6_hash:
				continue
		challenges_counter += 1

	var result: Dictionary = {}
	result["has_run_state"] = run_state_deserialized.get("has_run_state", false)
	result["run_won"] = data.get("run_won", 0)
	result["characters_unlocked"] = characters_unlocked_count
	result["challenges_completed"] = challenges_counter
	result["is_unlock_all_save"] = data.get("is_unlock_all_save")

	return result

func load_game_file(path: = "") -> void :
	load_progress_save_file(path)
	if load_status == LoadStatus.SAVE_OK or load_status == LoadStatus.CORRUPTED_SAVE:
		load_run_save_file(path)

func load_progress_save_file(path: = "") -> void :
	if path.empty():
		path = save_path
	if path.empty():
		printerr(LOG_PREFIX + "Loading failed - missing save path")
		return

	print(LOG_PREFIX + "Loading %s" % path)

	var save_file: = File.new()
	if not save_file.file_exists(path):
		print(LOG_PREFIX + "No v3 save found")
		load_status = LoadStatus.SAVE_MISSING
		return

	var error = save_file.open(path, File.READ)
	var basename = "save_v3_" + String(profile_id)
	if error != OK:
		printerr(LOG_PREFIX + "Could not open %s. Error code: %s" % [path, error])
		_close_file_and_load_backups(basename, save_file, path)
		return
	var content: = save_file.get_as_text();
	if content == null:
		printerr(LOG_PREFIX + "Content of %s is null." % path)
		_close_file_and_load_backups(basename, save_file, path)
		return
	if content.strip_edges() == "":
		printerr(LOG_PREFIX + "Content of %s is empty." % path)
		_close_file_and_load_backups(basename, save_file, path)
		return

	var parse_result: = JSON.parse(content)
	if parse_result.error != OK:
		var error_line: = parse_result.error_line
		var error_string: = parse_result.error_string
		printerr(LOG_PREFIX + "Error parsing save file (%s): %s at line %s" % [parse_result.error, error_string, error_line])
		_close_file_and_load_backups(basename, save_file, path)
		return

	var save_object = parse_result.result
	if typeof(save_object) != TYPE_DICTIONARY:
		printerr(LOG_PREFIX + "Save file is not a dictionary")
		_close_file_and_load_backups(basename, save_file, path)
		return

	for property in ["zones_unlocked", "characters_unlocked", "upgrades_unlocked", "consumables_unlocked", "weapons_unlocked", "items_unlocked", "challenges_completed", "difficulties_unlocked", "inactive_mods"]:
		if not save_object.has(property):
			printerr(LOG_PREFIX + "Save file is missing property: %s" % property)
			_close_file_and_load_backups(basename, save_file, path)
			return
		if typeof(save_object[property]) != TYPE_ARRAY:
			printerr(LOG_PREFIX + "Property %s is not an array" % property)
			_close_file_and_load_backups(basename, save_file, path)
			return

	for property in ["data"]:
		if not save_object.has(property):
			printerr(LOG_PREFIX + "Save file is missing property: %s" % property)
			_close_file_and_load_backups(basename, save_file, path)
			return
		if typeof(save_object[property]) != TYPE_DICTIONARY:
			printerr(LOG_PREFIX + "Property %s is not a dictionary" % property)
			_close_file_and_load_backups(basename, save_file, path)
			return

	zones_unlocked = save_object.zones_unlocked
	characters_unlocked = Utils.convert_to_hash_array(save_object.characters_unlocked)
	upgrades_unlocked = Utils.convert_to_hash_array(save_object.upgrades_unlocked)
	consumables_unlocked = Utils.convert_to_hash_array(save_object.consumables_unlocked)
	weapons_unlocked = Utils.convert_to_hash_array(save_object.weapons_unlocked)
	items_unlocked = Utils.convert_to_hash_array(save_object.items_unlocked)

	
	var challenges_completed_hash = Utils.convert_to_hash_array(save_object.challenges_completed, true)
	challenges_completed = challenges_completed_hash

	systems_unlocked = Utils.convert_to_hash_array(save_object.get("systems_unlocked", []))

	difficulties_unlocked_serialized = save_object.difficulties_unlocked
	inactive_mods = save_object.inactive_mods
	read_announcements = save_object.get("read_announcements", [])
	data = save_object.data
	if save_object.has("killed_enemies"):
		killed_enemies = Utils.convert_dictionary_to_hash(save_object.killed_enemies)
	if save_object.has("killed_by_enemies"):
		killed_by_enemies = Utils.convert_dictionary_to_hash(save_object.killed_by_enemies)
	if save_object.has("items_bought"):
		items_bought = Utils.convert_dictionary_to_hash(save_object.items_bought)
	version = save_object.version

	save_file.close()

func load_run_save_file(path: = "") -> void :
	if path.empty():
		path = run_save_path
	if path.empty():
		printerr(LOG_PREFIX + "Loading failed - missing save path")
		return

	print(LOG_PREFIX + "Loading %s" % path)

	var save_file: = File.new()
	if not save_file.file_exists(path):
		print(LOG_PREFIX + "No v3 save found")
		load_status = LoadStatus.RUN_SAVE_MISSING
		return

	var error = save_file.open(path, File.READ)
	var basename = "run_v3_" + String(profile_id)
	if error != OK:
		printerr(LOG_PREFIX + "Could not open %s. Error code: %s" % [path, error])
		_close_file_and_load_backups(basename, save_file, path, true)
		return

	var content: = save_file.get_as_text();
	if content == null:
		printerr(LOG_PREFIX + "Content of %s is null." % path)
		_close_file_and_load_backups(basename, save_file, path)
		return
	if content.strip_edges() == "":
		printerr(LOG_PREFIX + "Content of %s is empty." % path)
		_close_file_and_load_backups(basename, save_file, path)
		return

	var parse_result: = JSON.parse(content)
	if parse_result.error != OK:
		var error_line: = parse_result.error_line
		var error_string: = parse_result.error_string
		printerr(LOG_PREFIX + "Error parsing save file (%s): %s at line %s" % [parse_result.error, error_string, error_line])
		_close_file_and_load_backups(basename, save_file, path, true)
		return

	var save_object = parse_result.result
	if typeof(save_object) != TYPE_DICTIONARY:
		printerr(LOG_PREFIX + "Save file is not a dictionary")
		_close_file_and_load_backups(basename, save_file, path, true)
		return

	for property in ["current_run_state"]:
		if not save_object.has(property):
			printerr(LOG_PREFIX + "Save file is missing property: %s" % property)
			_close_file_and_load_backups(basename, save_file, path, true)
			return
		if typeof(save_object[property]) != TYPE_DICTIONARY:
			printerr(LOG_PREFIX + "Property %s is not a dictionary" % property)
			_close_file_and_load_backups(basename, save_file, path, true)
			return

	run_state_deserialized = deserialize_run_state(save_object.current_run_state)

	save_file.close()

func add_unlocked_by_default_from_blank_save() -> void :
	data = ProgressData.get_fresh_data()
	zones_unlocked.clear()
	for zone in ZoneService.zones:
		if zone.unlocked_by_default and not zones_unlocked.has(zone.my_id):
			zones_unlocked.push_back(zone.my_id)
	for item in ItemService.items:
		if item.unlocked_by_default:
			items_unlocked.push_back(item.my_id_hash)

	for weapon in ItemService.weapons:
		if weapon.unlocked_by_default:
			weapons_unlocked.push_back(weapon.weapon_id_hash)

	for upgrade in ItemService.upgrades:
		if upgrade.unlocked_by_default:
			upgrades_unlocked.push_back(upgrade.upgrade_id_hash)

	for character in ItemService.characters:
		if character.unlocked_by_default:
			characters_unlocked.push_back(character.my_id_hash)

	for consumable in ItemService.consumables:
		if consumable.unlocked_by_default:
			consumables_unlocked.push_back(consumable.my_id_hash)

	for character in ItemService.characters:
		var character_difficulty_info_exists = false
		var existing_zones_difficulty_info = []
		var char_diff_info_to_modify: = CharacterDifficultyInfo.new(character.my_id)

		for zone in ZoneService.zones:
			if zone.unlocked_by_default:
				var already_has_zone_diff_info = existing_zones_difficulty_info.has(zone.my_id)

				if not already_has_zone_diff_info:
					char_diff_info_to_modify.zones_difficulty_info.push_back(ZoneDifficultyInfo.new(zone.my_id))

		if not character_difficulty_info_exists:
			difficulties_unlocked_serialized.push_back(char_diff_info_to_modify.serialize())

func unlock_all() -> void :
	if data.size() <= 0:
		data = ProgressData.get_fresh_data()
	data.is_unlock_all_save = 1
	zones_unlocked.clear()
	for zone in ZoneService.zones:
		zones_unlocked.push_back(zone.my_id)

	unlock_all_items()
	unlock_all_weapons()
	unlock_all_characters()
	unlock_all_enemies()
	unlock_all_difficulties()
	unlock_all_challenge()

func unlock_all_items() -> void :
	for item in ItemService.items:
		if not items_unlocked.has(item.my_id_hash):
			items_unlocked.push_back(item.my_id_hash)

		if items_bought.has(item.my_id_hash):
			items_bought[item.my_id_hash] = max(items_bought[item.my_id_hash], item.unlock_codex_descr_after_get_it)
		else:
			items_bought[item.my_id_hash] = item.unlock_codex_descr_after_get_it

	for upgrade in ItemService.upgrades:
		if not upgrades_unlocked.has(upgrade.upgrade_id_hash):
			upgrades_unlocked.push_back(upgrade.upgrade_id_hash)

	for consumable in ItemService.consumables:
		if not consumables_unlocked.has(consumable.my_id_hash):
			consumables_unlocked.push_back(consumable.my_id_hash)

func unlock_all_weapons() -> void :
	for weapon in ItemService.weapons:
		if not weapons_unlocked.has(weapon.weapon_id_hash):
			weapons_unlocked.push_back(weapon.weapon_id_hash)

		if items_bought.has(weapon.my_id_hash):
			items_bought[weapon.my_id_hash] = max(items_bought[weapon.my_id_hash], weapon.unlock_codex_descr_after_get_it)
		else:
			items_bought[weapon.my_id_hash] = weapon.unlock_codex_descr_after_get_it


func unlock_all_characters() -> void :
	for character in ItemService.characters:
		if not characters_unlocked.has(character.my_id_hash):
			characters_unlocked.push_back(character.my_id_hash)

func unlock_all_enemies() -> void :
	for enemy in ItemService.entities:
		if killed_enemies.has(enemy.my_id_hash):
			killed_enemies[enemy.my_id_hash] = max(killed_enemies[enemy.my_id_hash], enemy.unlock_codex_descr_after_get_it)
		else:
			killed_enemies[enemy.my_id_hash] = enemy.unlock_codex_descr_after_get_it

func unlock_all_difficulties() -> void :
	var difficulties_unlocked_unserialized = []
	if difficulties_unlocked_serialized.size() > 0:
		for diff_serialized in difficulties_unlocked_serialized:
			var difficulty: = CharacterDifficultyInfo.new()
			difficulty.deserialize_and_merge(diff_serialized)
			for zone in difficulty.zones_difficulty_info:
				zone.max_selectable_difficulty = ProgressData.MAX_DIFFICULTY

			difficulties_unlocked_unserialized.append(difficulty)
	else:
		for character in ItemService.characters:
			var char_diff_info_to_modify: = CharacterDifficultyInfo.new(character.my_id)

			for zone in ZoneService.zones:
				if zone.unlocked_by_default:
					var zone_difficulty = ZoneDifficultyInfo.new(zone.my_id)
					zone_difficulty.max_selectable_difficulty = ProgressData.MAX_DIFFICULTY
					char_diff_info_to_modify.zones_difficulty_info.push_back(zone_difficulty)

			difficulties_unlocked_unserialized.push_back(char_diff_info_to_modify)

	difficulties_unlocked_serialized.clear()
	for diff_unserialized in difficulties_unlocked_unserialized:
		difficulties_unlocked_serialized.push_back(diff_unserialized.serialize())

func unlock_all_challenge() -> void :
	for challenge in ChallengeService.challenges:
		if not challenges_completed.has(challenge.my_id_hash):
			challenges_completed.append(challenge.my_id_hash)

func deserialize_run_state(state: Dictionary) -> Dictionary:
	var result = state.duplicate()

	if not state.has_run_state:
		return result

	result.players_data = []
	for serialized_player_data in state.players_data:
		if serialized_player_data is String:
			result.has_run_state = false
			return result
		result.players_data.push_back(PlayerRunData.new().deserialize(serialized_player_data))

	for bg in ItemService.backgrounds:
		if bg.name.to_lower() == state.current_background:
			result.current_background = bg
			break

	result.challenges_completed_this_run = []
	state.challenges_completed_this_run = Utils.convert_to_hash_array(state.challenges_completed_this_run.duplicate())

	for challenge_id in state.challenges_completed_this_run:
		for chal_data in ChallengeService.challenges:
			if chal_data.my_id_hash == challenge_id:
				result.challenges_completed_this_run.push_back(chal_data)
				break

	result.locked_shop_items = [[], [], [], []]
	for player_index in state.locked_shop_items.size():
		for locked_item in state.locked_shop_items[player_index]:
			var item_data = ItemService.get_element_safe(ItemService.items, locked_item[0].my_id)
			var weapon_data = ItemService.get_element_safe(ItemService.weapons, locked_item[0].my_id)

			# Gourmet DLC - P2W chests live outside the item registry on purpose;
			# resolve a locked chest through the chest loader or it silently
			# vanishes from the shop on reload
			if item_data == null and weapon_data == null and str(locked_item[0].my_id).begins_with("item_p2w_chest_"):
				item_data = ItemService.get_p2w_chest(int(str(locked_item[0].my_id).replace("item_p2w_chest_", "")))

			if item_data != null:
				item_data = item_data.duplicate()
				item_data.deserialize_and_merge(locked_item[0])
				result.locked_shop_items[player_index].push_back([item_data, locked_item[1]])

			if weapon_data != null:
				weapon_data = weapon_data.duplicate()
				weapon_data.deserialize_and_merge(locked_item[0])
				result.locked_shop_items[player_index].push_back([weapon_data, locked_item[1]])

	result.shop_items = [[], [], [], []]
	for player_index in state.shop_items.size():
		for shop_item in state.shop_items[player_index]:

			if shop_item[0] is String:
				continue

			var item_data = ItemService.get_element_safe(ItemService.items, shop_item[0].my_id)
			var weapon_data = ItemService.get_element_safe(ItemService.weapons, shop_item[0].my_id)

			# Gourmet DLC - P2W chests live outside the item registry; without this
			# fallback a resumed mid-shop save came back with 0 offers (reroll fixed
			# it because a fresh fill re-rolls chests)
			if item_data == null and weapon_data == null and str(shop_item[0].my_id).begins_with("item_p2w_chest_"):
				item_data = ItemService.get_p2w_chest(int(str(shop_item[0].my_id).replace("item_p2w_chest_", "")))

			if item_data != null:
				item_data = item_data.duplicate()
				item_data.deserialize_and_merge(shop_item[0])
				result.shop_items[player_index].push_back([item_data, shop_item[1]])

			if weapon_data != null:
				weapon_data = weapon_data.duplicate()
				weapon_data.deserialize_and_merge(shop_item[0])
				result.shop_items[player_index].push_back([weapon_data, shop_item[1]])

	return result


func _close_file_and_load_backups(basename: String, save_file: File, load_path: String, is_run_save: bool = false) -> void :
	save_file.close()
	_load_backups(basename, load_path, is_run_save)


func _load_backups(basename: String, previous_path: String, is_run_save: bool = false) -> void :
	if OS.get_name().begins_with("Seaven"):
		return

	if is_run_save:
		load_status = LoadStatus.CORRUPTED_RUN_SAVE
	else:
		load_status = LoadStatus.CORRUPTED_SAVE
	var backup_paths: = _collect_backup_paths(basename)
	var next_index: = 0 if previous_path == save_path else (backup_paths.find(previous_path) + 1)
	if next_index == - 1 or next_index >= backup_paths.size():
		
		if is_run_save:
			load_status = LoadStatus.CORRUPTED_RUN_SAVE
		else:
			load_status = LoadStatus.CORRUPTED_ALL_SAVES
		return
	if is_run_save:
		load_run_save_file(backup_paths[next_index])
	else:
		load_progress_save_file(backup_paths[next_index])


func save() -> void :
	var save_object_without_run_state = get_save_object()
	save_object_without_run_state.erase("current_run_state")
	var string_profile_id = String(profile_id)
	save_content("save_v3_" + string_profile_id, save_path, _tmp_path, save_object_without_run_state)
	save_content("run_v3_" + string_profile_id, run_save_path, _tmp_run_save_path, {
		"current_run_state": serialize_run_state(run_state_deserialized)
	})

func save_content(basename: String, path: String, tmp_path: String, content: Dictionary) -> void :
	if path.empty() or tmp_path.empty():
		printerr(LOG_PREFIX + "Saving failed - missing save path")
		return

	var save_file: = File.new()

	
	var error = save_file.open(tmp_path, File.WRITE)
	if error != OK:
		printerr(LOG_PREFIX + "Could not create %s. Aborting save operation. Error code: %s" % [tmp_path, error])
		return

	var sort_keys: = true
	var indent = ""
	if OS.has_feature("editor"):
		indent = "  "
	var save_json: = JSON.print(content, indent, sort_keys)
	save_file.store_string(save_json)
	save_file.close()

	var dir: = Directory.new()

	
	var _res = dir.open("user://");

	
	var do_backup: = true

	if OS.get_name() == "Windows":
		var latest_backup_path: = path.replace(basename, basename + "_01") + ".bak"
		if dir.file_exists(latest_backup_path):
			var latest_backup_file: = File.new()
			error = latest_backup_file.open(latest_backup_path, File.READ)
			if error != OK:
				printerr(LOG_PREFIX + "Could not open %s. Error code: %s" % [latest_backup_path, error])
				return
			var latest_backup_json = latest_backup_file.get_as_text()
			latest_backup_file.close()
			if latest_backup_json == save_json:
				do_backup = false

		if do_backup:
			var backup_path = path.replace(basename, basename + "_00") + ".bak"
			print(LOG_PREFIX + "Writing save to backup path %s" % backup_path)
			error = dir.copy(tmp_path, backup_path)
			if error != OK:
				printerr(LOG_PREFIX + "Could not copy save to %s. Error code: %s" % [backup_path, error])
				return

	
	print(LOG_PREFIX + "Writing save to main save path %s" % path)
	error = dir.copy(tmp_path, path)
	if error != OK:
		printerr(LOG_PREFIX + "Could not copy save to %s. Error code: %s" % [path, error])
		return

	
	error = dir.remove(tmp_path)
	if error != OK:
		printerr(LOG_PREFIX + "Could not delete %s. Error code: %s" % [tmp_path, error])
		return

	if OS.get_name() == "Windows":
		var backup_paths: = _collect_backup_paths(basename)
		if backup_paths.empty():
			printerr(LOG_PREFIX + "Could not find backup files")
			return

		
		while backup_paths.size() > MAX_BACKUP_FILES:
			var remove_path = backup_paths.pop_back()
			error = dir.remove(remove_path)
			if error != OK:
				printerr(LOG_PREFIX + "Could not remove %s. Error code: %s" % [remove_path, error])
				return
			print(LOG_PREFIX + "Removed old backup file: %s" % remove_path)

		if do_backup:
			
			for i in range(backup_paths.size(), 0, - 1):
				var previous_path = backup_paths[i - 1]
				var new_path = previous_path.replace(
					basename + "_%02d" % BackupFilenameSorter.parse_backup_number(previous_path), 
					basename + "_%02d" % (BackupFilenameSorter.parse_backup_number(previous_path) + 1)
					)
				if previous_path == new_path:
					printerr(LOG_PREFIX + "Could not increment backup file number: %s" % previous_path)
					return
				error = dir.rename(previous_path, new_path)
				if error != OK:
					printerr(LOG_PREFIX + "Could not rename %s to %s. Error code: %s" % [previous_path, new_path, error])
					return


func get_save_object() -> Dictionary:
	return {
		"zones_unlocked": zones_unlocked, 
		"characters_unlocked": characters_unlocked, 
		"upgrades_unlocked": upgrades_unlocked, 
		"consumables_unlocked": consumables_unlocked, 
		"weapons_unlocked": weapons_unlocked, 
		"items_unlocked": items_unlocked, 
		"challenges_completed": challenges_completed, 
		"systems_unlocked": systems_unlocked, 
		"difficulties_unlocked": difficulties_unlocked_serialized, 
		"inactive_mods": inactive_mods, 
		"read_announcements": read_announcements, 
		"current_run_state": serialize_run_state(run_state_deserialized), 
		"data": data, 
		"killed_enemies": killed_enemies, 
		"killed_by_enemies": killed_by_enemies, 
		"items_bought": items_bought, 
		"version": 3
	}


func serialize_run_state(state: Dictionary) -> Dictionary:
	var result = state.duplicate()

	if not state.has_run_state:
		return result

	if not "current_background" in state:
		result.has_run_state = false
		return result

	result.players_data = []
	for player_data in state.players_data:
		result.players_data.push_back(player_data.serialize())

	if state.current_background != null and state.current_background is BackgroundData:
		result.current_background = state.current_background.name.to_lower()

	result.challenges_completed_this_run = []
	for challenge in state.challenges_completed_this_run:
		result.challenges_completed_this_run.push_back(challenge.my_id_hash)

	result.locked_shop_items = [[], [], [], []]
	for player_index in state.locked_shop_items.size():
		var player_locked_items = state.locked_shop_items[player_index]
		for locked_item in player_locked_items:
			result.locked_shop_items[player_index].push_back([locked_item[0].serialize(), locked_item[1]])

	result.shop_items = [[], [], [], []]
	for player_index in state.shop_items.size():
		var player_shop_items = state.shop_items[player_index]
		for shop_item in player_shop_items:
			result.shop_items[player_index].push_back([shop_item[0].serialize(), shop_item[1]])

	return result



func _collect_backup_paths(basename: String) -> Array:
	var dir: = Directory.new()
	var paths: = []
	var save_dir_path: = save_path.get_base_dir()
	var error = dir.open(save_dir_path)
	if error != OK:
		printerr(LOG_PREFIX + "Could not open directory %s. Error code: %s" % [save_dir_path, error])
		return []
	error = dir.list_dir_begin()
	if error != OK:
		printerr(LOG_PREFIX + "Could not list directory %s. Error code: %s" % [save_dir_path, error])
		return []
	var next_filename = dir.get_next()
	while next_filename != "":
		if next_filename.begins_with(basename) and next_filename.get_extension() == "bak":
			paths.push_back("%s/%s" % [save_dir_path, next_filename])
		next_filename = dir.get_next()
	for path in paths:
		var test_number = BackupFilenameSorter.parse_backup_number(path)
		if test_number < 0:
			printerr(LOG_PREFIX + "Could not parse number from backup filename: %s" % path.get_file())
			return []
	if paths.size() <= 1:
		return paths
	paths.sort_custom(BackupFilenameSorter, "sort_ascending")
	if BackupFilenameSorter.parse_backup_number(paths.front()) > BackupFilenameSorter.parse_backup_number(paths.back()):
		printerr(LOG_PREFIX + "Backup paths not sorted correctly")
		return []
	return paths


class BackupFilenameSorter:
	static func sort_ascending(a: String, b: String) -> bool:
		var number_a = parse_backup_number(a)
		var number_b = parse_backup_number(b)
		return number_a < number_b


	static func parse_backup_number(path: String) -> int:
		var filename: = path.get_file()
		
		var components = filename.get_basename().get_basename().split("_")
		var number: = 0
		if components.size() < 3:
			printerr("Could not parse number from backup filename: %s" % filename)
			return - 1
		number = int(components[3])
		if number == 0 and components[3] != "00":
			printerr("Could not parse number from backup filename: %s" % filename)
			return - 1
		return number
