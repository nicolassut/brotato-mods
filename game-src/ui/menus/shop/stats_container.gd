class_name StatsContainer
extends PanelContainer

enum Tab{PRIMARY, SECONDARY}

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
		# Gourmet DLC - Wildcard: his sheet opens on Rules every time it is shown
		# for a new shop. In coop the sheet is an on-demand carousel page that can be built
		# after the shop's own init call, so keying off "became visible" is the only point
		# guaranteed to happen on every screen, in both single-player and coop.
		if is_visible_in_tree():
			_maybe_default_rules()


# Gourmet DLC - The Special: a TOP-LEVEL [Stats] [Rules] toggle that replaces the panel title,
# sitting ABOVE the Primary/Secondary row. Three buttons in the Primary/Secondary row did not
# fit; this gives Rules its own level instead. Selecting Rules hides the whole stats side
# (including the Primary/Secondary row) and shows the modifiers rolled for the NEXT wave.
# Buttons are duplicated from the existing Secondary button so they inherit the panel's exact
# theme styling. Only ever created for The Special.
var _top_tabs: HBoxContainer
var _stats_top_tab: Button
var _rules_top_tab: Button
var _rules_list: VBoxContainer
var _showing_rules: = false
var _rules_player_index: = 0
# Wave stamp for the once-per-shop default. Re-asserting on every visibility change would
# fight the player: opening an item popup hides and re-shows the sheet, and the view would
# snap back to Rules mid-shop. Stamping the wave means the default lands once each shop and
# a manual switch to Stats then sticks for the rest of that visit.
var _rules_defaulted_wave: = - 1


func _ensure_rules_ui(player_index: int) -> void :
	# ONLY The Special. His rules are rerolled every wave, so they cannot live on a static
	# character card and need a live panel. Every other character's rules are fixed and belong
	# on the selection card - do not add tabs here for them.
	if _top_tabs != null or not RunData.has_wildcard_flow(player_index):
		return

	_top_tabs = HBoxContainer.new()
	_top_tabs.name = "TopTabs"
	_top_tabs.add_constant_override("separation", 8)
	_top_tabs.alignment = BoxContainer.ALIGN_CENTER

	_stats_top_tab = _secondary_tab.duplicate(DUPLICATE_SCRIPTS)
	_stats_top_tab.name = "StatsTop"
	_stats_top_tab.text = "Stats"
	_top_tabs.add_child(_stats_top_tab)

	_rules_top_tab = _secondary_tab.duplicate(DUPLICATE_SCRIPTS)
	_rules_top_tab.name = "RulesTop"
	_rules_top_tab.text = "Rules"
	_top_tabs.add_child(_rules_top_tab)

	# slot the toggle in where the "STATS" title sits, and retire the title itself
	var holder = title_label.get_parent()
	holder.add_child(_top_tabs)
	holder.move_child(_top_tabs, title_label.get_index())
	title_label.hide()

	_rules_list = VBoxContainer.new()
	_rules_list.name = "RulesList"
	_rules_list.add_constant_override("separation", 6)
	_secondary_stats.get_parent().add_child(_rules_list)
	_rules_list.hide()

	_stats_top_tab.connect("pressed", self, "_on_StatsTop_pressed")
	_rules_top_tab.connect("pressed", self, "_on_RulesTop_pressed")

	# Default view depends on the screen. On the level-up screen you are picking a stat, so
	# Stats is what you want in front of you; in the shop and the pause menu what the wave is
	# about to do matters more. Derived from the owning scene so no .tscn edit is needed.
	var owner_scene: String = owner.filename if owner != null else ""
	var on_upgrade_screen: bool = "upgrades_ui" in owner_scene
	_set_rules_mode(not on_upgrade_screen)


# Without this the new tabs are unreachable by keyboard or controller: nothing points focus at
# them, and set_focus_neighbours() would overwrite anything set once. Called from there too so
# the vanilla wiring cannot clobber it.
func _wire_top_tab_focus() -> void :
	if _top_tabs == null:
		return

	_stats_top_tab.focus_mode = Control.FOCUS_ALL
	_rules_top_tab.focus_mode = Control.FOCUS_ALL

	_stats_top_tab.focus_neighbour_right = _stats_top_tab.get_path_to(_rules_top_tab)
	_rules_top_tab.focus_neighbour_left = _rules_top_tab.get_path_to(_stats_top_tab)

	if _showing_rules:
		# the rules list holds no focusable controls, so there is nowhere below to go
		_stats_top_tab.focus_neighbour_bottom = NodePath("")
		_rules_top_tab.focus_neighbour_bottom = NodePath("")
	else:
		_stats_top_tab.focus_neighbour_bottom = _stats_top_tab.get_path_to(_primary_tab)
		_rules_top_tab.focus_neighbour_bottom = _rules_top_tab.get_path_to(_secondary_tab)
		_primary_tab.focus_neighbour_top = _primary_tab.get_path_to(_stats_top_tab)
		_secondary_tab.focus_neighbour_top = _secondary_tab.get_path_to(_rules_top_tab)


func _on_StatsTop_pressed() -> void :
	_set_rules_mode(false)


func _on_RulesTop_pressed() -> void :
	_set_rules_mode(true)


func _set_rules_mode(on: bool) -> void :
	_showing_rules = on
	if _top_tabs == null:
		return

	_set_flat(_stats_top_tab, not on)
	_set_flat(_rules_top_tab, on)

	if on:
		# hide the entire stats side, Primary/Secondary row included
		_buttons_container.hide()
		_general_stats.hide()
		_primary_stats.hide()
		_secondary_stats.hide()
		_refresh_rules_list(_rules_player_index)
		_rules_list.show()
	else:
		_rules_list.hide()
		_buttons_container.visible = show_buttons
		# restore whichever stat tab was last selected
		update_tab(focused_tab)

	_wire_top_tab_focus()


# Gourmet DLC - Wildcard: in coop the stat sheet is a per-wave, on-demand carousel page, so the
# "default to Rules in the shop" set once in _ensure_rules_ui needs re-asserting each shop. The
# coop shop container calls this from its _ready. No-op for non-Wildcard (they have no toggle).
#
# player_index MUST be passed in coop: this used to run before the sheet's own
# update_player_stats had ever set _rules_player_index, so it built (or skipped) the toggle
# against player 0 - player 2's Wildcard sheet then never got tabs at all. It also used to
# bail whenever the tabs did not exist yet, which is exactly the case when the shop calls it
# during init, making the whole call a no-op.
func open_rules_default(player_index: int = - 1) -> void :
	if player_index >= 0:
		_rules_player_index = player_index
	_ensure_rules_ui(_rules_player_index)
	if _top_tabs == null:
		return
	_rules_defaulted_wave = RunData.current_wave
	_set_rules_mode(true)


# Assert the Rules-first default at most once per shop visit. Skipped on the level-up screen,
# where you are picking a stat and want the stats in front of you.
func _maybe_default_rules() -> void :
	if _top_tabs == null:
		return
	var owner_scene: String = owner.filename if owner != null else ""
	if "upgrades_ui" in owner_scene:
		return
	if _rules_defaulted_wave == RunData.current_wave:
		return
	_rules_defaulted_wave = RunData.current_wave
	_set_rules_mode(true)


func _refresh_rules_list(player_index: int) -> void :
	if _rules_list == null:
		return

	for child in _rules_list.get_children():
		child.queue_free()

	# Which set to show is derived, not passed in: during a wave the roll has been moved into
	# special_active_mods (so the pause menu shows what is happening RIGHT NOW), and between
	# waves only special_next_mods is populated (so the shop previews what is coming). The
	# active set is filtered to wave-scoped ids, because the shop-scoped ones in that roll
	# already did their job in the shop and would be misleading listed under "this wave".
	var active: Array = Utils.special_modifiers.stored_ids(Keys.special_active_mods_hash, player_index)
	var ids: Array
	var heading_text: String

	if not active.empty():
		ids = Utils.special_modifiers.ids_of_life(active, Utils.special_modifiers.LIFE_WAVE)
		heading_text = "THIS WAVE" if not ids.empty() else "THIS WAVE IS CLEAR"
	else:
		ids = Utils.special_modifiers.stored_ids(Keys.special_next_mods_hash, player_index)
		heading_text = "NEXT WAVE" if not ids.empty() else "NEXT WAVE IS CLEAR"

	var heading: = Label.new()
	heading.text = heading_text
	heading.add_color_override("font_color", Color(0.72, 0.72, 0.72))
	_rules_list.add_child(heading)

	for id_hash in ids:
		var mod: Dictionary = Utils.special_modifiers.get_by_hash(id_hash)
		if mod.empty():
			continue

		var name_label: = Label.new()
		name_label.text = mod.name
		name_label.autowrap = true
		# the game's own colour vocabulary for good / bad / cursed
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
	_ensure_rules_ui(player_index)
	# The toggle is built lazily here, so a sheet that was ALREADY visible when this ran never
	# saw a visibility change to trigger the default. Assert it here too - the wave stamp makes
	# whichever fires first the only one that acts.
	if is_visible_in_tree():
		_maybe_default_rules()
	if _showing_rules:
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


func update_tab(tab: int) -> void :
	focused_tab = tab

	# Gourmet DLC - while the Rules view is open the stats side stays hidden; _set_rules_mode
	# calls back into here when the player switches away from it.
	if _showing_rules:
		return

	if _rules_list != null:
		_rules_list.hide()

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

	# Gourmet DLC - reassert the Stats/Rules tab wiring; the block above rewrites the
	# Primary/Secondary neighbours from the exported paths and would clobber it.
	_wire_top_tab_focus()


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
