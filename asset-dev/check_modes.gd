extends SceneTree

# MODE GATE (check_all): the OFF DUTY mode ticks are UN-GATES - each makes a
# system that normally requires its owner character run for anybody. The boot
# and lobby gates only prove the code parses and the registry is well formed;
# this gate proves the un-gated helpers actually ANSWER DIFFERENTLY when a tick
# is stamped on a player, and that the TIER-LADDER LAW holds in both directions.
# Run: godot --path <live> -s asset-dev/check_modes.gd
#
# Everything is resolved through root.get_node at RUNTIME on purpose: naming an
# autoload class directly makes this script pull the singletons in at PARSE
# time, before the engine has built them, and the whole tree dies on cyclic
# reference errors (learned the hard way 2026-08-22).

var _fails: = []
var _done: = false


func _idle(_delta: float) -> bool:
	if _done:
		return true
	_done = true
	var run_data = root.get_node_or_null("RunData")
	var item_service = root.get_node_or_null("ItemService")
	var butcher = root.get_node_or_null("ButcherSkin")
	var modes = root.get_node_or_null("GameModes")
	var progress = root.get_node_or_null("ProgressData")
	if run_data == null or item_service == null or butcher == null or modes == null or progress == null:
		print("MODE GATE: singletons missing")
		OS.exit_code = 1
		return true

	var hero = item_service.get_element_safe(item_service.characters, "character_well_rounded")
	if hero == null:
		print("MODE GATE: no baseline character to test with")
		OS.exit_code = 1
		return true
	# add_character alone: reset(true) drags the whole run-restart path (and its
	# UI-facing signals) into a tree that has no scene, which spews unrelated
	# null-instance errors. A fresh boot already has empty players_data.
	run_data.add_character(hero, 0)

	# BASELINE: a plain character borrows none of these systems, so every
	# "true" further down can only have come from the tick itself
	_expect(not run_data.has_forge_flow(0), "plain character must not get the forge")
	_expect(not run_data.has_lootbox_crates(), "plain character must not get lootbox crates")
	_expect(not run_data.has_fog_flow(), "plain character must not get fog")
	_expect(not run_data.has_thick_fog(0), "plain character must not get thick fog")
	_expect(not run_data.uses_tier_ladder(0), "plain character must run vanilla tiers")
	_expect(not butcher.is_butcher_in_run(), "plain character must not get the meat skin")

	# each tick un-gates EXACTLY its own system
	_tick(run_data, ["smith_open_forge"])
	_expect(run_data.has_forge_flow(0), "smith_open_forge must open the forge")
	_expect(not run_data.uses_tier_ladder(0), "smith_open_forge alone must stay on vanilla tiers")
	_tick(run_data, ["p2w_crates"])
	_expect(run_data.has_lootbox_crates(), "p2w_crates must turn crates into lootboxes")
	_expect(run_data.first_lootbox_index() >= 0, "lootbox crates must resolve a REAL player index")
	_tick(run_data, ["p2w_everything"])
	_expect(run_data.has_lootbox_crates(), "p2w_everything must cover the crates too")
	_tick(run_data, ["mole_fog_all"])
	_expect(run_data.has_fog_flow(), "mole_fog_all must fog every wave")
	_tick(run_data, ["mole_fog_thick"])
	_expect(run_data.has_thick_fog(0), "mole_fog_thick must shrink the vision circle")
	_expect(not run_data.has_fog_flow(), "mole_fog_thick alone must not schedule fog")
	_tick(run_data, ["gourmet_steak"])
	_expect(butcher.is_butcher_in_run(), "gourmet_steak must apply the meat reskin")

	# TIER-LADDER LAW: borrowed forging runs VANILLA tiers until the linked
	# switch is on, and rides the 8-rung ladder once it is - both directions.
	_tick(run_data, ["smith_open_forge"])
	_expect(item_service.get_tier_ladder(0) == item_service.VANILLA_TIER_LADDER,
			"borrowed forge without the switch must walk the VANILLA ladder")
	_tick(run_data, ["smith_open_forge", "forge_full_ladder"])
	_expect(run_data.uses_tier_ladder(0), "the linked switch must turn the ladder on")
	_expect(item_service.get_tier_ladder(0) == item_service.BS_TIER_LADDER,
			"the linked switch must walk the 8-rung ladder")

	# END-TO-END: what a run start actually does. The tick is stored in
	# ProgressData.settings, read back through selected_mode_ids(), and stamped
	# onto every player exactly the way difficulty_selection.gd does it. This is
	# the chain the user reported broken (2026-08-22), so it is now a gate.
	_tick(run_data, [])
	var saved_selection = progress.settings.get("selected_game_modes", [])
	progress.settings["selected_game_modes"] = ["p2w_everything", "smith_open_forge"]
	var round_trip: Array = modes.selected_mode_ids()
	_expect(round_trip.has("p2w_everything") and round_trip.has("smith_open_forge"),
			"a stored selection must read back out of settings")
	# ...the exact stamp line from difficulty_selection.gd
	for stamp_index in run_data.get_player_count():
		run_data.players_data[stamp_index].game_mode_ids = round_trip.duplicate()
	_expect(run_data.is_game_mode_active("p2w_everything", 0),
			"run start must stamp the tick onto the player")
	_expect(run_data.has_lootbox_crates(),
			"a stamped lootbox tick must turn ground crates into lootboxes")
	_expect(run_data.has_forge_flow(0), "a stamped forge tick must open the forge")
	# ...and it must survive the save/load round trip a resumed run does
	# the save file itself: the ids must reach the JSON, come back out of it,
	# and still be registered - the loader (player_run_data.deserialize) drops
	# any id it cannot find in the registry, which is how a resumed run would
	# silently lose its modes.
	var blob: Dictionary = run_data.players_data[0].serialize()
	var reloaded_ids: Array = parse_json(to_json(blob)).get("game_mode_ids", [])
	_expect(reloaded_ids.has("p2w_everything"),
			"a stamped tick must reach the save file and come back")
	for reloaded_id in reloaded_ids:
		_expect(not modes.mode_by_id(str(reloaded_id)).empty(),
				"a saved tick must still be registered or the loader drops it: " + str(reloaded_id))
	progress.settings["selected_game_modes"] = saved_selection

	_tick(run_data, [])
	if _fails.empty():
		print("MODE GATE: OK (every un-gate answers per tick, tier-ladder law holds both ways)")
	else:
		print("MODE GATE: FAILED -> " + PoolStringArray(_fails).join(" | "))
		OS.exit_code = 1
	return true


func _tick(run_data, ids: Array) -> void :
	run_data.players_data[0].game_mode_ids = ids.duplicate()


func _expect(condition: bool, message: String) -> void :
	if not condition:
		_fails.push_back(message)
