class_name GalleyBounceProjectile
extends PlayerProjectile

# Gourmet DLC - Galley Cannon: the cannonball pierces every enemy it passes through
# and ricochets off the arena walls a few times before despawning, instead of
# exploding on the first hit. Movement and the range-timeout come from the parent
# _physics_process calls (Godot 3 invokes _physics_process for EVERY script in the
# inheritance chain - Projectile moves it, PlayerProjectile runs the timeout); this
# subclass only adds the wall ricochet and the bounce-count despawn.

# Wall bounces are a TIER trait, not a weapon stat: T1 3, T2 4, T3 5, T4 6. Read off the
# firing weapon's tier so curse (which scales stats, never tier) cannot inflate it. Keep
# in sync with the per-tier EFFECT_W_GALLEY_PIERCE value in asset-dev/build_weapons.py.
const WALL_BOUNCES_BY_TIER: = [3, 4, 5, 6]
const WALL_MARGIN: = 24.0  # inset from the arena edge so it bounces just inside the wall

var _wall_bounces_left: int = WALL_BOUNCES_BY_TIER[0]


# _hitbox.from is the Weapon node that fired us (see PlayerProjectile.shoot_ex);
# anything else (a turret proxy) falls back to the tier-1 count.
func _wall_bounces_for_source() -> int:
	var source = _hitbox.from
	if source is Weapon:
		return WALL_BOUNCES_BY_TIER[int(clamp(source.tier, 0, WALL_BOUNCES_BY_TIER.size() - 1))]
	return WALL_BOUNCES_BY_TIER[0]


func shoot() -> void :
	.shoot()
	_wall_bounces_left = _wall_bounces_for_source()
	# the arena walls end this projectile, not the camera edge; keep it alive long
	# enough that the bounce count is what despawns it (INFINITE_RANGE / speed cap).
	destroy_on_leaving_screen = false
	_max_range = INFINITE_RANGE
	_set_time_until_max_range()


func _physics_process(_delta: float) -> void :
	var rect: Rect2 = ZoneService.current_zone_rect
	if rect.size.x <= 0.0:
		return
	var min_x: float = rect.position.x + WALL_MARGIN
	var max_x: float = rect.position.x + rect.size.x - WALL_MARGIN
	var min_y: float = rect.position.y + WALL_MARGIN
	var max_y: float = rect.position.y + rect.size.y - WALL_MARGIN

	var pos: Vector2 = global_position
	var vel: Vector2 = velocity
	var bounced: = false
	if pos.x <= min_x and vel.x < 0.0:
		vel.x = - vel.x
		pos.x = min_x
		bounced = true
	elif pos.x >= max_x and vel.x > 0.0:
		vel.x = - vel.x
		pos.x = max_x
		bounced = true
	if pos.y <= min_y and vel.y < 0.0:
		vel.y = - vel.y
		pos.y = min_y
		bounced = true
	elif pos.y >= max_y and vel.y > 0.0:
		vel.y = - vel.y
		pos.y = max_y
		bounced = true

	if bounced:
		if _wall_bounces_left <= 0:
			# out of ricochets: the wall that would have reflected it kills it instead,
			# so the tier's count is exactly how many bounces the player gets to see
			stop()
			return
		velocity = vel
		global_position = pos
		rotation = vel.angle()
		# let the ricochet hit enemies it already pierced on the way out
		_hitbox.ignored_objects.clear()
		_wall_bounces_left -= 1
