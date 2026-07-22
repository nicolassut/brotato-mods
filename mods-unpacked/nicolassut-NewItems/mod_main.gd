extends Node

const MOD_DIR = "nicolassut-NewItems/"
const MOD_LOG = "nicolassut-NewItems"

var dir = ""


func _init():
	ModLoaderLog.info("Init", MOD_LOG)
	dir = ModLoaderMod.get_unpacked_dir() + MOD_DIR


func _ready():
	var ContentLoader = get_node("/root/ModLoader/Darkly77-ContentLoader/ContentLoader")

	ContentLoader.load_data(dir + "content_data/new_items_and_character.tres", MOD_LOG)

	ModLoaderLog.info("Done", MOD_LOG)
