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
