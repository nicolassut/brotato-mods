extends HBoxContainer

# Gourmet DLC - per-player HUD grid of active food buffs (icon + stacks + seconds left).
# Instanced from main.gd under the player's life container each wave. Polls the
# player's _food_buffs dict every frame; the dict holds a handful of entries at
# most so a straight poll is cheaper than a signal protocol.
#
# Layout law (user 2026-08-13): chips stack VERTICALLY, at most COLUMN_MAX per
# column, then wrap into a new column beside it - the display stays a compact
# block instead of a row marching across the screen into another player's UI.
# Bottom-screen players (positions 2/3) grow UPWARD: their bars sit at the
# bottom, so columns bottom-align and new chips stack on top.

const COLUMN_MAX: = 10

var player = null
var grow_up: bool = false

var _chips: = {}
var _order: = []
var _columns: = []
var _font = preload("res://resources/fonts/actual/base/font_26_outline.tres")


func _process(_delta: float) -> void :
	if player == null or not is_instance_valid(player) or player.cleaning_up:
		visible = false
		return

	# Gourmet DLC - render food buffs AND item-buff chips (Sugar Rush) in one grid. They live in
	# separate dicts on the player because _food_buffs.size() drives Full Belly and Food Coma,
	# so the chips must not be mixed into it. Merged here purely for display.
	var buffs: = {}
	for food_id in player._food_buffs:
		buffs[food_id] = player._food_buffs[food_id]
	for item_id in player._item_buff_chips:
		buffs[item_id] = player._item_buff_chips[item_id]

	visible = buffs.size() > 0

	var membership_changed: bool = false
	for food_id in buffs:
		var buff: Dictionary = buffs[food_id]
		if not _chips.has(food_id):
			_chips[food_id] = _make_chip(buff["icon"])
			_order.push_back(food_id)
			membership_changed = true
		# Rest-of-wave buffs carry no "timer" key: show the stack count with no seconds.
		if buff.has("timer"):
			var time_left: int = int(ceil(buff["timer"].time_left))
			_chips[food_id].get_node("Label").text = "x%s %ss" % [buff["stacks"], time_left]
		else:
			_chips[food_id].get_node("Label").text = "x%s" % buff["stacks"]

	for food_id in _chips.keys():
		if not buffs.has(food_id):
			_chips[food_id].queue_free()
			var _erased = _chips.erase(food_id)
			_order.erase(food_id)
			membership_changed = true

	if membership_changed:
		_reflow()


# Chips are created detached; _reflow owns their placement into columns.
func _make_chip(icon: Texture) -> Control:
	var chip: = HBoxContainer.new()

	var texture_rect: = TextureRect.new()
	texture_rect.texture = icon
	texture_rect.rect_min_size = Vector2(32, 32)
	texture_rect.expand = true
	texture_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	chip.add_child(texture_rect)

	var label: = Label.new()
	label.name = "Label"
	label.add_font_override("font", _font)
	label.valign = Label.VALIGN_CENTER
	chip.add_child(label)

	return chip


# Rebuild the column layout from _order: detach every live chip, drop the old
# columns, deal chips back out COLUMN_MAX at a time. For grow_up players each
# chip is prepended so the column reads bottom-to-top (newest on top) and the
# column bottom-aligns against the player's UI.
func _reflow() -> void :
	for food_id in _order:
		var chip: Control = _chips[food_id]
		if chip.get_parent() != null:
			chip.get_parent().remove_child(chip)
	for column in _columns:
		column.queue_free()
	_columns = []

	var column: VBoxContainer = null
	for i in _order.size():
		if i % COLUMN_MAX == 0:
			column = VBoxContainer.new()
			if grow_up:
				column.alignment = BoxContainer.ALIGN_END
				column.size_flags_vertical = SIZE_EXPAND_FILL
			add_child(column)
			_columns.push_back(column)
		var chip: Control = _chips[_order[i]]
		column.add_child(chip)
		if grow_up:
			column.move_child(chip, 0)
