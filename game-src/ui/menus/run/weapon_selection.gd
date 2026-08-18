class_name WeaponSelection
extends BaseSelection


var _player_weapons: = []

onready var _back_button: Button = $"%BackButton"
onready var _character_panel: ItemPanelUI = $"%CharacterPanelUI"


func _ready() -> void :
	RunData.menu_selection_back = false;
	_player_weapons.resize(RunData.get_player_count())

	var player_index_0: = 0
	_character_panel.set_data(RunData.players_data[player_index_0].current_character, player_index_0)
	_character_panel.visible = not RunData.is_coop_run

	var inventories = _get_inventories()

	var base_columns = inventories[0].columns

	if RunData.get_player_count() > 1:
		base_columns = 16

	var columns = int(base_columns / RunData.get_player_count())

	for inventory in inventories:
		inventory.columns = columns
		inventory.queue_set_focus_neighbours()

	for margin in [MARGIN_LEFT, MARGIN_TOP]:
		_back_button.set_focus_neighbour(margin, _back_button.get_path_to(_back_button))

	for player_index in RunData.get_player_count():
		if not RunData.player_has_weapon_slots(player_index) and not RunData.player_has_starting_items(player_index):
			
			_set_selected_element(player_index)
			
			var panel = _get_panels()[player_index]
			panel.set_data(RunData.get_player_character(player_index), player_index)
			panel.show()
			
			var inventory_container = _get_inventory_containers()[player_index]
			inventory_container.rect_min_size = Vector2(panel.rect_size.x, 0)

	_background.texture = ZoneService.get_zone_data(RunData.current_zone).ui_background

	if RunData.is_coop_run and Utils.on_nintendo_nx_or_ounce:
		
		
		if OS.get_controller_count() <= 1 and OS.get_controller_style(0) == 0:
			_manage_back()
			return


func _on_BackButton_pressed():
	_manage_back()


func _process(_delta: float) -> void :
	if RunData.is_coop_run and Utils.on_nintendo_nx_or_ounce:
		
		
		if OS.get_controller_count() <= 1 and OS.get_controller_style(0) == 0:
			_manage_back()
			return


func _input(event: InputEvent) -> void :
	if not RunData.is_coop_run:
		return

	
	for player_index in RunData.get_player_count():
		if not RunData.player_has_weapon_slots(player_index):
			
			continue
		var panel = _get_panels()[player_index]
		if Utils.is_player_action_pressed(event, player_index, CoopShowCharacterHint.UI_ACTION):
			
			panel.set_data(RunData.get_player_character(player_index), player_index)
			panel.selected = false
		elif Utils.is_player_action_released(event, player_index, CoopShowCharacterHint.UI_ACTION) and _displayed_panel_data_element[player_index] != null:
			
			_display_element_panel_data(_displayed_panel_data_element[player_index], player_index)
			panel.selected = _has_player_selected[player_index]


func _get_unlocked_elements(player_index: int) -> Array:
	var elements_unlocked = []
	var starting_weapons = ItemService.get_ordered_starting_weapons(RunData.get_player_character(player_index).starting_weapons)

	for weapon in starting_weapons:
		if ProgressData.weapons_unlocked.has(weapon.weapon_id_hash):
			elements_unlocked.push_back(weapon.my_id_hash)

	var starting_items = ItemService.get_ordered_starting_items(RunData.get_player_character(player_index).starting_items)
	for item in starting_items:
		if ProgressData.items_unlocked.has(item.my_id_hash):
			elements_unlocked.push_back(item.my_id_hash)

	return elements_unlocked


func _go_back() -> void :
	for player_index in RunData.get_player_count():
		var character = RunData.get_player_character(player_index)
		Utils.last_elt_selected[player_index] = character
		RunData.remove_character(character, player_index)
	RunData.revert_all_selections()
	# Gourmet ecosystem - a flow begun at the Hub's shuttle backs out to the
	# Hub, not into character select (HUB_PLAN flow law)
	if MenuData.run_flow_from_lobby:
		MenuData.run_flow_from_lobby = false
		RunData.menu_selection_back = false
		_change_scene(MenuData.lobby_scene)
		return
	RunData.menu_selection_back = true

	_change_scene(MenuData.character_selection_scene)


func _get_all_possible_elements(player_index: int) -> Array:
	var character_data = RunData.get_player_character(player_index)
	var elements = []
	elements.append_array(ItemService.get_ordered_starting_weapons(character_data.starting_weapons))
	elements.append_array(ItemService.get_ordered_starting_items(character_data.starting_items))
	return elements


func _get_reward_type() -> int:
	return RewardType.STARTING_WEAPON


func _on_element_pressed(element: InventoryElement, inventory_player_index: int) -> void :
	if element.is_random:
		var available_elements: = []
		for element in displayed_elements[inventory_player_index]:
			if not element.is_locked:
				available_elements.push_back(element)
		var weapon = Utils.get_rand_element(available_elements)
		_player_weapons[inventory_player_index] = weapon
	elif element.is_special:
		return
	else:
		_player_weapons[inventory_player_index] = element.item

	_set_selected_element(inventory_player_index)


func _on_selections_completed() -> void :
	for player_index in _player_weapons.size():
		var element = _player_weapons[player_index]
		
		if element != null:
			if element is WeaponData:
				var _weapon = RunData.add_weapon(element, player_index, true)
			elif element is ItemData:
				var _item = RunData.add_item(element, player_index, true)

	RunData.add_starting_items_and_weapons()
	_change_scene(MenuData.difficulty_selection_scene)


func _on_element_focused(element: InventoryElement, inventory_player_index: int, displayPanelData: bool = true) -> void :
	._on_element_focused(element, inventory_player_index, displayPanelData)

	var player_index = FocusEmulatorSignal.get_player_index(element)
	if player_index >= 0:
		_player_weapons[player_index] = null
		_clear_selected_element(player_index)


func _is_locked_elements_displayed() -> bool:
	return false


func _get_inventories() -> Array:
	
	var inventory_containers: = _get_inventory_containers()
	var inventories: = []
	for container in inventory_containers:
		inventories.push_back(container.inventory)
	return inventories
