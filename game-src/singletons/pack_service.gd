extends Node

# Gourmet ecosystem - the pack lifecycle service, autoloaded as "Packs"
# (ECOSYSTEM.md). Phase 2: custom content registration lives in the six
# PackData resources under res://packs/ (no longer scene-baked in
# item_service.tscn); this service applies every enabled pack at boot in a
# fixed order, then runs the same unlock+pool pairing ProgressData.activate_dlc
# uses for DLCs. The cached boolean facade below is the guard surface future
# seams read (`if Packs.food:`).
#
# Still deliberately NOT here (arrives with ECOSYSTEM.md Phase 3):
# - persistence (settings.disabled_packs) beyond this session and the toggle UI
#   polish; runtime deactivate works but mid-run toggling is unsupported.
# - RunData.enabled_packs run snapshot + Continue invalidation.

signal pack_activated(pack_id)
signal pack_deactivated(pack_id)

const PACKS_DIR: = "res://packs"
# apply order is fixed so the character-select roster groups deterministically
const PACK_APPLY_ORDER: = ["food", "fortune", "forge", "ledger", "roster"]

# pack_id -> PackData resource
var available_packs: = {}
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
	for pack_id in available_packs:
		enabled[pack_id] = true
	_apply_enabled()
	_refresh_flags()
	# greppable boot line - the smoke-test gate for the pack system
	print("PackService: %d pack(s) available: %s" % [available_packs.size(), str(available_packs.keys())])
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
	if applied > 0:
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


func activate_pack(pack_id: String) -> void :
	if not available_packs.has(pack_id) or bool(enabled.get(pack_id, false)):
		return
	enabled[pack_id] = true
	available_packs[pack_id].add_resources()
	ProgressData.add_unlocked_by_default()
	ItemService.init_unlocked_pool()
	_refresh_flags()
	emit_signal("pack_activated", pack_id)


func deactivate_pack(pack_id: String) -> void :
	if not bool(enabled.get(pack_id, false)):
		return
	enabled[pack_id] = false
	available_packs[pack_id].remove_resources()
	ItemService.init_unlocked_pool()
	_refresh_flags()
	emit_signal("pack_deactivated", pack_id)


func _refresh_flags() -> void :
	core = true
	food = is_pack_enabled("food")
	fortune = is_pack_enabled("fortune")
	forge = is_pack_enabled("forge")
	ledger = is_pack_enabled("ledger")
	roster = is_pack_enabled("roster")
