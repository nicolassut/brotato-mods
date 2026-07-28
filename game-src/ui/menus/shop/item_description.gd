class_name ItemDescription
extends VBoxContainer

const SCROLL_SPEED: = 600.0

signal mouse_hovered_category
signal mouse_exited_category

export (PackedScene) var effect_line
export (bool) var expand_indefinitely = true
export (bool) var show_details = true
export (bool) var show_player_stats = false
export (bool) var hide_description_if_locked_in_codex: = false
export (bool) var silhouette_locked_items: = false

var item: ItemParentData
onready var icon_panel: Panel = get_node_or_null("%IconPanel")

onready var _icon: TextureRect = get_node_or_null("HBoxContainer/IconPanel/Icon")
onready var _name = get_node_or_null("%Name")
onready var _category = get_node_or_null("%Category")

onready var _vbox_container = $"%VBoxContainer" as VBoxContainer
onready var _effects = $"%Effects" as VBoxContainer
onready var _weapon_stats: RichTextLabel = get_node_or_null("%WeaponStats")
onready var _player_stat_descr_l: RichTextLabel = get_node_or_null("%PlayerStatsDescr_left")
onready var _player_stat_descr_r: RichTextLabel = get_node_or_null("%PlayerStatsDescr_right")

onready var _scroll_container = $"%ScrollContainer"
onready var _effects_scrolled = $"%Effects_scrolled" as VBoxContainer
onready var _weapon_stats_scrolled: RichTextLabel = get_node_or_null("%WeaponStats_scrolled")
onready var _player_stat_descr_scrolled_l: RichTextLabel = get_node_or_null("%PlayerStatsDescr_scrolled_left")
onready var _player_stat_descr_scrolled_r: RichTextLabel = get_node_or_null("%PlayerStatsDescr_scrolled_right")

var _player_index: = 0


func _ready() -> void :
	_vbox_container.visible = show_details and expand_indefinitely
	_scroll_container.visible = show_details and not expand_indefinitely
	set_process_input(false)

func _process(delta: float) -> void :
	_scroll_container.scroll_vertical += Utils.get_player_rjoy_vector(_player_index).y * SCROLL_SPEED * delta

func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		if is_instance_valid(_scroll_container):
			set_process(_scroll_container.visible)

func set_item(item_data: ItemParentData, player_index: int, item_count: = 1) -> void :
	item = item_data
	_player_index = player_index

	icon_panel.set_count(item_count)

	_category.show()

	_name.text = item_data.get_name_text()
	_icon.texture = item_data.get_icon()
	_name.modulate = ItemService.get_color_from_tier(item_data.tier)

	icon_panel._update_stylebox(item_data.is_cursed, item_data.tier)

	get_player_stats( - 1).visible = show_player_stats
	get_player_stats(1).visible = show_player_stats

	if show_player_stats:
		get_player_stats( - 1).bbcode_text = item_data._get_item_player_stats_description( - 1)
		get_player_stats(1).bbcode_text = item_data._get_item_player_stats_description(1)


	if item_data is DifficultyData and item_data.effects.size() == 0:
		get_effects().bbcode_text = item_data.description
	else:
		if item_data._is_locked_in_codex() and hide_description_if_locked_in_codex:
			var quantity_needed: int = item_data.unlock_codex_descr_after_get_it - item_data._get_bought_times()
			_generate_special_description_effects(Text.text("CODEX_NEED_TO_BUY_MORE", [str(quantity_needed)], [Sign.NEGATIVE]), null, true)
		else:
			_generate_description_effects(player_index, item_data.effects, true)
	get_effects().visible = get_effects().get_child_count() > 0

	if item_data is WeaponData:
		if not (hide_description_if_locked_in_codex and item_data._is_locked_in_codex()):
			get_weapon_stats().show()
			get_weapon_stats().bbcode_text = item_data.get_weapon_stats_text(player_index)
			if get_weapon_stats().bbcode_text == "":
				get_weapon_stats().hide()
			_category.text = tr(ItemService.get_weapon_sets_text(item_data.sets))
		else:
			get_weapon_stats().hide()
	else:
		get_weapon_stats().hide()
		if item_data is CharacterData:
			_category.text = tr("CHARACTER")
		elif item_data is UpgradeData:
			_category.text = tr("UPGRADE")
			icon_panel._replace_with_positive_color()
		elif item_data is DifficultyData:
			_category.text = tr("DIFFICULTY")
		else:
			var is_pet = item_data.is_pet_item()
			var is_structure = item_data.is_structure_item()
			if item_data.max_nb == 1:
				if is_pet:
					if is_structure:
						_category.text = tr("PET") + ", " + tr("STRUCTURE") + ", " + tr("UNIQUE")
					else:
						_category.text = tr("PET") + ", " + tr("UNIQUE")
				elif is_structure:
					_category.text = tr("STRUCTURE") + ", " + tr("UNIQUE")
				else:
					_category.text = tr("UNIQUE")
			elif item_data.max_nb != - 1 and item_data.max_nb != 0:
				if is_pet:
					if is_structure:
						_category.text = tr("PET") + ", " + tr("STRUCTURE") + ", " + Text.text("LIMITED", [str(RunData.get_nb_item(item_data.my_id_hash, player_index)), str(item_data.max_nb)])
					else:
						_category.text = tr("PET") + ", " + Text.text("LIMITED", [str(RunData.get_nb_item(item_data.my_id_hash, player_index)), str(item_data.max_nb)])
				elif is_structure:
					# Gourmet DLC - the food-spawner items are the only LIMITED structures, and
					# "Structure, Limited (X/Y)" overflows the fixed-width Category button, clipping
					# the (X/Y) count. Show just "Limited (X/Y)" so the limit reads properly (matches
					# every non-structure limited item, e.g. Grandma's Cookbook).
					_category.text = Text.text("LIMITED", [str(RunData.get_nb_item(item_data.my_id_hash, player_index)), str(item_data.max_nb)])
				else:
					_category.text = Text.text("LIMITED", [str(RunData.get_nb_item(item_data.my_id_hash, player_index)), str(item_data.max_nb)])
			else:
				if is_pet:
					if is_structure:
						_category.text = tr("PET") + ", " + tr("STRUCTURE")
					else:
						_category.text = tr("PET")
				elif is_structure:
					_category.text = tr("STRUCTURE")
				else:
					_category.text = tr("ITEM")

	if silhouette_locked_items and item_data._is_silhouette_in_codex():
		_icon.modulate = Color(0, 0, 0, 1)
		_name.text = "???"
		_category.text = ""
	else:
		_icon.modulate = Color(1, 1, 1, 1)

func _generate_description_effects(player_index, effects: Array, colored: bool = true, activate_tab: bool = true):
	var _effect = get_effects()

	for child in _effect.get_children():
		child.queue_free()

	for effect in effects:
		var line: EffectLine = effect_line.instance()
		_effect.add_child(line)
		line._display_effect(player_index, effect, colored, activate_tab)

	if item.tracking_text != "[EMPTY]":
		var line: EffectLine = effect_line.instance()
		_effect.add_child(line)
		line._display_special_text(item._get_tracking_text(player_index), null)

	# Gourmet DLC - food-source cards (spawner items, food weapons AND food characters
	# like Girly): append each spawned food's max buff stacks (shown once - one source's
	# foods share the cap) and how many of EACH the player has eaten this run.
	var spawner_foods: Array = _get_spawner_foods(item)
	if spawner_foods.size() > 0:
		var stack_text: String = _food_max_stacks_text(spawner_foods[0], player_index)
		if stack_text != "":
			var stack_line: EffectLine = effect_line.instance()
			_effect.add_child(stack_line)
			stack_line._display_special_text(stack_text, null)
		if player_index != RunData.DUMMY_PLAYER_INDEX and player_index < RunData.tracked_item_effects.size():
			for spawner_food in spawner_foods:
				var food_hash: int = spawner_food.get_my_id_hash()
				if RunData.tracked_item_effects[player_index].has(food_hash):
					var eaten: int = int(RunData.tracked_item_effects[player_index][food_hash])
					var eaten_line: EffectLine = effect_line.instance()
					_effect.add_child(eaten_line)
					eaten_line._display_special_text(_food_eaten_text(spawner_food, eaten), null)


# Resolve EVERY food a source spawns from its own effects (custom_key consumable_food_*).
# Returns a de-duplicated list; single-food spawners yield a one-element list (identical
# card to before), multi-food sources (Girly = Fries + Fried Rice) yield all of them.
func _get_spawner_foods(item_data) -> Array:
	var foods: = []
	if item_data == null:
		return foods
	var seen: = {}
	for effect in item_data.effects:
		if effect.custom_key.begins_with("consumable_food_"):
			var fh: int = Keys.generate_hash(effect.custom_key)
			if not seen.has(fh):
				seen[fh] = true
				var food = ItemService.get_food_from_hash(fh)
				if food != null:
					foods.push_back(food)
	return foods


# "Max buff stacks: N" - only for foods that actually grant a stacking buff. Non-stacking
# foods (buff_stacks=false, e.g. Chili) cap at 1; pure special/permanent/heal foods have no
# stacking buff and get no line.
func _food_max_stacks_text(food, player_index) -> String:
	if food.buff_stats.size() == 0 and food.wave_stats.size() == 0:
		return ""
	var max_stacks: int = 1 if not food.buff_stacks else int(food.buff_stack_cap)
	# Elastic Waistband raises the live cap; the card must show the effective value
	# (same read as the player.gd cap gates) or it would lie about the limit
	if food.buff_stacks and player_index != RunData.DUMMY_PLAYER_INDEX:
		max_stacks += int(RunData.get_player_effect(Keys.food_stack_cap_bonus_hash, player_index))
	return "[color=#" + Utils.SECONDARY_FONT_COLOR.to_html() + "]" + Text.text("FOOD_MAX_STACKS", [str(max_stacks)]) + "[/color]"


func _food_eaten_text(food, eaten: int) -> String:
	return "[color=#" + Utils.SECONDARY_FONT_COLOR.to_html() + "]" + Text.text("FOOD_EATEN", [food.name, str(eaten)]) + "[/color]"



func _generate_special_description_effects(text: String, icon: Texture = null, locked_item: bool = false):
	var _effect = get_effects()

	for child in _effect.get_children():
		child.queue_free()

	var line: EffectLine = effect_line.instance()
	_effect.add_child(line)
	line._display_special_text(text, icon, locked_item)


func set_custom_data(name: String, icon: Resource) -> void :
	_name.text = name
	_name.modulate = Color.white
	_icon.texture = icon
	_category.hide()

	get_weapon_stats().hide()
	get_effects().hide()
	item = null


func get_weapon_stats() -> RichTextLabel:
	return _weapon_stats if expand_indefinitely else _weapon_stats_scrolled


func get_player_stats(side: int = 0) -> RichTextLabel:
	if side <= 0:
		return _player_stat_descr_l if expand_indefinitely else _player_stat_descr_scrolled_l
	else:
		return _player_stat_descr_r if expand_indefinitely else _player_stat_descr_scrolled_r


func get_effects() -> VBoxContainer:
	return _effects if expand_indefinitely else _effects_scrolled


func _on_Category_mouse_entered() -> void :
	emit_signal("mouse_hovered_category")


func _on_Category_mouse_exited() -> void :
	emit_signal("mouse_exited_category")
