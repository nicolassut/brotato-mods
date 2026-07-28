extends RangedWeaponShootingBehavior

# Gourmet DLC - Ice Cream Scoop: it is SWUNG, not fired. The scoop cocks back, swings
# forward through an arc, and flings the scoop projectile at the forward point - a throw,
# not a gun recoil. Projectile spawning is the parent RangedWeapon path unchanged (same
# muzzle, same spread, same on-hit wiring); only the sprite animation differs. The arc
# sign mirrors the melee sweep so it reads correctly whether the weapon faces left or right.
const WINDUP := 1.7279   # 0.55 * PI - how far the scoop cocks back
const FOLLOW := 1.2566   # 0.40 * PI - how far it follows through past forward


func shoot(_distance: float) -> void :
	var rest_rotation: float = _parent.sprite.rotation
	_parent.set_shooting(true)

	# facing sign: sprite.flip_v is true when aiming left, same convention the melee sweep uses
	var s: float = 1.0 if _parent.sprite.flip_v else -1.0

	# 1) cock back
	_swing_to(rest_rotation + s * WINDUP, 0.07, Tween.TRANS_QUAD, Tween.EASE_OUT)
	yield(_parent.tween, "tween_all_completed")

	# 2) swing forward back to rest, where the muzzle points forward - release here
	_swing_to(rest_rotation, 0.05, Tween.TRANS_QUAD, Tween.EASE_IN)
	yield(_parent.tween, "tween_all_completed")

	SoundManager.play(Utils.get_rand_element(_parent.current_stats.shooting_sounds), _parent.current_stats.sound_db_mod, 0.2)
	var attack_id: = _get_next_attack_id()
	for _i in _parent.current_stats.nb_projectiles:
		var proj_rotation = rand_range(_parent.rotation - _parent.current_stats.projectile_spread, _parent.rotation + _parent.current_stats.projectile_spread)
		var projectile = shoot_projectile(proj_rotation, Vector2(cos(proj_rotation), sin(proj_rotation)))
		projectile._hitbox.player_attack_id = attack_id

	# 3) follow through past forward
	_swing_to(rest_rotation - s * FOLLOW, 0.06, Tween.TRANS_QUAD, Tween.EASE_OUT)
	yield(_parent.tween, "tween_all_completed")

	# 4) settle back to rest
	_swing_to(rest_rotation, 0.09, Tween.TRANS_EXPO, Tween.EASE_OUT)
	yield(_parent.tween, "tween_all_completed")

	_parent.set_shooting(false)


func _swing_to(target: float, dur: float, trans: int, easing: int) -> void :
	_parent.tween.interpolate_property(_parent.sprite, "rotation", _parent.sprite.rotation, target, dur, trans, easing)
	_parent.tween.start()
