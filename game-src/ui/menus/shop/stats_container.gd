class_name StatsContainer
extends PanelContainer

enum Tab{PRIMARY, SECONDARY, RULES}

signal stat_focused(stat_button, stat_title, stat_value, player_index)
signal stat_unfocused(player_index)
signal stat_hovered(stat_button, stat_title, stat_value, player_index)
signal stat_unhovered(player_index)

export (bool) var enable_stat_focus_on_button_focus: = false
export (bool) var show_buttons: = true
export (bool) var show_title: = true
export (Tab) var focused_tab: = Tab.PRIMARY
export var title: = "STATS"
export var min_height: = 780
export (bool) var loop_focus_top: = false
export (bool) var loop_focus_bottom: = false

var general_stats: Array
var primary_stats: Array
var secondary_stats: Array
var first_primary_stat: StatContainer
var last_primary_stat: StatContainer

onready var title_label = $"%StatsLabel"
onready var _buttons_container = $MarginContainer / VBoxContainer2 / HBoxContainer
onready var _primary_tab = $"%Primary" as Button
onready var _secondary_tab = $"%Secondary" as Button
onready var _general_stats = $"%GeneralStats"
onready var _primary_stats = $"%PrimaryStats"
onready var _secondary_stats = $"%SecondaryStats"


func _ready() -> void :
	title_label.text = title
	title_label.visible = show_title
	_buttons_container.visible = show_buttons
	rect_min_size.y = min_height

	for stat in ItemService.stats:
		if stat.is_dlc_stat:
			if stat.is_primary_stat:
				var dlc_stat = _primary_stats.get_child(0).duplicate()
				dlc_stat.key = stat.stat_name.to_upper()
				dlc_stat.color_override = stat.color_override
				_primary_stats.add_child(dlc_stat)
				_primary_stats.move_child(dlc_stat, 0)
				dlc_stat.init_label_focus()
			else:
				var dlc_stat = _secondary_stats.get_child(0).duplicate()
				dlc_stat.key = stat.stat_name.to_upper()
				dlc_stat.reverse = stat.reverse
				_secondary_stats.add_child(dlc_stat)
				dlc_stat.disable_focus()

	general_stats = _general_stats.get_children()
	primary_stats = _primary_stats.get_children()
	secondary_stats = _secondary_stats.get_children()
	first_primary_stat = primary_stats[0]
	last_primary_stat = primary_stats[ - 1]

	update_tab(focused_tab)

	for stat in primary_stats:
		stat.connect("focused", self, "on_stat_focused")
		stat.connect("unfocused", self, "on_stat_unfocused")
		stat.connect("hovered", self, "on_stat_hovered")
		stat.connect("unhovered", self, "on_stat_unhovered")
		stat.enable_focus()

	set_process_input(false)


func _input(event: InputEvent) -> void :
	if event is InputEventJoypadButton and show_buttons and (event.is_action_pressed("ltrigger") or event.is_action_pressed("rtrigger")):
		if focused_tab == Tab.PRIMARY:
			update_tab(Tab.SECONDARY)
		else:
			update_tab(Tab.PRIMARY)


func _notification(what):
	if what == NOTIFICATION_VISIBILITY_CHANGED:
		set_process_input(is_visible_in_tree())


# Gourmet DLC - The Special: a third tab, "Rules", sitting beside Primary and Secondary and
# listing the modifiers rolled for the NEXT wave. Built by duplicating the existing Secondary
# button so it inherits the panel's exact button styling, rather than hand-rolling a look that
# would drift from the theme. Only ever created for The Special; every other character sees the
# untouched two-tab panel.
var _rules_tab: Button
var _rules_list: VBoxContainer
var _rules_player_index: = 0


func _ensure_rules_tab(player_index: int) -> void :
	if _rules_tab != null or not RunData.is_special(player_index):
		return

	_rules_tab = _secondary_tab.duplicate(DUPLICATE_SCRIPTS)
	_rules_tab.name = "Rules"
	_rules_tab.text = "Rules"
	_buttons_container.add_child(_rules_tab)
	_rules_tab.connect("pressed", self, "_on_Rules_pressed")

	_rules_list = VBoxContainer.new()
	_rules_list.name = "RulesList"
	_rules_list.add_constant_override("separation", 6)
	_secondary_stats.get_parent().add_child(_rules_list)
	_rules_list.hide()


func _refresh_rules_list(player_index: int) -> void :
	if _rules_list == null:
		return

	for child in _rules_list.get_children():
		child.queue_free()

	var ids: Array = RunData.get_player_effect(Keys.special_next_mods_hash, player_index)

	var heading: = Label.new()
	heading.text = "NEXT WAVE" if not ids.empty() else "NEXT WAVE: CLEAR"
	heading.add_color_override("font_color", Color(0.72, 0.72, 0.72))
	_rules_list.add_child(heading)

	for id in ids:
		var mod: Dictionary = SpecialModifiers.get_by_id(id)
		if mod.empty():
			continue

		var name_label: = Label.new()
		name_label.text = mod.name
		name_label.autowrap = true
		# same colour vocabulary the rest of the game uses for good / bad / cursed
		match mod.kind:
			"good":
				name_label.add_color_override("font_color", Color(ProgressData.settings.color_positive))
			"bad":
				name_label.add_color_override("font_color", Color(ProgressData.settings.color_negative))
			_:
				name_label.add_color_override("font_color", Utils.CURSE_COLOR)
		_rules_list.add_child(name_label)

		var text_label: = Label.new()
		text_label.text = mod.text
		text_label.autowrap = true
		text_label.add_color_override("font_color", Color(0.85, 0.85, 0.85))
		_rules_list.add_child(text_label)


func update_player_stats(player_index: int) -> void :
	_rules_player_index = player_index
	_ensure_rules_tab(player_index)
	_refresh_rules_list(player_index)

	var update_stats
	if show_buttons:
		update_stats = primary_stats + secondary_stats
	elif focused_tab == Tab.PRIMARY:
		update_stats = primary_stats
	else:
		update_stats = secondary_stats
	var level_container = general_stats[0]
	level_container.player_index = player_index
	level_container.update_info(player_index)
	for stat in update_stats:
		stat.update_player_stat(player_index)


func enable_focus() -> void :
	for stat in primary_stats:
		stat.enable_focus()


func disable_focus() -> void :
	for stat in general_stats + primary_stats + secondary_stats:
		stat.disable_focus()


func on_stat_focused(stat_button, stat_title, stat_value, player_index) -> void :
	emit_signal("stat_focused", stat_button, stat_title, stat_value, player_index)


func on_stat_unfocused(player_index) -> void :
	emit_signal("stat_unfocused", player_index)


func on_stat_hovered(stat_button, stat_title, stat_value, player_index) -> void :
	emit_signal("stat_hovered", stat_button, stat_title, stat_value, player_index)


func on_stat_unhovered(player_index) -> void :
	emit_signal("stat_unhovered", player_index)


func _on_Primary_pressed() -> void :
	update_tab(Tab.PRIMARY)


func _on_Primary_focus_entered() -> void :
	if enable_stat_focus_on_button_focus:
		enable_focus()


func _on_Secondary_pressed() -> void :
	update_tab(Tab.SECONDARY)


func _on_Rules_pressed() -> void :
	update_tab(Tab.RULES)


func update_tab(tab: int) -> void :
	focused_tab = tab

	# Gourmet DLC - The Special's Rules tab. Handled before the vanilla branches so the two
	# stat lists are hidden the same way they hide each other.
	if tab == Tab.RULES and _rules_list != null:
		_set_flat(_primary_tab, false)
		_set_flat(_secondary_tab, false)
		_set_flat(_rules_tab, true)
		_general_stats.hide()
		_primary_stats.hide()
		_secondary_stats.hide()
		_refresh_rules_list(_rules_player_index)
		_rules_list.show()
		return

	if _rules_list != null:
		_rules_list.hide()
	if _rules_tab != null:
		_set_flat(_rules_tab, false)

	if tab == Tab.PRIMARY:
		_set_flat(_primary_tab, true)
		_set_flat(_secondary_tab, false)
		_general_stats.show()
		_primary_stats.show()
		_secondary_stats.hide()

	else:
		if get_focus_owner() != null and get_focus_owner().get_parent() == _primary_stats:
			_secondary_tab.grab_focus()

		_set_flat(_primary_tab, false)
		_set_flat(_secondary_tab, true)
		_secondary_stats.show()
		_general_stats.hide()
		_primary_stats.hide()

	set_focus_neighbours()

func _set_flat(button: Button, value: bool) -> void :
	
	if button.has_meta("original_flat"):
		button.set_meta("original_flat", value)
		return
	button.flat = value


func set_focus_neighbours() -> void :
	_reset_focus_neighbours()

	if focused_tab == Tab.PRIMARY:
		if loop_focus_top:
			if show_buttons:
				_primary_tab.focus_neighbour_top = _primary_tab.get_path_to(last_primary_stat)
				_secondary_tab.focus_neighbour_top = _secondary_tab.get_path_to(last_primary_stat)
			else:
				first_primary_stat.focus_neighbour_top = first_primary_stat.get_path_to(last_primary_stat)

		if loop_focus_bottom:
			if show_buttons:
				last_primary_stat.focus_neighbour_bottom = last_primary_stat.get_path_to(_primary_tab)
			else:
				last_primary_stat.focus_neighbour_bottom = last_primary_stat.get_path_to(first_primary_stat)

	
	if focus_neighbour_top:
		if show_buttons:
			_primary_tab.focus_neighbour_top = _primary_tab.get_path_to(get_node(focus_neighbour_top))
			_secondary_tab.focus_neighbour_top = _secondary_tab.get_path_to(get_node(focus_neighbour_top))
		else:
			first_primary_stat.focus_neighbour_top = first_primary_stat.get_path_to(get_node(focus_neighbour_top))
	if focus_neighbour_bottom:
		last_primary_stat.focus_neighbour_bottom = last_primary_stat.get_path_to(get_node(focus_neighbour_bottom))
	if focus_neighbour_left:
		_primary_tab.focus_neighbour_left = _primary_tab.get_path_to(get_node(focus_neighbour_left))
	if focus_neighbour_right:
		_secondary_tab.focus_neighbour_right = _secondary_tab.get_path_to(get_node(focus_neighbour_right))

	for stat in primary_stats:
		if focus_neighbour_left:
			stat.focus_neighbour_left = stat.get_path_to(get_node(focus_neighbour_left))
		if focus_neighbour_right:
			stat.focus_neighbour_right = stat.get_path_to(get_node(focus_neighbour_right))


func _reset_focus_neighbours() -> void :
	for margin in [MARGIN_TOP, MARGIN_TOP, MARGIN_LEFT, MARGIN_RIGHT]:

		if margin == MARGIN_TOP and focus_neighbour_top != NodePath(""):
			continue

		_primary_tab.set_focus_neighbour(margin, NodePath(""))
		_secondary_tab.set_focus_neighbour(margin, NodePath(""))

	for stat in primary_stats:
		stat.focus_neighbour_top = NodePath("")
		stat.focus_neighbour_bottom = NodePath("")
		stat.focus_neighbour_left = NodePath("")
		stat.focus_neighbour_right = NodePath("")
