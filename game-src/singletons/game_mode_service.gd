extends Node

# Gourmet ecosystem - game modes (core service, autoloaded as "GameModes").
# ETG-style run mutators, selectable independently of character (ECOSYSTEM.md
# lobby spec; this service + the run_options_panel selector are the pre-lobby
# form - the lobby mode shrine replaces the UI later, not the engine).
#
# Registry style follows special_modifiers.gd (the sibling system): plain dicts,
# ids stored per player in RunData.players_data[i].game_mode_ids (serialized,
# so save/resume round-trips). A mode with requires_packs only appears while
# those packs are enabled.
#
# "wildcard_rules" deliberately carries NO numbers of its own: it routes the
# player through the Wildcard's existing per-wave modifier flow (roll at wave
# end, shop preview, apply at wave start, teardown - all via
# RunData.has_wildcard_flow), so its balance is exactly the already-approved
# 63-modifier pool.

const REGISTRY: = [
	{
		"id": "wildcard_rules",
		"name": "Wildcard Rules",
		"desc": "Every wave rolls Wildcard modifiers for you, like The Wildcard does",
		"requires_packs": [],
		"allowed_in_coop": true,
	},
]


func available_modes() -> Array:
	var result: = []
	for mode in REGISTRY:
		var packs_ok: bool = true
		for required_id in mode["requires_packs"]:
			if not Utils.packs.is_pack_enabled(str(required_id)):
				packs_ok = false
		if packs_ok:
			result.push_back(mode)
	return result


# Run-wide multi-select (user, 2026-08-18: modes affect the WHOLE RUN, several
# at once; the Hub's mode shrine is the only chooser). Legacy single-mode key
# folds in transparently.
func selected_mode_ids() -> Array:
	var ids: = []
	for mode_id in ProgressData.settings.get("selected_game_modes", []):
		if not mode_by_id(str(mode_id)).empty() and not ids.has(str(mode_id)):
			ids.push_back(str(mode_id))
	var legacy: String = str(ProgressData.settings.get("selected_game_mode", ""))
	if legacy != "" and not mode_by_id(legacy).empty() and not ids.has(legacy):
		ids.push_back(legacy)
	return ids


func set_mode_selected(mode_id: String, selected: bool) -> void :
	var ids: Array = selected_mode_ids()
	if selected and not ids.has(mode_id):
		ids.push_back(mode_id)
	elif not selected:
		ids.erase(mode_id)
	ProgressData.settings.selected_game_modes = ids
	ProgressData.settings.selected_game_mode = ""
	ProgressData.save_settings()


func mode_by_id(mode_id: String) -> Dictionary:
	for mode in REGISTRY:
		if str(mode["id"]) == mode_id:
			return mode
	return {}
