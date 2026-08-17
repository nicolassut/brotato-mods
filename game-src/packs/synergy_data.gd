extends "res://packs/pack_data.gd"

# Gourmet ecosystem - SynergyData: content that exists ONLY while every pack in
# requires_packs is enabled (the hidden-when-incomplete law, ECOSYSTEM.md).
# Inherits the full PackData registration contract (arrays + reversible
# add_resources/remove_resources); Packs.evaluate_synergies() drives it on boot
# and on every pack toggle. A synergy lives in exactly ONE owning pack's
# `synergies` array - the owner must itself be enabled for the synergy to
# activate, so never list the owner in requires_packs.

export (String) var synergy_id: = ""
