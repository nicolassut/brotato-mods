class_name MenuCodex
extends Popup

signal codex_closed()

const SCROLL_SPEED: = 600.0

onready var tab_challenge: ProgressionUI = $"%tab_challenges"
onready var inventory_items: Inventory = $"%InventoryItems"
onready var inventory_weapons: Inventory = $"%InventoryWeapons"
onready var inventory_enemies: Inventory = $"%InventoryEnemies"
onready var but_tier0: Button = $"%ButTier0"
onready var but_tier1: Button = $"%ButTier1"
onready var but_tier2: Button = $"%ButTier2"
onready var but_tier3: Button = $"%ButTier3"
onready var scroll_right_item: ScrollContainer = $"%scroll_right_items"
onready var scroll_right_weapons: ScrollContainer = $"%scroll_right_weapons"
onready var scroll_right_enemies: ScrollContainer = $"%scroll_right_enemies"

onready var animation_tree: AnimationTree = $AnimationTree
onready var progressbar: ProgressBar = $"%ProgressBar_codex"
onready var progressbar_label: Label = $"%Progress_label_codex"

onready var lb_texture: TextureRect = $"%lb_texture"
onready var rb_texture: TextureRect = $"%rb_texture"

onready var focus_before_created: Control = null

onready var _unlockall_icon: TextureRect = $"%unlockall_icon"

export (int) var player_index: = 0

var unlocked_items: = 0
var unlocked_weapons: = 0
var unlocked_entities: = 0



func _pop():
	unlocked_items = 0
	unlocked_weapons = 0
	unlocked_entities = 0

	focus_before_created = get_focus_owner()

	popup()
	if RunData.is_coop_run:
		Utils._popup = self

	animation_tree.set("parameters/conditions/finish", false)
	animation_tree.active = true

	tab_challenge.set_elements(true)

	lb_texture.player_index = player_index
	rb_texture.player_index = player_index

	_focus_control($"%but_tab_challenger")

	var list_of_items: Array = ItemService.items.duplicate()
	list_of_items.sort_custom(SortItem, "sort_by_tier")

	for item in list_of_items:
		if ProgressData.items_unlocked.has(item.my_id_hash):
			item.is_locked = false
		else:
			item.is_locked = true
		if ProgressData.items_bought.has(item.my_id_hash):
			unlocked_items += 1

	inventory_items.set_elements(list_of_items)
	inventory_items.on_element_focused(inventory_items.get_child(0))

	var list_of_weapons: Array = ItemService.weapons.duplicate()
	list_of_weapons.sort_custom(SortItem, "sort_by_tier")

	var list_to_remove: Array
	for weapon in list_of_weapons:
		if ProgressData.weapons_unlocked.has(weapon.weapon_id_hash):
			weapon.is_locked = false
		else:
			weapon.is_locked = true

		if weapon.previous_upgrade != null:
			list_to_remove.append(weapon)
		elif ProgressData.items_bought.has(weapon.my_id_hash):
			unlocked_weapons += 1


	for weapon in list_to_remove:
		list_of_weapons.erase(weapon)

	inventory_weapons.set_elements(list_of_weapons)
	inventory_weapons.on_element_focused(inventory_weapons.get_child(0))

	_change_color_tier_button(but_tier0, Tier.COMMON)
	_change_color_tier_button(but_tier1, Tier.UNCOMMON)
	_change_color_tier_button(but_tier2, Tier.RARE)
	_change_color_tier_button(but_tier3, Tier.LEGENDARY)

	var list_of_entities: Array = ItemService.entities.duplicate()
	var list_of_entities_id: Array = []

	for entity in list_of_entities:
		if entity._get_how_many_killed() > 0:
			unlocked_entities += 1
		if list_of_entities_id.has(entity.my_id_hash):
			list_of_entities.erase(entity)
		else:
			list_of_entities_id.append(entity.my_id_hash)
	inventory_enemies.set_elements(list_of_entities)

	inventory_enemies.on_element_focused(inventory_enemies.get_child(0))

	_unlockall_icon.visible = ProgressData.is_unlock_all_save()


func _focus_control(control: Control, player: int = 0) -> void :
	if RunData.is_coop_run:
		if RunData.is_coop_run:
			Utils.focus_player_control(control, player)
	else:
		control.grab_focus()


func _process(delta: float) -> void :
	if visible:
		if scroll_right_item.is_visible_in_tree():
			scroll_right_item.scroll_vertical += int(Utils.get_player_rjoy_vector(player_index).y * SCROLL_SPEED * delta)
		if scroll_right_weapons.is_visible_in_tree():
			scroll_right_weapons.scroll_vertical += int(Utils.get_player_rjoy_vector(player_index).y * SCROLL_SPEED * delta)
		if scroll_right_enemies.is_visible_in_tree():
			scroll_right_enemies.scroll_vertical += int(Utils.get_player_rjoy_vector(player_index).y * SCROLL_SPEED * delta)



func _change_color_tier_button(button: Button, tier: int) -> void :
	var stylebox_color = button.get_stylebox("normal").duplicate()
	ItemService.change_inventory_element_stylebox_from_tier(stylebox_color, tier, 0.25)
	button.add_stylebox_override("normal", stylebox_color)
	var stylebox_color_pressed = button.get_stylebox("pressed").duplicate()
	ItemService.change_inventory_element_stylebox_from_tier(stylebox_color_pressed, tier, 0.25)
	button.add_stylebox_override("pressed", stylebox_color_pressed)


class SortItem:
	static func tier_rank(t: int) -> int:
		# Gourmet DLC - sort along the rarity LADDER (gray, green, blue, teal,
		# purple, red, pink, gold), not by raw tier int: the modded tiers are
		# 7-10 and would otherwise all clump after the vanilla 0-3
		var ladder_order: Dictionary = {0: 0, 7: 1, 1: 2, 8: 3, 2: 4, 3: 5, 9: 6, 10: 7}
		return int(ladder_order.get(t, t + 20))

	static func sort_by_tier(a, b):
		if tier_rank(a.tier) < tier_rank(b.tier):
			return true
		return false


func _on_InventoryItems_element_pressed(element: InventoryElement):
	if element.item.is_locked:
		$"%codex_item_description".set_custom_data("???", inventory_items.locked_icon)
		return
	$"%codex_item_description".set_item(element.item, 0)


func _on_InventoryWeapons_element_pressed(element: InventoryElement):
	if element.item.is_locked:
		$"%codex_weapon_description".set_custom_data("???", inventory_weapons.locked_icon)
		return
	$"%codex_weapon_description".set_item(element.item, 0)
	var weapon: WeaponData = element.item

	_button_weapon_tier_visible(but_tier0, false)
	_button_weapon_tier_visible(but_tier1, false)
	_button_weapon_tier_visible(but_tier2, false)
	_button_weapon_tier_visible(but_tier3, false)

	
	var weapon_evolution_list: Array = [weapon]
	var next_weapon: WeaponData = weapon
	while next_weapon.upgrades_into != null:
		weapon_evolution_list.append(next_weapon.upgrades_into)
		next_weapon = next_weapon.upgrades_into
	next_weapon = weapon
	while next_weapon.previous_upgrade != null:
		weapon_evolution_list.append(next_weapon.previous_upgrade)
		next_weapon = next_weapon.previous_upgrade

	
	for w in weapon_evolution_list:
		match w.tier:
			0:
				if but_tier0.is_connected("pressed", $"%codex_weapon_description", "set_item"):
					but_tier0.disconnect("pressed", $"%codex_weapon_description", "set_item")
				but_tier0.connect("pressed", $"%codex_weapon_description", "set_item", [w, 0])
				_button_weapon_tier_visible(but_tier0)
			1:
				if but_tier1.is_connected("pressed", $"%codex_weapon_description", "set_item"):
					but_tier1.disconnect("pressed", $"%codex_weapon_description", "set_item")
				but_tier1.connect("pressed", $"%codex_weapon_description", "set_item", [w, 0])
				_button_weapon_tier_visible(but_tier1)
			2:
				if but_tier2.is_connected("pressed", $"%codex_weapon_description", "set_item"):
					but_tier2.disconnect("pressed", $"%codex_weapon_description", "set_item")
				but_tier2.connect("pressed", $"%codex_weapon_description", "set_item", [w, 0])
				_button_weapon_tier_visible(but_tier2)
			3:
				if but_tier3.is_connected("pressed", $"%codex_weapon_description", "set_item"):
					but_tier3.disconnect("pressed", $"%codex_weapon_description", "set_item")
				but_tier3.connect("pressed", $"%codex_weapon_description", "set_item", [w, 0])
				_button_weapon_tier_visible(but_tier3)


func _on_InventoryEnemies_element_pressed(element: InventoryElement):
	if element.item.is_locked:
		$"%codex_enemy_description".set_custom_data("???", inventory_enemies.locked_icon)
		return
	$"%codex_enemy_description".set_item(element.item, 0)


func _button_weapon_tier_visible(button: Button, visible: bool = true) -> void :
	button.disabled = not visible
	button.modulate = Color(1, 1, 1, 1) if visible else Color(0.5, 0.5, 0.5, 1)


func _input(event):
	if visible:
		if event.is_action_released("ui_cancel"):
			_on_BackButton_pressed()
			get_tree().set_input_as_handled()


func _on_BackButton_pressed() -> void :
	emit_signal("codex_closed")
	animation_tree.set("parameters/conditions/finish", true)
	yield(get_tree().create_timer(0.4), "timeout")
	_focus_control(focus_before_created)
	hide()
	if RunData.is_coop_run:
		Utils._popup = null
	animation_tree.active = false


func _update_progress_bar(progress: float) -> void :
	progressbar.value = progress
	progressbar_label.text = str(min(floor(progress * 100), 100)) + "%"


func _on_but_tab_challenger_pressed():
	_update_progress_bar(ProgressData.get_percent_challenges_unlocked())


func _on_but_tab_items_pressed():
	
	var count = float(inventory_items.get_child_count())
	_update_progress_bar(float(unlocked_items) / count)


func _on_but_tab_weapons_pressed():
	
	var count = float(inventory_weapons.get_child_count())
	_update_progress_bar(float(unlocked_weapons) / count)


func _on_but_tab_enemies_pressed():
	var itemServiceEntities = float(ItemService.entities.size())

	
	
	

	
	_update_progress_bar(float(unlocked_entities) / (itemServiceEntities - 3))
