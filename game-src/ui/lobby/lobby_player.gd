extends KinematicBody2D

# Gourmet ecosystem - the Hub avatar (HUB_PLAN step 1). Movement ONLY:
# deliberately not player.gd, which is hard-wired to weapons/waves/stats.
# Each avatar belongs to one player slot: solo reads the plain movement
# actions, coop reads the device-suffixed actions exactly like
# PlayerMovementBehavior does in a run. The avatar WEARS a character: base
# potato plus the character's item_appearances, so you walk the Hub as your
# last-played (or booth-chosen) character.

const SPEED: = 430.0
# the walkable area; keep in sync with the floor rect lobby.gd draws
const BOUNDS: = Rect2(-1050, -570, 2100, 1140)

var player_index: int = 0
var device: int = 0
var use_device_actions: bool = false

var _visual: Node2D = null


func _physics_process(_delta: float) -> void :
	var direction: = _read_movement()
	if direction.length() > 1.0:
		direction = direction.normalized()
	var _velocity = move_and_slide(direction * SPEED)
	if direction.x != 0.0 and _visual != null:
		_visual.scale.x = - 1.0 if direction.x < 0.0 else 1.0
	position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
	position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)


func _read_movement() -> Vector2:
	var analog: = _vector_for_prefix("analog_")
	var button: = _vector_for_prefix("button_")
	return analog if analog.length() > button.length() else button


func _vector_for_prefix(prefix: String) -> Vector2:
	# mirrors PlayerMovementBehavior.get_vector_for_input_prefix
	if use_device_actions:
		return Input.get_vector(
			prefix + "move_left_%s" % device, prefix + "move_right_%s" % device,
			prefix + "move_up_%s" % device, prefix + "move_down_%s" % device)
	return Input.get_vector(
		prefix + "move_left", prefix + "move_right",
		prefix + "move_up", prefix + "move_down")


func dress_as(character) -> void :
	# base potato + the character's own appearance layers, stacked like
	# player.gd apply_items_effects does in a run (behind layers use
	# show_behind_parent). Placeholder-quality on purpose: no legs animation.
	if _visual != null:
		_visual.queue_free()
	_visual = Node2D.new()
	_visual.name = "Visual"
	add_child(_visual)

	var base: = Sprite.new()
	var potato = load("res://entities/units/player/potato.png")
	if potato != null:
		base.texture = potato
	_visual.add_child(base)

	if character == null:
		return
	var appearances: Array = character.item_appearances
	appearances = appearances.duplicate()
	appearances.sort_custom(self, "_sort_appearance_depth")
	for appearance in appearances:
		if appearance == null:
			continue
		var layer: = Sprite.new()
		layer.texture = appearance.get_sprite()
		base.add_child(layer)
		if appearance.depth < - 1:
			layer.show_behind_parent = true


func _sort_appearance_depth(a, b) -> bool:
	return a.depth < b.depth
