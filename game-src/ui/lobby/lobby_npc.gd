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
# per-station override (big buildings need the prompt to reach past their collision)
var near_radius: float = NEAR_RADIUS
# where the [E] prompt sits relative to the node origin (the sprite BASE).
# Stations put it just under their base; the OFF DUTY mode guys have no sprite
# of their own (the station rides on the character body) so theirs goes above
# the head instead of into the floor.
var prompt_offset: = Vector2(0, 16)
# Stations that stand shoulder to shoulder (the OFF DUTY mode guys) would each
# pop their own prompt and the labels would pile on top of each other. The
# lobby suppresses every one but the CLOSEST, so exactly one prompt shows and
# [E] can only ever mean the guy you are actually standing next to.
var prompt_suppressed: bool = false setget set_prompt_suppressed
# half the sprite height; the node origin sits at the sprite BASE (y-sort)
var _half_h: float = 48.0


func base_offset() -> float:
	return _half_h


func setup(texture: Texture, display_name: String, prompt: String) -> void :
	npc_name = display_name
	prompt_text = prompt

	var sprite: = Sprite.new()
	if texture != null:
		sprite.texture = texture
		_half_h = texture.get_height() / 2.0
	# base-anchored: the node origin is the sprite's BASE, so the lobby's
	# YSort draws whoever is lower on screen on top (2026-08-19 playtest:
	# the avatar rendered under the shuttle when standing in front of it)
	sprite.offset = Vector2(0, - _half_h)
	add_child(sprite)

	# no floating name plate (user 2026-08-21) - the prompt alone talks

	_prompt = _make_label(prompt, prompt_offset)
	_prompt.modulate = Color(1, 0.9, 0.4, 1)
	_prompt.visible = false
	add_child(_prompt)

	var area: = Area2D.new()
	var shape_owner: = CollisionShape2D.new()
	var circle: = CircleShape2D.new()
	circle.radius = near_radius
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


func set_prompt_suppressed(value: bool) -> void :
	prompt_suppressed = value
	_refresh_prompt_visibility()


func is_player_near() -> bool:
	return _player_near


func _refresh_prompt_visibility() -> void :
	if _prompt != null:
		_prompt.visible = _player_near and not prompt_suppressed


func _on_body_entered(body: Node) -> void :
	if body is KinematicBody2D:
		_player_near = true
		_refresh_prompt_visibility()


func _on_body_exited(body: Node) -> void :
	if body is KinematicBody2D:
		_player_near = false
		_refresh_prompt_visibility()


func _unhandled_input(event: InputEvent) -> void :
	if _player_near and not prompt_suppressed and event.is_action_pressed("interact"):
		get_tree().set_input_as_handled()
		emit_signal("interacted")
