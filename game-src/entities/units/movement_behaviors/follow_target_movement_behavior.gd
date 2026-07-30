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
	# Gourmet DLC - get_follow_target_position is a Unit-only method this mod adds, so
	# that chasers path to Sweet Potato's FROZEN position during her panic-teleport
	# instead of snapping to where she reappeared. Vanilla, though, legitimately parks
	# current_target on a TargetBehavior node as a "no valid target" sentinel - the
	# Lootworm with no trees and no gold left (lootworm_target_behavior.gd), and
	# PlayerOwner once its owner is dead. Those are plain Node2Ds with no such method,
	# and calling it on them hard-crashes the run. Fall back to vanilla's global_position.
	if _parent.current_target.has_method("get_follow_target_position"):
		return _parent.current_target.get_follow_target_position()
	return _parent.current_target.global_position


func _on_TargetBehavior_target_found(node: Node2D):
	_target_player = false


func _on_TargetBehavior_target_player(node: Node2D):
	_target_player = true
