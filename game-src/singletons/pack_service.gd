extends Node

# Gourmet ecosystem - the pack lifecycle service, autoloaded as "Packs"
# (ECOSYSTEM.md). Phase 1 scaffolding: scans res://packs/, everything found is
# enabled, and the cached boolean facade below is the guard surface future
# seams read (`if Packs.food:`).
#
# Deliberately NOT yet done here (arrives with ECOSYSTEM.md Phase 2/3):
# - calling PackData.add_resources()/remove_resources() on toggle: all content
#   is still scene-baked in item_service.tscn, so applying resources here would
#   double-register. Until registration migrates, toggling only flips flags.
# - persistence (settings.disabled_packs) and the toggle UI.
# - RunData.enabled_packs run snapshot + Continue invalidation.

signal pack_activated(pack_id)
signal pack_deactivated(pack_id)

const PACKS_DIR: = "res://packs"

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


func _ready() -> void :
	_scan_available()
	for pack_id in available_packs:
		enabled[pack_id] = true
	_refresh_flags()
	# greppable boot line - the smoke-test gate for the pack system
	print("PackService: %d pack(s) available: %s" % [available_packs.size(), str(available_packs.keys())])


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
	# unknown packs read as disabled; the transitional "everything" marker pack
	# stands in for every real pack until the Phase 2 split
	if enabled.get("everything", false):
		return true
	return bool(enabled.get(pack_id, false))


func activate_pack(pack_id: String) -> void :
	if not available_packs.has(pack_id) or bool(enabled.get(pack_id, false)):
		return
	enabled[pack_id] = true
	# Phase 2: available_packs[pack_id].add_resources() once registration
	# migrates off item_service.tscn
	_refresh_flags()
	emit_signal("pack_activated", pack_id)


func deactivate_pack(pack_id: String) -> void :
	if not bool(enabled.get(pack_id, false)):
		return
	enabled[pack_id] = false
	# Phase 2: available_packs[pack_id].remove_resources()
	_refresh_flags()
	emit_signal("pack_deactivated", pack_id)


func _refresh_flags() -> void :
	core = true
	food = is_pack_enabled("food")
	fortune = is_pack_enabled("fortune")
	forge = is_pack_enabled("forge")
	ledger = is_pack_enabled("ledger")
	roster = is_pack_enabled("roster")
