class_name FollowTargetMovementBehavior
extends MovementBehavior

export (bool) var stop_close_to_target: = false
export (float) var distance_to_target: = 30

var _target_player: = false

func get_movement() -> Vector2:
	if stop_close_to_target and _target_player and _parent.global_position.distance_squared_to(_parent.current_target.global_position) < distance_to_target * distance_to_target:
		return Vector2.ZERO

	var value = get_target_position() - _parent.global_position
	return value


func get_target_position():
	if not is_instance_valid(_parent.current_target):
		return global_position
	# Gourmet DLC - Units expose get_follow_target_position() (Girly's panic-teleport
	# freezes it). Non-Unit targets - lootworm chases gold piles, dead trees and
	# neutrals, which are plain Node2Ds - do not, so fall back to vanilla behaviour.
	if _parent.current_target.has_method("get_follow_target_position"):
		return _parent.current_target.get_follow_target_position()
	return _parent.current_target.global_position


func _on_TargetBehavior_target_found(node: Node2D):
	_target_player = false


func _on_TargetBehavior_target_player(node: Node2D):
	_target_player = true
