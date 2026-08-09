class_name CoopShopPlayerContainer
extends Container


export (int) var player_index: = 0 setget _set_player_index
func _set_player_index(v: int) -> void :
	player_index = v
	if not is_inside_tree() or player_index >= RunData.get_player_count():
		return
	carousel.player_index = player_index
	player_gear_container.player_index = player_index
	shop_items_container.player_index = player_index
	_toggle_popup_hint.player_index = player_index
	for stats_container in [primary_stats_container, secondary_stats_container]:
		stats_container.update_player_stats(player_index)
	item_popup.player_index = player_index
	var player_color = CoopService.get_player_color(player_index)
	gold_icon.modulate = player_color
	gold_label.add_color_override("font_color", player_color)
	reroll_button.gold_icon.modulate = player_color
	_endless_button.visible = player_index == 0 and RunData.should_show_endless_button()
	_update_stylebox()


onready var margin_container = $MarginContainer
onready var carousel = $"%Carousel"
onready var gold_icon = $"%GoldIcon"
onready var gold_label = $"%GoldLabel"
onready var reroll_button = $"%RerollButton"
onready var checkmark_group = $"%CheckmarkGroup"
onready var go_button = $"%GoButton"
onready var item_popup = $"%ItemPopup"
onready var player_gear_container = $"%PlayerGearContainer"
onready var shop_items_container: ShopItemsContainer = $"%ShopItemsContainer"
onready var elite_info_panel: EliteInfoPanel = $"%EliteInfoPanel"
onready var elite_container: Container = $"%EliteContainer"
onready var primary_stats_container: StatsContainer = $"%PrimaryStatsContainer"
onready var secondary_stats_container: StatsContainer = $"%SecondaryStatsContainer"

onready var _popup_dim_screen = $"%PopupDimScreen"
onready var _endless_button = $"%EndlessButton"
onready var _toggle_popup_hint: Container = $"%TogglePopupHint"


var _resume_shop_control_focus = null


func _ready():
	
	_set_player_index(player_index)
	
	if RunData.get_player_count() == 2:
		margin_container.add_constant_override("margin_left", 75)
		margin_container.add_constant_override("margin_right", 75)
	item_popup.set_synergies_visible(_should_show_synergies())
	_set_focus_neighbours()
	item_popup.connect("popup_toggled", self, "on_popup_toggled")

	# Gourmet DLC - Wildcard: default the coop stat sheet to the Rules view each shop (no-op for
	# other characters). In coop the sheet is a per-wave, on-demand carousel page, so the
	# one-time default in StatsContainer._ensure_rules_ui is not enough by itself.
	for stats_container in [primary_stats_container, secondary_stats_container]:
		stats_container.open_rules_default(player_index)


func update_stats() -> void :
	primary_stats_container.update_player_stats(player_index)
	secondary_stats_container.update_player_stats(player_index)


func on_show_shop_item_popup(shop_item: ShopItem) -> void :
	item_popup.shop_item = shop_item
	item_popup.set_synergies_visible(true)
	item_popup.show_shop_hints(shop_item)


func on_hide_shop_item_popup(_shop_item: ShopItem) -> void :
	item_popup.shop_item = null
	item_popup.set_synergies_visible(_should_show_synergies())
	item_popup.hide_hints()


func on_show_inventory_popup(element: InventoryElement) -> void :
	item_popup.set_synergies_visible(_should_show_synergies())
	
	item_popup.show_inventory_hint(element.item)


func on_hide_inventory_popup(_element: InventoryElement) -> void :
	item_popup.hide_hints()


func on_show_focused_inventory_popup() -> void :
	item_popup.set_synergies_visible(true)
	item_popup.hide_hints()
	_popup_dim_screen.show()


func on_hide_focused_inventory_popup() -> void :
	
	
	_popup_dim_screen.hide()


func _should_show_synergies() -> bool:
	
	return RunData.get_player_count() <= 3


func _update_stylebox() -> void :
	var stylebox = get_stylebox("panel").duplicate()
	CoopService.change_stylebox_for_player(stylebox, player_index)
	add_stylebox_override("panel", stylebox)


func _on_Carousel_index_changed(index: int) -> void :
	_set_focus_neighbours()
	if _popup_dim_screen.visible:
		
		item_popup.cancel()
	
	
	call_deferred("_set_focus_after_carousel_index_change", index)


func _set_focus_after_carousel_index_change(index: int) -> void :
	var focused_control = Utils.get_player_focused_control(self, player_index)
	if focused_control and carousel.get_content_element(0).is_a_parent_of(focused_control):
		_resume_shop_control_focus = focused_control
	if index == 0:
		
		if _resume_shop_control_focus:
			Utils.focus_player_control(_resume_shop_control_focus, player_index)

	else:
		
		if carousel.are_trigger_buttons_active():
			Utils.focus_player_control(go_button, player_index)


func _on_EndlessButton_toggled(button_pressed: bool) -> void :
	RunData.is_endless_run = button_pressed


func _set_focus_neighbours() -> void :
	for margin in [MARGIN_TOP, MARGIN_TOP, MARGIN_LEFT, MARGIN_RIGHT]:
		carousel.arrow_left.set_focus_neighbour(margin, NodePath(""))
		carousel.arrow_right.set_focus_neighbour(margin, NodePath(""))
		go_button.set_focus_neighbour(margin, NodePath(""))

	if carousel.index == 0:
		go_button.set_focus_neighbour(MARGIN_BOTTOM, NodePath(""))
		carousel.arrow_left.set_focus_neighbour(MARGIN_TOP, NodePath(""))
		carousel.arrow_right.set_focus_neighbour(MARGIN_TOP, NodePath(""))

	elif carousel.index == 1:
		if carousel.are_trigger_buttons_active():
			primary_stats_container.first_primary_stat.focus_neighbour_top = primary_stats_container.first_primary_stat.get_path_to(go_button)
			go_button.focus_neighbour_bottom = go_button.get_path_to(primary_stats_container.first_primary_stat)
		else:
			carousel.arrow_left.focus_neighbour_top = carousel.arrow_left.get_path_to(go_button)
			carousel.arrow_right.focus_neighbour_top = carousel.arrow_right.get_path_to(go_button)
			go_button.focus_neighbour_bottom = go_button.get_path_to(carousel.arrow_left)


func on_popup_toggled(hide_popup, _player_index) -> void :
	if hide_popup:
		_toggle_popup_hint.set_text("COOP_POPUP_ENABLE_HINT")
	else:
		_toggle_popup_hint.set_text("COOP_POPUP_DISABLE_HINT")
