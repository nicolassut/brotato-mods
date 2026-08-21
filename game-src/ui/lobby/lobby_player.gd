extends KinematicBody2D

# Gourmet ecosystem - the lobby avatar (ECOSYSTEM.md Phase 7). Movement ONLY:
# deliberately not player.gd, which is hard-wired to weapons/waves/stats. Reads
# the game's own movement actions so keyboard and controller both work with the
# player's existing bindings.

const SPEED: = 430.0
# the walkable area; keep in sync with the floor rect lobby.gd draws
const BOUNDS: = Rect2(-1050, -570, 2100, 1140)

onready var _sprite: Sprite = get_node("Sprite")


func _physics_process(_delta: float) -> void :
	var direction: = Vector2(
		Input.get_action_strength("button_move_right") + Input.get_action_strength("analog_move_right")
		 - Input.get_action_strength("button_move_left") - Input.get_action_strength("analog_move_left"),
		Input.get_action_strength("button_move_down") + Input.get_action_strength("analog_move_down")
		 - Input.get_action_strength("button_move_up") - Input.get_action_strength("analog_move_up"))
	if direction.length() > 1.0:
		direction = direction.normalized()
	var _velocity = move_and_slide(direction * SPEED)
	if direction.x != 0.0:
		_sprite.flip_h = direction.x < 0.0
	position.x = clamp(position.x, BOUNDS.position.x, BOUNDS.position.x + BOUNDS.size.x)
	position.y = clamp(position.y, BOUNDS.position.y, BOUNDS.position.y + BOUNDS.size.y)
