class_name CoopShop
extends BaseShop


var _player_container1: CoopShopPlayerContainer
var _player_container2: CoopShopPlayerContainer
var _player_container3: CoopShopPlayerContainer
var _player_container4: CoopShopPlayerContainer

var _stat_popup1: StatPopup
var _stat_popup2: StatPopup
var _stat_popup3: StatPopup
var _stat_popup4: StatPopup


func _ready():
	_find_nodes()

	var player_count = RunData.get_player_count()

	for i in CoopService.UI_MAX_PLAYER_COUNT:
		_get_coop_player_container(i).visible = i < player_count

	for player_index in player_count:
		var player_container = _get_coop_player_container(player_index)
		var stat_popup = _get_stat_popup(player_index)
		stat_popup.parent_node_path = player_container.carousel.get_path()
		_popup_manager.add_stat_popup(stat_popup, player_index)
		_popup_manager.connect_stats_container(player_container.primary_stats_container)
		_popup_manager.connect_stats_container(player_container.secondary_stats_container)
		_popup_manager.connect_shop_items_container(player_container.shop_items_container)

	_update_stats()


func on_paused() -> void :
	.on_paused()
	var _error = InputService.connect("game_lost_focus", self, "_on_game_lost_focus")
	for player_index in RunData.get_player_count():
		
		Utils.get_focus_emulator(player_index).visible = false


func on_unpaused() -> void :
	.on_unpaused()
	var _error = InputService.disconnect("game_lost_focus", self, "_on_game_lost_focus")
	for player_index in RunData.get_player_count():
		Utils.get_focus_emulator(player_index).visible = true

func _on_game_lost_focus() -> void :
	_pause_menu.on_game_lost_focus()

func _on_shop_item_focused(shop_item: ShopItem, player_index: int) -> void :
	._on_shop_item_focused(shop_item, player_index)
	_get_coop_player_container(player_index).on_show_shop_item_popup(shop_item)


func _on_shop_item_unfocused(shop_item: ShopItem, player_index: int) -> void :
	._on_shop_item_unfocused(shop_item, player_index)
	_get_coop_player_container(player_index).on_hide_shop_item_popup(shop_item)


func _on_element_focused(element: InventoryElement, player_index: int) -> void :
	._on_element_focused(element, player_index)
	_get_coop_player_container(player_index).on_show_inventory_popup(element)


func _on_element_unfocused(element: InventoryElement, player_index: int) -> void :
	._on_element_unfocused(element, player_index)
	_get_coop_player_container(player_index).on_hide_inventory_popup(element)


func _on_element_pressed(element: InventoryElement, player_index: int, popup_focused: bool) -> void :
	._on_element_pressed(element, player_index, popup_focused)
	if popup_focused:
		_get_coop_player_container(player_index).on_show_focused_inventory_popup()


func _on_item_combine_button_pressed(weapon_data: WeaponData, player_index: int) -> void :
	._on_item_combine_button_pressed(weapon_data, player_index)
	_get_coop_player_container(player_index).on_hide_focused_inventory_popup()


func _on_item_discard_button_pressed(weapon_data: ItemParentData, player_index: int) -> void :
	._on_item_discard_button_pressed(weapon_data, player_index)
	_get_coop_player_container(player_index).on_hide_focused_inventory_popup()


func _on_item_cancel_button_pressed(item_data: ItemParentData, player_index: int) -> void :
	._on_item_cancel_button_pressed(item_data, player_index)
	_get_coop_player_container(player_index).on_hide_focused_inventory_popup()


func _get_coop_player_container(player_index: int) -> CoopShopPlayerContainer:
	_find_nodes()
	return [_player_container1, _player_container2, _player_container3, _player_container4][player_index]


func _get_stat_popup(player_index: int) -> StatPopup:
	return [_stat_popup1, _stat_popup2, _stat_popup3, _stat_popup4][player_index]



func _find_nodes() -> void :
	if _player_container1 != null:
		return
	_player_container1 = get_node("%CoopShopPlayerContainer1")
	_player_container2 = get_node("%CoopShopPlayerContainer2")
	_player_container3 = get_node("%CoopShopPlayerContainer3")
	_player_container4 = get_node("%CoopShopPlayerContainer4")
	_stat_popup1 = get_node("%StatPopup1")
	_stat_popup2 = get_node("%StatPopup2")
	_stat_popup3 = get_node("%StatPopup3")
	_stat_popup4 = get_node("%StatPopup4")


func _update_stats(player_index: = - 1) -> void :
	if player_index >= 0:
		_get_coop_player_container(player_index).update_stats()
	else:
		for i in RunData.get_player_count():
			_get_coop_player_container(i).update_stats()


func _get_shop_items_container(player_index: int) -> ShopItemsContainer:
	return _get_coop_player_container(player_index).shop_items_container


func _get_gear_container(player_index: int) -> PlayerGearContainer:
	return _get_coop_player_container(player_index).player_gear_container


func _get_gold_label(player_index: int) -> Control:
	return _get_coop_player_container(player_index).gold_label


func _get_checkmark(player_index: int) -> Control:
	return _get_coop_player_container(player_index).checkmark_group


func _get_reroll_button(player_index: int) -> Control:
	return _get_coop_player_container(player_index).reroll_button


func _get_go_button(player_index: int) -> Control:
	return _get_coop_player_container(player_index).go_button


func _get_item_popup(player_index: int) -> ItemPopup:
	return _get_coop_player_container(player_index).item_popup


func _get_elite_info_panel(player_index: int) -> EliteInfoPanel:
	return _get_coop_player_container(player_index).elite_info_panel


func _get_elite_container(player_index: int) -> Container:
	return _get_coop_player_container(player_index).elite_container
