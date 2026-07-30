class_name ShopItemsContainer
extends Container

signal shop_item_bought(shop_item)
signal shop_item_stolen(shop_item)
signal shop_item_insufficient_currency(shop_item)
signal mouse_hovered_category(shop_item)
signal mouse_exited_category(shop_item)
signal shop_item_deactivated(shop_item)
signal shop_item_focused(shop_item)
signal shop_item_unfocused(shop_item)
signal shop_item_banned(shop_item)

export (Array, NodePath) var _shop_items_node_paths: Array

export var player_index: = 0 setget _set_player_index
func _set_player_index(value: int) -> void :
	player_index = value
	for shop_item in _shop_items:
		shop_item.player_index = value

var item_steals: = 0

var _shop_items: Array
var _buy_delay_timer: Timer
var _is_delay_active = false


func _ready() -> void :
	_buy_delay_timer = Timer.new()
	_buy_delay_timer.wait_time = 0.05
	_buy_delay_timer.one_shot = true

	var _delay = _buy_delay_timer.connect("timeout", self, "_on_BuyDelayTimer_timeout")
	add_child(_buy_delay_timer)

	for node_path in _shop_items_node_paths:
		_shop_items.push_back(get_node(node_path))

	connect_shop_items()


func connect_shop_items() -> void :
	for shop_item in _shop_items:
		_connect_shop_item(shop_item)


# Gourmet DLC - split out of connect_shop_items so a single late-added card (the
# Freeloader's extra 4 slots) can be wired without re-connecting the original 4.
func _connect_shop_item(shop_item) -> void :
	var _error_buy = shop_item.connect("buy_button_pressed", self, "on_shop_item_buy_button_pressed")
	var _error_steal = shop_item.connect("steal_button_pressed", self, "on_shop_item_steal_button_pressed")
	var _error_deactivate = shop_item.connect("shop_item_deactivated", self, "on_shop_item_deactivated")
	var _error_focused = shop_item.connect("shop_item_focused", self, "on_shop_item_focused")
	var _error_unfocused = shop_item.connect("shop_item_unfocused", self, "on_shop_item_unfocused")
	var _error_category_hovered = shop_item.connect("mouse_hovered_category", self, "on_mouse_hovered_category")
	var _error_category_exited = shop_item.connect("mouse_exited_category", self, "on_mouse_exited_category")
	var _error_ban = shop_item.connect("ban_item_pressed", self, "on_shop_item_ban_button_pressed")
	var _error_ban_update = shop_item.connect("ban_update_remaining_token", self, "on_ban_update_remaining_token")


func on_shop_item_buy_button_pressed(shop_item: ShopItem) -> void :
	if _is_delay_active:
		return
	if RunData.get_player_currency(player_index) < shop_item.value:
		emit_signal("shop_item_insufficient_currency", shop_item)
		return

	# Gourmet DLC - The Freeloader takes exactly ONE thing per shop, item or weapon. Gated
	# here rather than per-category because this is the single entry point both routes
	# through, and it blocks before anything is committed. Reuses the insufficient-currency
	# shake, same as the Minimalist slot cap below.
	if not _can_freeloader_still_buy():
		emit_signal("shop_item_insufficient_currency", shop_item)
		return

	if shop_item.item_data.get_category() == Category.WEAPON:
		if not _can_weapon_be_bought(shop_item):
			return

	if shop_item.item_data.get_category() == Category.ITEM:
		if not _can_item_be_bought(shop_item):
			return

	emit_signal("shop_item_bought", shop_item)
	shop_item.deactivate()

	update_buttons_color()

	_is_delay_active = true
	_buy_delay_timer.start()


func on_shop_item_steal_button_pressed(shop_item: ShopItem) -> void :
	if item_steals <= 0:
		return

	if _is_delay_active:
		return

	if not _can_freeloader_still_buy():
		emit_signal("shop_item_insufficient_currency", shop_item)
		return

	if shop_item.item_data.get_category() == Category.WEAPON:
		if not _can_weapon_be_bought(shop_item):
			return

	emit_signal("shop_item_stolen", shop_item)

	shop_item.deactivate()

	update_buttons_color()

	_is_delay_active = true
	_buy_delay_timer.start()


# Gourmet DLC - false once the Freeloader has already taken his one thing this shop.
# Always true for every other character.
func _can_freeloader_still_buy() -> bool:
	if not RunData.is_freeloader(player_index):
		return true

	return not RunData.freeloader_bought_this_shop[player_index]


# Gourmet DLC - Minimalist: purchases are blocked while all 6 item slots are full
func _can_item_be_bought(shop_item: ShopItem) -> bool:
	var character = RunData.get_player_character(player_index)
	if character != null and character.my_id == "character_minimalist":
		var nb_items_held: = 0
		for held in RunData.get_player_items_ref(player_index):
			if held is ItemData and not held is WeaponData and not held is CharacterData:
				nb_items_held += 1
		if nb_items_held >= 6:
			emit_signal("shop_item_insufficient_currency", shop_item)
			return false
	return true


func _can_weapon_be_bought(shop_item: ShopItem) -> bool:
	var min_weapon_tier = RunData.get_player_effect(Keys.min_weapon_tier_hash, player_index)
	var max_weapon_tier = RunData.get_player_effect(Keys.max_weapon_tier_hash, player_index)
	var no_melee_weapons = RunData.get_player_effect_bool(Keys.no_melee_weapons_hash, player_index)
	var no_ranged_weapons = RunData.get_player_effect_bool(Keys.no_ranged_weapons_hash, player_index)
	var no_duplicate_weapons = RunData.get_player_effect_bool(Keys.no_duplicate_weapons_hash, player_index)
	var lock_current_weapons = RunData.get_player_effect_bool(Keys.lock_current_weapons_hash, player_index)

	var weapon_data: WeaponData = shop_item.item_data
	var weapon_type: = weapon_data.type
	var weapons = RunData.get_player_weapons_ref(player_index)
	var weapon_slot_available: bool = RunData.has_weapon_slot_available(weapon_data, player_index)

	var player_has_weapon = false
	for weapon in weapons:
		if weapon.my_id == weapon_data.my_id:
			player_has_weapon = true
			break

	var player_has_weapon_family = false
	if weapon_data.weapon_id in RunData.get_unique_weapon_ids(player_index):
		player_has_weapon_family = true

	if weapon_data.tier > max_weapon_tier or weapon_data.tier < min_weapon_tier:
		return false

	if no_melee_weapons and weapon_type == WeaponType.MELEE:
		return false

	if no_ranged_weapons and weapon_type == WeaponType.RANGED:
		return false

	if lock_current_weapons and not weapon_slot_available:
		return false


	# Gourmet DLC - Blacksmith: no auto-merge-on-buy. For everyone else, buying an exact
	# copy while full is allowed because it combines into the next tier; the Blacksmith's
	# whole identity is the manual class-based forge, so that vanilla shortcut would rob
	# him of the random-next-tier roll. Block the buy instead (weapon can't enter a full
	# inventory until space is made), same as any non-mergeable weapon when full.
	if player_has_weapon and not weapon_slot_available and weapon_data.upgrades_into != null and weapon_data.upgrades_into.tier <= max_weapon_tier and not RunData.is_blacksmith(player_index):
		return true

	if no_duplicate_weapons and player_has_weapon_family:
		return false

	return weapon_slot_available


func update_buttons_color() -> void :
	for item in _shop_items:
		item.update_color()


func on_shop_item_deactivated(shop_item: ShopItem) -> void :
	emit_signal("shop_item_deactivated", shop_item)


func on_shop_item_focused(shop_item: ShopItem) -> void :
	# widened (banner) shop only: pop the full card in the hover overlay
	if _grid != null:
		_show_banner_detail(shop_item)
	enable_shop_lock_buttons_focus()
	emit_signal("shop_item_focused", shop_item)


func on_shop_item_unfocused(shop_item: ShopItem) -> void :
	if _grid != null:
		_hide_banner_detail()
	emit_signal("shop_item_unfocused", shop_item)


func get_focus_control(latest_focused_shop_item: ShopItem = null) -> Control:
	var search_index: = 1
	
	if latest_focused_shop_item != null:
		var index = _shop_items.find(latest_focused_shop_item)
		if index >= 0:
			search_index = index

	
	var search_range: = range(search_index, _shop_items.size()) + range(search_index - 1, - 1, - 1)
	for i in search_range:
		var shop_item = _shop_items[i]
		if shop_item.active and shop_item.value <= RunData.get_player_gold(player_index):
			return shop_item._button
	
	for i in search_range:
		var shop_item = _shop_items[i]
		if shop_item.active:
			return shop_item._button
	return null


func reload_shop_items() -> void :
	for i in _shop_items.size():
		if _shop_items[i].active:
			_shop_items[i].item_steals = item_steals

			
			if _shop_items[i].item_data:
				_shop_items[i].set_shop_item(_shop_items[i].item_data, _shop_items[i].wave_value)


func get_shop_item_node(index: int) -> ShopItem:
	return _shop_items[index]


# Gourmet DLC - grows the row to `wanted` cards by instancing the same scene the existing
# cards came from (read off template.filename, so the coop shop gets coop_shop_item.tscn
# instead of a hardcoded path). Instancing beats Node.duplicate() here: duplicate() copies
# signal connections by default and these cards are already connected by _ready, so clones
# would fire every handler twice.
func _ensure_shop_item_capacity(wanted: int) -> void :
	if _shop_items.empty() or wanted <= _shop_items.size():
		return

	var template = _shop_items[0]
	var scene_path: String = template.filename

	if scene_path == "":
		push_error("ShopItemsContainer: cannot widen the shop, template card has no scene filename")
		return

	var packed = load(scene_path)
	var parent = template.get_parent()

	while _shop_items.size() < wanted:
		var clone = packed.instance()
		clone.name = "ShopItemExtra" + str(_shop_items.size())
		parent.add_child(clone)
		clone.player_index = player_index
		_shop_items.push_back(clone)
		_connect_shop_item(clone)

	_reflow_into_grid()


# 8 cards do not fit one row. self is an HBoxContainer (the script lives on it) so it can only
# sort horizontally and cannot wrap. Instead of fighting it, drop a GridContainer into it,
# reparent every card into that, and let the grid do 2 rows of 4. Each card is then compressed
# so both rows fit the fixed 603px-tall area; the card's own ScrollContainer takes the overflow
# text. Only runs on a widened shop; a normal 4-card shop never enters _ensure_shop_item_capacity
# and keeps its authored single-row layout untouched.
# The co-op shop solves "too many cards, too little space" by showing compact BANNERS
# (icon + name + category + price) and revealing the full card only on hover. Same idea here.
# Layout: a GridContainer of 2 columns x 4 rows of banners. A banner is the normal card with
# its ItemDescription detail hidden (via _vbox_container / _scroll_container, the same nodes
# the show_details flag drives) and its PanelContainer min-height floor dropped so the card
# collapses to header + price. The banners stay collapsed; hovering pops the full card in a
# separate floating overlay (see _show_banner_detail). Only runs on a widened shop.
const BANNER_SIZE: = Vector2(560, 140)
var _grid: GridContainer

func _reflow_into_grid() -> void :
	if _grid == null:
		_grid = GridContainer.new()
		_grid.name = "WideShopGrid"
		_grid.columns = 2
		_grid.add_constant_override("hseparation", 12)
		_grid.add_constant_override("vseparation", 10)
		add_child(_grid)

	# hide ONLY the scene's spacer Controls (EmptySpace*). Exclude the cards: at this point
	# they are still direct children of self, and blanking them once left the shop empty.
	for child in get_children():
		if child != _grid and child is Control and not (child is Timer) and not (child in _shop_items):
			child.visible = false

	# Cards go DIRECTLY into the grid (no wrapper). A GridContainer stretches each child to a
	# uniform cell; a plain Control wrapper does not, which is why the cards kept their old
	# ~500px height and overflowed. Combined with the PanelContainer min-height drop in
	# _set_banner_mode (so a card is ALLOWED to be short), every card is forced to BANNER_SIZE.
	for shop_item in _shop_items:
		if shop_item.get_parent() != _grid:
			var host = shop_item.get_parent()
			if host != null:
				host.remove_child(shop_item)
			_grid.add_child(shop_item)
		shop_item.size_flags_horizontal = SIZE_FILL
		shop_item.size_flags_vertical = SIZE_FILL
		shop_item.rect_min_size = BANNER_SIZE
		shop_item.visible = true
		_set_banner_mode(shop_item, true)

	# focus chain for a 2-wide grid so controller nav walks columns and rows
	for i in _shop_items.size():
		var button = _shop_items[i]._button
		if button == null:
			continue
		button.focus_neighbour_left = button.get_path_to(_shop_items[i - 1]._button) if (i % 2) == 1 else NodePath("")
		button.focus_neighbour_right = button.get_path_to(_shop_items[i + 1]._button) if (i % 2) == 0 and i + 1 < _shop_items.size() else NodePath("")
		button.focus_neighbour_top = button.get_path_to(_shop_items[i - 2]._button) if i - 2 >= 0 else NodePath("")
		button.focus_neighbour_bottom = button.get_path_to(_shop_items[i + 2]._button) if i + 2 < _shop_items.size() else NodePath("")


# Collapse a card to a banner: hide the ItemDescription detail (the same two containers its
# show_details flag drives), leaving just the icon + name + category header and the price.
# The banners stay collapsed; the full detail is shown separately by the hover overlay below.
func _set_banner_mode(shop_item, banner: bool) -> void :
	var d = shop_item._item_description
	if d == null:
		return
	if d._vbox_container != null:
		d._vbox_container.visible = not banner
	if d._scroll_container != null:
		d._scroll_container.visible = not banner
	# Hiding the detail is not enough: the card's PanelContainer has a 475px min-height floor,
	# so the card stays full height with an empty middle and overflows the banner slot. Drop
	# that floor so the card collapses to just its header + price row.
	var panel = shop_item.get_node_or_null("PanelContainer")
	if panel != null:
		panel.rect_min_size.y = 0 if banner else 475


# On hover, the full card is shown in a floating panel anchored to the banner, exactly like the
# co-op shop pops an ItemPopup. It lives in a top-level overlay that is the LAST child of self,
# so it draws over the other banners by tree order (Control has no z_index in Godot 3). One
# reused ItemDescription is repopulated per hover.
var _detail_overlay: Control
var _detail_panel: PanelContainer
var _detail_desc

func _ensure_detail_overlay() -> void :
	if _detail_overlay != null:
		return
	_detail_overlay = Control.new()
	_detail_overlay.name = "BannerDetailOverlay"
	_detail_overlay.set_as_toplevel(true)
	_detail_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_detail_overlay)

	_detail_panel = PanelContainer.new()
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.96)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.35, 0.35, 0.35)
	sb.set_corner_radius_all(6)
	_detail_panel.add_stylebox_override("panel", sb)
	_detail_panel.rect_min_size = Vector2(BANNER_SIZE.x, 0)
	_detail_overlay.add_child(_detail_panel)

	_detail_desc = load("res://ui/menus/shop/item_description.tscn").instance()
	_detail_panel.add_child(_detail_desc)
	_detail_overlay.visible = false


func _show_banner_detail(shop_item) -> void :
	if shop_item == null or shop_item.item_data == null:
		return
	_ensure_detail_overlay()
	_detail_desc.set_item(shop_item.item_data, player_index)
	_detail_panel.rect_global_position = shop_item.get_global_rect().position
	_detail_overlay.visible = true


func _hide_banner_detail() -> void :
	if _detail_overlay != null:
		_detail_overlay.visible = false


func set_shop_items(items_data: Array) -> void :
	# Gourmet DLC - The Freeloader's shop holds 8 offerings, but the scene only ships 4
	# ShopItem nodes and the loop below would silently drop the extras. Grow to fit
	# whatever the item service handed us. Deliberately self-sizing rather than gated on
	# the character, so a normal 4-item shop never enters the branch.
	_ensure_shop_item_capacity(items_data.size())

	for i in _shop_items.size():
		if i < items_data.size():
			_shop_items[i].item_steals = item_steals
			_shop_items[i].set_shop_item(items_data[i][0], items_data[i][1])
		else:
			_shop_items[i].deactivate()


func disable_shop_buttons_focus() -> void :
	for shop_item in _shop_items:
		shop_item.disable_focus()


func enable_shop_buttons_focus() -> void :
	for shop_item in _shop_items:
		shop_item.enable_focus()


func disable_shop_lock_buttons_focus() -> void :
	for shop_item in _shop_items:
		shop_item.disable_lock_focus()


func enable_shop_lock_buttons_focus() -> void :
	for shop_item in _shop_items:
		shop_item.enable_lock_focus()


func unlock_all_shop_items_visually() -> void :
	for shop_item in _shop_items:
		shop_item.unlock_visually()


func lock_shop_item_visually(index: int) -> void :
	if index < _shop_items.size():
		_shop_items[index].lock_visually()


func is_shop_item_locked_visually(index: int) -> bool:
	return _shop_items[index].locked


func on_mouse_hovered_category(shop_item: ShopItem) -> void :
	emit_signal("mouse_hovered_category", shop_item)


func on_mouse_exited_category(shop_item: ShopItem) -> void :
	emit_signal("mouse_exited_category", shop_item)


func _on_BuyDelayTimer_timeout() -> void :
	if _is_delay_active:
		_is_delay_active = false

func on_shop_item_ban_button_pressed(shop_item: ShopItem) -> void :
	var player_run_data = RunData.players_data[player_index]
	if player_run_data.remaining_ban_token > 0 and not player_run_data.banned_items.has(shop_item.item_data.my_id_hash):
		shop_item.ban_item()
		emit_signal("shop_item_banned", shop_item)

func on_ban_update_remaining_token() -> void :
	for shop_item in _shop_items:
		if shop_item != null:
			shop_item.manage_ban_button_visibility()
