class_name GalleyBounceProjectile
extends PlayerProjectile

# Gourmet DLC - Galley Cannon: the cannonball pierces every enemy it passes through
# and ricochets off the arena walls a few times before despawning, instead of
# exploding on the first hit. Movement and the range-timeout come from the parent
# _physics_process calls (Godot 3 invokes _physics_process for EVERY script in the
# inheritance chain - Projectile moves it, PlayerProjectile runs the timeout); this
# subclass only adds the wall ricochet and the bounce-count despawn.

const WALL_BOUNCES: = 4
const WALL_MARGIN: = 24.0  # inset from the arena edge so it bounces just inside the wall

var _wall_bounces_left: = WALL_BOUNCES


func shoot() -> void :
	.shoot()
	_wall_bounces_left = WALL_BOUNCES
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
		velocity = vel
		global_position = pos
		rotation = vel.angle()
		# let the ricochet hit enemies it already pierced on the way out
		_hitbox.ignored_objects.clear()
		_wall_bounces_left -= 1
		if _wall_bounces_left < 0:
			stop()
