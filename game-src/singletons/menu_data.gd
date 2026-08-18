extends Node

var community_url: String = "https://www.blobfishgames.com/community"
var newsletter_url: String = "https://www.blobfishgames.com/newsletter"
onready var more_games_url: String = Platform.get_more_games_url()
onready var dlc_url: String = Platform.get_dlc_url()

var title_screen_scene: String = "res://ui/menus/title_screen/title_screen.tscn"
var game_scene: String = "res://main.tscn"
var shop_scene: String = "res://ui/menus/shop/shop.tscn"
var character_selection_scene: String = "res://ui/menus/run/character_selection.tscn"
# Gourmet ecosystem - the walkable Hub, its own main-menu destination (never in
# the Start path - user law 2026-08-18). run_flow_from_lobby marks a run flow
# begun at the Hub's Departure door so Back returns there.
var lobby_scene: String = "res://ui/lobby/lobby.tscn"
var run_flow_from_lobby: bool = false
# set by the Hub's changing booth: character select stores the picks as hub
# characters and returns to the Hub instead of continuing to weapon select
var character_select_for_lobby: bool = false
# avatar positions captured when leaving the Hub into any menu; the Hub
# restores (and clears) them on re-entry so you come back exactly where you
# stood. Empty = fresh entry, spawn at the entrance.
var lobby_return_positions: Array = []
var weapon_selection_scene: String = "res://ui/menus/run/weapon_selection.tscn"
var difficulty_selection_scene: String = "res://ui/menus/run/difficulty_selection/difficulty_selection.tscn"
