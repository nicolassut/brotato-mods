class_name PopupManager
extends Node


signal element_focused(element, player_index)
signal element_unfocused(element, player_index)
signal element_pressed(element, player_index, popup_focused)
signal shop_item_focused(shop_item, player_index)
signal shop_item_unfocused(shop_item, player_index)

var _item_popups: = [null, null, null, null]
var _elements_hovered: = [null, null, null, null]
var _elements_focused: = [null, null, null, null]
var _elements_pressed: = [null, null, null, null]
var _stat_popups: = [null, null, null, null]


func add_item_popup(item_popup: ItemPopup, player_index: int) -> void :
	_item_popups[player_index] = item_popup


func connect_inventory_container(container: InventoryContainer) -> void :
	var inventory = container._elements
	var _err = inventory.connect("element_hovered", self, "_on_element_hovered")
	_err = inventory.connect("element_unhovered", self, "_on_element_unhovered")
	_err = inventory.connect("element_focused", self, "_on_element_focused")
	_err = inventory.connect("element_unfocused", self, "_on_element_unfocused")
	_err = inventory.connect("element_pressed", self, "_on_element_pressed")


func add_stat_popup(stat_popup: StatPopup, player_index: int) -> void :
	_stat_popups[player_index] = stat_popup


func connect_stats_container(container: StatsContainer) -> void :
	var _err = container.connect("stat_focused", self, "_on_stat_focused")
	_err = container.connect("stat_unfocused", self, "_on_stat_unfocused")
	_err = container.connect("stat_hovered", self, "_on_stat_hovered")
	_err = container.connect("stat_unhovered", self, "_on_stat_unhovered")


func connect_shop_items_container(container: ShopItemsContainer) -> void :
	var _err = container.connect("shop_item_focused", self, "_on_shop_item_focused")
	_err = container.connect("shop_item_unfocused", self, "_on_shop_item_unfocused")


func reset_focus(player_index: int) -> void :
	_elements_hovered[player_index] = null
	_elements_focused[player_index] = null
	_elements_pressed[player_index] = null

	if _item_popups[player_index]:
		_item_popups[player_index].hide()


func _on_element_hovered(element: InventoryElement) -> void :
	var player_index = _get_player_index_for_control(element)
	if _elements_pressed[player_index] != null:
		return
	element.grab_focus()
	_elements_hovered[player_index] = element
	_elements_focused[player_index] = element
	if _item_popups[player_index]:
		_item_popups[player_index].display_element(element)


func _on_element_unhovered(element: InventoryElement) -> void :
	var player_index = _get_player_index_for_control(element)
	if _elements_pressed[player_index] != null:
		return
	if _elements_hovered[player_index] == element:
		_elements_hovered[player_index] = null
		_on_element_unfocused(element)


func _on_element_focused(element: InventoryElement) -> void :
	var player_index = _get_player_index_for_control(element)
	emit_signal("element_focused", element, player_index)
	if _elements_pressed[player_index] != null:
		return
	_elements_focused[player_index] = element
	if _item_popups[player_index]:
		_item_popups[player_index].display_element(element)


func _on_element_unfocused(element: InventoryElement) -> void :
	var player_index = _get_player_index_for_control(element)
	emit_signal("element_unfocused", element, player_index)
	if _elements_pressed[player_index] != null:
		return
	if _elements_focused[player_index] == element:
		_elements_focused[player_index] = null
		if _item_popups[player_index]:
			_item_popups[player_index].hide()


func _on_element_pressed(element: InventoryElement) -> void :
	var player_index = _get_player_index_for_control(element)
	var popup_focused = _item_popups[player_index] and _item_popups[player_index].will_show_buttons_when_focused(element.item)
	if popup_focused:
		_elements_hovered[player_index] = element
		_elements_focused[player_index] = element
		_elements_pressed[player_index] = element
		_item_popups[player_index].display_element(element)
		_item_popups[player_index].focus()
	emit_signal("element_pressed", element, player_index, popup_focused)


func _on_stat_focused(button: Node, title: String, value: int, player_index: int) -> void :
	var stat_popup = _stat_popups[player_index]
	if stat_popup != null:
		stat_popup.display_stat(button, title, value, player_index)


func _on_stat_unfocused(player_index: int) -> void :
	var stat_popup = _stat_popups[player_index]
	if stat_popup != null:
		stat_popup.hide()


func _on_stat_hovered(button: Node, title: String, value: int, player_index: int) -> void :
	var stat_popup = _stat_popups[player_index]
	if stat_popup != null:
		stat_popup.display_stat(button, title, value, player_index)


func _on_stat_unhovered(player_index: int) -> void :
	var stat_popup = _stat_popups[player_index]
	if stat_popup != null:
		stat_popup.hide()


func _on_shop_item_focused(shop_item: ShopItem):
	var player_index = _get_player_index_for_control(shop_item._button)
	# Gourmet DLC - the Freeloader's 8-slot shop uses the same compact cards co-op uses, so it
	# needs the same hover popup for the details those cards do not show.
	if _item_popups[player_index] and (RunData.is_coop_run or RunData.is_freeloader(player_index)):
		_item_popups[player_index].display_item_data(shop_item.item_data, shop_item._button)
	emit_signal("shop_item_focused", shop_item, player_index)


func _on_shop_item_unfocused(shop_item: ShopItem):
	var player_index = _get_player_index_for_control(shop_item._button)
	if _item_popups[player_index]:
		_item_popups[player_index].hide()
	emit_signal("shop_item_unfocused", shop_item, player_index)


func _get_player_index_for_control(control: Control) -> int:
	if not RunData.is_coop_run:
		return 0
	var player_index = FocusEmulatorSignal.get_player_index(control)
	if player_index < 0:
		push_error("Focus emulator signal not triggered")
		return 0
	return player_index
