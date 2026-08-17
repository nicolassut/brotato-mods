extends Node

var community_url: String = "https://www.blobfishgames.com/community"
var newsletter_url: String = "https://www.blobfishgames.com/newsletter"
onready var more_games_url: String = Platform.get_more_games_url()
onready var dlc_url: String = Platform.get_dlc_url()

var title_screen_scene: String = "res://ui/menus/title_screen/title_screen.tscn"
var game_scene: String = "res://main.tscn"
var shop_scene: String = "res://ui/menus/shop/shop.tscn"
var character_selection_scene: String = "res://ui/menus/run/character_selection.tscn"
var weapon_selection_scene: String = "res://ui/menus/run/weapon_selection.tscn"
var difficulty_selection_scene: String = "res://ui/menus/run/difficulty_selection/difficulty_selection.tscn"
