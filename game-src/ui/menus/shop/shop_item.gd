class_name ShopItem
extends Control

signal buy_button_pressed(shop_item)
signal steal_button_pressed(shop_item)
signal shop_item_deactivated(shop_item)
signal shop_item_focused(shop_item)
signal shop_item_unfocused(shop_item)
signal mouse_hovered_category(shop_item)
signal mouse_exited_category(shop_item)
signal ban_item_pressed(shop_item)
signal ban_update_remaining_token()

export var player_index: = 0

var item_data: ItemParentData
var active: = true
var value: = 1
# materials shaved off this card by the Loyalty Card 5th-purchase discount;
# read by base_shop on purchase for the MATERIALS_SAVED counter
var loyalty_saving: = 0
var locked = false
var item_steals: = 0
var ban_button_presed: bool = false

var wave_value: = 1

# Gourmet DLC - P2W two-stage chest state. -1 = not armed; otherwise the uid of
# the serialized pending entry this card opens on its next press.
var p2w_pending_uid: int = - 1
var p2w_cursed: bool = false

onready var _panel = $PanelContainer
onready var _button = $"%BuyButton"
onready var _item_description = $"%ItemDescription"
onready var _steal_button = $"%StealButton"
onready var _lock_button = $"%LockButton"
onready var _ban_button = $"%BanButton" as Button
onready var _progress_ban = $"%progress_ban"
onready var _lock_icon = $"%LockIcon"


func _ready():
	yield(get_tree(), "idle_frame")
	_progress_ban.modulate = Color(ProgressData.settings.color_negative)
	_ban_button.connect("button_up", self, "_release_BanButton")


func disable_focus() -> void :
	_button.focus_mode = FOCUS_NONE


func enable_focus() -> void :
	if active:
		_button.focus_mode = FOCUS_ALL


func disable_lock_focus() -> void :
	_lock_button.focus_mode = FOCUS_NONE


func enable_lock_focus() -> void :
	if active:
		_lock_button.focus_mode = FOCUS_ALL


func deactivate() -> void :
	modulate = Color(1, 1, 1, 0)
	_button.disable()
	_steal_button.disable()
	_steal_button.pressed = false
	_lock_button.disable()
	_lock_button.pressed = false
	_lock_icon.hide()
	_ban_button.disable()
	_ban_button.pressed = false
	_ban_button.hide()
	locked = false
	active = false
	emit_signal("shop_item_deactivated", self)


func activate() -> void :
	modulate = Color(1, 1, 1, 1)
	_button.reinitialize_colors(player_index)
	if item_steals > 0:
		_steal_button.activate()
	else:
		_steal_button.disable()
		_steal_button.hide()

	manage_lock_button_visibility()
	manage_ban_button_visibility()

	
	if not _lock_button.visible and not _steal_button.visible and not _ban_button.visible:
		# Vanilla shows a fully TRANSPARENT steal button here purely to reserve layout space so
		# cards keep a consistent shape. Gourmet DLC - on the Freeloader's compact cards that
		# reserved width lands between the price and the card's right edge and reads as a bug,
		# so skip the placeholder and let the expanding description push the price hard right.
		if not use_compact_style:
			_steal_button.modulate = Color(1, 1, 1, 0)
			_steal_button.show()

	_button.activate()
	active = true


func manage_lock_button_visibility() -> void :
	# Gourmet DLC - the Freeloader reaches this via the disable_item_locking effect on his
	# character (locking is a soft reroll, and he may not reconsider anything). Using the
	# vanilla key rather than a character check means change_lock_status() blocks the ACTION
	# too, so hiding the button is not the only thing standing in the way.
	# is_freeloader is checked alongside the effect for the same serialization reason as
	# change_lock_status: an in-flight run carries the old kit without the effect.
	if RunData.is_freeloader(player_index) or RunData.get_player_effect_bool(Keys.disable_item_locking_hash, player_index):
		_lock_button.disable()
		_lock_button.hide()
	else:
		if not RunData.is_coop_run:
			_lock_button.show()
		_lock_button.activate()


func manage_ban_button_visibility() -> void :
	if not ChallengeService.is_challenge_completed(ChallengeService.chal_banned_items_hash) or not RunData.is_ban_active_in_current_run() or item_data is WeaponData:
		_ban_button.disable()
		_ban_button.hide()
		return

	if item_data != null and item_data.my_id_hash == Keys.item_bait_hash:
		if RunData.players_data[player_index].current_character.my_id_hash == Keys.character_fisherman_hash:
			_ban_button.disable()
			_ban_button.hide()
			return

	var remaining_ban_token = RunData.players_data[player_index].remaining_ban_token
	_ban_button.text = Text.text("BAN_SHOP", [str(remaining_ban_token)])
	if remaining_ban_token > 0:
		if not RunData.is_coop_run:
			_ban_button.show()
		_ban_button.activate()
	else:
		_ban_button.disable()
		_ban_button.hide()


func set_shop_item(p_item_data: ItemParentData, p_wave_value: int = RunData.current_wave) -> void :
	item_data = p_item_data
	wave_value = p_wave_value
	value = ItemService.get_value(wave_value, p_item_data.value, player_index, true, p_item_data is WeaponData, p_item_data.my_id_hash)

	# food-tagged items get their own price modifier (e.g. Picky Eater's discount)
	var food_items_price = RunData.get_player_effect(Keys.food_items_price_hash, player_index)
	if food_items_price != 0 and not p_item_data is WeaponData and p_item_data.tags.has("food"):
		value = max(1, int(value * (1.0 + food_items_price / 100.0)))

	# Gourmet DLC - Picky Eater: food spawner items cost less
	var spawner_items_price = RunData.get_player_effect(Keys.spawner_items_price_hash, player_index)
	if spawner_items_price != 0 and not p_item_data is WeaponData and p_item_data.tags.has("spawner"):
		value = max(1, int(value * (1.0 + spawner_items_price / 100.0)))

	# Gourmet DLC - Loyalty Card: every 5th shop purchase is 30% off
	loyalty_saving = 0
	if RunData.get_player_effect(Keys.loyalty_card_hash, player_index) > 0 and (int(RunData.get_player_effect(Keys.shop_purchases_hash, player_index)) + 1) % 5 == 0:
		var value_before_loyalty: int = value
		value = max(1, int(value * 0.7))
		loyalty_saving = value_before_loyalty - value

	# Gourmet DLC - The Freeloader takes everything for free, and free means 0, never 1.
	# ItemService.get_value already returns 0 for him at the root, but the three price
	# modifiers above are each wrapped in max(1, ...), so any of them that applies would
	# turn that 0 back into 1. Re-zeroing here after all of them is what actually holds
	# the price at nothing.
	if RunData.is_freeloader(player_index):
		value = 0

	activate()

	var item_count: = 1
	var additional_icon: Image

	if RunData.get_player_effect_bool(Keys.hp_shop_hash, player_index):
		value = ceil(value / 20.0) as int
		var material_icon: Image = ItemService.get_stat_icon(Keys.stat_max_hp_hash).get_data()
		var texture: = ImageTexture.new()
		texture.create_from_image(material_icon)
		_button.set_material_icon(texture)

	var current_character = RunData.get_player_character(player_index)
	var duplicate_item_effects: Array = RunData.get_player_effect(Keys.duplicate_item_hash, player_index)
	var duplicate_item_icon = ItemService.get_icon_for_duplicate_shop_item(current_character, RunData.get_player_items(player_index), RunData.get_player_weapons(player_index), item_data, player_index)

	if duplicate_item_icon != null:
		additional_icon = duplicate_item_icon

	if duplicate_item_effects.size() > 0:

		if item_data.get_category() == Category.ITEM:
			var remaining_item_count: int = RunData.get_remaining_max_nb_item(item_data, player_index)
			var max_clones: = 1
			for effect in duplicate_item_effects:
				max_clones = min(max_clones + effect[1], remaining_item_count) as int
			item_count = max_clones

			if remaining_item_count > 1:

				var item_id = duplicate_item_effects[0][0]
				assert (item_id is int)
				var source_item: ItemData = ItemService.get_item_from_id(item_id)
				additional_icon = source_item.icon.get_data()

		elif item_data.get_category() == Category.WEAPON:
			# Gourmet DLC - Mime: mirrors duplicate weapons too, so show the count + mirror
			# icon. The badge used to be hardcoded x2, which is only right with ONE mirror -
			# three mirrors buy four copies. mime_max_copies_that_fit is the same number
			# buy_weapon will actually deliver (mirrors capped to what the inventory can
			# absorb), so the badge cannot promise copies the purchase then declines to make.
			# A count of 1 means no duplication is possible, so no badge.
			if RunData.is_mime(player_index):
				var mime_copies: int = RunData.mime_max_copies_that_fit(item_data, player_index)
				if mime_copies > 1:
					item_count = mime_copies
					var mirror_item_id = duplicate_item_effects[0][0]
					assert (mirror_item_id is int)
					var mirror_source_item: ItemData = ItemService.get_item_from_id(mirror_item_id)
					additional_icon = mirror_source_item.icon.get_data()

	_button.remove_additional_icon()

	if additional_icon:
		var texture = ImageTexture.new()
		texture.create_from_image(additional_icon)
		_button.set_additional_icon(texture)

	# Gourmet DLC - Credit Card: the price colour reflects buyability, so it must count
	# available credit, or a credit-affordable item would show a red price you can still afford.
	# The Debtor has no money and buys on debt, so his prices read as debt: "-50" in red.
	_button.set_debt_mode(RunData.is_debtor(player_index))
	_button.set_value(value, _spending_power(player_index))

	var steal_spawn_elite_effect = RunData.get_player_effect(Keys.item_steals_spawns_random_elite_hash, player_index)
	var steal_chance = ItemService.get_chance_getting_caught(self, RunData.current_wave, steal_spawn_elite_effect / 100.0)

	var displayed_steal_chance = steal_chance * 100.0

	if displayed_steal_chance < 1.0:
		displayed_steal_chance = stepify(displayed_steal_chance, 0.1)
	else:
		displayed_steal_chance = stepify(displayed_steal_chance, 1.0)

	if not RunData.is_coop_run:
		_steal_button.text = tr("MENU_STEAL") + "  " + str(displayed_steal_chance) + "%"

	_item_description.set_item(p_item_data, player_index, item_count)

	if not p_item_data.is_lockable:
		_lock_button.disable()
		_lock_button.hide()
	else:
		manage_lock_button_visibility()

	_set_panel_lock_style()


# Gourmet DLC - P2W: the chest was paid for; the card stays live showing OPEN at
# price 0, with a purple border when the purchase rolled cursed.
func p2w_arm(uid: int, cursed: bool) -> void :
	p2w_pending_uid = uid
	p2w_cursed = cursed
	value = 0
	_button.set_value(0, _spending_power(player_index))
	_button.set_text(tr("P2W_OPEN"))
	if cursed:
		var panel_stylebox = _panel.get_stylebox("panel").duplicate()
		if panel_stylebox is StyleBoxFlat:
			panel_stylebox.border_color = ItemService.TIER_RARE_COLOR
			panel_stylebox.set_border_width_all(3)
			panel_stylebox.border_blend = true
			_panel.add_stylebox_override("panel", panel_stylebox)


func steal_item() -> void :
	_steal_button.emit_signal("pressed")

func ban_item() -> void :
	var player_run_data = RunData.players_data[player_index]
	player_run_data.banned_items.push_back(item_data.my_id_hash)
	player_run_data.remaining_ban_token -= 1
	deactivate()
	emit_signal("ban_update_remaining_token")

func update_color() -> void :
	_button.set_color_from_currency(_spending_power(player_index))


# Gourmet DLC - materials plus available Credit Card overspend (0 without a card, and the HP
# shop cannot be paid on credit). Mirrors the affordability gate in shop_items_container.
func _spending_power(p_index: int) -> int:
	var power: int = RunData.get_player_currency(p_index)
	if not RunData.get_player_effects(p_index)[Keys.hp_shop_hash]:
		power += RunData.get_available_credit(p_index)
	return power


func lock_visually() -> void :

	if not item_data: return

	locked = true
	_lock_button.set_pressed_no_signal(true)
	_lock_icon.show()
	_set_panel_lock_style()


func unlock_visually() -> void :

	if not item_data: return
	locked = false
	_lock_button.set_pressed_no_signal(false)
	_lock_icon.hide()
	_set_panel_lock_style()


func _on_LockButton_toggled(button_pressed: bool) -> void :
	change_lock_status(button_pressed)


func change_lock_status(button_pressed: bool) -> void :
	if RunData.get_player_effect_bool(Keys.disable_item_locking_hash, player_index):
		return

	# Gourmet DLC - belt and braces for the Freeloader. The disable_item_locking effect above is
	# the proper mechanism, but CHARACTER EFFECTS ARE SERIALIZED INTO THE RUN: a run started
	# before that effect was added keeps the old kit, so the guard above silently misses and the
	# lock still works mid-run. my_id survives serialization, so this closes the hole on
	# in-flight runs too. This is the ACTION chokepoint; hiding the button is not enough.
	if RunData.is_freeloader(player_index):
		return

	if button_pressed:
		lock_visually()
		RunData.lock_player_shop_item(item_data, wave_value, player_index)
	else:
		unlock_visually()
		RunData.unlock_player_shop_item(item_data, player_index)


func get_category_text_pos() -> Vector2:
	return _item_description._category.rect_global_position


# Gourmet DLC - set on the Freeloader's compact cards (coop_shop_item.tscn used in a solo
# run). Those cards carry StyleBoxEmpty panels on purpose because co-op conveys tier by
# tinting the ICON panel, so the solo branch below would try to tier-colour an empty stylebox
# and draw nothing. Routing them down the co-op path gives the intended look.
var use_compact_style: = false


func _set_panel_lock_style() -> void :
	# explicit bool: `var compact: = ...` cannot infer a type from untyped is_coop_run
	var compact: bool = RunData.is_coop_run or use_compact_style
	var panel = _item_description.icon_panel if compact else _panel
	var stylebox = panel.get_stylebox("panel").duplicate()
	if compact:
		var tier_color = ItemService.get_color_from_tier(item_data.tier)
		tier_color.a = stylebox.bg_color.a
		stylebox.bg_color = tier_color
		stylebox.set_border_width_all(3 if locked else 0)
		stylebox.border_blend = true
	else:
		ItemService.change_panel_stylebox_from_tier(stylebox, item_data.tier)
	if locked:
		stylebox.border_color = Color.white
	panel.add_stylebox_override("panel", stylebox)


func _on_BuyButton_focus_entered() -> void :
	emit_signal("shop_item_focused", self)


func _on_BuyButton_focus_exited() -> void :
	emit_signal("shop_item_unfocused", self)


func _on_BuyButton_pressed() -> void :
	emit_signal("buy_button_pressed", self)


func _on_StealButton_pressed() -> void :
	emit_signal("steal_button_pressed", self)


func _on_ItemDescription_mouse_hovered_category() -> void :
	if active:
		emit_signal("mouse_hovered_category", self)


func _on_ItemDescription_mouse_exited_category() -> void :
	emit_signal("mouse_exited_category", self)


func _on_BuyButton_mouse_exited() -> void :
	emit_signal("shop_item_unfocused", self)


func _on_BuyButton_mouse_entered() -> void :
	emit_signal("shop_item_focused", self)


func _on_BanButton_button_down():
	if _ban_button.disabled: return
	if not ProgressData.settings.holding_button:
		
		return

	ban_button_presed = true
	while true:
		_progress_ban.value += 0.025
		yield(get_tree(), "physics_frame")
		if _progress_ban.value >= 1:
			break
		elif not ban_button_presed:
			_progress_ban.value = 0
			return
	_progress_ban.value = 0

	yield(UIService._ban_item_control(_panel), "completed")
	emit_signal("ban_item_pressed", self)


func _release_BanButton():
	ban_button_presed = false
	if _ban_button.disabled: return
	if not ProgressData.settings.holding_button:
		emit_signal("ban_item_pressed", self)
		return


func _can_be_selected(can_be_selected: bool = true):
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP if can_be_selected else Control.MOUSE_FILTER_IGNORE


func _on_BanButton_pressed():
	if _ban_button.disabled: return
	if not ProgressData.settings.holding_button:
		emit_signal("ban_item_pressed", self)
