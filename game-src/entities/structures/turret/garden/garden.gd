class_name Garden
extends Turret


# Gourmet DLC - Butcher: the garden shows as a meat locker (butcher_meat_locker)
func _ready() -> void :
	._ready()
	var spr = get_node_or_null("Animation/Sprite")
	if spr == null:
		return
	if not has_meta("orig_garden_tex"):
		set_meta("orig_garden_tex", spr.texture)
	if Utils.butcher_skin.is_butcher_in_run():
		var meat = Utils.butcher_skin.world_texture("meat_locker_ingame")
		if meat != null:
			spr.texture = meat
	else:
		spr.texture = get_meta("orig_garden_tex")


func shoot() -> void :
	SoundManager2D.play(Utils.get_rand_element(stats.shooting_sounds), global_position, stats.sound_db_mod, 0.2)
	emit_signal("wanted_to_spawn_fruit", global_position)


func should_shoot() -> bool:
	return _cooldown <= 0 and not _is_shooting
