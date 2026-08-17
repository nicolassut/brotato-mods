extends Node2D

# Gourmet ecosystem - one lobby NPC/station (ECOSYSTEM.md Phase 7). A sprite, a
# name plate, a proximity ring (pattern: the player's item_attract_area), and an
# interact prompt. Emits "interacted" when the player presses interact in range;
# the lobby wires each signal to its behavior. No focusable UI here, so the
# FocusEmulator law is satisfied trivially.

signal interacted

var npc_name: String = ""
var prompt_text: String = ""

var _player_near: bool = false
var _prompt: Label = null
var _name_plate: Label = null

const NEAR_RADIUS: = 110.0


func setup(texture: Texture, display_name: String, prompt: String) -> void :
	npc_name = display_name
	prompt_text = prompt

	var sprite: = Sprite.new()
	if texture != null:
		sprite.texture = texture
	add_child(sprite)

	_name_plate = _make_label(display_name, Vector2(0, -78))
	add_child(_name_plate)

	_prompt = _make_label(prompt, Vector2(0, 64))
	_prompt.modulate = Color(1, 0.9, 0.4, 1)
	_prompt.visible = false
	add_child(_prompt)

	var area: = Area2D.new()
	var shape_owner: = CollisionShape2D.new()
	var circle: = CircleShape2D.new()
	circle.radius = NEAR_RADIUS
	shape_owner.shape = circle
	area.add_child(shape_owner)
	add_child(area)
	var _e1 = area.connect("body_entered", self, "_on_body_entered")
	var _e2 = area.connect("body_exited", self, "_on_body_exited")


func set_prompt(prompt: String) -> void :
	prompt_text = prompt
	if _prompt != null:
		_prompt.text = prompt


func _make_label(text: String, offset: Vector2) -> Label:
	var label: = Label.new()
	label.text = text
	label.align = Label.ALIGN_CENTER
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.rect_position = offset + Vector2(-200, 0)
	label.rect_min_size = Vector2(400, 0)
	return label


func _on_body_entered(body: Node) -> void :
	if body is KinematicBody2D:
		_player_near = true
		_prompt.visible = true


func _on_body_exited(body: Node) -> void :
	if body is KinematicBody2D:
		_player_near = false
		_prompt.visible = false


func _unhandled_input(event: InputEvent) -> void :
	if _player_near and event.is_action_pressed("interact"):
		get_tree().set_input_as_handled()
		emit_signal("interacted")
