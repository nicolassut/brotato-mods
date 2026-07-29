class_name UpgradesUIPlayerContainer
extends Container

export (int) var player_index: = 0

signal choose_button_pressed(upgrade)
signal item_take_button_pressed(item_data)
signal item_discard_button_pressed(item_data)
signal item_ban_button_pressed(item_data)

onready var _button_delay_timer = $ButtonDelayTimer
onready var _upgrade_ui_1 = $"%UpgradeUI"
onready var _upgrade_ui_2 = $"%UpgradeUI2"
onready var _upgrade_ui_3 = $"%UpgradeUI3"
onready var _upgrade_ui_4 = $"%UpgradeUI4"
onready var _reroll_button = $"%RerollButton"

onready var _item_panel_container = $"%ItemPanelContainer"
onready var _item_description = $"%ItemDescription"
onready var _take_button = $"%TakeButton"
onready var _discard_button = $"%DiscardButton"
onready var _ban_button = $"%BanButton"
onready var _ban_button_label = $"%label_banitem"
onready var _progress_ban = $"%progress_ban"
onready var _icon_ban = $"%icon_ban"

onready var _items_container = $"%ItemsContainer"
onready var _upgrades_container = $"%UpgradesContainer"


onready var _things_to_process_container = get_node_or_null("%UIThingsToProcessPlayerContainer")

var _level: = 0
var _reroll_price: = 0
var _reroll_discount: = 0
var _reroll_count: = 0
var _old_upgrades = []
var _consumable_data: ConsumableData = null
var _item_data: ItemParentData = null
var _button_pressed: = false
var is_pressing_b: = false
# Gourmet DLC - extra draft cards added at runtime for the Freeloader's 8-option level up.
# Empty for every other character, so _get_upgrade_uis() returns the authored 4 unchanged.
var _extra_upgrade_uis: = []


func _ready() -> void :
	for upgrade_ui in _get_upgrade_uis():
		upgrade_ui.connect("choose_button_pressed", self, "_on_choose_button_pressed")
	_items_container.hide()
	_upgrades_container.hide()
	if not ChallengeService.is_challenge_completed(ChallengeService.chal_banned_items_hash) or not RunData.is_ban_active_in_current_run():
		_ban_button.visible = false
	else:
		_ban_button.visible = true
		_icon_ban.modulate = Color(ProgressData.settings.color_negative)
		_progress_ban.modulate = Color(ProgressData.settings.color_negative)


func show_upgrades_for_level(level: int) -> void :
	if _reroll_price == 0:
		var result = ItemService.get_reroll_price(RunData.current_wave, _reroll_count, player_index)
		_reroll_price = result[0]
		_reroll_discount = result[1]
	_reroll_button.init(_reroll_price, player_index)

	_level = level
	var upgrades = ItemService.get_upgrades(level, ItemService.get_nb_upgrade_options(player_index), _old_upgrades, player_index)
	_old_upgrades = upgrades

	# Gourmet DLC - the Freeloader drafts from 8, so make sure there are 8 cards to fill.
	_ensure_upgrade_ui_capacity(upgrades.size())

	var upgrade_uis: = _get_upgrade_uis()
	for i in upgrade_uis.size():
		var upgrade_ui = upgrade_uis[i]
		upgrade_ui.visible = i < upgrades.size()
		if upgrade_ui.visible:
			upgrade_ui.set_upgrade(upgrades[i], player_index)

	# Gourmet DLC - the Freeloader cannot reroll anything, level-up draft included.
	_reroll_button.visible = upgrades.size() > 1 and not RunData.is_freeloader(player_index)
	_update_gold_label()
	_items_container.hide()
	_upgrades_container.show()


func _input(event):
	if not RunData.is_coop_run:
		if event.is_action_pressed("ui_info") and _discard_button.is_visible_in_tree():
			_discard_button.emit_signal("pressed")

	if _items_container.visible:
		if ChallengeService.is_challenge_completed(ChallengeService.chal_banned_items_hash) and RunData.is_ban_active_in_current_run():
			var player_run_data = RunData.players_data[player_index]
			if player_run_data.remaining_ban_token > 0:
				if Utils.is_player_ui_coop_ban_pressed(event, player_index):
					_on_BanButton_pressed()
					while is_pressing_b:
						yield(get_tree(), "physics_frame")
						_ban_button.pressed = true
				elif Utils.is_player_ui_coop_ban_released(event, player_index):
					_on_BanButton_button_up()


func show_consumable_data(consumable_data: ConsumableData):
	var item_data = ItemService.process_item_box(consumable_data, RunData.current_wave, player_index)
	_consumable_data = consumable_data
	show_item(item_data)


func show_item(item_data: ItemParentData) -> void :
	_item_data = item_data

	_item_description.set_item(item_data, player_index)
	_discard_button.text = tr("MENU_RECYCLE") + " (+" + str(ItemService.get_recycling_value(RunData.current_wave, item_data.value, player_index, item_data is WeaponData)) + ")"

	var player_run_data = RunData.players_data[player_index]
	if player_run_data.remaining_ban_token > 0:
		_ban_button_label.text = tr("MENU_BAN") + " (" + str(RunData.BAN_MAX_TOKEN - player_run_data.remaining_ban_token) + "/" + str(RunData.BAN_MAX_TOKEN) + ") (+" + str(floor(ItemService.get_recycling_value(RunData.current_wave, item_data.value, player_index, item_data is WeaponData))) + ")"
	else:
		_ban_button.visible = false

	var duplicate_item_icon = ItemService.get_icon_for_duplicate_shop_item(RunData.get_player_character(player_index), RunData.get_player_items(player_index), RunData.get_player_weapons(player_index), item_data, player_index)

	if duplicate_item_icon != null:
		
		
		
		var texture = ImageTexture.new()
		texture.create_from_image(duplicate_item_icon)
		_take_button.icon = texture
	else:
		_take_button.icon = null

	var stylebox_color = _item_panel_container.get_stylebox("panel").duplicate()
	ItemService.change_panel_stylebox_from_tier(stylebox_color, item_data.tier, false, get_node_or_null("%frame"))
	_item_panel_container.add_stylebox_override("panel", stylebox_color)

	_update_gold_label()
	_items_container.show()
	_upgrades_container.hide()


func show_remaining_things(upgrades_to_process: Array, consumables_to_process: Array) -> void :
	if _things_to_process_container == null:
		return
	for upgrade_to_process in upgrades_to_process:
		_things_to_process_container.upgrades.add_element(ItemService.get_icon(Keys.icon_upgrade_to_process_hash), upgrade_to_process.level)
	for consumable_to_process in consumables_to_process:
		_things_to_process_container.consumables.add_element(consumable_to_process.consumable_data)


func update_inventory() -> void :
	pass


func update_stats() -> void :
	pass


func finish() -> void :
	pass


func _update_gold_label() -> void :
	pass


func focus() -> void :
	if _items_container.visible:
		_take_button.call_deferred("grab_focus")
	else:
		var upgrade_ui = _upgrade_ui_2 if _upgrade_ui_2.visible else _upgrade_ui_1
		upgrade_ui.button.call_deferred("grab_focus")


func _get_upgrade_uis() -> Array:
	return [_upgrade_ui_1, _upgrade_ui_2, _upgrade_ui_3, _upgrade_ui_4] + _extra_upgrade_uis


# Gourmet DLC - grows the level-up draft to `wanted` cards for the Freeloader. Same
# approach as ShopItemsContainer._ensure_shop_item_capacity: instance the card's own
# scene (read off filename) rather than Node.duplicate(), because duplicate() copies
# signal connections and _ready has already connected the original 4.
func _ensure_upgrade_ui_capacity(wanted: int) -> void :
	var existing: = _get_upgrade_uis()

	if wanted <= existing.size():
		return

	var template = _upgrade_ui_1
	var scene_path: String = template.filename

	if scene_path == "":
		push_error("UpgradesUIPlayerContainer: cannot widen the draft, template card has no scene filename")
		return

	var packed = load(scene_path)
	var parent = template.get_parent()

	while _get_upgrade_uis().size() < wanted:
		var clone = packed.instance()
		clone.name = "UpgradeUIExtra" + str(_get_upgrade_uis().size())
		parent.add_child(clone)
		_extra_upgrade_uis.push_back(clone)
		clone.connect("choose_button_pressed", self, "_on_choose_button_pressed")

	# The authored cards size themselves for a row of 4. Let all of them expand to an
	# even share instead so 8 fit without overflowing the row.
	for upgrade_ui in _get_upgrade_uis():
		upgrade_ui.rect_min_size.x = 150
		upgrade_ui.size_flags_horizontal = SIZE_EXPAND_FILL


func _on_RerollButton_pressed() -> void :
	if RunData.get_player_gold(player_index) < _reroll_price or _button_pressed:
		return
	_button_pressed = true
	_button_delay_timer.start()
	RunData.remove_gold(_reroll_price, player_index)
	_update_gold_label()

	var spyglass_count: int = RunData.get_nb_item(Keys.item_spyglass_hash, player_index)
	if spyglass_count > 0:
		var reroll_price_amount: int = RunData.get_player_effect(Keys.reroll_price_hash, player_index)
		var spyglass_item = ItemService.get_item_from_id(Keys.item_spyglass_hash)
		var sypglass_amount: int = spyglass_item.effects[1].value
		var total_spyglass_amount = spyglass_count * sypglass_amount
		var spyglass_factor = float(total_spyglass_amount) / float(reroll_price_amount)
		RunData.add_tracked_value(player_index, Keys.item_spyglass_hash, ceil(_reroll_discount * spyglass_factor) as int)

	_reroll_count += 1
	var result = ItemService.get_reroll_price(RunData.current_wave, _reroll_count, player_index)
	_reroll_price = result[0]
	_reroll_discount = result[1]
	show_upgrades_for_level(_level)


func _on_ButtonDelayTimer_timeout() -> void :
	_button_pressed = false


func _on_choose_button_pressed(upgrade: UpgradeData) -> void :
	if _button_pressed: return
	_button_pressed = true
	_button_delay_timer.start()
	if _things_to_process_container:
		_things_to_process_container.upgrades.remove_element(_level)
	emit_signal("choose_button_pressed", upgrade)


func _on_TakeButton_pressed():
	# Gourmet DLC - Minimalist: crate items cannot be taken past the 6-item cap
	if _item_data != null and _item_data.my_id.begins_with("item_"):
		var minimalist_char = RunData.get_player_character(player_index)
		if minimalist_char != null and minimalist_char.my_id == "character_minimalist":
			var nb_items_held: = 0
			for held in RunData.get_player_items_ref(player_index):
				if held.my_id.begins_with("item_"):
					nb_items_held += 1
			if nb_items_held >= 6:
				UIService._reached_max_shake(_take_button)
				return

	if _button_pressed: return
	_button_pressed = true
	_button_delay_timer.start()
	if _things_to_process_container:
		_things_to_process_container.consumables.remove_element(_consumable_data)
	emit_signal("item_take_button_pressed", _item_data)


func _on_DiscardButton_pressed():
	if _button_pressed: return
	_button_pressed = true
	_button_delay_timer.start()
	if _things_to_process_container:
		_things_to_process_container.consumables.remove_element(_consumable_data)
	emit_signal("item_discard_button_pressed", _item_data)


func _on_BanButton_pressed():
	if ProgressData.settings.holding_button:
		is_pressing_b = true

		while true:
			_progress_ban.value += 0.025
			yield(get_tree(), "physics_frame")
			if _button_pressed: return
			if _progress_ban.value >= 1:
				_ban_button_label.modulate = Color(1, 1, 1, 1)
				break
			elif not is_pressing_b:
				_ban_button_label.modulate = Color(1, 1, 1, 1)
				_progress_ban.value = 0
				return
		_progress_ban.value = 0

		yield(UIService._ban_item_control(_item_panel_container), "completed")

	_button_pressed = true
	_button_delay_timer.start()

	if _things_to_process_container:
		if _consumable_data != null:
			_things_to_process_container.consumables.remove_element(_consumable_data)
	emit_signal("item_ban_button_pressed", _item_data)

func _on_BanButton_button_up():
	is_pressing_b = false
