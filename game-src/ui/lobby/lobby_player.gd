extends KinematicBody2D

# Gourmet ecosystem - the Hub avatar (HUB_PLAN step 1). Movement ONLY:
# deliberately not player.gd, which is hard-wired to weapons/waves/stats.
# Each avatar belongs to one player slot: solo reads the plain movement
# actions, coop reads the device-suffixed actions exactly like
# PlayerMovementBehavior does in a run. The avatar WEARS a character: base
# potato plus the character's item_appearances, so you walk the Hub as your
# last-played (or booth-chosen) character.

const SPEED: = 430.0
# the walkable area; keep in sync with HUB_ART_SPEC.md section 1
const BOUNDS: = Rect2(-1376, -1176, 2752, 2288)

var player_index: int = 0
var device: int = 0
var use_device_actions: bool = false

var _visual: Node2D = null
var _anim_player: AnimationPlayer = null


func _physics_process(_delta: float) -> void :
	var direction: = _read_movement()
	if direction.length() > 1.0:
		direction = direction.normalized()
	var _velocity = move_and_slide(direction * SPEED)
	var moving: = direction != Vector2.ZERO
	if _anim_player != null:
		if moving and _anim_player.current_animation != "move":
			_anim_player.play("move")
		elif not moving and _anim_player.current_animation != "idle":
			_anim_player.play("idle")
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
	# the REAL in-game body: Animation node (shadow + potato + legs) driven by
	# the actual player idle/move animations, so the avatar walks and bounces
	# exactly like in a run. Appearance layers stack on the body sprite like
	# player.gd apply_items_effects does.
	if _visual != null:
		_visual.queue_free()
	_visual = Node2D.new()
	_visual.name = "Visual"
	_visual.set_script(load("res://ui/lobby/lobby_avatar_visual.gd"))
	add_child(_visual)

	var anim_node: = Node2D.new()
	anim_node.name = "Animation"
	anim_node.position = Vector2(0, - 24)
	_visual.add_child(anim_node)

	var potato = load("res://entities/units/player/potato.png")

	var shadow: = Sprite.new()
	shadow.name = "Shadow"
	shadow.texture = potato
	shadow.modulate = Color(0, 0, 0, 0.392157)
	shadow.position = Vector2(0, 38)
	shadow.scale = Vector2(1, - 0.3)
	shadow.show_behind_parent = true
	anim_node.add_child(shadow)

	var body: = Sprite.new()
	body.name = "Sprite"
	body.texture = potato
	anim_node.add_child(body)

	var legs: = Node2D.new()
	legs.name = "Legs"
	legs.show_behind_parent = true
	anim_node.add_child(legs)
	var leg_l = load("res://entities/units/player/leg_l.tscn").instance()
	leg_l.position = Vector2(15, 18)
	leg_l.show_behind_parent = true
	legs.add_child(leg_l)
	var leg_r = load("res://entities/units/player/leg_r.tscn").instance()
	leg_r.position = Vector2(-16, 18)
	leg_r.show_behind_parent = true
	legs.add_child(leg_r)

	if character != null:
		var appearances: Array = character.item_appearances
		appearances = appearances.duplicate()
		appearances.sort_custom(self, "_sort_appearance_depth")
		for appearance in appearances:
			if appearance == null:
				continue
			var layer: = Sprite.new()
			layer.texture = appearance.get_sprite()
			body.add_child(layer)
			if appearance.depth < - 1:
				layer.show_behind_parent = true

	# AnimationPlayer as a child of Visual: its default root is Visual, so the
	# track paths ("Animation:...", "Animation/Legs/LegL:...") resolve, and
	# the "." method track finds play_step_sound on lobby_avatar_visual.gd
	_anim_player = AnimationPlayer.new()
	_anim_player.add_animation("idle", load("res://entities/units/player/player_idle.tres"))
	_anim_player.add_animation("move", load("res://entities/units/player/player_move.tres"))
	_visual.add_child(_anim_player)
	_anim_player.play("idle")


func _sort_appearance_depth(a, b) -> bool:
	return a.depth < b.depth
