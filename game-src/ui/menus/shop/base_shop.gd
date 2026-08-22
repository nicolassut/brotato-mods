class_name BaseShop
extends Control

# Gourmet DLC - P2W chest-opening ceremony overlay
const P2WReel = preload("res://ui/menus/shop/p2w_reel.gd")

export (Array, Resource) var combine_sounds
export (Array, Resource) var recycle_sounds
export var go_text: = "MENU_GO"

var _shop_items: = [[], [], [], []]
var _focused_shop_item: = [null, null, null, null]
var _latest_focused_shop_item: = [null, null, null, null]
var _player_pressed_go_button: = [false, false, false, false]

var _has_bonus_free_reroll: = [false, false, false, false]
var _reroll_price: = [0, 0, 0, 0]
var _initial_free_rerolls: = [0, 0, 0, 0]
var _free_rerolls: = [0, 0, 0, 0]
var _item_steals: = [0, 0, 0, 0]
var _reroll_count: = [0, 0, 0, 0]
var _paid_reroll_count: = [0, 0, 0, 0]
var _reroll_discount: = [0, 0, 0, 0]

onready var _pause_menu = $PauseMenu
onready var _synergy_popup: SynergyContainer = $Content / SynergyPopup
onready var _tags_popup: TagsContainer = $Content / TagsContainer
onready var _popup_manager: PopupManager = $PopupManager
onready var _background = $"%Background"
onready var _floating_text_manager: FloatingTextManagerShop = $"%FloatingTextManagerShop"
onready var _floating_texts: Node2D = $"%FloatingTexts"


func _ready() -> void :
	LinkedStats.reset()
	TempStats.reset()

	_find_nodes()

	var _error_exited_tree = self.connect("tree_exited", self, "_on_tree_exited")

	var _error_connect = _popup_manager.connect("shop_item_focused", self, "_on_shop_item_focused")
	_error_connect = _popup_manager.connect("shop_item_unfocused", self, "_on_shop_item_unfocused")

	_error_connect = _popup_manager.connect("element_focused", self, "_on_element_focused")
	_error_connect = _popup_manager.connect("element_unfocused", self, "_on_element_unfocused")
	_error_connect = _popup_manager.connect("element_pressed", self, "_on_element_pressed")

	var player_count: int = RunData.get_player_count()
	for player_index in player_count:
		_item_steals[player_index] = RunData.get_player_effect(Keys.item_steals_hash, player_index)
		var free_rerolls = RunData.get_player_effect(Keys.free_rerolls_hash, player_index)
		_initial_free_rerolls[player_index] = free_rerolls
		_free_rerolls[player_index] = free_rerolls

	if not RunData.shop_effects_checked:
		var update_stats_container: = false
		for player_index in player_count:
			if RunData.get_player_effect_bool(Keys.destroy_weapons_hash, player_index):
				RunData.remove_all_weapons(player_index)
				update_stats_container = true

		for player_index in player_count:
			var effects = RunData.get_player_effects(player_index)
			for effect in effects[Keys.upgrade_random_weapon_hash]:
				update_stats_container = true

				var possible_upgrades = []
				var weapons = RunData.get_player_weapons(player_index)
				for weapon in weapons:
					# Gourmet DLC - Anvil steps the player's tier ladder, so for the
					# Blacksmith it walks 1 -> 8 in order rather than following the
					# resource's own upgrades_into (which skips the new tiers).
					if ItemService.can_upgrade_further(weapon, player_index):
						possible_upgrades.push_back(weapon)

				if possible_upgrades.size() > 0 and not RunData.get_player_effect(Keys.lock_current_weapons_hash, player_index):
					var weapon_to_upgrade = Utils.get_rand_element(possible_upgrades)
					_combine_weapon(weapon_to_upgrade, player_index, true)
				else:
					assert (effect[0] is int)
					RunData.add_stat(effect[0], effect[1], player_index)
					RunData.add_tracked_value(player_index, Keys.item_anvil_hash, effect[1])

		if update_stats_container:
			_update_stats()

	RunData.shop_effects_checked = true

	var next_elite_wave = - 1
	var next_elite_type = EliteType.ELITE
	for elite_spawn in RunData.elites_spawn:
		if elite_spawn[0] > RunData.current_wave:
			next_elite_wave = elite_spawn[0]
			next_elite_type = elite_spawn[1]
			break

	var key = "ELITE_APPEARING" if next_elite_type == EliteType.ELITE else "HORDE_APPEARING"
	var elite_info_panel = _get_elite_info_panel(0)
	var elite_container = _get_elite_container(0)
	elite_info_panel.visible = (RunData.is_endless_run or next_elite_wave <= 20) and next_elite_wave >= 1
	elite_container.visible = next_elite_wave != - 1
	if elite_info_panel.visible:
		elite_info_panel.info_box.text = Text.text(key, [str(next_elite_wave)])
		if next_elite_wave == RunData.current_wave + 1:
			var stylebox_color = elite_info_panel.get_stylebox("panel").duplicate()
			stylebox_color.border_color = Color.gray
			elite_info_panel.add_stylebox_override("panel", stylebox_color)

	var need_to_set_locked = false
	if RunData.resumed_from_state_in_shop:
		_shop_items = ProgressData.saved_run_state.shop_items
		_reroll_count = ProgressData.saved_run_state.reroll_count
		_paid_reroll_count = ProgressData.saved_run_state.paid_reroll_count
		_initial_free_rerolls = ProgressData.saved_run_state.initial_free_rerolls
		_free_rerolls = ProgressData.saved_run_state.free_rerolls
		_item_steals = ProgressData.saved_run_state.item_steals

		RunData.resumed_from_state_in_shop = false
		need_to_set_locked = true
	else:
		for player_index in player_count:
			var player_locked_items = RunData.get_player_locked_shop_items(player_index)
			fill_shop_items(player_locked_items, player_index, true)

		if ProgressData.settings.keep_lock:
			need_to_set_locked = true
		else:
			for player_locked_items in RunData.locked_shop_items:
				player_locked_items.clear()

	for player_index in player_count:
		var result: Array = ItemService.get_reroll_price(RunData.current_wave, _paid_reroll_count[player_index], player_index)
		_reroll_price[player_index] = result[0]
		_reroll_discount[player_index] = result[1]

		_has_bonus_free_reroll[player_index] = _shop_items[player_index].empty()
		set_reroll_button_price(player_index)

	_error_connect = _pause_menu.connect("paused", self, "on_paused")
	_error_connect = _pause_menu.connect("unpaused", self, "on_unpaused")

	for player_index in player_count:
		RunData.clear_forge_pick(player_index)  # Gourmet DLC - Blacksmith: no armed pick carries into a new shop
		var weapons = RunData.get_player_weapons(player_index)
		var items = RunData.get_player_items(player_index)

		var player_gear_container = _get_gear_container(player_index)
		player_gear_container.set_weapons_data(weapons)
		player_gear_container.set_items_data(items)
		_sync_forge_weapons(player_index)  # Gourmet DLC - Blacksmith: seed the UI weapon list for forge checks

		var shop_items_container = _get_shop_items_container(player_index)
		shop_items_container.item_steals = _item_steals[player_index]
		shop_items_container.set_shop_items(_shop_items[player_index])
		_error_connect = shop_items_container.connect("shop_item_bought", self, "on_shop_item_bought", [player_index])
		_error_connect = shop_items_container.connect("shop_item_stolen", self, "on_shop_item_stolen", [player_index])
		_error_connect = shop_items_container.connect("shop_item_insufficient_currency", self, "_on_shop_item_insufficient_currency", [player_index])
		_error_connect = shop_items_container.connect("shop_item_deactivated", self, "on_shop_item_deactivated", [player_index])
		_error_connect = shop_items_container.connect("shop_item_banned", self, "on_shop_item_banned", [player_index])

		var gold_label = _get_gold_label(player_index)
		gold_label.update_value(RunData.get_player_gold(player_index))
		_update_shop_debt(player_index)  # Gourmet DLC - show the debt readout in the shop too

		var reroll_button = _get_reroll_button(player_index)
		_error_connect = reroll_button.connect("pressed", self, "_on_RerollButton_pressed", [player_index])
		# Gourmet DLC - The Freeloader cannot reroll. Hidden here and hard-guarded in
		# _on_RerollButton_pressed, so a controller shortcut cannot reach it either.
		reroll_button.visible = not RunData.is_freeloader(player_index)

		var item_popup = _get_item_popup(player_index)
		item_popup.item_steals = _item_steals[player_index]
		_error_connect = item_popup.connect("item_cancel_button_pressed", self, "_on_item_cancel_button_pressed", [player_index])
		_error_connect = item_popup.connect("item_discard_button_pressed", self, "_on_gourmet_item_discard_pressed", [player_index])
		_error_connect = item_popup.connect("item_combine_button_pressed", self, "_on_item_combine_button_pressed", [player_index])

		_popup_manager.add_item_popup(item_popup, player_index)

		var weapons_container = player_gear_container.weapons_container
		_popup_manager.connect_inventory_container(weapons_container)
		_error_connect = weapons_container._elements.connect("focus_lost", self, "_on_player_focus_lost", [player_index])
		# Gourmet DLC - Blacksmith: keep the forge's UI weapon list fresh after any buy/recycle/forge
		_error_connect = weapons_container._elements.connect("elements_changed", self, "_sync_forge_weapons", [player_index])

		var items_container = player_gear_container.items_container
		_popup_manager.connect_inventory_container(items_container)
		_error_connect = items_container._elements.connect("focus_lost", self, "_on_player_focus_lost", [player_index])

		var go_button = _get_go_button(player_index)
		_error_connect = go_button.connect("pressed", self, "_on_GoButton_pressed", [player_index])
		_error_connect = go_button.connect("focus_exited", self, "_on_GoButton_focus_exited", [player_index])
		go_button.text = tr(go_text) + " (" + Text.text("WAVE", [str(RunData.current_wave + 1)]) + ")"
		

		
		if RunData.is_coop_run:
			shop_items_container.unlock_all_shop_items_visually()

	update_go_next_button_text()

	if need_to_set_locked:
		_update_visual_locks()

	var _error_category_hovered = _get_shop_items_container(0).connect("mouse_hovered_category", self, "on_mouse_hovered_category")
	var _error_category_exited = _get_shop_items_container(0).connect("mouse_exited_category", self, "on_mouse_exited_category")

	var _error_gold = RunData.connect("gold_changed", self, "_on_gold_changed")

	for player_index in player_count:
		Utils.focus_player_control(_get_default_focus_control(player_index), player_index)

	_background.texture = ZoneService.get_zone_data(RunData.current_zone).ui_background

	ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)

func update_go_next_button_text():
	var player_count = RunData.get_player_count()

	var wave_reset_count: = 0
	for player_index in player_count:
		var effects = RunData.get_player_effects(player_index)
		var hourglass_count = effects[Keys.item_hourglass_hash] if effects.has(Keys.item_hourglass_hash) else 0
		wave_reset_count += hourglass_count

	for player_index in player_count:
		_get_go_button(player_index).text = tr(go_text) + " (" + Text.text("WAVE", [str(RunData.current_wave + 1 - wave_reset_count)]) + ")"

func _input(event: InputEvent) -> void :
	if RunData.is_streamplay_run:
		if Utils.is_player_pause_released(event, 0):
				_pause_menu.pause(0)
	else:
		for player_index in RunData.get_player_count():
			if Utils.is_player_pause_released(event, player_index):
				_pause_menu.pause(player_index)
				break

	for player_index in RunData.get_player_count():
		var shop_item = _focused_shop_item[player_index]
		if Utils.is_player_select_pressed(event, player_index) and shop_item != null:
			if _item_steals[player_index] > 0:
				shop_item.steal_item()
			if not RunData.get_player_effect_bool(Keys.disable_item_locking_hash, player_index) and shop_item.item_data.is_lockable:
				shop_item.change_lock_status( not shop_item.locked)

			if RunData.is_coop_run:
				_get_item_popup(player_index).show_shop_hints(shop_item)
			get_tree().set_input_as_handled()
		elif (
		Utils.is_player_ui_coop_ban_pressed(event, player_index)
		and shop_item != null
		and ( not shop_item.item_data is WeaponData)
		and ChallengeService.is_challenge_completed(ChallengeService.chal_banned_items_hash)) and RunData.is_ban_active_in_current_run():
			var player_run_data = RunData.players_data[player_index]
			if player_run_data.remaining_ban_token > 0 and not player_run_data.banned_items.has(shop_item.item_data.my_id_hash):
				shop_item._on_BanButton_button_down()
		elif (
		Utils.is_player_ui_coop_ban_released(event, player_index)
		and shop_item != null
		and ( not shop_item.item_data is WeaponData)):
			var player_run_data = RunData.players_data[player_index]
			if player_run_data.remaining_ban_token > 0 and not player_run_data.banned_items.has(shop_item.item_data.my_id_hash):
				shop_item._release_BanButton()
		elif (
			_player_pressed_go_button[player_index]
			and (
				Utils.is_player_cancel_pressed(event, player_index)
				or Utils.is_player_action_pressed(event, player_index, "ltrigger")
				or Utils.is_player_action_pressed(event, player_index, "rtrigger")
			)
		):
			_clear_go_button_pressed(player_index)
			get_tree().set_input_as_handled()



func on_paused() -> void :
	ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)
	$Content.hide()


func on_unpaused() -> void :
	$Content.show()


func get_player_shop_items(player_index: int) -> Array:
	return _shop_items[player_index]


func _update_visual_locks() -> void :
	unlock_all_shop_items_visually()
	for player_index in RunData.get_player_count():
		var shop_items_container = _get_shop_items_container(player_index)
		var player_shop_items = _shop_items[player_index]
		var player_locked_items = RunData.get_player_locked_shop_items(player_index)
		for locked_item in player_locked_items:
			for i in player_shop_items.size():
				if shop_items_container.is_shop_item_locked_visually(i):
					continue
				var shop_item = player_shop_items[i]
				if locked_item[0].my_id == shop_item[0].my_id:
					shop_items_container.lock_shop_item_visually(i)
					break


func _on_player_focus_lost(player_index: int) -> void :
	var focus_control = _get_reroll_button(player_index) if _reroll_price[player_index] == 0 else _get_go_button(player_index)
	Utils.focus_player_control(focus_control, player_index)


func _on_GoButton_pressed(player_index: int) -> void :
	
	
	if get_tree().paused:
		return

	if _player_pressed_go_button[player_index]:
		
		_clear_go_button_pressed(player_index)
		return

	_player_pressed_go_button[player_index] = true
	var checkmark = _get_checkmark(player_index)
	if checkmark != null:
		checkmark.show()

	
	for other_player_index in RunData.get_player_count():
		if not _player_pressed_go_button[other_player_index]:
			return

	ProgressData.save_run_state(_shop_items, _reroll_count, _paid_reroll_count, _initial_free_rerolls, _free_rerolls, _item_steals)

	
	for player_index in RunData.get_player_count():
		if RunData.get_player_effects(player_index).has(Keys.used_item_locking_hash):
			if not ChallengeService.is_challenge_completed(ChallengeService.chal_candy_bag_hash) and not RunData.get_player_effect_bool(Keys.used_item_locking_hash, player_index):
				var shop_item_containers = _get_shop_items_container(player_index)
				for shop_item in shop_item_containers._shop_items:
					if shop_item != null and shop_item.active and shop_item.locked:
						var effects = RunData.get_player_effects(player_index)
						effects[Keys.used_item_locking_hash] = 1

	var wave_reset_count: = 0
	for player_index in RunData.get_player_count():
		var effects = RunData.get_player_effects(player_index)
		var hourglass_count = effects[Keys.item_hourglass_hash] if effects.has(Keys.item_hourglass_hash) else 0
		if hourglass_count > 0:
			wave_reset_count += hourglass_count
			var source_item = RunData.get_player_item(Keys.item_hourglass_hash, player_index)
			RunData.remove_item(source_item, player_index)

		var extra_elite_spawn_chance = effects[Keys.extra_elite_next_wave_chance_hash] if effects.has(Keys.extra_elite_next_wave_chance_hash) else 0
		if Utils.get_chance_success(float(extra_elite_spawn_chance) / 100):
			var rand_elite_id = ItemService.get_random_elite_id_hash_from_zone(ZoneService.current_zone.my_id)
			effects[Keys.extra_enemies_next_wave_hash].append(["res://zones/common/elite/group_elite.tres", 1, rand_elite_id])

	RunData.current_wave += 1 - wave_reset_count
	var _error = get_tree().change_scene(MenuData.game_scene)


func _on_GoButton_focus_exited(player_index: int):
	_clear_go_button_pressed(player_index)


func _clear_go_button_pressed(player_index: int) -> void :
	_player_pressed_go_button[player_index] = false
	var checkmark = _get_checkmark(player_index)
	if checkmark != null:
		checkmark.hide()


func fill_shop_items(player_locked_items: Array, player_index: int, just_entered_shop: bool = false) -> void :
	# Gourmet DLC - P2W: every fill (shop entry, reload, reroll) first grants any
	# chest that was paid for but never opened - paid content is never lost, and no
	# armed card uid can survive into a fresh card set.
	if RunData.is_p2w(player_index):
		RunData.p2w_flush_pending(player_index)
	var player_shop_items = _shop_items[player_index]
	var prev_items = player_locked_items.duplicate() if just_entered_shop else player_shop_items.duplicate()
	_shop_items[player_index] = player_locked_items.duplicate()

	var new_item_count = ItemService.get_nb_shop_items(player_index) - player_locked_items.size()

	if new_item_count > 0:
		var args: = ItemServiceGetShopItemsArgs.new(_shop_items, player_index)
		# Gourmet ecosystem - Freeloader 8-slot / Wildcard slot-delta shop size.
		# Set here, NOT in the args class' _init: extending a Reference with a
		# required-arg _init cannot be done from a script extension.
		args.count = ItemService.get_nb_shop_items(player_index)
		args.count = new_item_count
		args.prev_items = prev_items
		args.locked_items = player_locked_items

		if not just_entered_shop:
			var increase_tier_effects: Array = RunData.get_player_effect(Keys.increase_tier_on_reroll_hash, player_index)
			for increase_tier_effect in increase_tier_effects:
				args.increase_tier = increase_tier_effect[1]
				var source_item

				for player_item in RunData.get_player_items(player_index):
					assert (increase_tier_effect[0] is int)
					if player_item.my_id_hash == increase_tier_effect[0]:
						for effect in player_item.effects:
							if effect.custom_key_hash == Keys.increase_tier_on_reroll_hash and effect.value == increase_tier_effect[1]:
								source_item = player_item
								if source_item.my_id_hash == Keys.item_goldfish_hash:
									SoundManager.play(load("res://ui/sounds/goldfish.wav"), 0, 0.2)
								break

				if not source_item:
					break

				RunData.remove_item(source_item, player_index)
				_get_gear_container(player_index).set_items_data(RunData.get_player_items(player_index))
				break

		var items_to_add = ItemService.get_player_shop_items(RunData.current_wave, player_index, args)
		_shop_items[player_index].append_array(items_to_add)
	if (RunData.forced_shop_items.size() > 0):
		for i in RunData.forced_shop_items.size():
			if (i < 4):
				_shop_items[player_index][i] = RunData.forced_shop_items[i]
		RunData.forced_shop_items.clear()


func _on_RerollButton_pressed(player_index: int) -> void :
	var player_locked_items = RunData.get_player_locked_shop_items(player_index)
	var shop_items_container = _get_shop_items_container(player_index)

	# Gourmet DLC - The Freeloader cannot reroll, by any input path.
	if RunData.is_freeloader(player_index):
		return

	if player_locked_items.size() >= ItemService.get_nb_shop_items(player_index):
		return
	# Gourmet DLC - The Debtor buys EVERYTHING on credit, rerolls included. He can never bank
	# materials, so a wallet check would lock him out of rerolling for the whole run.
	# remove_currency turns the shortfall into debt (it is the same path shop purchases use).
	if not RunData.is_debtor(player_index) and RunData.get_player_gold(player_index) < _reroll_price[player_index]:
		UIService._reached_max_shake(_get_gold_label(player_index).get_parent())
		return

	if RunData.is_debtor(player_index):
		RunData.remove_currency(_reroll_price[player_index], player_index)
	else:
		RunData.remove_gold(_reroll_price[player_index], player_index)
	LinkedStats.reset_player(player_index)

	# Gourmet DLC - Farmers' Market banks every reroll for next wave's Fruit Salads,
	# capped at 10 (each market converts up to 10 banked rerolls into Fruit Salads)
	RunData.get_player_effects(player_index)[Keys.banked_rerolls_hash] = min(10, RunData.get_player_effects(player_index)[Keys.banked_rerolls_hash] + 1)
	Utils.gourmet_tracker.ev("reroll", {"p": player_index, "bank": RunData.get_player_effect(Keys.banked_rerolls_hash, player_index)})

	for gain_stats in RunData.get_player_effect(Keys.gain_stats_on_reroll_hash, player_index):
		assert (gain_stats[0] is int)
		var chance: int = gain_stats[2]
		var stat: int = gain_stats[0]
		var stat_increase: int = gain_stats[1]
		if Utils.get_chance_success(chance / 100.0):
			RunData.add_stat(stat, stat_increase, player_index)

			var reroll_button: = _get_reroll_button(player_index)
			var pos = reroll_button.rect_global_position
			if not RunData.is_coop_run:
				pos.y += reroll_button.rect_size.y / 2
			else:
				pos.x += reroll_button.rect_size.x - 80

			_floating_text_manager.stat_added(stat, stat_increase, 0, pos)

			if stat_increase > 0:
				RunData.add_tracked_value(player_index, Keys.item_bone_dice_hash, stat_increase, 0)
			elif stat_increase < 0:
				RunData.add_tracked_value(player_index, Keys.item_bone_dice_hash, abs(stat_increase) as int, 1)

	shop_items_container.unlock_all_shop_items_visually()

	fill_shop_items(player_locked_items, player_index)

	shop_items_container.set_shop_items(_shop_items[player_index])
	for i in player_locked_items.size():
		shop_items_container.lock_shop_item_visually(i)

	_reroll_count[player_index] += 1
	if _free_rerolls[player_index] > 0 and not _has_bonus_free_reroll[player_index]:
		_free_rerolls[player_index] -= 1
		var saved_materials: int = ItemService.get_reroll_price(RunData.current_wave, _paid_reroll_count[player_index], player_index)[0]
		RunData.add_tracked_value(player_index, Keys.item_dangerous_bunny_hash, saved_materials)
	elif _has_bonus_free_reroll[player_index]:
		_has_bonus_free_reroll[player_index] = false
	else:
		var spyglass_count: int = RunData.get_nb_item(Keys.item_spyglass_hash, player_index)
		if spyglass_count > 0:
			var reroll_price_amount: int = RunData.get_player_effect(Keys.reroll_price_hash, player_index)
			var spyglass_item: ItemData = ItemService.get_item_from_id(Keys.item_spyglass_hash)
			var sypglass_amount: int = spyglass_item.effects[1].value
			var total_spyglass_amount: = spyglass_count * sypglass_amount
			var spyglass_factor: = float(total_spyglass_amount) / float(reroll_price_amount)
			RunData.add_tracked_value(player_index, Keys.item_spyglass_hash, ceil(_reroll_discount[player_index] * spyglass_factor) as int)

		_paid_reroll_count[player_index] += 1

	var result: Array = ItemService.get_reroll_price(RunData.current_wave, _paid_reroll_count[player_index], player_index)
	_reroll_price[player_index] = result[0]
	_reroll_discount[player_index] = result[1]
	set_reroll_button_price(player_index)

	_update_stats(player_index)
	shop_items_container.update_buttons_color()

	
	# The Debtor can always afford another reroll (it goes on credit), so focus must not jump
	# away from the reroll button for him.
	if not RunData.is_debtor(player_index) and RunData.get_player_gold(player_index) < _reroll_price[player_index]:
		var available_shop_item = shop_items_container.get_focus_control()
		if available_shop_item == null:
			Utils.focus_player_control(_get_go_button(player_index), player_index)

	ChallengeService.try_complete_challenge(ChallengeService.chal_unlucky_hash, _reroll_count[player_index])


func set_reroll_button_price(player_index: int) -> void :
	if _free_rerolls[player_index] > 0 or _has_bonus_free_reroll[player_index]:
		_reroll_price[player_index] = 0
	var reroll_button: = _get_reroll_button(player_index)
	reroll_button.init(_reroll_price[player_index], player_index)

	reroll_button.remove_additional_icon()
	for increase_tier_effect in RunData.get_player_effect(Keys.increase_tier_on_reroll_hash, player_index):
		var source_item: ItemData = ItemService.get_item_from_id(increase_tier_effect[0])
		var texture: ImageTexture = ImageTexture.new()
		texture.create_from_image(source_item.icon.get_data())
		reroll_button.set_additional_icon(texture)
		break


# Gourmet DLC - P2W: run the case-opening ceremony, then resolve its outcome.
# Coroutine: the shop stays alive underneath; if it is freed mid-reel (player left)
# the yield never resumes and the pending entry is granted by the next fill's flush.
# Coop skips the ceremony (a fullscreen solo reel would block the other players)
# and takes the drop directly. "cancel" (ESC before the spin) leaves the chest
# armed on its card for another go.
func _p2w_run_reel_and_open(shop_item: ShopItem, player_index: int) -> void :
	var p2w_uid: int = shop_item.p2w_pending_uid
	var p2w_entry: Dictionary = RunData.p2w_peek_pending(player_index, p2w_uid)
	if p2w_entry.empty():
		shop_item.p2w_pending_uid = - 1  # stale uid self-heal: next press buys normally
		return
	# Gourmet DLC - the ceremony runs in COOP too. It used to be skipped there (the chest just
	# granted silently) because the overlay was authored full-screen. The reel now shrinks
	# itself into the buying player's own section of the split screen.
	var outcome: String = "take"
	var reel = P2WReel.new()
	add_child(reel)
	reel.setup(p2w_entry, player_index, false, RunData.p2w_resolve_uid(player_index, p2w_uid))
	outcome = yield(reel, "reel_done")
	reel.queue_free()
	if outcome == "cancel":
		return

	var drop_data = RunData.p2w_claim_drop(player_index, p2w_uid)
	if drop_data == null:
		return
	if outcome == "recycle":
		var p2w_refund: int = ItemService.get_recycling_value(RunData.current_wave, drop_data.value, player_index, drop_data is WeaponData)
		RunData.add_gold(p2w_refund, player_index)
	elif drop_data is WeaponData:
		# route through the shop's own pipeline so the gear container updates; a
		# weapon that can neither fit nor merge converts to its shop value instead
		var p2w_slot_max: int = int(RunData.get_player_effect(Keys.weapon_slot_hash, player_index))
		var p2w_can_merge: bool = false
		for owned_weapon in RunData.get_player_weapons_ref(player_index):
			if owned_weapon.my_id == drop_data.my_id and drop_data.upgrades_into != null:
				p2w_can_merge = true
		if RunData.get_player_weapons_ref(player_index).size() < p2w_slot_max or p2w_can_merge:
			buy_weapon(drop_data, player_index)
		else:
			RunData.add_gold(drop_data.value, player_index)
	else:
		buy_item(drop_data, player_index)

	Utils.gourmet_tracker.ev("p2w_chest_open", {"p": player_index, "outcome": outcome, "got": drop_data.my_id, "cursed_chest": p2w_entry.get("cursed", false)})
	# a mirror-duplicated purchase has more chests queued: the next ceremony
	# opens immediately on the same card
	if not shop_item.p2w_extra_uids.empty():
		shop_item.p2w_pending_uid = int(shop_item.p2w_extra_uids.pop_front())
		_update_stats(player_index)
		_p2w_run_reel_and_open(shop_item, player_index)
		return
	shop_item.deactivate()
	# erase the exact opened instance; an id match could hit a same-rung twin
	# (chests share my_id per rung), eating a locked or unopened offer instead
	var p2w_erased: = false
	for p2w_offer in _shop_items[player_index]:
		if p2w_offer[0] == shop_item.item_data:
			_shop_items[player_index].erase(p2w_offer)
			p2w_erased = true
			break
	if not p2w_erased:
		for p2w_offer in _shop_items[player_index]:
			if p2w_offer[0].my_id == shop_item.item_data.my_id:
				_shop_items[player_index].erase(p2w_offer)
				break
	_update_stats(player_index)
	_get_shop_items_container(player_index).reload_shop_items()


func on_shop_item_bought(shop_item: ShopItem, player_index: int) -> void :
	# Gourmet DLC - P2W: chests buy in two stages. Press 1 pays and ARMS the card in
	# place (contents + curse already rolled and serialized by p2w_arm_chest, so a
	# save/quit cannot eat the purchase); press 2 OPENS it. buy_item is never called -
	# a chest is not a real inventory item.
	if RunData.is_p2w(player_index) and shop_item.item_data.my_id.begins_with("item_p2w_chest_"):
		if shop_item.p2w_pending_uid >= 0:
			_p2w_run_reel_and_open(shop_item, player_index)
		else:
			RunData.remove_currency(shop_item.value, player_index)
			RunData.get_player_effects(player_index)[Keys.shop_purchases_hash] += 1
			var p2w_rung: int = int(shop_item.item_data.my_id.replace("item_p2w_chest_", ""))
			var p2w_entry: Dictionary = RunData.p2w_arm_chest(player_index, p2w_rung, bool(shop_item.item_data.is_cursed))
			shop_item.p2w_arm(int(p2w_entry.uid), bool(p2w_entry.cursed))
			# Magic Mirrors duplicate chest purchases too (the card already showed
			# x2): each consumed mirror arms one EXTRA chest with its OWN roll,
			# and the ceremonies then run back-to-back
			shop_item.p2w_extra_uids = []
			var p2w_mirrors_used: = 0
			for p2w_dup_effect in RunData.get_player_effect(Keys.duplicate_item_hash, player_index).duplicate():
				for _p2w_nb in range(int(p2w_dup_effect[1])):
					var p2w_mirror = RunData.get_player_item(p2w_dup_effect[0], player_index)
					if p2w_mirror == null:
						break
					RunData.remove_item(p2w_mirror, player_index)
					p2w_mirrors_used += 1
					var p2w_extra: Dictionary = RunData.p2w_arm_chest(player_index, p2w_rung, bool(shop_item.item_data.is_cursed))
					shop_item.p2w_extra_uids.push_back(int(p2w_extra.uid))
			if p2w_mirrors_used > 0:
				_get_gear_container(player_index).set_items_data(RunData.get_player_items(player_index))
			Utils.gourmet_tracker.ev("p2w_chest_buy", {"p": player_index, "rung": p2w_rung, "cursed": p2w_entry.cursed, "paid": shop_item.value, "mirrored": p2w_mirrors_used})
			# the ceremony opens immediately (user spec); cancelling it leaves the
			# armed card behind, whose next press re-enters the ceremony above
			_p2w_run_reel_and_open(shop_item, player_index)
		return

	# Gourmet DLC - Minimalist: can hold a maximum of 6 items (P2W branch above)
	var minimalist_char = RunData.get_player_character(player_index)
	if minimalist_char != null and minimalist_char.my_id == "character_minimalist" and shop_item.item_data.get_category() == Category.ITEM:
		var nb_items_held: = 0
		for held in RunData.get_player_items_ref(player_index):
			if held is ItemData and not held is WeaponData and not held is CharacterData and held.get_category() == Category.ITEM:
				nb_items_held += 1
		if nb_items_held >= 6:
			UIService._reached_max_shake(_get_gold_label(player_index).get_parent())
			return

	for item in _shop_items[player_index]:
		if item[0].my_id == shop_item.item_data.my_id:
			_shop_items[player_index].erase(item)
			break

	RunData.remove_currency(shop_item.value, player_index)

	# Gourmet DLC - The Freeloader has now taken his one thing for this shop. Recorded as the
	# CURRENT WAVE in the serialized effects dict, so quitting and reloading cannot hand him a
	# second purchase from the same shop. Set after the purchase is committed, so a purchase
	# blocked further up never burns his pick.
	if RunData.is_freeloader(player_index):
		RunData.get_player_effects(player_index)[Keys.freeloader_shop_wave_hash] = RunData.current_wave

	# Gourmet DLC - Loyalty Card counts every completed purchase
	RunData.get_player_effects(player_index)[Keys.shop_purchases_hash] += 1

	# Gourmet DLC - Picky Eater: his first spawner auto-selects as the active one
	var picky_char = RunData.get_player_character(player_index)
	if picky_char != null and picky_char.my_id == "character_picky_eater" and shop_item.item_data is ItemData and shop_item.item_data.tags.has("spawner"):
		if RunData.get_player_effect(Keys.selected_spawner_hash, player_index) == 0:
			select_spawner(shop_item.item_data, player_index)
	Utils.gourmet_tracker.ev("purchase", {"p": player_index, "id": shop_item.item_data.my_id, "paid": shop_item.value, "base": shop_item.item_data.value, "n": RunData.get_player_effect(Keys.shop_purchases_hash, player_index)})

	# Gourmet DLC - Loyalty Card: record the materials its discount saved (coupon pattern)
	if shop_item.loyalty_saving > 0:
		RunData.add_tracked_value(player_index, Keys.generate_hash("item_loyalty_card"), shop_item.loyalty_saving)

	var nb_coupons = RunData.get_nb_item(Keys.item_coupon_hash, player_index)

	if nb_coupons > 0:
		var coupon_value = get_coupon_value(player_index)
		var coupon_effect = nb_coupons * (coupon_value / 100.0)
		var base_value = ItemService.get_value(shop_item.wave_value, shop_item.item_data.value, player_index, false, shop_item.item_data is WeaponData, shop_item.item_data.my_id_hash)
		RunData.add_tracked_value(player_index, Keys.item_coupon_hash, (base_value * coupon_effect) as int)

	var reroll_price_before: int = RunData.get_player_effect(Keys.reroll_price_hash, player_index)

	if shop_item.item_data.get_category() == Category.ITEM:
		buy_item(shop_item.item_data, player_index)
	elif shop_item.item_data.get_category() == Category.WEAPON:
		buy_weapon(shop_item.item_data, player_index)

	_update_stats(player_index)
	_get_shop_items_container(player_index).reload_shop_items()

	if shop_item.item_data.my_id_hash == Keys.item_hourglass_hash:
		update_go_next_button_text()

	
	var reroll_price_after: int = RunData.get_player_effect(Keys.reroll_price_hash, player_index)
	if _reroll_price[player_index] > 0 and reroll_price_after < reroll_price_before:
		var result: Array = ItemService.get_reroll_price(RunData.current_wave, _paid_reroll_count[player_index], player_index)
		_reroll_price[player_index] = result[0]
		_reroll_discount[player_index] = result[1]

	
	var total_free_rerolls = RunData.get_player_effect(Keys.free_rerolls_hash, player_index)
	var has_new_rerolls = total_free_rerolls > _initial_free_rerolls[player_index]
	if has_new_rerolls:
		var new_rerolls = total_free_rerolls - _initial_free_rerolls[player_index]
		_initial_free_rerolls[player_index] = total_free_rerolls
		_free_rerolls[player_index] += new_rerolls

	_has_bonus_free_reroll[player_index] = _shop_items[player_index].empty()
	set_reroll_button_price(player_index)


func on_shop_item_stolen(shop_item: ShopItem, player_index: int) -> void :
	if _item_steals[player_index] > 0:
		_item_steals[player_index] -= 1
		_get_shop_items_container(player_index).item_steals = _item_steals[player_index]
		_get_item_popup(player_index).item_steals = _item_steals[player_index]

		var effects: Dictionary = RunData.get_player_effects(player_index)
		for effect in effects[Keys.item_steals_spawns_enemy_hash]:
			var spawn_chance: int = effect[1]
			var group_data_path: String = effect[0]
			if Utils.get_chance_success(spawn_chance / 100.0):
				effects[Keys.extra_enemies_next_wave_hash].append([group_data_path, 1])

		var caught_chance = ItemService.get_chance_getting_caught(shop_item, RunData.current_wave, effects[Keys.item_steals_spawns_random_elite_hash])

		if Utils.get_chance_success(caught_chance):
			var icon = ItemService.get_element(ItemService.icons, Keys.icon_elite_hash).icon
			var popup_pos = shop_item._steal_button.rect_global_position
			var direction: Vector2

			if RunData.is_coop_run:
				popup_pos.x -= 35
				direction = Vector2(0, - 30)
			else:
				popup_pos.x += shop_item._steal_button.rect_size.x / 2.0
				direction = Vector2(25, - 100)

			_floating_text_manager.display_shop_icon(icon, popup_pos, direction)
			var rand_elite_id = ItemService.get_random_elite_id_hash_from_zone(ZoneService.current_zone.my_id)
			effects[Keys.extra_enemies_next_wave_hash].append(["res://zones/common/elite/group_elite.tres", 1, rand_elite_id])

		shop_item.value = 0
		on_shop_item_bought(shop_item, player_index)


func buy_item(item_data: ItemData, player_index: int) -> void :
	# Gourmet DLC - the Bank Loan's one-shot (+500 / +300 debt / flip to "Used") fires in
	# RunData.add_item, so it works whether the loan is bought here or granted as a starting
	# item, and cannot re-fire on reload. Nothing loan-specific is needed in this path.
	var were_items_duplicated: = false
	var duplicate_item_effects: Array = RunData.get_player_effect(Keys.duplicate_item_hash, player_index)

	# Gourmet DLC - Minimalist: mirror duplication can't push past the 6-item cap
	var minimalist_cap_char = RunData.get_player_character(player_index)
	if minimalist_cap_char != null and minimalist_cap_char.my_id == "character_minimalist":
		var minimalist_nb_held: = 0
		for held in RunData.get_player_items_ref(player_index):
			if held.my_id.begins_with("item_"):
				minimalist_nb_held += 1
		if minimalist_nb_held >= 5:
			duplicate_item_effects = []

	for duplicate_item_effect in duplicate_item_effects:
		var remaining_item_count: int = RunData.get_remaining_max_nb_item(item_data, player_index)
		var value: int = duplicate_item_effect[1]
		var normal_buy_count: = 1
		var duplicated_count: = min(value, remaining_item_count - normal_buy_count)

		for _nb in range(duplicated_count):
			were_items_duplicated = true
			var source_item = RunData.get_player_item(duplicate_item_effect[0], player_index)
			RunData.remove_item(source_item, player_index)
			RunData.add_item(item_data, player_index)

	RunData.add_item(item_data, player_index)

	var player_gear_container = _get_gear_container(player_index)
	if were_items_duplicated:
		player_gear_container.set_items_data(RunData.get_player_items(player_index))
	else:
		player_gear_container.items_container._elements.add_element(item_data, true)


func buy_weapon(item_data: WeaponData, player_index: int) -> void :
	var player_gear_container = _get_gear_container(player_index)

	# Gourmet DLC - Mime: Magic Mirrors also duplicate weapon purchases. EVERY mirror (and its
	# value) adds one extra copy, matching item duplication and consuming that mirror. Slots
	# are deliberately NOT checked here - see the cascade note below.
	if RunData.is_mime(player_index):
		# Only spend the mirrors whose copies can actually be absorbed - RunData decides, and
		# the shop gate asked the same question before enabling the buy, so the two agree.
		var wanted_copies: int = RunData.mime_max_copies_that_fit(item_data, player_index)
		var mirror_copies: = 0
		for dup_effect in RunData.get_player_effect(Keys.duplicate_item_hash, player_index):
			for _nb in range(int(dup_effect[1])):
				if mirror_copies >= wanted_copies - 1:
					break
				var source_item = RunData.get_player_item(dup_effect[0], player_index)
				if source_item == null:
					break
				RunData.remove_item(source_item, player_index)
				mirror_copies += 1
				RunData.add_tracked_value(player_index, Keys.generate_hash("character_mime"), 1)
		if mirror_copies > 0:
			player_gear_container.set_items_data(RunData.get_player_items(player_index))
			# A full inventory used to abort mirror duplication entirely (the old
			# `weapons.size() >= weapon_slot_max - 1` bail), which is backwards: a duplicate
			# is exactly what MAKES room, because two identical weapons merge into one of the
			# next tier. Add the purchase and every mirror copy first, then cascade-merge the
			# whole inventory down until it fits - "as if buying repeatedly" per the spec.
			# The result of a merge can itself pair with an existing weapon of that tier, so
			# 2xT1 -> T2 can chain into T2+T2 -> T3 in one purchase.
			for _copy in range(mirror_copies + 1):
				var copy_weapon = RunData.add_weapon(item_data, player_index)
				player_gear_container.weapons_container._elements.add_element(copy_weapon)
			_auto_merge_to_fit(item_data.weapon_id, player_index)
			# If its own line could not absorb everything (nothing left to pair with, or the
			# line is already max tier) drop the copies that do not fit rather than leaving
			# the player over their slot limit. The purchase itself always survives.
			var fit_max: = int(RunData.get_player_effect(Keys.weapon_slot_hash, player_index))
			while RunData.get_player_weapons_ref(player_index).size() > fit_max:
				var overflow = _find_lowest_weapon_in_line(item_data.weapon_id, player_index)
				if overflow == null:
					break  # nothing of this line left to shed; leave the rest to the caller
				player_gear_container.weapons_container._elements.remove_element(overflow, 1, true)
				var _dropped = RunData.remove_weapon(overflow, player_index)
				Utils.gourmet_tracker.ev("mime_copy_dropped", {"p": player_index, "id": overflow.my_id})
			_update_stats(player_index)
			_get_shop_items_container(player_index).reload_shop_items()
			_on_player_focus_lost(player_index)
			return

	if not RunData.has_weapon_slot_available(item_data, player_index):
		player_gear_container.weapons_container._elements.add_element(item_data)
		var weapons = RunData.get_player_weapons(player_index)
		for weapon in weapons:
			if weapon.my_id == item_data.my_id and item_data.upgrades_into != null:
				var _weapon = RunData.add_weapon(item_data, player_index)
				_combine_weapon(item_data, player_index, false)
				_on_player_focus_lost(player_index)
				break
	else:
		# Gourmet DLC - Blacksmith: the UI element must hold the SAME WeaponData instance
		# RunData stores (add_weapon returns a duplicate). A shop-instance element made the
		# forge pick self-heal erase a just-bought weapon's pick on the next read, so its
		# Forge press silently did nothing until the next shop rebuild resynced identities.
		var new_weapon = RunData.add_weapon(item_data, player_index)
		player_gear_container.weapons_container._elements.add_element(new_weapon)


func _on_shop_item_insufficient_currency(_shop_item: ShopItem, player_index: int) -> void :
	UIService._reached_max_shake(_get_gold_label(player_index).get_parent())


func _on_item_combine_button_pressed(weapon_data: WeaponData, player_index: int) -> void :
	if RunData.get_player_effect_bool(Keys.lock_current_weapons_hash, player_index):
		return

	# Gourmet DLC - Blacksmith: two-step manual forge. First press arms a weapon; a second
	# press on the armed weapon cancels; a press on a legal partner forges the pair. All
	# merges (including identical duplicates) go through this one path - no vanilla auto-merge.
	if RunData.has_forge_flow(player_index):
		_sync_forge_weapons(player_index)
		var pick = RunData.get_forge_pick(player_index)
		if pick == null:
			RunData.set_forge_pick(player_index, weapon_data)
			_popup_manager.reset_focus(player_index)
			_refresh_forge_visuals(player_index)
			_restore_forge_focus(weapon_data, player_index)
		elif pick == weapon_data:
			RunData.clear_forge_pick(player_index)
			_popup_manager.reset_focus(player_index)
			_refresh_forge_visuals(player_index)
			_restore_forge_focus(weapon_data, player_index)
		elif RunData.is_valid_forge_pair(pick, weapon_data, player_index):
			RunData.clear_forge_pick(player_index)
			_popup_manager.reset_focus(player_index)
			_forge_weapon(pick, weapon_data, player_index)
			_refresh_forge_visuals(player_index)
		return

	_popup_manager.reset_focus(player_index)
	_combine_weapon(weapon_data, player_index, false)


# Gourmet DLC - Blacksmith: hand keyboard/gamepad focus back to the weapon after arming or
# cancelling a forge pick. popup_manager._on_element_pressed moves focus INTO the item popup,
# and reset_focus then HIDES that popup - so on those two steps, which change no inventory and
# therefore trigger no container rebuild, focus was left on a hidden control and the player
# lost every input. Only that player froze, and only when the mouse is hidden (gamepad, i.e.
# always in couch co-op); with a visible mouse, re-hovering silently restored focus, which is
# why it looked multiplayer-only. Same guard and helper the forge COMPLETION step already
# uses at _forge_weapon (it re-focuses the new weapon), so all three steps now behave alike.
func _restore_forge_focus(weapon_data: WeaponData, player_index: int) -> void :
	if Input.get_mouse_mode() != Input.MOUSE_MODE_HIDDEN:
		return
	_get_gear_container(player_index).weapons_container._elements.focus_element(weapon_data)


# Gourmet DLC - Blacksmith forge feedback. When a weapon is armed, tint every owned weapon
# so the choice is unmistakable: armed = gold, a legal partner = green, everything else = dim.
# Also swaps the weapons-panel label to a "pick a partner" hint. Clears back to normal when
# nothing is armed. Called on every arm / cancel / forge so state is always in sync.
# Gourmet DLC - Blacksmith: hand RunData the shop's live UI weapon instances so the forge
# logic matches what the popup actually gives us (the data-side instances can differ).
func _sync_forge_weapons(player_index: int) -> void :
	var owned: = []
	for element in _get_gear_container(player_index).weapons_container._elements.get_children():
		if element is InventoryElement and element.item != null and element.item is WeaponData:
			owned.push_back(element.item)
	RunData.set_forge_owned_weapons(player_index, owned)


func _refresh_forge_visuals(player_index: int) -> void :
	var gear_container: = _get_gear_container(player_index)
	_sync_forge_weapons(player_index)
	var pick = RunData.get_forge_pick(player_index) if RunData.has_forge_flow(player_index) else null

	if pick != null:
		gear_container.weapons_container.set_label(tr("GOURMET_FORGE_HINT"))
	else:
		gear_container._on_weapons_changed()

	for element in gear_container.weapons_container._elements.get_children():
		if not (element is InventoryElement) or element.item == null or not (element.item is WeaponData):
			continue
		if pick == null:
			element.modulate = Color(1, 1, 1, 1)
		elif element.item == pick:
			element.modulate = Color(1, 0.82, 0.28, 1)   # armed weapon - gold
		elif RunData.is_valid_forge_pair(pick, element.item, player_index):
			element.modulate = Color(0.45, 1, 0.5, 1)     # legal partner - green
		else:
			element.modulate = Color(0.4, 0.4, 0.4, 1)    # can't forge with this - dim


# Gourmet DLC - Blacksmith forging: consume the pair, add a random unlocked
# next-tier weapon sharing one of their classes
func _forge_weapon(weapon_data: WeaponData, partner: WeaponData, player_index: int) -> void :
	var shared_sets: = []
	for weapon_set in weapon_data.sets:
		for partner_set in partner.sets:
			if weapon_set.my_id == partner_set.my_id:
				shared_sets.push_back(weapon_set)
	# Gourmet DLC - forge to the next LADDER step, not tier + 1. Raw +1 from vanilla
	# T4 lands on DANGER_4 (empty pool) and from T1 skips green entirely.
	# Gourmet DLC - same target rule the validity gate uses: one ladder step up, or the
	# same tier when already at the top (two golds fuse into another gold).
	var forge_pool = RunData.get_blacksmith_forge_pool(
		RunData.get_forge_target_tier(weapon_data.tier, player_index), shared_sets)
	if forge_pool.empty():
		# nothing forged, so nothing rebuilds the container - hand focus back or the
		# caller's reset_focus leaves this player with no focused control (see
		# _restore_forge_focus). Both weapons are still owned at this point.
		_restore_forge_focus(weapon_data, player_index)
		return

	var weapons_container: = _get_gear_container(player_index).weapons_container
	weapons_container._elements.remove_element(weapon_data, 1, true)
	var _removed_a = RunData.remove_weapon(weapon_data, player_index)
	weapons_container._elements.remove_element(partner, 1, true)
	var _removed_b = RunData.remove_weapon(partner, player_index)

	# Gourmet DLC - deliberately untyped: curse_item returns ItemParentData, and a
	# WeaponData-typed local would fail to accept the cursed duplicate it hands back.
	var forged = Utils.get_rand_element(forge_pool)

	# Gourmet DLC - carry the curse THROUGH the forge, the same way vanilla's
	# _combine_weapon does for an ordinary merge. Without this the forge silently
	# laundered curses away, making it a free curse-removal service. The factor is the
	# max across both ingredients and their effects, so when both are cursed the higher
	# one wins and the other's is discarded - matching vanilla's merge behaviour.
	var forge_curse_factor: = 0.0
	var forge_is_cursed: = false
	for ingredient in [weapon_data, partner]:
		if ingredient != null and ingredient.is_cursed:
			forge_is_cursed = true
			forge_curse_factor = max(forge_curse_factor, ingredient.curse_factor)
			for curse_effect in ingredient.effects:
				forge_curse_factor = max(forge_curse_factor, curse_effect.curse_factor)

	if forge_is_cursed:
		for dlc_id in RunData.enabled_dlcs:
			var dlc_data = ProgressData.get_dlc_data(dlc_id)
			if dlc_data and dlc_data.has_method("curse_item"):
				forged = dlc_data.curse_item(forged, player_index, false, forge_curse_factor)

	var new_weapon = RunData.add_weapon(forged, player_index)
	RunData.add_tracked_value(player_index, Keys.generate_hash("character_blacksmith"), 1)
	Utils.gourmet_tracker.ev("blacksmith_forge", {"p": player_index, "a": weapon_data.my_id, "b": partner.my_id, "out": forged.my_id})

	_update_stats(player_index)
	_get_shop_items_container(player_index).reload_shop_items()
	weapons_container._elements.add_element(new_weapon)
	if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		weapons_container._elements.focus_element(new_weapon)
	SoundManager.play(Utils.get_rand_element(combine_sounds), 0, 0.1, true)



# Gourmet DLC - Mime: merge duplicate weapons until the inventory is back within its slot
# limit. Each pass merges the LOWEST-tier duplicate pair, because merging low first is what
# lets a result cascade: 2xT1 Stick -> T2 Stick, which then pairs with an existing T2 Stick
# -> T3. Merging high first would strand the low pair. Purely a fitting operation - it stops
# the moment the inventory fits, so an under-capacity Mime still merges only when vanilla
# would. Bounded by a hard iteration cap as well as by the pair search failing, since this
# runs inside a shop interaction and must never hang the UI.
const MIME_MAX_CASCADE_MERGES: = 32

func _auto_merge_to_fit(weapon_id: String, player_index: int) -> void :
	var slot_max: = int(RunData.get_player_effect(Keys.weapon_slot_hash, player_index))
	var merges: = 0
	while RunData.get_player_weapons_ref(player_index).size() > slot_max:
		if merges >= MIME_MAX_CASCADE_MERGES:
			break
		var pair_seed = _find_lowest_mergeable_weapon(weapon_id, player_index)
		if pair_seed == null:
			break
		merges += 1
		_combine_weapon(pair_seed, player_index, false)
	if merges > 0:
		Utils.gourmet_tracker.ev("mime_cascade_merge", {"p": player_index, "id": weapon_id, "n": merges})


# Returns the lowest-tier weapon IN THE BOUGHT WEAPON'S OWN LINE that has an identical
# partner it can upgrade with, or null. Restricted to weapon_id (the untiered id, so every
# Stick tier qualifies but nothing else) because a purchase must never silently consume an
# unrelated pair - buying a Stick should not merge away two Galley Cannons to make room.
# Lowest tier first: merging low is what lets the result cascade (2xT1 -> T2, then that T2
# pairs with an owned T2 -> T3). Reads the UI element list rather than RunData because that
# is what _combine_weapon operates on, and the two must agree on instance identity (see the
# Blacksmith note in buy_weapon).
func _find_lowest_mergeable_weapon(weapon_id: String, player_index: int):
	var weapons_container: = _get_gear_container(player_index).weapons_container
	var owned: = []
	for element in weapons_container._elements.get_children():
		owned.push_back(element.item)

	var tier_cap: int = int(RunData.get_player_effect(Keys.max_weapon_tier_hash, player_index))
	var best = null
	for i in owned.size():
		var candidate = owned[i]
		if candidate == null or candidate.weapon_id != weapon_id or candidate.upgrades_into == null:
			continue
		# match RunData._mime_copies_fit exactly, or the shop promises merges the cascade
		# then refuses to perform
		if candidate.upgrades_into.tier > tier_cap:
			continue
		if best != null and candidate.tier >= best.tier:
			continue
		for j in range(owned.size()):
			if j != i and owned[j] != null and owned[j].my_id == candidate.my_id:
				best = candidate
				break
	return best


# Lowest-tier weapon of a line regardless of whether it can pair. Used only to shed copies
# that the cascade could not absorb (e.g. buying into an inventory full of OTHER weapons: the
# two new copies merge once and then have nothing left to pair with). Sheds the least
# valuable copy, never a merge result the player earned.
func _find_lowest_weapon_in_line(weapon_id: String, player_index: int):
	var best = null
	for element in _get_gear_container(player_index).weapons_container._elements.get_children():
		var owned = element.item
		if owned == null or owned.weapon_id != weapon_id:
			continue
		if best == null or owned.tier < best.tier:
			best = owned
	return best


func _combine_weapon(weapon_data: WeaponData, player_index: int, is_upgrade: bool) -> void :
	var nb_to_remove = 2
	var removed_weapons_tracked_value = 0
	var curse_new_weapon = false
	var new_cursed_weapon_min_factor = 0.0

	if is_upgrade:
		nb_to_remove = 1

	var weapons_container: = _get_gear_container(player_index).weapons_container
	weapons_container._elements.remove_element(weapon_data, 1, true)
	removed_weapons_tracked_value += RunData.remove_weapon(weapon_data, player_index)

	var existing_weapon_to_remove

	if nb_to_remove == 2:

		var existing_weapons = []

		for element in weapons_container._elements.get_children():
			existing_weapons.push_back(element.item)

		
		existing_weapons.erase(weapon_data)

		for weapon in existing_weapons:
			if weapon.my_id == weapon_data.my_id:
				existing_weapon_to_remove = weapon

				
				if ( not weapon_data.is_cursed and weapon.is_cursed) or (weapon_data.is_cursed and not weapon.is_cursed):
					break

		weapons_container._elements.remove_element(existing_weapon_to_remove, 1, true)
		removed_weapons_tracked_value += RunData.remove_weapon(existing_weapon_to_remove, player_index)

	if weapon_data.is_cursed or (existing_weapon_to_remove and existing_weapon_to_remove.is_cursed):
		curse_new_weapon = true

	if weapon_data.is_cursed:
		new_cursed_weapon_min_factor = weapon_data.curse_factor
		for effect in weapon_data.effects:
			new_cursed_weapon_min_factor = max(new_cursed_weapon_min_factor, effect.curse_factor)

	if existing_weapon_to_remove and existing_weapon_to_remove.is_cursed:
		new_cursed_weapon_min_factor = max(new_cursed_weapon_min_factor, existing_weapon_to_remove.curse_factor)
		for effect in existing_weapon_to_remove.effects:
			new_cursed_weapon_min_factor = max(new_cursed_weapon_min_factor, effect.curse_factor)

	# Gourmet DLC - one ladder step for this player. Drives BOTH the Anvil and the
	# shop's auto-merge, since both funnel through _combine_weapon.
	var weapon_to_upgrade_into = ItemService.get_upgrade_target(weapon_data, player_index)

	if curse_new_weapon:
		for dlc_id in RunData.enabled_dlcs:
			var dlc_data = ProgressData.get_dlc_data(dlc_id)
			if dlc_data and dlc_data.has_method("curse_item"):
				weapon_to_upgrade_into = dlc_data.curse_item(weapon_to_upgrade_into, player_index, false, new_cursed_weapon_min_factor)

	var new_weapon = RunData.add_weapon(weapon_to_upgrade_into, player_index)

	new_weapon.tracked_value = removed_weapons_tracked_value

	if is_upgrade:
		new_weapon.dmg_dealt_last_wave = weapon_data.dmg_dealt_last_wave

	_update_stats(player_index)
	_get_shop_items_container(player_index).reload_shop_items()

	weapons_container._elements.add_element(new_weapon)

	if Input.get_mouse_mode() == Input.MOUSE_MODE_HIDDEN:
		weapons_container._elements.focus_element(new_weapon)

	SoundManager.play(Utils.get_rand_element(combine_sounds), 0, 0.1, true)


# Gourmet DLC - Minimalist: items recycle exactly like weapons
# Gourmet DLC - mark a spawner as the selected one (its food id hash goes into
# the selected_spawner effect; the spawner is identified via its food-text
# effect's custom_key, which every spawner carries)
func select_spawner(item_data: ItemData, player_index: int) -> void :
	for selection_effect in item_data.effects:
		if selection_effect.custom_key.begins_with("consumable_food_"):
			RunData.get_player_effects(player_index)[Keys.selected_spawner_hash] = Keys.generate_hash(selection_effect.custom_key)
			Utils.gourmet_tracker.ev("spawner_selected", {"p": player_index, "id": item_data.my_id})
			# Gourmet DLC - Set Menu is consumed on use; Picky Eater picks for free via his trait
			var spawner_char = RunData.get_player_character(player_index)
			var picks_for_free: bool = spawner_char != null and spawner_char.my_id == "character_picky_eater"
			if not picks_for_free:
				_consume_one_set_menu(player_index)
			var selection_popup = _get_item_popup(player_index)
			selection_popup.hide()
			_popup_manager.reset_focus(player_index)
			return


# Gourmet DLC - remove one Set Menu from the inventory (used when it sets a daily special)
func _consume_one_set_menu(player_index: int) -> void :
	var set_menu_item = RunData.get_player_item(Keys.generate_hash("item_set_menu"), player_index)
	if set_menu_item == null:
		return
	var items_container: = _get_gear_container(player_index).items_container
	items_container._elements.remove_element(set_menu_item, 1, true)
	RunData.remove_item(set_menu_item, player_index)
	_update_stats(player_index)
	_get_shop_items_container(player_index).reload_shop_items()


func recycle_minimalist_item(item_data: ItemData, player_index: int) -> void :
	_popup_manager.reset_focus(player_index)
	RunData.add_recycled(player_index)

	var items_container = _get_gear_container(player_index).items_container
	items_container._elements.remove_element(item_data, 1, true)
	RunData.remove_item(item_data, player_index)

	var recycling_value = ItemService.get_recycling_value(RunData.current_wave, item_data.value, player_index, true)
	RunData.add_gold(recycling_value, player_index)
	# Gourmet DLC - item recycling is the Minimalist's alone, and it is the run-long payout
	# his card advertises; credit it to him so the materials are actually visible somewhere.
	var recycle_char = RunData.get_player_character(player_index)
	if recycle_char != null and recycle_char.my_id == "character_minimalist":
		RunData.add_tracked_value(player_index, recycle_char.get_my_id_hash(), recycling_value)

	SoundManager.play(Utils.get_rand_element(recycle_sounds), 0, 0.1, true)
	_update_stats(player_index)
	_get_shop_items_container(player_index).reload_shop_items()


func _on_item_discard_button_pressed(weapon_data: WeaponData, player_index: int) -> void :
	if RunData.get_player_effect_bool(Keys.lock_current_weapons_hash, player_index):
		return

	_popup_manager.reset_focus(player_index)
	RunData.add_recycled(player_index)

	var weapons_container: = _get_gear_container(player_index).weapons_container
	weapons_container._elements.remove_element(weapon_data, 1, true)

	var _weapon = RunData.remove_weapon(weapon_data, player_index)
	var base_recycling_value = weapon_data.value
	var specific_recycling_price_factor = 1.0

	for specific_item_price in RunData.get_player_effect(Keys.specific_items_price_hash, player_index):
		assert (specific_item_price[0] is int)
		if Keys.hash_to_string[specific_item_price[0]] in weapon_data.my_id:
			specific_recycling_price_factor = specific_item_price[1]
			break

	base_recycling_value *= specific_recycling_price_factor

	var recycling_value = ItemService.get_recycling_value(RunData.current_wave, base_recycling_value, player_index, true)
	RunData.add_gold(recycling_value, player_index)
	RunData.update_recycling_tracking_value(weapon_data, player_index)

	var nb_coupons = RunData.get_nb_item(Keys.item_coupon_hash, player_index)

	if nb_coupons > 0:
		var base_value = ItemService.get_recycling_value(RunData.current_wave, weapon_data.value, player_index, true, false)
		var actual_value = ItemService.get_recycling_value(RunData.current_wave, weapon_data.value, player_index, true)
		var val_lost = (base_value - actual_value) as int
		RunData.add_tracked_value(player_index, Keys.item_coupon_hash, - val_lost)

	_update_stats(player_index)
	_get_shop_items_container(player_index).reload_shop_items()
	var reroll_button = _get_reroll_button(player_index)
	reroll_button.set_color_from_currency(RunData.get_player_gold(player_index))
	SoundManager.play(Utils.get_rand_element(recycle_sounds), 0, 0.1, true)


# Gourmet ecosystem - discard works on ANY item, not just weapons. New name +
# new signature: the vanilla _on_item_discard_button_pressed(WeaponData, int)
# stays untouched (extension-sandwich rule), the popup connect targets this.
func _on_gourmet_item_discard_pressed(weapon_data: ItemParentData, player_index: int) -> void :
	# Gourmet DLC - spawner selection (Set Menu / Picky Eater) rides the same button;
	# Minimalist keeps recycling instead
	var selection_char = RunData.get_player_character(player_index)
	var minimalist_selection: bool = selection_char != null and selection_char.my_id == "character_minimalist"
	if not minimalist_selection and weapon_data is ItemData and not weapon_data is WeaponData and weapon_data.tags.has("spawner"):
		var is_picky: bool = selection_char != null and selection_char.my_id == "character_picky_eater"
		if is_picky or RunData.get_player_effect(Keys.set_menu_hash, player_index) > 0:
			select_spawner(weapon_data, player_index)
			return

	# Gourmet DLC - Minimalist: non-weapon items recycle through the same menu
	if not weapon_data is WeaponData:
		recycle_minimalist_item(weapon_data, player_index)
		return

	if RunData.get_player_effect_bool(Keys.lock_current_weapons_hash, player_index):
		return

	_popup_manager.reset_focus(player_index)
	RunData.add_recycled(player_index)

	var weapons_container: = _get_gear_container(player_index).weapons_container
	weapons_container._elements.remove_element(weapon_data, 1, true)

	var _weapon = RunData.remove_weapon(weapon_data, player_index)
	var base_recycling_value = weapon_data.value
	var specific_recycling_price_factor = 1.0

	for specific_item_price in RunData.get_player_effect(Keys.specific_items_price_hash, player_index):
		assert (specific_item_price[0] is int)
		if Keys.hash_to_string[specific_item_price[0]] in weapon_data.my_id:
			specific_recycling_price_factor = specific_item_price[1]
			break

	base_recycling_value *= specific_recycling_price_factor

	var recycling_value = ItemService.get_recycling_value(RunData.current_wave, base_recycling_value, player_index, true)
	RunData.add_gold(recycling_value, player_index)
	RunData.update_recycling_tracking_value(weapon_data, player_index)

	var nb_coupons = RunData.get_nb_item(Keys.item_coupon_hash, player_index)

	if nb_coupons > 0:
		var base_value = ItemService.get_recycling_value(RunData.current_wave, weapon_data.value, player_index, true, false)
		var actual_value = ItemService.get_recycling_value(RunData.current_wave, weapon_data.value, player_index, true)
		var val_lost = (base_value - actual_value) as int
		RunData.add_tracked_value(player_index, Keys.item_coupon_hash, - val_lost)

	_update_stats(player_index)
	_get_shop_items_container(player_index).reload_shop_items()
	var reroll_button = _get_reroll_button(player_index)
	reroll_button.set_color_from_currency(RunData.get_player_gold(player_index))
	SoundManager.play(Utils.get_rand_element(recycle_sounds), 0, 0.1, true)


func _on_item_cancel_button_pressed(item_data: ItemParentData, player_index: int) -> void :
	_popup_manager.reset_focus(player_index)
	if $Content.visible:
		var inventory_container
		if item_data is WeaponData:
			inventory_container = _get_gear_container(player_index).weapons_container
		else:
			inventory_container = _get_gear_container(player_index).items_container
		inventory_container._elements.focus_element(item_data)


func get_coupon_value(player_index: int) -> int:
	var coupon_value = 0
	var items = RunData.get_player_items(player_index)
	for item in items:
		
		
		if item.my_id_hash == Keys.item_coupon_hash:
			coupon_value = abs(item.effects[0].value)
			break
	return coupon_value


func unlock_all_shop_items_visually() -> void :
	for player_index in RunData.get_player_count():
		var shop_items_container = _get_shop_items_container(player_index)
		shop_items_container.unlock_all_shop_items_visually()


func on_mouse_hovered_category(shop_item: ShopItem) -> void :
	show_shop_item_synergies(shop_item)
	show_shop_item_tags(shop_item)


func on_mouse_exited_category(shop_item: ShopItem) -> void :
	hide_synergies(shop_item)
	hide_tags(shop_item)


func on_shop_item_deactivated(shop_item: ShopItem, player_index: int) -> void :
	var focused_shop_item = _focused_shop_item[player_index]
	if focused_shop_item == null or shop_item == focused_shop_item:
		Utils.focus_player_control(_get_default_focus_control(player_index), player_index)


func _get_default_focus_control(player_index: int) -> Control:
	var shop_items_container = _get_shop_items_container(player_index)
	var shop_item = shop_items_container.get_focus_control(_latest_focused_shop_item[player_index])
	if shop_item != null:
		return shop_item
	
	
	if _reroll_price[player_index] == 0 or (RunData.is_coop_run and _reroll_price[player_index] <= RunData.get_player_gold(player_index)):
		return _get_reroll_button(player_index)
	return _get_go_button(player_index)


func show_shop_item_synergies(shop_item: ShopItem) -> void :
	if shop_item.item_data is WeaponData:
		_synergy_popup.show()
		
		_synergy_popup.set_synergies_text(shop_item.item_data, 0)
		_synergy_popup.set_pos_from(shop_item)


func hide_synergies(shop_item: ShopItem) -> void :
	if shop_item.item_data is WeaponData:
		_synergy_popup.hide()


func show_shop_item_tags(shop_item: ShopItem) -> void :
	if shop_item.item_data is ItemData:
		_tags_popup.show()
		
		_tags_popup.set_tags_text(shop_item.item_data, 0)
		_tags_popup.set_pos_from(shop_item)


func hide_tags(shop_item: ShopItem) -> void :
	if shop_item.item_data is ItemData:
		_tags_popup.hide()


func _on_gold_changed(new_value: int, player_index: int) -> void :
	var gold_label = _get_gold_label(player_index)
	gold_label.update_value(new_value)
	_update_shop_debt(player_index)


# Gourmet DLC - the shop's gold label is a plain Label (no per-part colour), so the debt is
# shown as a separate red Label created once beside it, mirroring the battle HUD. Reads the
# gold label's own font so the two match. Hidden when not in debt.
func _update_shop_debt(player_index: int) -> void :
	var gold_label = _get_gold_label(player_index)
	if gold_label == null:
		return
	var parent = gold_label.get_parent()
	if parent == null:
		return
	var debt_label: Label = parent.get_node_or_null("GourmetDebtLabel")
	if debt_label == null:
		debt_label = Label.new()
		debt_label.name = "GourmetDebtLabel"
		var gold_font = gold_label.get("custom_fonts/font")
		if gold_font != null:
			debt_label.set("custom_fonts/font", gold_font)
		debt_label.add_color_override("font_color", Color(1, 0.27, 0.27, 1))
		parent.add_child(debt_label)
		parent.move_child(debt_label, gold_label.get_index() + 1)
	var debt: int = RunData.get_player_debt(player_index)
	debt_label.visible = debt > 0
	debt_label.text = " -" + str(debt) if debt > 0 else ""


func _on_shop_item_focused(shop_item: ShopItem, player_index: int) -> void :
	_focused_shop_item[player_index] = shop_item
	_latest_focused_shop_item[player_index] = shop_item


func _on_shop_item_unfocused(shop_item: ShopItem, player_index: int) -> void :
	if _focused_shop_item[player_index] == shop_item:
		_focused_shop_item[player_index] = null

func on_shop_item_banned(shop_item: ShopItem, player_index: int) -> void :
	for item in _shop_items[player_index]:
		if item[0].my_id_hash == shop_item.item_data.my_id_hash:
			_shop_items[player_index].erase(item)
			break

	_has_bonus_free_reroll[player_index] = _shop_items[player_index].empty()
	set_reroll_button_price(player_index)

func _on_tree_exited() -> void :
	# Gourmet DLC - The Special: strip the NEXT-SHOP scoped modifiers now that the shop they
	# were rolled for is closing. These are the second lifetime: they are applied at wave end
	# so they are live while shopping, and removed here. Tearing them down at wave end with
	# the wave-scoped ones would have made every shop modifier silently do nothing.
	for special_index in RunData.get_player_count():
		if not RunData.has_wildcard_flow(special_index):
			continue
		var sp_effects: Dictionary = RunData.get_player_effects(special_index)
		var shop_ids: Array = Utils.special_modifiers.stored_ids(Keys.special_shop_mods_hash, special_index)
		if not shop_ids.empty():
			Utils.special_modifiers.unapply_ids(shop_ids, special_index)
			sp_effects[Keys.special_shop_mods_hash] = []

	for player_index in range(RunData.get_player_count()):
		var curse_locked_items: int = RunData.get_player_effect(Keys.curse_locked_items_hash, player_index)
		var has_cursed_an_item = false
		var nb_locked_items_that_didnt_get_cursed: int = 0
		var locked_items: Array = RunData.locked_shop_items[player_index]
		var randomized_positions = []

		for i in locked_items.size():
			randomized_positions.push_back(i)

		randomized_positions.shuffle()

		for i in randomized_positions:
			if not locked_items[i][0].is_cursed and Utils.get_chance_success((RunData.players_data[player_index].curse_locked_shop_items_pity + curse_locked_items) / 100.0):
				for dlc_id in RunData.enabled_dlcs:
					var dlc_data = ProgressData.get_dlc_data(dlc_id)
					if dlc_data and dlc_data.has_method("curse_item"):
						has_cursed_an_item = true
						RunData.players_data[player_index].curse_locked_shop_items_pity = 0
						RunData.set_tracked_value(player_index, Keys.item_fish_hook_hash, RunData.players_data[player_index].curse_locked_shop_items_pity)
						locked_items[i][0] = dlc_data.curse_item(locked_items[i][0], player_index)
			elif not locked_items[i][0].is_cursed:
				nb_locked_items_that_didnt_get_cursed += 1

		if curse_locked_items > 0 and locked_items.size() > 0 and not has_cursed_an_item and nb_locked_items_that_didnt_get_cursed > 0:
			RunData.players_data[player_index].curse_locked_shop_items_pity += int(nb_locked_items_that_didnt_get_cursed * (curse_locked_items / 4.0))
			RunData.set_tracked_value(player_index, Keys.item_fish_hook_hash, RunData.players_data[player_index].curse_locked_shop_items_pity)


func _on_element_focused(_element: InventoryElement, _player_index: int) -> void :
	pass


func _on_element_unfocused(_element: InventoryElement, _player_index: int) -> void :
	pass


func _on_element_pressed(_element: InventoryElement, _player_index: int, _popup_focused: bool) -> void :
	pass


func _update_stats(_player_index: = - 1) -> void :
	
	pass


func _find_nodes() -> void :
	
	pass


func _get_shop_items_container(_player_index: int) -> ShopItemsContainer:
	
	return null


func _get_gear_container(_player_index: int) -> PlayerGearContainer:
	
	return null


func _get_gold_label(_player_index: int) -> Control:
	
	return null


func _get_checkmark(_player_index: int) -> Control:
	
	return null


func _get_reroll_button(_player_index: int) -> Control:
	
	return null


func _get_go_button(_player_index: int) -> Control:
	
	return null


func _get_item_popup(_player_index: int) -> ItemPopup:
	
	return null


func _get_elite_info_panel(_player_index: int) -> EliteInfoPanel:
	
	return null


func _get_elite_container(_player_index: int) -> Container:
	
	return null


func add_floating_text(instance: Node) -> void :
	_floating_texts.add_child(instance)
