extends Node2D

# Gourmet ecosystem - THE LOBBY (ECOSYSTEM.md Phase 7, v1 foundation). A
# walkable hub between main menu and character select: run-start door, the
# game-mode shrine (interact to cycle - no focusable UI, so controller nav
# needs nothing), and a framework ready for per-pack NPCs. ESC returns to the
# title screen. settings.skip_lobby bypasses the whole scene.

const LobbyNpc: = preload("res://ui/lobby/lobby_npc.gd")
const LobbyPlayer: = preload("res://ui/lobby/lobby_player.gd")

const FLOOR_COLOR: = Color(0.16, 0.13, 0.11, 1.0)
const WALL_COLOR: = Color(0.09, 0.07, 0.06, 1.0)

var _player: KinematicBody2D = null
var _shrine = null


func _ready() -> void :
	_build_floor()
	_build_player()
	_build_npcs()
	print("Lobby ready: %d station(s)" % (get_tree().get_nodes_in_group("lobby_npcs").size()))


func _build_floor() -> void :
	var wall: = ColorRect.new()
	wall.rect_position = Vector2(-1250, -770)
	wall.rect_size = Vector2(2500, 1540)
	wall.color = WALL_COLOR
	add_child(wall)
	var floor_rect: = ColorRect.new()
	floor_rect.rect_position = Vector2(-1100, -620)
	floor_rect.rect_size = Vector2(2200, 1240)
	floor_rect.color = FLOOR_COLOR
	add_child(floor_rect)


func _build_player() -> void :
	_player = KinematicBody2D.new()
	_player.set_script(LobbyPlayer)
	var sprite: = Sprite.new()
	sprite.name = "Sprite"
	var potato = load("res://entities/units/player/potato.png")
	if potato != null:
		sprite.texture = potato
	_player.add_child(sprite)
	var camera: = Camera2D.new()
	camera.current = true
	camera.smoothing_enabled = true
	camera.smoothing_speed = 6.0
	_player.add_child(camera)
	_player.position = Vector2(0, 260)
	add_child(_player)


func _build_npcs() -> void :
	# the run-start door - always present (core)
	var door = _spawn_npc("res://items/custom/street_vendor/street_vendor.png",
			Vector2(620, -40), tr("LOBBY_DOOR"), tr("LOBBY_DOOR_PROMPT"))
	var _e1 = door.connect("interacted", self, "_on_door_interacted")

	# the game-mode shrine - always present (core); interact cycles the mode
	_shrine = _spawn_npc("res://items/custom_characters/special/special_icon.png",
			Vector2(-620, -40), tr("LOBBY_SHRINE"), "")
	_update_shrine_prompt()
	var _e2 = _shrine.connect("interacted", self, "_on_shrine_interacted")


func _spawn_npc(texture_path: String, at: Vector2, display_name: String, prompt: String):
	var npc = LobbyNpc.new()
	var texture: Texture = null
	if ResourceLoader.exists(texture_path):
		texture = load(texture_path)
	npc.setup(texture, display_name, prompt)
	npc.position = at
	npc.add_to_group("lobby_npcs")
	add_child(npc)
	return npc


func _on_door_interacted() -> void :
	ProgressData.start_activity()
	var _error = get_tree().change_scene(MenuData.character_selection_scene)


func _on_shrine_interacted() -> void :
	# cycle: none -> each available mode -> none. Persisted immediately; the
	# run start stamps it per player (difficulty_selection).
	var modes: Array = GameModes.available_modes()
	var current: String = str(ProgressData.settings.get("selected_game_mode", ""))
	var cycle: Array = [""]
	for mode in modes:
		cycle.push_back(str(mode["id"]))
	var next_index: int = (cycle.find(current) + 1) % cycle.size()
	ProgressData.settings.selected_game_mode = cycle[next_index]
	ProgressData.save_settings()
	_update_shrine_prompt()


func _update_shrine_prompt() -> void :
	var current: String = str(ProgressData.settings.get("selected_game_mode", ""))
	var mode: Dictionary = GameModes.mode_by_id(current)
	var mode_name: String = tr("MODE_NONE") if mode.empty() else str(mode["name"])
	_shrine.set_prompt(tr("LOBBY_SHRINE_PROMPT") % mode_name)


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		var _error = get_tree().change_scene(MenuData.title_screen_scene)
