extends Node

# Gourmet ecosystem - the pack lifecycle service, autoloaded as "Packs"
# (ECOSYSTEM.md). Phase 2: custom content registration lives in the six
# PackData resources under res://packs/ (no longer scene-baked in
# item_service.tscn); this service applies every enabled pack at boot in a
# fixed order, then runs the same unlock+pool pairing ProgressData.activate_dlc
# uses for DLCs. The cached boolean facade below is the guard surface future
# seams read (`if Packs.food:`).
#
# Phase 3: persistence (ProgressData.settings.disabled_packs, DLC opt-out
# pattern), the options-menu toggle UI, the RunData.enabled_packs run snapshot
# (Continue invalidates when a required pack is off), and a --packs= cmdline
# override for the boot test matrix. Mid-run toggling stays unsupported: the
# toggle UI is title-screen-only.

signal pack_activated(pack_id)
signal pack_deactivated(pack_id)

const PACKS_DIR: = "res://packs"
# apply order is fixed so the character-select roster groups deterministically
const PACK_APPLY_ORDER: = ["food", "fortune", "forge", "ledger", "roster"]
# The character-select order (historical, pre-split). Pack apply order groups
# customs by pack, which reshuffled the roster (user 2026-08-18) - after every
# apply the custom characters are re-sorted into THIS order. New characters
# must be added here or they land after the known ones.
const ROSTER_ORDER: = ["character_gourmet", "character_picky_eater", "character_dishwasher",
	"character_comp_eater", "character_butcher", "character_zombie", "character_minimalist",
	"character_mime", "character_tourist", "character_ruminant", "character_snail",
	"character_blacksmith", "character_juggler", "character_mole", "character_girly",
	"character_freeloader", "character_special", "character_test_debt", "character_p2w"]

# pack_id -> PackData resource
var available_packs: = {}
# synergy_id -> SynergyData currently APPLIED (content registered)
var active_synergies: = {}
# pack_id -> bool (in-memory; persistence lands in Phase 2)
var enabled: = {}

# cached guard booleans - the greppable seam surface. All true while content
# stays scene-baked; _refresh_flags() keeps them honest once toggling is real.
var core: = true
var food: = true
var fortune: = true
var forge: = true
var ledger: = true
var roster: = true


var _applied_at_boot: bool = false


func _ready() -> void :
	# fallback only: ProgressData._ready drives apply_at_boot() BEFORE it loads
	# the save file. If that hook is ever lost, this at least registers content
	# late (menus work, saved-run resolution would not - hence the hook).
	apply_at_boot()


# Register all packs' content. MUST run before ProgressData.load_game_file()
# resolves a saved run (character, shop offers, inventory) against the content
# registry - the vanilla DLCs register at exactly that point, and running after
# it silently null-resolves every custom id in the save (2026-08-17 regression:
# resumed P2W run lost is_p2w - chest went to inventory, vanilla weapons in the
# chest shop). Idempotent: first caller wins.
func apply_at_boot() -> void :
	if _applied_at_boot:
		return
	_applied_at_boot = true
	_scan_available()
	# enabled = available minus the persisted opt-out list (DLC pattern:
	# settings.deactivated_dlcs). Settings are loaded before this runs
	# (ProgressData._ready calls load_settings() before the pack hook).
	var disabled: Array = ProgressData.settings.get("disabled_packs", [])
	for pack_id in available_packs:
		enabled[pack_id] = not disabled.has(pack_id)
	# test-only override: --packs=food,forge / --packs=none / --packs=all
	# (used by check_pack_matrix.sh; never set in normal play)
	for cmdline_arg in OS.get_cmdline_args():
		if str(cmdline_arg).begins_with("--packs="):
			var wanted: = str(cmdline_arg).replace("--packs=", "")
			for pack_id in available_packs:
				if wanted == "all":
					enabled[pack_id] = true
				elif wanted == "none":
					enabled[pack_id] = false
				else:
					enabled[pack_id] = wanted.split(",").has(pack_id)
	_apply_enabled()
	_refresh_flags()
	# greppable boot line - the smoke-test gate for the pack system. States the
	# ENABLED set + registered counts so a boot log proves which packs are live
	# (a line that reads the same for every combination proves nothing).
	var enabled_ids: Array = enabled_pack_ids()
	print("PackService: %d available, enabled=%s | chars=%d items=%d weapons=%d foods=%d" % [
		available_packs.size(), str(enabled_ids),
		ItemService.characters.size(), ItemService.items.size(),
		ItemService.weapons.size(), ItemService.foods.size()])
	# full self-test AFTER the whole boot settles (save loaded, pools built)
	call_deferred("_verify_registration")


# Permanent boot self-test (greppable: "PackService VERIFY"). Proves for every
# enabled pack that each declared resource actually sits in the live registry,
# that no registry array contains null (a broken tres path in a pack injects
# nulls), and that every pack character resolves by id - the exact failure
# class of the 2026-08-17 resume regression.
func _verify_registration() -> void :
	var problems: = []
	var registries: = {
		"characters": ItemService.characters, "items": ItemService.items,
		"weapons": ItemService.weapons, "foods": ItemService.foods,
		"stats": ItemService.stats, "sets": ItemService.sets,
		"upgrades": ItemService.upgrades,
	}
	for reg_name in registries:
		for entry in registries[reg_name]:
			if entry == null:
				problems.push_back("null entry in ItemService.%s" % reg_name)
	for pack_id in available_packs:
		if not bool(enabled.get(pack_id, false)):
			continue
		var pack = available_packs[pack_id]
		var pack_arrays: = {
			"characters": pack.characters, "items": pack.items,
			"weapons": pack.weapons, "foods": pack.foods,
			"stats": pack.stats, "sets": pack.sets, "upgrades": pack.upgrades,
		}
		for reg_name in pack_arrays:
			for res in pack_arrays[reg_name]:
				if res == null:
					problems.push_back("%s: null resource in %s (broken tres path)" % [pack_id, reg_name])
				elif not registries[reg_name].has(res):
					problems.push_back("%s: %s missing from ItemService.%s" % [pack_id, str(res.resource_path), reg_name])
		for character in pack.characters:
			if character != null and ItemService.get_element_safe(ItemService.characters, character.my_id) == null:
				problems.push_back("%s: character %s does not resolve by id" % [pack_id, str(character.my_id)])
	for sid in active_synergies:
		var synergy = active_synergies[sid]
		var synergy_arrays: = {
			"characters": synergy.characters, "items": synergy.items,
			"weapons": synergy.weapons, "foods": synergy.foods,
			"stats": synergy.stats, "sets": synergy.sets, "upgrades": synergy.upgrades,
		}
		for reg_name in synergy_arrays:
			for res in synergy_arrays[reg_name]:
				if res == null:
					problems.push_back("synergy %s: null resource in %s" % [sid, reg_name])
				elif not registries[reg_name].has(res):
					problems.push_back("synergy %s: %s missing from ItemService.%s" % [sid, str(res.resource_path), reg_name])
	if problems.empty():
		print("PackService VERIFY: OK (all pack content registered, no nulls, characters resolve)")
	else:
		for problem in problems:
			printerr("PackService VERIFY FAIL: %s" % problem)


# Register every enabled pack's content into the live singletons, then unlock
# and pool ONCE - mirroring ProgressData.activate_dlc's add_resources +
# add_unlocked_by_default pairing. Runs at boot (this autoload is last, so
# every singleton is ready) and content lands before any save/profile load
# re-runs the same generic unlock scan.
func _apply_enabled() -> void :
	var apply_order: Array = []
	for pack_id in PACK_APPLY_ORDER:
		if available_packs.has(pack_id):
			apply_order.push_back(pack_id)
	for pack_id in available_packs:
		if not apply_order.has(pack_id):
			apply_order.push_back(pack_id)
	var applied: int = 0
	for pack_id in apply_order:
		if bool(enabled.get(pack_id, false)):
			available_packs[pack_id].add_resources()
			applied += 1
	evaluate_synergies(true)
	_reorder_roster()
	if applied > 0:
		ProgressData.add_unlocked_by_default()
		ItemService.init_unlocked_pool()


func _reorder_roster() -> void :
	var customs: = []
	for character in ItemService.characters:
		if character != null and ROSTER_ORDER.has(character.my_id):
			customs.push_back(character)
	for character in customs:
		ItemService.characters.erase(character)
	customs.sort_custom(self, "_roster_compare")
	for character in customs:
		ItemService.characters.push_back(character)


func _roster_compare(a, b) -> bool:
	return ROSTER_ORDER.find(a.my_id) < ROSTER_ORDER.find(b.my_id)


# The hidden-when-incomplete law: a synergy's content is registered ONLY while
# its owning pack AND every pack in requires_packs are enabled; the moment any
# of them is disabled the content is unregistered (absent from select, shop,
# codex). Runs at boot and after every toggle. skip_pairing: boot calls the
# unlock+pool pairing once for packs and synergies together.
func evaluate_synergies(skip_pairing: bool = false) -> void :
	var changed: bool = false
	var seen_ids: = {}
	for pack_id in available_packs:
		var pack = available_packs[pack_id]
		for synergy in pack.synergies:
			if synergy == null or str(synergy.synergy_id) == "":
				continue
			var sid: String = str(synergy.synergy_id)
			seen_ids[sid] = true
			var wanted: bool = bool(enabled.get(pack_id, false))
			for required_id in synergy.requires_packs:
				if not bool(enabled.get(str(required_id), false)):
					wanted = false
			if wanted and not active_synergies.has(sid):
				synergy.add_resources()
				active_synergies[sid] = synergy
				changed = true
			elif not wanted and active_synergies.has(sid):
				active_synergies[sid].remove_resources()
				var _erased = active_synergies.erase(sid)
				changed = true
	# a synergy whose owner vanished from the scan entirely
	for sid in active_synergies.keys():
		if not seen_ids.has(sid):
			active_synergies[sid].remove_resources()
			var _erased2 = active_synergies.erase(sid)
			changed = true
	var hidden: = []
	for sid in seen_ids:
		if not active_synergies.has(sid):
			hidden.push_back(sid)
	hidden.sort()
	var active_ids: Array = active_synergies.keys()
	active_ids.sort()
	print("PackService synergies: active=%s hidden=%s" % [str(active_ids), str(hidden)])
	if changed and not skip_pairing:
		ProgressData.add_unlocked_by_default()
		ItemService.init_unlocked_pool()


func _scan_available() -> void :
	available_packs.clear()
	var dir: = Directory.new()
	if dir.open(PACKS_DIR) != OK:
		return
	dir.list_dir_begin(true, true)
	var entry: String = dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			var tres_path: String = PACKS_DIR + "/" + entry + "/pack_data.tres"
			if ResourceLoader.exists(tres_path):
				var pack = load(tres_path)
				if pack != null and str(pack.pack_id) != "":
					available_packs[str(pack.pack_id)] = pack
		entry = dir.get_next()
	dir.list_dir_end()


func is_pack_enabled(pack_id: String) -> bool:
	return bool(enabled.get(pack_id, false))


func enabled_pack_ids() -> Array:
	var ids: = []
	for pack_id in enabled:
		if bool(enabled[pack_id]):
			ids.push_back(str(pack_id))
	ids.sort()
	return ids


func activate_pack(pack_id: String) -> void :
	if not available_packs.has(pack_id) or bool(enabled.get(pack_id, false)):
		return
	enabled[pack_id] = true
	available_packs[pack_id].add_resources()
	ProgressData.add_unlocked_by_default()
	ItemService.init_unlocked_pool()
	ProgressData.settings.disabled_packs.erase(pack_id)
	ProgressData.save_settings()
	evaluate_synergies()
	_reorder_roster()
	_refresh_flags()
	emit_signal("pack_activated", pack_id)


func deactivate_pack(pack_id: String) -> void :
	if not bool(enabled.get(pack_id, false)):
		return
	enabled[pack_id] = false
	available_packs[pack_id].remove_resources()
	ItemService.init_unlocked_pool()
	if not ProgressData.settings.disabled_packs.has(pack_id):
		ProgressData.settings.disabled_packs.push_back(pack_id)
	ProgressData.save_settings()
	evaluate_synergies()
	_refresh_flags()
	emit_signal("pack_deactivated", pack_id)


func _refresh_flags() -> void :
	core = true
	food = is_pack_enabled("food")
	fortune = is_pack_enabled("fortune")
	forge = is_pack_enabled("forge")
	ledger = is_pack_enabled("ledger")
	roster = is_pack_enabled("roster")
