class_name DifficultySelection
extends BaseSelection

var difficulty_selected: = false
var cancelled = false

onready var _back_button: Button = $"%BackButton"
onready var _character_panel: ItemPanelUI = $MarginContainer / VBoxContainer / DescriptionContainer / CharacterPanel
onready var _weapon_panel: ItemPanelUI = $MarginContainer / VBoxContainer / DescriptionContainer / WeaponPanel
onready var _locked_panel1: Container = $"%LockedPanel1"


func _ready() -> void :
	RunData.menu_selection_back = false
	_character_panel.visible = not RunData.is_coop_run
	if _character_panel.visible:
		_character_panel.set_data(RunData.players_data[0].current_character, 0)

	var selected_weapon = RunData.get_player_selected_weapon(0)
	_weapon_panel.visible = selected_weapon != null and not RunData.is_coop_run
	if _weapon_panel.visible:
		_weapon_panel.set_data(selected_weapon, 0)

	var diff_info = ProgressData.get_character_difficulty_info(RunData.players_data[0].current_character.my_id_hash, RunData.current_zone)
	_inventory1.focus_element_index(diff_info.difficulty_selected_value)

	for margin in [MARGIN_LEFT, MARGIN_TOP]:
		_back_button.set_focus_neighbour(margin, _back_button.get_path_to(_back_button))

	_background.texture = ZoneService.get_zone_data(RunData.current_zone).ui_background


func _process(_delta: float) -> void :
	if RunData.is_coop_run and Utils.on_nintendo_nx_or_ounce:
		
		
		if OS.get_controller_count() <= 1 and OS.get_controller_style(0) == 0:
			_manage_back()
			return


func _get_unlocked_elements(_player_index: int) -> Array:
	var unlocked_difficulties = []

	for player_data in RunData.players_data:
		var character = player_data.current_character
		for diff in ItemService.difficulties:
			var max_diff = ProgressData.get_character_difficulty_info(character.my_id_hash, RunData.current_zone).max_selectable_difficulty
			if diff.value <= max_diff or diff.unlocked_by_default or DebugService.unlock_all_difficulties:
				unlocked_difficulties.push_back(diff.my_id_hash)

	return unlocked_difficulties


func _go_back() -> void :
	RunData.menu_selection_back = true
	if RunData.some_player_has_weapon_slots():
		var selected_characters: = []
		for player_index in RunData.get_player_count():
			var player_data = RunData.players_data[player_index]
			selected_characters.push_back(player_data.current_character)
			Utils.last_elt_selected[player_index] = RunData.get_player_selected_weapon(player_index)
		RunData.revert_all_selections()
		
		for player_index in RunData.get_player_count():
			RunData.add_character(selected_characters[player_index], player_index)
		_change_scene(MenuData.weapon_selection_scene)
	else:
		for player_index in RunData.get_player_count():
			Utils.last_elt_selected[player_index] = RunData.get_player_character(player_index)
		RunData.revert_all_selections()
		_change_scene(MenuData.character_selection_scene)


func _get_all_possible_elements(_player_index: int) -> Array:
	return ItemService.difficulties


func _get_reward_type() -> int:
	return RewardType.DIFFICULTY


func _on_element_pressed(element: InventoryElement, _inventory_player_index: int) -> void :
	if difficulty_selected:
		return

	if element.is_special:
		return
	else:
		difficulty_selected = true

		if not RunData.is_coop_run:
			var current_character = RunData.get_player_character(0)
			var character_difficulty = ProgressData.get_character_difficulty_info(current_character.my_id_hash, RunData.current_zone)
			character_difficulty.difficulty_selected_value = element.item.value

		RunData.current_difficulty = element.item.value
		RunData.reset_elites_spawn()
		RunData.init_elites_spawn()
		RunData.init_events_nightmare()


		RunData.enabled_dlcs = ProgressData.get_active_dlc_ids()

	# Gourmet ecosystem - stamp the selected game mode onto every player (the
	# pre-lobby selector is global; per-player selection arrives with the lobby
	# mode shrine). Validated against the live registry + pack availability.
	var selected_mode: String = str(ProgressData.settings.get("selected_game_mode", ""))
	for mode_player_index in RunData.get_player_count():
		RunData.players_data[mode_player_index].game_mode_ids = []
		if selected_mode != "" and not GameModes.mode_by_id(selected_mode).empty():
			for available_mode in GameModes.available_modes():
				if str(available_mode["id"]) == selected_mode:
					RunData.players_data[mode_player_index].game_mode_ids.push_back(selected_mode)

		ProgressData.save()

		
		for effect in element.item.effects:
			effect.apply(0)

		
		for player_index in range(RunData.get_player_count()):
			var player_run_data = RunData.players_data[player_index]
			player_run_data.uses_ban = RunData.is_ban_mode_active
			player_run_data.remaining_ban_token = RunData.BAN_MAX_TOKEN

		
		RunData.init_bosses_spawn()

	RunData.current_run_accessibility_settings = ProgressData.settings.enemy_scaling.duplicate()
	ProgressData.load_status = LoadStatus.SAVE_OK
	ProgressData.increment_stat("run_started")
	ProgressData.data["chal_hourglass_quit_wave"] = false
	var _error = get_tree().change_scene(MenuData.game_scene)

func _on_element_focused(element: InventoryElement, inventory_player_index: int, displayPanelData: bool = true) -> void :
	var player_index = FocusEmulatorSignal.get_player_index(element)
	
	
	if player_index < 0:
		player_index = inventory_player_index

	var panel = _get_panels()[player_index]
	if element.is_random:
		if displayPanelData:
			panel._show_random()
		panel.visible = true
	else:
		panel.visible = not element.is_special

	if not panel.visible:
		_locked_panel1.visible = not element.is_random and element.is_special
		if _locked_panel1.visible:
			_locked_panel1.player_color_index = - 1
			_locked_panel1.set_element(element.item, _get_reward_type())
	else:
		_locked_panel1.visible = false

	_latest_focused_element[player_index] = element
	if panel.visible and displayPanelData:
		_display_element_panel_data(element, player_index)


func _on_BackButton_pressed():
	_manage_back()
