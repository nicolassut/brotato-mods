extends HBoxContainer

# Gourmet DLC - per-player HUD row of active food buffs (icon + stacks + seconds left).
# Instanced from main.gd under the player's life container each wave. Polls the
# player's _food_buffs dict every frame; the dict holds a handful of entries at
# most so a straight poll is cheaper than a signal protocol.

var player = null

var _chips: = {}
var _font = preload("res://resources/fonts/actual/base/font_26_outline.tres")


func _process(_delta: float) -> void :
	if player == null or not is_instance_valid(player) or player.cleaning_up:
		visible = false
		return

	var buffs: Dictionary = player._food_buffs
	visible = buffs.size() > 0

	for food_id in buffs:
		var buff: Dictionary = buffs[food_id]
		if not _chips.has(food_id):
			_chips[food_id] = _make_chip(buff["icon"])
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

	add_child(chip)
	return chip
