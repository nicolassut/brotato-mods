extends "res://ui/menus/pages/main_menu.gd"

func init():
	.init()
	if version_label:
		version_label.text += "  |  Mods are working!"
