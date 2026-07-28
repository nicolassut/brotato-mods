class_name FollowRandPosAroundPlayerMovementBehavior
extends MovementBehavior

export (int) var range_around_player = 200
export (int) var range_randomization = 0
export (bool) var allow_within: bool = true

var _actual: int
var _distance_from_player: Vector2


func init(parent: Node) -> Node:
	var _init = .init(parent)
	_actual = range_around_player + rand_range( - range_randomization, range_randomization)
	_distance_from_player = Vector2(rand_range( - _actual, _actual), rand_range( - _actual, _actual))

	if not allow_within:
		_distance_from_player = _distance_from_player.normalized() * _actual

	return self


func get_movement() -> Vector2:
	var target = get_target_position()

	if Utils.vectors_approx_equal(target, _parent.global_position, EQUALITY_PRECISION):
		return Vector2.ZERO

	return target - _parent.global_position


func get_target_position():
	# Gourmet DLC - see follow_target_movement_behavior.gd: non-Unit targets have no
	# get_follow_target_position(), so fall back to vanilla global_position.
	if _parent.current_target.has_method("get_follow_target_position"):
		return _parent.current_target.get_follow_target_position() + _distance_from_player
	return _parent.current_target.global_position + _distance_from_player
