extends Node

const LOG_NAME = "nicolassut-HelloBrotato"

func _init(modLoader = ModLoader):
	ModLoaderUtils.log_info("Init", LOG_NAME)
	modLoader.install_script_extension("res://mods-unpacked/nicolassut-HelloBrotato/extensions/ui/menus/pages/main_menu.gd")

func _ready():
	ModLoaderUtils.log_info("Ready", LOG_NAME)
