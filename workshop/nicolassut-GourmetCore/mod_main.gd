extends Node

# GourmetCore mod entry (SCAFFOLD - not functional yet; see WORKSHOP_READINESS.md).
# The real implementation will:
#  1. install_script_extension() for every file in core_surface.json
#     (requires extensions/ to be generated from a pristine-vs-modified diff)
#  2. add the Packs / GameModes / GourmetTracker / ButcherSkin / SpecialModifiers
#     services as root nodes (runtime pseudo-autoloads - project.godot cannot be
#     patched by a mod)
#  3. register the "interact" input action via InputMap at runtime
#  4. load pack .pck art through ProjectSettings.load_resource_pack

func _init(modLoader = ModLoader):
	pass
