class_name CharacterSelection
extends BaseSelection

var _player_characters: = [null, null, null, null]

var __restore_player0_element = null

onready var _back_button: Button = $"%BackButton"
onready var _run_options_panel: PanelContainer = $"%RunOptionsPanel"
onready var _endless_button: CheckButton = $"%EndlessButton"
onready var _coop_button: CheckButton = $"%CoopButton"
onready var _info_panel: PanelContainer = $"%InfoPanel"
onready var _coop_join_instructions: Control = $"%CoopJoinInstructions"
onready var _inventories: Control = $"%Inventories"
onready var _zone_selection_button: OptionButton = $"%ZoneSelectionButton"

onready var _run_options_panel_content: Container = $"%RunOptionsPanel/MarginContainer/VBoxContainer/VBoxContainer"
onready var _coop_join_panel1: Container = $"%CoopJoinPanel1"
onready var _coop_join_panel2: Container = $"%CoopJoinPanel2"
onready var _coop_join_panel3: Container = $"%CoopJoinPanel3"
onready var _coop_join_panel4: Container = $"%CoopJoinPanel4"
onready var _locked_panel1: Container = $"%LockedPanel1"
onready var _locked_panel2: Container = $"%LockedPanel2"
onready var _locked_panel3: Container = $"%LockedPanel3"
onready var _locked_panel4: Container = $"%LockedPanel4"
onready var _legend_tier: Container = $"%legend_tier"
onready var _unlockall_icon: TextureRect = $"%unlockall_icon"
onready var _popup_manager: PopupManager = $PopupManager
onready var _ui_random_zone_background: TextureRect = $"%ui_random_zone_background"

var __need_controller_applet_timer = - 1
var _mode_selection_button: OptionButton


func _ready() -> void :
	var selected_zone = ProgressData.settings.zone_selected

	if selected_zone >= ZoneService.zones.size():
		selected_zone = 0
	
	
	_zone_selection_button.selected = selected_zone

	var first_run_option = _zone_selection_button
	if _zone_selection_button.get_item_count() <= 1:
		_zone_selection_button.hide()
		first_run_option = _endless_button

	_zone_selection_button.add_item(tr("RANDOM"), ZoneService.zones.size() + 1)
	if (ProgressData.settings.zone_is_random):
		selected_zone = ZoneService.zones.size()
		_zone_selection_button.selected = ZoneService.zones.size()

	for margin in [MARGIN_LEFT, MARGIN_TOP]:
		_back_button.set_focus_neighbour(margin, _back_button.get_path_to(_back_button))
	for margin in [MARGIN_RIGHT, MARGIN_BOTTOM]:
		_back_button.set_focus_neighbour(margin, _back_button.get_path_to(first_run_option))

	_on_ZoneSelectionButton_item_selected(selected_zone)

	var max_players = CoopService.get_max_players()
	_coop_join_panel1.visible = 1 <= max_players
	_coop_join_panel2.visible = 2 <= max_players
	_coop_join_panel3.visible = 3 <= max_players
	_coop_join_panel4.visible = 4 <= max_players
	init_coop_service()

	
	if ProgressData.is_colors_tier_by_default():
		_legend_tier.queue_free()
	else:
		for indx in _legend_tier.get_child_count():
			var stylebox_color = _legend_tier.get_child(indx).get_stylebox("panel").duplicate()
			if indx == 0:
				stylebox_color.bg_color = Color(ProgressData.settings.tier_0_color)
				stylebox_color.bg_color.a = 0.3
			else:
				ItemService.change_inventory_element_stylebox_from_tier(stylebox_color, indx, 0.3)
			_legend_tier.get_child(indx).add_stylebox_override("panel", stylebox_color)

	_unlockall_icon.visible = ProgressData.is_unlock_all_save()

	RunData.try_unlock_nightmare()


func init_coop_service() -> void :

	_init_play_mode_ui()

	var _e = _coop_button.connect("coop_initialized", self, "_on_coop_initialized", [false])
	_e = CoopService.connect("connected_players_updated", self, "_on_connected_players_updated", [false])
	_e = CoopService.connect("connection_progress_updated", self, "_on_connection_progress_updated")

	
	
	
	if RunData.menu_selection_back:
		current_mode = RunData.play_mode
		_play_mode_init(RunData.play_mode, true)
	elif Utils.on_nintendo_nx_or_ounce:
		var playMode = RunData.PlayMode.SOLO;
		if Utils.on_nintendo_ounce:
			if Streamplay.playing():
				playMode = RunData.PlayMode.STREAMPLAY_LOCAL if not Streamplay.is_online() else RunData.PlayMode.STREAMPLAY_INTERNET
		_play_mode_init(playMode, true)
	else:
		_play_mode_init(RunData.play_mode, false)
	RunData.menu_selection_back = false
	

	_update_character_selection_player_count_ui()
	_coop_button.init()
	_run_options_panel.init()
	CoopService.set_process_input(true)


func _init_play_mode_ui() -> void :
	if Utils.on_nintendo_ounce or OS_Seaven.is_in_editor_mode():
		_coop_button.visible = OS_Seaven.is_in_editor_mode()
		if _mode_selection_button == null:
			_mode_selection_button = OptionButton.new()
			_run_options_panel_content.add_child(_mode_selection_button);
			_mode_selection_button.connect("item_selected", self, "_on_ModeSelectionButton_item_selected")
		_mode_selection_button.visible = true
		_mode_selection_button.clear()
		_mode_selection_button.add_item(tr("SOLO"), RunData.PlayMode.SOLO)
		_mode_selection_button.add_item(tr("COOP"), RunData.PlayMode.COOP)
		_mode_selection_button.add_item(tr("GAMESHARE_LOCAL"), RunData.PlayMode.STREAMPLAY_LOCAL)
	else:
		_coop_button.visible = true
		if _mode_selection_button != null:
			_mode_selection_button.visible = false


func _exit_tree() -> void :
	CoopService.set_process_input(false)


func _input(event: InputEvent) -> void :
	var focus_owner = get_focus_owner()
	if RunData.is_coop_run and RunData.get_player_count() == 0 and focus_owner == null and event.is_action_pressed("ui_up"):
		
		_coop_button.call_deferred("grab_focus")


func _init_players() -> void :
	if not RunData.is_coop_run:
		._init_players()
		return
	
	_on_connected_players_updated(CoopService.connected_players, true)


func _go_back() -> void :
	RunData.reload_music = false
	# Gourmet ecosystem - back returns to the lobby it came from
	if bool(ProgressData.settings.get("skip_lobby", false)):
		var _error = get_tree().change_scene(MenuData.title_screen_scene)
	else:
		var _error = get_tree().change_scene(MenuData.lobby_scene)
	ProgressData.end_activity(false)


func _get_unlocked_elements(player_index: int) -> Array:
	if DebugService.unlock_all_chars:
		var all_unlocked: = []
		for element in _get_all_possible_elements(player_index):
			all_unlocked.push_back(element.my_id_hash)
		return all_unlocked

	return ProgressData.characters_unlocked


func _get_all_possible_elements(_player_index: int) -> Array:
	
	var elements: = []
	for character in ItemService.characters:
		var element = character.duplicate()
		var diff_info = ProgressData.get_character_difficulty_info(element.my_id_hash, RunData.current_zone)
		if diff_info.max_difficulty_beaten.difficulty_value == 0:
			element.tier = Tier.DANGER_0
		elif diff_info.max_difficulty_beaten.difficulty_value > 0:
			element.tier = diff_info.max_difficulty_beaten.difficulty_value
		elements.push_back(element)
	return elements


func _get_reward_type() -> int:
	return RewardType.CHARACTER


func _on_element_pressed(element: InventoryElement, _inventory_player_index: int) -> void :
	var inventory_player_index = FocusEmulatorSignal.get_player_index(element)
	if inventory_player_index < 0:
		return

	if element.is_random:
		var available_elements: = []
		
		for element in displayed_elements[0]:
			if not element.is_locked:
				available_elements.push_back(element)
		var character = Utils.get_rand_element(available_elements)
		_player_characters[inventory_player_index] = character
	elif element.is_special:
		return
	else:
		_player_characters[inventory_player_index] = null
		_on_element_focused(element, _inventory_player_index)
		_player_characters[inventory_player_index] = element.item

	_set_selected_element(inventory_player_index)


func _on_selections_completed() -> void :
	if (ProgressData.settings.zone_is_random):
		_setup_zone(ProgressData.settings.zone_selected)
	for player_index in RunData.get_player_count():
		var character = _player_characters[player_index]
		RunData.add_character(character, player_index)
	if Utils.on_nintendo_nx_or_ounce and RunData.is_coop_run:
		OS.set_max_controller_count(RunData.get_player_count())
	if RunData.some_player_has_weapon_slots():
		_change_scene(MenuData.weapon_selection_scene)
	else:
		RunData.add_starting_items_and_weapons()
		_change_scene(MenuData.difficulty_selection_scene)

export (Array, int) var ps_device_colors: = [
	4278767051, 
	4290910731, 
	4281319940, 
	4290953728
]

func set_controller_colors() -> void :
	if Utils.on_playstation:
		for player_index in CoopService.get_max_players():
			var device = CoopService.get_remapped_player_device(player_index)
			if device == CoopService.GAMEPAD_REMAPPED_DEVICE_ID:
				device = 0
			if device >= 0 and device < 4:
				OS.set_controller_color(device, ps_device_colors[player_index])

var last_mode: int = - 1
var current_mode: int = - 1

func _on_coop_initialized(active: bool, initialize: bool) -> void :
	_play_mode_init(RunData.PlayMode.COOP if active else RunData.PlayMode.SOLO, initialize)


func _play_mode_init(mode: int, initialize: bool) -> void :
	

	
	
	

	last_mode = current_mode
	current_mode = mode
	RunData.play_mode = current_mode;
	var changed = (current_mode != last_mode)

	print("[CharacterSelection] _play_mode_init(current_mode:%s, last_mode:%s, changed:%s)" % [current_mode, last_mode, changed])

	if Utils.on_nintendo_ounce:
		RunData.is_streamplay_run = current_mode == RunData.PlayMode.STREAMPLAY_LOCAL or current_mode == RunData.PlayMode.STREAMPLAY_INTERNET
	else:
		RunData.is_streamplay_run = false

	RunData.set_coop_run(current_mode == RunData.PlayMode.COOP or RunData.is_streamplay_run)

	if Utils.on_nintendo_ounce:
		if _mode_selection_button != null:
			_mode_selection_button.selected = current_mode
	else:
		_coop_button.pressed = RunData.is_coop_run

	if not RunData.is_streamplay_run and (last_mode == RunData.PlayMode.STREAMPLAY_LOCAL or last_mode == RunData.PlayMode.STREAMPLAY_INTERNET):
		Streamplay.stop()
	

	CoopService.listening_for_inputs = RunData.is_coop_run
	_info_panel.visible = false
	_coop_join_instructions.visible = RunData.is_coop_run
	_inventories.visible = not RunData.is_coop_run
	__restore_player0_element = null

	if not initialize:
		CoopService.clear_coop_players()

		var player_count = 0 if RunData.is_coop_run else 1
		_update_player_count(player_count, initialize)

		if RunData.is_coop_run:
			
			var focus_owner = get_focus_owner()
			if focus_owner != null:
				focus_owner.release_focus()
		else:
			_get_inventories()[0].focus_element_index(0)

	
	if Utils.on_nintendo_nx_or_ounce and changed:
		if RunData.is_coop_run:
			if not RunData.is_streamplay_run:
				print("[CharacterSelection] Coop")
				print("[CharacterSelection] max controller ", CoopService.get_max_players())
				OS.set_min_controller_count(2)
				OS.set_max_controller_count(CoopService.get_max_players())
				OS.set_controller_color(0, 4293786785)
				OS.set_controller_color(1, 4287081970)
				OS.set_controller_color(2, 4288806057)
				OS.set_controller_color(3, 4287623420)
				set_process(true)
				__need_controller_applet_timer = 2
			else:
				var guestCount = 0
				if not Streamplay.playing():
					var streamPlayConfig = {"guestCountMin": 1, "guestCountMax": 3};
					guestCount = Streamplay.start(mode == RunData.PlayMode.STREAMPLAY_INTERNET, streamPlayConfig);
				else:
					guestCount = Streamplay.guests()
				if guestCount > 0:
					print("[CharacterSelection] Streamplay start width %s guests" % guestCount)
					CoopService.clear_coop_players()
					for i in guestCount + 1:
						print("guest %s " % i)
						var remapped = i
						if remapped == 0:
							remapped = CoopService.GAMEPAD_REMAPPED_DEVICE_ID
						CoopService._add_player(remapped, CoopService.PlayerType.GAMEPAD_SWITCH)
					
					
					set_process(true)
					
				else:
					print("[CharacterSelection] Rollback")
					
					_play_mode_init(RunData.PlayMode.SOLO, false);

		else:
			if OS.get_max_controller_count() != 1:
				print("[CharacterSelection] max controller 1")
				OS.set_max_controller_count(1)
				OS.show_controller_applet(1, 1)
				set_process(false)

	if RunData.is_coop_run:
		set_controller_colors()

	

	for panel in _get_panels():
		panel._small(RunData.is_coop_run)

	if ProgressData.settings.zone_is_random:
		_inventory1.update_elements_color( - 1)


func _on_ModeSelectionButton_item_selected(index: int) -> void :
	yield(get_tree().create_timer(0.1), "timeout")
	_play_mode_init(index, false)



func _on_connected_players_updated(connected_players: Array, initialize: bool) -> void :
	var player_count = connected_players.size()
	var is_new_player = player_count > RunData.get_player_count()
	_update_player_count(player_count, initialize)

	if player_count > 0 and is_new_player:
		var new_player_index = player_count - 1
		var element = _get_inventories()[0].get_child(0)
		Utils.focus_player_control(element, new_player_index)

	set_controller_colors()



func _on_connection_progress_updated(progress_values: Array) -> void :
	for coop_join_panel in _get_coop_join_panels():
		coop_join_panel.update_indicators(CoopService.connected_players, progress_values)


func _update_player_count(count: int, initialize: bool) -> void :
	RunData.set_player_count(count)
	_set_base_ui_player_count(count, RunData.is_coop_run, initialize)
	if not initialize:
		
		_update_character_selection_player_count_ui()



func _update_character_selection_player_count_ui() -> void :
	var player_count = RunData.get_player_count()
	_coop_join_instructions.visible = RunData.is_coop_run and player_count == 0
	_inventories.visible = player_count > 0
	if player_count == 0:
		__restore_player0_element = null
	var coop_join_panels: = _get_coop_join_panels()
	var locked_panels: = _get_locked_panels()
	for player_index in CoopService.get_max_players():
		var is_player_connected = player_index < player_count
		var coop_join_panel = coop_join_panels[player_index]
		coop_join_panel.visible = RunData.is_coop_run and not is_player_connected
		coop_join_panel.update_indicators(CoopService.connected_players, CoopService.connection_progress)
		var locked_panel = locked_panels[player_index]
		if not is_player_connected:
			
			locked_panel.hide()


func _get_coop_join_panels() -> Array:
	var ret = [_coop_join_panel1, _coop_join_panel2, _coop_join_panel3, _coop_join_panel4]
	ret.resize(CoopService.get_max_players())
	return ret


func _get_locked_panels() -> Array:
	var ret = [_locked_panel1, _locked_panel2, _locked_panel3, _locked_panel4]
	ret.resize(CoopService.get_max_players())
	return ret


func _on_element_focused(element: InventoryElement, inventory_player_index: int, displayPanelData: bool = true) -> void :
	var player_index = FocusEmulatorSignal.get_player_index(element)
	if player_index < 0:
		push_error("[CharacterSelection] Focus emulator signal not triggered")
		return

	if player_index == 0 and __restore_player0_element != null:
		if __restore_player0_element.is_visible_in_tree():
			Utils.call_deferred("focus_player_control", __restore_player0_element, player_index)
		__restore_player0_element = null
		return

	var character = element.item
	if character != null:
		RunData.add_item(character, player_index)

	._on_element_focused(element, inventory_player_index, _player_characters[player_index] == null)

	if player_index >= 0:
		if _player_characters[player_index] == null:
			_clear_selected_element(player_index)

		
		CoopService.listening_for_inputs = RunData.is_coop_run

	var locked_panel = _get_locked_panels()[player_index]
	locked_panel.visible = not element.is_random and element.is_special
	if locked_panel.visible:
		locked_panel.player_color_index = player_index if RunData.is_coop_run else - 1
		locked_panel.set_element(element.item, _get_reward_type())

	_info_panel.visible = not RunData.is_coop_run and not element.is_random
	if _info_panel.visible and _player_characters[player_index] == null and player_index >= 0:
		update_info_panel(element.item)
	if character != null:
		RunData.remove_item(character, player_index)


func _clear_selected_element(player_index: int) -> void :
	._clear_selected_element(player_index)
	_player_characters[player_index] = null


func reload_info_panel() -> void :

	if _info_panel.character_currently_displayed == "":
		return

	var item_info

	for element in _get_all_possible_elements(0):
		if element.my_id == _info_panel.character_currently_displayed:
			item_info = element
			break

	if item_info:
		update_info_panel(item_info)
		var panel = _get_panels()[0]
		panel.set_data(item_info, 0)


func update_info_panel(item_info: ItemParentData) -> void :
	assert (item_info.my_id_hash != null and item_info.my_id_hash != Keys.empty_hash)
	if ProgressData.settings.zone_is_random:
		_info_panel.set_element( - 1)
	else:
		_info_panel.set_element(item_info.my_id_hash)

	var stylebox_color = _info_panel.get_stylebox("panel").duplicate()
	ItemService.change_panel_stylebox_from_tier(stylebox_color, item_info.tier, false, get_node_or_null("%frame_infopanel"))
	_info_panel.add_stylebox_override("panel", stylebox_color)


func _on_ZoneSelectionButton_item_selected(index: int) -> void :
	var zonesCount = ZoneService.zones.size()
	if (index == zonesCount):
		ProgressData.settings.zone_is_random = true
		RunData.reset_background()
		_background.texture = _ui_random_zone_background.texture
		ProgressData.settings.zone_selected = rand_range(0, zonesCount)
		_inventory1.update_elements_color( - 1)
		reload_info_panel()
		_panel1._update_bg()
		_panel2._update_bg()
		_panel3._update_bg()
		_panel4._update_bg()
	else:
		ProgressData.settings.zone_is_random = false
		_setup_zone(index)

func _setup_zone(index: int) -> void :
	RunData.current_zone = _zone_selection_button.get_item_id(index)
	ProgressData.settings.zone_selected = RunData.current_zone
	RunData.reset_background()
	_background.texture = ZoneService.get_zone_data(RunData.current_zone).ui_background
	_inventory1.update_elements_color(RunData.current_zone)
	reload_info_panel()
	_panel1._update_bg()
	_panel2._update_bg()
	_panel3._update_bg()
	_panel4._update_bg()


func _on_BackButton_pressed():
	if RunData.is_streamplay_run:
		Streamplay.stop()
	if (ProgressData.settings.zone_is_random):
		_zone_selection_button.selected = ZoneService.zones.size()
		_on_ZoneSelectionButton_item_selected(_zone_selection_button.selected)
	ProgressData.save()
	_manage_back()


func _on_CoopButton_focus_entered():
	var player_index = FocusEmulatorSignal.get_player_index(_coop_button)
	if player_index < 0:
		push_error("[CharacterSelection] Focus emulator signal not triggered")
		return
	assert (player_index == 0, "[CharacterSelection] only player 0 should be able to focus run options")
	__restore_player0_element = _latest_focused_element[player_index]


func _process(_delta: float) -> void :
	if Utils.on_nintendo_nx_or_ounce:
		
		match current_mode:
			RunData.PlayMode.COOP:
				
				
				if __need_controller_applet_timer == - 1:
					if OS.get_controller_count() <= 1:
						_play_mode_init(RunData.PlayMode.SOLO, false)
						
						
						
						
						return
				var num_connected_players: = len(CoopService.connected_players)
				if OS.get_controller_count() != num_connected_players:
					if __need_controller_applet_timer >= 0:
						__need_controller_applet_timer -= 1
						if __need_controller_applet_timer < 0:
							__need_controller_applet_timer = - 1
							print("[CharacterSelection] show controller applet in process")
							OS.show_controller_applet(2, CoopService.get_max_players())
							
							
						return
					print("[CharacterSelection] Controller count different from player count, add auto players " + str(OS.get_controller_count()) + " " + str(len(CoopService.connected_players)))
					if OS.get_controller_count() > num_connected_players:
						for i in OS.get_controller_count():
							var remapped = i
							if remapped == 0:
								remapped = CoopService.GAMEPAD_REMAPPED_DEVICE_ID
							CoopService._add_player(remapped, CoopService.PlayerType.GAMEPAD_SWITCH)
							
							
					else:
						for i in range(OS.get_controller_count(), num_connected_players):
							var remapped = i
							if remapped == 0:
								remapped = CoopService.GAMEPAD_REMAPPED_DEVICE_ID
							CoopService._remove_player(remapped)
							
							
			
			
