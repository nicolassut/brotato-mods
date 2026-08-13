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
	# Gourmet DLC - Credit Card: a purchase is affordable if the wallet plus available credit
	# covers it. Credit is 0 without a card, so this is unchanged for everyone else. Overspend
	# turns into debt in RunData.remove_currency. The HP shop cannot be paid on credit.
	var effects = RunData.get_player_effects(player_index)
	var spending_power: int = RunData.get_player_currency(player_index)
	if not effects[Keys.hp_shop_hash]:
		spending_power += RunData.get_available_credit(player_index)
	if spending_power < shop_item.value:
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

	# Gourmet DLC - P2W: chest cards are never deactivated here - base_shop owns
	# their lifecycle (armed cards must survive a cancelled ceremony; they die
	# only when the drop is taken or recycled).
	var p2w_chest_press: bool = RunData.is_p2w(player_index) and shop_item.item_data.my_id.begins_with("item_p2w_chest_")

	emit_signal("shop_item_bought", shop_item)
	if not p2w_chest_press:
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

	# Compare against the wave the purchase was made in, read from the SERIALIZED effects
	# dict. A plain non-serialized flag reset on reload, which let him buy a second thing
	# out of a shop he had already bought from.
	return RunData.get_player_effect(Keys.freeloader_shop_wave_hash, player_index) != RunData.current_wave


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

	# Gourmet DLC - Mime: mirrors deliver 2+ copies at once and copies merge with each other,
	# so a full inventory does not necessarily block the buy. The vanilla allowance above only
	# fires on an EXACT my_id match, which wrongly blocked "own 3x Stick T2, buy Stick T1"
	# even though the two mirrored T1s become a T2 that then pairs with an owned T2. Ask
	# whether the cascade actually lands within the slot limit instead of assuming it cannot.
	if not weapon_slot_available and RunData.is_mime(player_index) \
			and weapon_data.upgrades_into != null and weapon_data.upgrades_into.tier <= max_weapon_tier \
			and RunData.mime_purchase_fits(weapon_data, player_index):
		return true

	return weapon_slot_available


func update_buttons_color() -> void :
	for item in _shop_items:
		item.update_color()


func on_shop_item_deactivated(shop_item: ShopItem) -> void :
	emit_signal("shop_item_deactivated", shop_item)


func on_shop_item_focused(shop_item: ShopItem) -> void :
	# hover details are handled by the game's own ItemPopup via popup_manager, which is wired
	# to this signal already. Nothing custom needed here.
	enable_shop_lock_buttons_focus()
	emit_signal("shop_item_focused", shop_item)


func on_shop_item_unfocused(shop_item: ShopItem) -> void :
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
		if shop_item.active and shop_item.value <= RunData.get_player_gold(player_index) + RunData.get_available_credit(player_index):
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
				# Gourmet DLC - P2W: an ARMED chest card must never be re-set - that
				# would restore its full price and erase the OPEN state mid-shop.
				if _shop_items[i].p2w_pending_uid >= 0:
					continue
				_shop_items[i].set_shop_item(_shop_items[i].item_data, _shop_items[i].wave_value)


func get_shop_item_node(index: int) -> ShopItem:
	return _shop_items[index]


# Widen the shop to `wanted` slots. A normal 4-item shop never enters here.
func _ensure_shop_item_capacity(wanted: int) -> void :
	if _shop_items.empty() or wanted <= _shop_items.size():
		return

	_rebuild_as_compact_grid(wanted)


# The Freeloader's 8-slot shop reuses the game's OWN compact card, coop_shop_item.tscn, which
# is the purpose-built banner co-op uses when space is tight: icon + name + category + price in
# a single ~80px row. It carries the same shop_item.gd script and every node that script needs
# (PanelContainer, %BuyButton, %ItemDescription, %StealButton, %LockButton, %BanButton,
# %progress_ban, %LockIcon), so it is a drop-in replacement for the tall solo card.
# Details on hover come from the game's existing ItemPopup: popup_manager._on_shop_item_focused
# already calls display_item_data(item_data, attachment) and handles positioning, it was merely
# gated to co-op. Do NOT hand-roll a banner or a detail overlay here; both already exist.
const COMPACT_CARD: = "res://ui/menus/shop/coop_shop_item.tscn"
const GRID_HSEPARATION: = 16
# Modest per-card minimum: enough that the two columns cannot collapse onto each other, but
# small enough that the grid never demands more width than the shop column actually gets.
# Deriving this from a guessed 1890px made the container minimum 1890 and pushed the Stats
# panel and Go button out of the layout entirely. Cards EXPAND_FILL into the real width.
# Wide enough that icon + name + price fit INSIDE the drawn panel even before expansion. At
# 320 the content minimum exceeded the card, so the price spilled outside the background box.
const CARD_MIN_WIDTH: = 400
# In coop the shop column is roughly a quarter of the screen, so the solo minimum is wider
# than the space that exists and the two columns fight over it - which is what used to squash
# the cards into unreadable strips and got coop excluded from the 8-slot menu entirely. The
# compact card is icon + name + price on one line and stays legible well below that.
const CARD_MIN_WIDTH_COOP: = 190
var _grid: GridContainer


func _card_min_width() -> int:
	return CARD_MIN_WIDTH_COOP if RunData.is_coop_run else CARD_MIN_WIDTH


# Rebuild the shop as a 2-column grid of compact cards, discarding the authored tall solo
# cards entirely rather than trying to squash them.
# A dark rounded panel behind each compact row. Built here rather than edited into
# coop_shop_item.tscn so the real co-op shop, which supplies its own surrounding panel, is
# untouched.
func _compact_card_stylebox() -> StyleBoxFlat:
	var sb: = StyleBoxFlat.new()
	sb.bg_color = Color(0, 0, 0, 0.55)
	sb.set_corner_radius_all(6)
	sb.content_margin_left = 6
	sb.content_margin_right = 6
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	return sb


func _rebuild_as_compact_grid(wanted: int) -> void :
	if _grid == null:
		_grid = GridContainer.new()
		_grid.name = "WideShopGrid"
		_grid.columns = 2
		_grid.add_constant_override("hseparation", GRID_HSEPARATION)
		_grid.add_constant_override("vseparation", 4)
		_grid.size_flags_horizontal = SIZE_EXPAND_FILL
		_grid.size_flags_vertical = SIZE_SHRINK_CENTER
		add_child(_grid)

	# self is an HBoxContainer sitting at its own minimum width, so EXPAND_FILL on the grid had
	# nothing to expand INTO and the cards stayed at CARD_MIN_WIDTH. Let self claim the shop
	# column's full width; the stats panel lives in a different branch of the tree so it keeps
	# its space, and the grid then splits the real width evenly between the two columns.
	size_flags_horizontal = SIZE_EXPAND_FILL

	for old in _shop_items:
		old.queue_free()
	_shop_items.clear()

	# collapse the scene's spacer Controls so they stop eating the row
	for child in get_children():
		if child != _grid and child is Control and not (child is Timer):
			child.visible = false

	var packed = load(COMPACT_CARD)
	for i in wanted:
		var card = packed.instance()
		card.name = "CompactShopItem" + str(i)
		_grid.add_child(card)
		card.player_index = player_index
		card.size_flags_horizontal = SIZE_EXPAND_FILL
		# full-Vector2 assignment: `rect_min_size.x = ...` silently no-ops in Godot 3
		card.rect_min_size = Vector2(_card_min_width(), 0)
		# NOTE on price alignment: nothing is needed here. The description MarginContainer
		# already carries size_flags_horizontal = 3 in coop_shop_item.tscn, so it always
		# absorbed the slack. What actually stranded the price mid-card was the transparent
		# placeholder steal button vanilla shows when lock/steal/ban are all hidden; that is
		# skipped for compact cards in shop_item.activate().

		# tier is conveyed by tinting the icon panel, the way co-op does it
		card.use_compact_style = true
		# and the card needs a real background: both panels in coop_shop_item.tscn are
		# StyleBoxEmpty because co-op's own container draws the surrounding panel, so in a
		# solo shop the rows would otherwise float on the bare shop backdrop.
		card.add_stylebox_override("panel", _compact_card_stylebox())
		_shop_items.push_back(card)
		_connect_shop_item(card)

	# focus chain for a 2-wide grid so controller nav walks columns and rows
	for i in _shop_items.size():
		var button = _shop_items[i]._button
		if button == null:
			continue
		button.focus_neighbour_left = button.get_path_to(_shop_items[i - 1]._button) if (i % 2) == 1 else NodePath("")
		button.focus_neighbour_right = button.get_path_to(_shop_items[i + 1]._button) if (i % 2) == 0 and i + 1 < _shop_items.size() else NodePath("")
		button.focus_neighbour_top = button.get_path_to(_shop_items[i - 2]._button) if i - 2 >= 0 else NodePath("")
		button.focus_neighbour_bottom = button.get_path_to(_shop_items[i + 2]._button) if i + 2 < _shop_items.size() else NodePath("")


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
