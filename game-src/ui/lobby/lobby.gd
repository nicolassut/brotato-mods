extends Node2D

# Gourmet ecosystem - THE HUB (HUB_PLAN.md; step 1 = flow on placeholders).
# Two faked tiers: the upper DEPARTURE DECK (north, behind a wall band with
# two stair gaps) and the lower plaza. Stations: the departure SHUTTLE (enters
# the run flow at weapon select - characters come from hub state), the
# CHANGING BOOTH on the back wall between the stairs (opens the unchanged
# vanilla character select for all players; coop joins there), and the
# game-mode shrine. Six slot anchors await the pack buildings (step 2).
# Avatars: one per active player, each wearing its last-played character
# (settings.last_played_characters, well_rounded if never played).
# ESC returns to the title screen.

const LobbyNpc: = preload("res://ui/lobby/lobby_npc.gd")
const LobbyPlayer: = preload("res://ui/lobby/lobby_player.gd")

const FLOOR_COLOR: = Color(0.16, 0.13, 0.11, 1.0)
const WALL_COLOR: = Color(0.09, 0.07, 0.06, 1.0)
const DEFAULT_CHARACTER: = "character_well_rounded"

# the wall band separating deck from plaza, and its two stair gaps
const DIVIDER_TOP: = - 260.0
const DIVIDER_BOTTOM: = - 160.0
const STAIR_LEFT: = Rect2(-820, DIVIDER_TOP, 200, 100)
const STAIR_RIGHT: = Rect2(620, DIVIDER_TOP, 200, 100)

const SLOT_POSITIONS: = [
	Vector2(-750, 60), Vector2(-750, 260), Vector2(-750, 460),
	Vector2(750, 60), Vector2(750, 260), Vector2(750, 460),
]
const SPAWN_POINT: = Vector2(0, 540)

var _players: = []
var _camera: Camera2D = null
var _shrine = null


func _ready() -> void :
	_build_floor()
	_build_slots()
	_build_players()
	_build_camera()
	_build_npcs()
	print("Lobby ready: %d station(s), %d slots" % [
		get_tree().get_nodes_in_group("lobby_npcs").size(),
		get_tree().get_nodes_in_group("lobby_slots").size()])


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
	# the deck/plaza divider wall band, with the two stair gaps drawn open
	var divider: = ColorRect.new()
	divider.rect_position = Vector2(-1100, DIVIDER_TOP)
	divider.rect_size = Vector2(2200, DIVIDER_BOTTOM - DIVIDER_TOP)
	divider.color = WALL_COLOR
	add_child(divider)
	for stair in [STAIR_LEFT, STAIR_RIGHT]:
		var gap: = ColorRect.new()
		gap.rect_position = stair.position
		gap.rect_size = stair.size
		gap.color = FLOOR_COLOR
		add_child(gap)
	# collision: three wall segments; the stair gaps stay walkable
	_add_wall(Rect2(-1100, DIVIDER_TOP, STAIR_LEFT.position.x + 1100, 100))
	_add_wall(Rect2(STAIR_LEFT.end.x, DIVIDER_TOP,
			STAIR_RIGHT.position.x - STAIR_LEFT.end.x, 100))
	_add_wall(Rect2(STAIR_RIGHT.end.x, DIVIDER_TOP, 1100 - STAIR_RIGHT.end.x, 100))


func _add_wall(rect: Rect2) -> void :
	if rect.size.x <= 0.0:
		return
	var body: = StaticBody2D.new()
	var shape: = CollisionShape2D.new()
	var box: = RectangleShape2D.new()
	box.extents = rect.size / 2.0
	shape.shape = box
	body.position = rect.position + rect.size / 2.0
	body.add_child(shape)
	add_child(body)


func _build_slots() -> void :
	# fixed anchors for the pack buildings (HUB_PLAN slot system, filled in
	# step 2). Position2D only for now - the gate asserts they exist.
	for i in SLOT_POSITIONS.size():
		var marker: = Position2D.new()
		marker.name = "slot_%d" % (i + 1)
		marker.position = SLOT_POSITIONS[i]
		marker.add_to_group("lobby_slots")
		add_child(marker)


func _build_players() -> void :
	var count: int = int(clamp(RunData.get_player_count(), 1, 4))
	var last_played: Array = ProgressData.settings.get("last_played_characters", ["", "", "", ""])
	for player_index in count:
		# untyped on purpose: the typed form parse-checks members against
		# KinematicBody2D and rejects the script's own player_index/dress_as
		var avatar = KinematicBody2D.new()
		avatar.set_script(LobbyPlayer)
		avatar.player_index = player_index
		avatar.use_device_actions = RunData.is_coop_run
		if RunData.is_coop_run:
			avatar.device = CoopService.get_remapped_player_device(player_index)
		var shape: = CollisionShape2D.new()
		var circle: = CircleShape2D.new()
		circle.radius = 24.0
		shape.shape = circle
		avatar.add_child(shape)
		avatar.position = SPAWN_POINT + Vector2((player_index - (count - 1) / 2.0) * 90.0, 0)
		add_child(avatar)
		avatar.dress_as(_resolve_character(str(last_played[player_index]) if player_index < last_played.size() else ""))
		_players.push_back(avatar)


func _resolve_character(my_id: String):
	# last-played id -> live registry (the pack may be off - fall back), else
	# the never-played default
	var character = null
	if my_id != "":
		character = ItemService.get_element_safe(ItemService.characters, my_id)
	if character == null:
		character = ItemService.get_element_safe(ItemService.characters, DEFAULT_CHARACTER)
	return character


func _build_camera() -> void :
	_camera = Camera2D.new()
	_camera.current = true
	_camera.smoothing_enabled = true
	_camera.smoothing_speed = 6.0
	_camera.limit_left = - 1250
	_camera.limit_right = 1250
	_camera.limit_top = - 770
	_camera.limit_bottom = 770
	add_child(_camera)


func _process(_delta: float) -> void :
	if _players.empty() or _camera == null:
		return
	var midpoint: = Vector2.ZERO
	for avatar in _players:
		midpoint += avatar.position
	_camera.position = midpoint / _players.size()


func _build_npcs() -> void :
	# the departure shuttle (deck) - enters the run flow at WEAPON select
	var shuttle = _spawn_npc("res://items/custom/street_vendor/street_vendor.png",
			Vector2(0, -460), tr("LOBBY_SHUTTLE"), tr("LOBBY_SHUTTLE_PROMPT"))
	var _e0 = shuttle.connect("interacted", self, "_on_shuttle_interacted")

	# the changing booth - back wall between the stairs (opens character select)
	var booth = _spawn_npc("res://items/custom/espresso_machine/espresso_machine.png",
			Vector2(0, -60), tr("LOBBY_BOOTH"), tr("LOBBY_BOOTH_PROMPT"))
	var _e1 = booth.connect("interacted", self, "_on_booth_interacted")

	# the game-mode shrine (deck) - interact cycles the mode
	_shrine = _spawn_npc("res://items/custom_characters/special/special_icon.png",
			Vector2(-620, -460), tr("LOBBY_SHRINE"), "")
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


func _on_shuttle_interacted() -> void :
	# HUB_PLAN flow law: the hub character IS the run character. Apply every
	# active player's hub character to RunData exactly like character
	# selection's confirm does, then enter the flow at weapon select.
	MenuData.run_flow_from_lobby = true
	ProgressData.start_activity()
	var last_played: Array = ProgressData.settings.get("last_played_characters", ["", "", "", ""])
	for player_index in RunData.get_player_count():
		var my_id: String = str(last_played[player_index]) if player_index < last_played.size() else ""
		RunData.add_character(_resolve_character(my_id), player_index)
	if RunData.some_player_has_weapon_slots():
		var _e = get_tree().change_scene(MenuData.weapon_selection_scene)
	else:
		RunData.add_starting_items_and_weapons()
		var _e2 = get_tree().change_scene(MenuData.difficulty_selection_scene)


func _on_booth_interacted() -> void :
	MenuData.run_flow_from_lobby = true
	MenuData.character_select_for_lobby = true
	ProgressData.start_activity()
	var _error = get_tree().change_scene(MenuData.character_selection_scene)


func _on_shrine_interacted() -> void :
	# cycle: none -> each available mode -> none. Persisted immediately; the
	# run start stamps it per player (difficulty_selection).
	var modes: Array = Utils.game_modes.available_modes()
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
	var mode: Dictionary = Utils.game_modes.mode_by_id(current)
	var mode_name: String = tr("MODE_NONE") if mode.empty() else str(mode["name"])
	_shrine.set_prompt(tr("LOBBY_SHRINE_PROMPT") % mode_name)


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		var _error = get_tree().change_scene(MenuData.title_screen_scene)
