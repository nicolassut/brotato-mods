extends "res://global/dlc_data.gd"

# Gourmet ecosystem - PackData: one feature pack (ECOSYSTEM.md). Extends the
# vanilla DLC contract, which already provides every registration array plus
# reversible add_resources()/remove_resources() and the per-item hooks. Packs
# live under res://packs/ (NEVER res://dlcs/ - that scan runs Steam entitlement
# checks). Extended by path, not class_name, so loading never depends on the
# editor's global class cache.

# machine id of this pack: core, food, fortune, forge, ledger, roster
export (String) var pack_id: = ""
# human name shown in (future) toggle UI
export (String) var display_name: = ""
# other pack_ids this pack needs (core is implicit and never listed)
export (PoolStringArray) var requires_packs: = PoolStringArray()
# SynergyData resources owned by this pack (registered by PackService only when
# every required pack is enabled - the hidden-when-incomplete law)
export (Array, Resource) var synergies: = []
# Gourmet-specific registries the vanilla DLC contract does not know about
export (Array, Resource) var foods: = []
export (Array, Resource) var upgrades: = []


# The inherited implementation covers characters/items/weapons/stats/sets/
# translations/tracked_items and re-runs hashing + the unlocked pool. The
# weapon->starting_weapons splice it contains is gated on a per-weapon field
# none of our weapons set, so it is inert here. We only add the Gourmet arrays.
# NOTE: PackService calls ProgressData.add_unlocked_by_default() and
# ItemService.init_unlocked_pool() ONCE after applying all packs - the same
# pairing ProgressData.activate_dlc does for DLCs.
func add_resources():
	.add_resources()
	ItemService.foods.append_array(foods)
	ItemService.upgrades.append_array(upgrades)


func remove_resources():
	.remove_resources()
	for food in foods:
		ItemService.foods.erase(food)
	for upgrade in upgrades:
		ItemService.upgrades.erase(upgrade)
