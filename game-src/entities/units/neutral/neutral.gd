class_name Neutral
extends Unit

export (int) var number_of_hits_before_dying = 8

var current_number_of_hits = 0


func init(zone_min_pos: Vector2, zone_max_pos: Vector2, players_ref: Array = [], entity_spawner_ref = null) -> void :
	.init(zone_min_pos, zone_max_pos, players_ref, entity_spawner_ref)
	init_current_stats()
	_apply_butcher_meat_rack()


# Gourmet DLC - Butcher: the on-map fruit tree shows as a meat drying rack. Pooled
# nodes carry textures across runs, so both directions are set explicitly. (butcher_meat_rack)
func _apply_butcher_meat_rack() -> void :
	if stats == null or stats.resource_path.find("tree") == - 1:
		return
	var spr = get_node_or_null("Animation/Sprite")
	if spr == null:
		return
	if not has_meta("orig_tree_tex"):
		set_meta("orig_tree_tex", spr.texture)
	if ButcherSkin.is_butcher_in_run():
		var meat = ButcherSkin.world_texture("meat_rack_ingame")
		if meat != null:
			spr.texture = meat
	else:
		spr.texture = get_meta("orig_tree_tex")


func respawn() -> void :
	.respawn()
	init_current_stats()
	current_number_of_hits = 0
	_apply_butcher_meat_rack()


func take_damage(value: int, args: TakeDamageArgs) -> Array:
	var result = .take_damage(value, args)

	current_number_of_hits += 1

	if dead:
		return result
	if args.hitbox and args.hitbox.from and ( not (args.hitbox.from is Object) or (args.hitbox.from is Object and ( not "player_index" in args.hitbox.from or args.hitbox.from.player_index == - 1))):
		return result

	if (current_number_of_hits >= number_of_hits_before_dying
		or (args.hitbox and is_instance_valid(args.hitbox) and RunData.get_player_effect_bool(Keys.one_shot_trees_hash, args.hitbox.from.player_index))
		or DebugService.one_shot_enemies):
		die(_die_args_unit)

	return result


func die(_args: = Utils.default_die_args) -> void :
	.die()
	ProgressData.increment_stat("trees_killed")
	
	
