extends Node

# Gourmet ecosystem - game modes (core service, autoloaded as "GameModes").
# ETG-style run mutators, selectable independently of character. The HUB's OFF
# DUTY corner is the chooser (HUB_PLAN 4c): each MODE GUY owns a tick-box
# dialog, and every tick in it is one entry of the REGISTRY below.
#
# Registry style follows special_modifiers.gd (the sibling system): plain dicts,
# ids stored per player in RunData.players_data[i].game_mode_ids (serialized,
# so save/resume round-trips). A mode with requires_packs only appears while
# those packs are enabled - and a guy whose whole kit is gated away simply is
# not at the campfire (UN-GATE LAW: modes never ADD a system, they remove the
# "that character must be in the run" gate on a system its pack already ships).
#
# TICK-BOX GRAMMAR (HUB_PLAN 4c - three patterns, reused by every future guy):
#   SUPERSEDE       "supersedes": [ids]      - while this is on, those ticks are
#                                              covered by it (greyed, not lost)
#   EXCLUSIVE PAIR  "exclusive_with": [ids]  - ticking this unticks those
#   LINKED SWITCH   "owners": [a, b]         - ONE setting that appears in two
#                                              guys' dialogs (same id = mirrored
#                                              by construction, not by syncing)
#
# TIER-LADDER LAW (HUB_PLAN 4c): "forge_full_ladder" is the linked switch shared
# by The P2W and The Blacksmith. OFF -> borrowed forging/lootboxes run on
# VANILLA tiers; ON -> both ride the full 8-rung ladder. The Blacksmith CHARACTER
# always forges on the ladder; the switch governs mode-borrowed forging only.
# All ticks stamp at run start (difficulty_selection) and never flip mid-run.

const REGISTRY: = [
	# --- THE GOURMET: "House Menu" (food pack) ---
	{
		"id": "gourmet_steak",
		"owners": ["character_gourmet"],
		"name": "MODE_GOURMET_STEAK",
		"desc": "MODE_GOURMET_STEAK_DESC",
		"requires_packs": ["food"],
		"supersedes": [],
		"exclusive_with": ["gourmet_food"],
		"allowed_in_coop": true,
	},
	{
		"id": "gourmet_food",
		"owners": ["character_gourmet"],
		"name": "MODE_GOURMET_FOOD",
		"desc": "MODE_GOURMET_FOOD_DESC",
		"requires_packs": ["food"],
		"supersedes": [],
		"exclusive_with": ["gourmet_steak"],
		"allowed_in_coop": true,
	},
	{
		"id": "gourmet_shop_spawner",
		"owners": ["character_gourmet"],
		"name": "MODE_GOURMET_SPAWNER",
		"desc": "MODE_GOURMET_SPAWNER_DESC",
		"requires_packs": ["food"],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	# --- THE P2W: "Lootboxes" (forge pack) ---
	{
		"id": "p2w_crates",
		"owners": ["character_p2w"],
		"name": "MODE_P2W_CRATES",
		"desc": "MODE_P2W_CRATES_DESC",
		"requires_packs": ["forge"],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	{
		"id": "p2w_shop",
		"owners": ["character_p2w"],
		"name": "MODE_P2W_SHOP",
		"desc": "MODE_P2W_SHOP_DESC",
		"requires_packs": ["forge"],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	{
		"id": "p2w_everything",
		"owners": ["character_p2w"],
		"name": "MODE_P2W_EVERYTHING",
		"desc": "MODE_P2W_EVERYTHING_DESC",
		"requires_packs": ["forge"],
		"supersedes": ["p2w_crates", "p2w_shop"],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	# --- THE BLACKSMITH: "Open Forge" (forge pack) ---
	{
		"id": "smith_open_forge",
		"owners": ["character_blacksmith"],
		"name": "MODE_SMITH_OPEN",
		"desc": "MODE_SMITH_OPEN_DESC",
		"requires_packs": ["forge"],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	{
		"id": "smith_loose",
		"owners": ["character_blacksmith"],
		"name": "MODE_SMITH_LOOSE",
		"desc": "MODE_SMITH_LOOSE_DESC",
		"requires_packs": ["forge"],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	{
		"id": "smith_elite_drops",
		"owners": ["character_blacksmith"],
		"name": "MODE_SMITH_ELITES",
		"desc": "MODE_SMITH_ELITES_DESC",
		"requires_packs": ["forge"],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	# THE LINKED SWITCH: one setting, two dialogs (P2W + Blacksmith)
	{
		"id": "forge_full_ladder",
		"owners": ["character_p2w", "character_blacksmith"],
		"name": "MODE_FULL_LADDER",
		"desc": "MODE_FULL_LADDER_DESC",
		"requires_packs": ["forge"],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	# --- THE WILDCARD: "Rules" (roster pack) ---
	{
		"id": "wildcard_rules",
		"owners": ["character_special"],
		"name": "MODE_WILDCARD_RULES",
		"desc": "MODE_WILDCARD_RULES_DESC",
		"requires_packs": [],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	{
		"id": "wildcard_double",
		"owners": ["character_special"],
		"name": "MODE_WILDCARD_DOUBLE",
		"desc": "MODE_WILDCARD_DOUBLE_DESC",
		"requires_packs": [],
		"supersedes": ["wildcard_rules"],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	{
		"id": "wildcard_sticky",
		"owners": ["character_special"],
		"name": "MODE_WILDCARD_STICKY",
		"desc": "MODE_WILDCARD_STICKY_DESC",
		"requires_packs": [],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	# --- THE MOLE: "Lights Out" (roster pack) ---
	{
		"id": "mole_fog_boss",
		"owners": ["character_mole"],
		"name": "MODE_MOLE_FOG_BOSS",
		"desc": "MODE_MOLE_FOG_BOSS_DESC",
		"requires_packs": ["roster"],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	{
		"id": "mole_fog_all",
		"owners": ["character_mole"],
		"name": "MODE_MOLE_FOG_ALL",
		"desc": "MODE_MOLE_FOG_ALL_DESC",
		"requires_packs": ["roster"],
		"supersedes": ["mole_fog_boss"],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	{
		"id": "mole_fog_thick",
		"owners": ["character_mole"],
		"name": "MODE_MOLE_FOG_THICK",
		"desc": "MODE_MOLE_FOG_THICK_DESC",
		"requires_packs": ["roster"],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	# --- THE DEMON: "Blood Market" (vanilla host, no pack gate) ---
	{
		"id": "demon_shortfall",
		"owners": ["character_demon"],
		"name": "MODE_DEMON_SHORTFALL",
		"desc": "MODE_DEMON_SHORTFALL_DESC",
		"requires_packs": [],
		"supersedes": [],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
	{
		"id": "demon_everything",
		"owners": ["character_demon"],
		"name": "MODE_DEMON_EVERYTHING",
		"desc": "MODE_DEMON_EVERYTHING_DESC",
		"requires_packs": [],
		"supersedes": ["demon_shortfall"],
		"exclusive_with": [],
		"allowed_in_coop": true,
	},
]


func available_modes() -> Array:
	var result: = []
	for mode in REGISTRY:
		if _packs_ok(mode):
			result.push_back(mode)
	return result


func _packs_ok(mode: Dictionary) -> bool:
	for required_id in mode.get("requires_packs", []):
		if not Utils.packs.is_pack_enabled(str(required_id)):
			return false
	return true


# Every tick this guy owns, in registry order (empty -> he has nothing to
# offer right now, so the corner leaves his seat empty).
func modes_for_owner(owner_id: String) -> Array:
	var result: = []
	for mode in REGISTRY:
		if mode.get("owners", []).has(owner_id) and _packs_ok(mode):
			result.push_back(mode)
	return result


# The guys who own at least one currently-available tick, in registry order.
func owner_ids() -> Array:
	var result: = []
	for mode in REGISTRY:
		if not _packs_ok(mode):
			continue
		for owner_id in mode.get("owners", []):
			if not result.has(str(owner_id)):
				result.push_back(str(owner_id))
	return result


# SUPERSEDE grammar: a bigger tick is on and covers this one. The covered tick
# keeps its own stored state (it is greyed in the dialog, never silently lost).
func is_superseded(mode_id: String) -> bool:
	return is_superseded_in(mode_id, selected_mode_ids())


# pure form: "is mode_id covered, given THIS selection" (verify() tests it
# against synthetic selections without writing anyone's settings)
func is_superseded_in(mode_id: String, selected: Array) -> bool:
	for mode in REGISTRY:
		if not selected.has(str(mode["id"])):
			continue
		if mode.get("supersedes", []).has(mode_id):
			return true
	return false


# Which selected mode is covering this one (for the dialog's "covered by" note).
func superseder_of(mode_id: String) -> Dictionary:
	var selected: Array = selected_mode_ids()
	for mode in REGISTRY:
		if not selected.has(str(mode["id"])):
			continue
		if mode.get("supersedes", []).has(mode_id):
			return mode
	return {}


# The ids that actually take effect: selected AND not covered by a superseder.
func effective_mode_ids() -> Array:
	var result: = []
	for mode_id in selected_mode_ids():
		if not is_superseded(mode_id):
			result.push_back(mode_id)
	return result


# Run-wide multi-select (user, 2026-08-18: modes affect the WHOLE RUN, several
# at once). Legacy single-mode key folds in transparently.
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
	var ids: Array = apply_tick(selected_mode_ids(), mode_id, selected)
	ProgressData.settings.selected_game_modes = ids
	ProgressData.settings.selected_game_mode = ""
	ProgressData.save_settings()


# pure form of one tick landing on a selection - the EXCLUSIVE PAIR grammar
# lives here so it is identical in the dialog, in tests and in any caller.
func apply_tick(ids_in: Array, mode_id: String, selected: bool) -> Array:
	var ids: Array = ids_in.duplicate()
	if selected and not ids.has(mode_id):
		ids.push_back(mode_id)
		for other_id in mode_by_id(mode_id).get("exclusive_with", []):
			ids.erase(str(other_id))
	elif not selected:
		ids.erase(mode_id)
	return ids


func mode_by_id(mode_id: String) -> Dictionary:
	for mode in REGISTRY:
		if str(mode["id"]) == mode_id:
			return mode
	return {}


# How many of a guy's own ticks are on (his [E] prompt shows this).
func active_count_for_owner(owner_id: String) -> int:
	var selected: Array = selected_mode_ids()
	var count: int = 0
	for mode in modes_for_owner(owner_id):
		if selected.has(str(mode["id"])):
			count += 1
	return count


# Boot-time self-check (same discipline as PackService VERIFY): the registry's
# structure AND the three grammar patterns are asserted against synthetic
# selections, so a typo'd id or a broken supersede shows up in the gate rather
# than in a playtest. Prints one line; the lobby calls it.
func verify() -> bool:
	var problems: = []
	var seen: = []
	for mode in REGISTRY:
		var mode_id: String = str(mode["id"])
		if seen.has(mode_id):
			problems.push_back("duplicate id " + mode_id)
		seen.push_back(mode_id)
		if mode.get("owners", []).empty():
			problems.push_back(mode_id + " has no owner")
		for owner_id in mode.get("owners", []):
			if ItemService.get_element_safe(ItemService.characters, str(owner_id)) == null:
				problems.push_back(mode_id + " owner missing: " + str(owner_id))
		for key in [str(mode["name"]), str(mode["desc"])]:
			if tr(key) == key:
				problems.push_back(mode_id + " untranslated: " + key)
		for other_id in mode.get("supersedes", []):
			if mode_by_id(str(other_id)).empty():
				problems.push_back(mode_id + " supersedes unknown " + str(other_id))
		for other_id in mode.get("exclusive_with", []):
			var other: Dictionary = mode_by_id(str(other_id))
			if other.empty():
				problems.push_back(mode_id + " exclusive with unknown " + str(other_id))
			elif not other.get("exclusive_with", []).has(mode_id):
				problems.push_back(mode_id + " exclusive pair not symmetric with " + str(other_id))
	# GRAMMAR behaviour, on synthetic selections (never touches settings)
	for mode in REGISTRY:
		var mode_id: String = str(mode["id"])
		# SUPERSEDE: turning the big tick on covers each of its siblings
		for covered_id in mode.get("supersedes", []):
			if not is_superseded_in(str(covered_id), [mode_id]):
				problems.push_back("supersede broken: " + mode_id + " -> " + str(covered_id))
			if is_superseded_in(str(covered_id), []):
				problems.push_back("supersede leaks with nothing on: " + str(covered_id))
		# EXCLUSIVE: ticking one drops its opposite from the selection
		for other_id in mode.get("exclusive_with", []):
			if apply_tick([str(other_id)], mode_id, true).has(str(other_id)):
				problems.push_back("exclusive broken: " + mode_id + " kept " + str(other_id))
	# LINKED: a shared switch must really be reachable from every owner's dialog
	for mode in REGISTRY:
		if mode.get("owners", []).size() < 2 or not _packs_ok(mode):
			continue
		for owner_id in mode["owners"]:
			var found: = false
			for owned in modes_for_owner(str(owner_id)):
				if str(owned["id"]) == str(mode["id"]):
					found = true
			if not found:
				problems.push_back("linked switch missing from " + str(owner_id) + ": " + str(mode["id"]))
	if problems.empty():
		print("GameModes VERIFY: OK (%d modes, %d guys, grammar checks pass)" % [
			REGISTRY.size(), owner_ids().size()])
		return true
	print("GameModes VERIFY: FAILED -> " + PoolStringArray(problems).join(" | "))
	return false
