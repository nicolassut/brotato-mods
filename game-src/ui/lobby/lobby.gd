extends Node2D

# Gourmet ecosystem - THE HUB (HUB_PLAN.md; step 1 = flow on placeholders).
# Two faked tiers per HUB_ART_SPEC.md section 1 (the layout IS the art spec):
# upper DEPARTURE DECK, 256px cliff face strip with two LONG staircases, and
# the lower plaza. Stations: the departure SHUTTLE (enters
# the run flow at weapon select - characters come from hub state), the
# CHANGING BOOTH on the back wall between the stairs (opens the unchanged
# vanilla character select for all players; coop joins there), and the
# game-mode shrine. Six slot anchors await the pack buildings (step 2).
# Avatars: one per active player, each wearing its last-played character
# (settings.last_played_characters, well_rounded if never played).
# ESC returns to the title screen.

const LobbyNpc: = preload("res://ui/lobby/lobby_npc.gd")
const LobbyPlayer: = preload("res://ui/lobby/lobby_player.gd")

const FLOOR_COLOR: = Color(0.17, 0.14, 0.125, 1.0)      # plaza: alien dirt
const DECK_COLOR: = Color(0.14, 0.15, 0.17, 1.0)        # deck: metal plating
const CLIFF_COLOR: = Color(0.08, 0.065, 0.055, 1.0)     # cliff face strip
const WALL_COLOR: = Color(0.055, 0.045, 0.04, 1.0)      # perimeter
const PAD_COLOR: = Color(0.19, 0.19, 0.16, 1.0)         # shuttle pad decal
const SLOT_COLOR: = Color(0.13, 0.11, 0.10, 1.0)        # building footprints
const DEFAULT_CHARACTER: = "character_well_rounded"

# ALL rects come from HUB_ART_SPEC.md section 1 - placeholder footprints are
# the FINAL art footprints (placeholder law). Change the spec first.
const DECK_RECT: = Rect2(-1216, -936, 2432, 420)
const CLIFF_RECT: = Rect2(-1216, -516, 2432, 256)
const PLAZA_RECT: = Rect2(-1216, -260, 2432, 1140)
const STAIR_WEST: = Rect2(-896, -580, 256, 384)
const STAIR_EAST: = Rect2(640, -580, 256, 384)
const SHUTTLE_PAD_RECT: = Rect2(-280, -940, 560, 420)
const SHUTTLE_POS: = Vector2(0, -730)
const SHRINE_POS: = Vector2(-640, -700)
const BOARD_RECT: = Rect2(448, -812, 384, 224)
const BOOTH_POS: = Vector2(0, -240)
const FOUNTAIN_RECT: = Rect2(-192, 80, 384, 320)
const GATE_RECT: = Rect2(-192, 864, 384, 160)
const SLOT_SIZE: = Vector2(416, 352)
const SLOT_POSITIONS: = [
	Vector2(-880, -20), Vector2(-880, 320), Vector2(-880, 660),
	Vector2(880, -20), Vector2(880, 320), Vector2(880, 660),
]
const SPAWN_POINT: = Vector2(0, 800)

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
	_rect(Rect2(-1280, -1000, 2560, 2000), WALL_COLOR)
	_rect(DECK_RECT, DECK_COLOR)
	_rect(CLIFF_RECT, CLIFF_COLOR)
	_rect(PLAZA_RECT, FLOOR_COLOR)
	# the two long staircases descend the cliff strip (landing + run + apron)
	for stair in [STAIR_WEST, STAIR_EAST]:
		_rect(stair, DECK_COLOR)
	_rect(SHUTTLE_PAD_RECT, PAD_COLOR)
	_rect(FOUNTAIN_RECT, SLOT_COLOR)
	_rect(BOARD_RECT, SLOT_COLOR)
	_rect(GATE_RECT, CLIFF_COLOR)
	for slot_pos in SLOT_POSITIONS:
		_rect(Rect2(slot_pos - SLOT_SIZE / 2.0, SLOT_SIZE), SLOT_COLOR)
	# collision: cliff strip blocks deck<->plaza except through the stairs
	_add_wall(Rect2(CLIFF_RECT.position.x, CLIFF_RECT.position.y,
			STAIR_WEST.position.x - CLIFF_RECT.position.x, CLIFF_RECT.size.y))
	_add_wall(Rect2(STAIR_WEST.end.x, CLIFF_RECT.position.y,
			STAIR_EAST.position.x - STAIR_WEST.end.x, CLIFF_RECT.size.y))
	_add_wall(Rect2(STAIR_EAST.end.x, CLIFF_RECT.position.y,
			CLIFF_RECT.end.x - STAIR_EAST.end.x, CLIFF_RECT.size.y))
	# the fountain is solid
	_add_wall(FOUNTAIN_RECT)


func _rect(rect: Rect2, color: Color) -> void :
	var r: = ColorRect.new()
	r.rect_position = rect.position
	r.rect_size = rect.size
	r.color = color
	add_child(r)


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
	_camera.limit_left = - 1280
	_camera.limit_right = 1280
	_camera.limit_top = - 1000
	_camera.limit_bottom = 944
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
			SHUTTLE_POS, tr("LOBBY_SHUTTLE"), tr("LOBBY_SHUTTLE_PROMPT"))
	var _e0 = shuttle.connect("interacted", self, "_on_shuttle_interacted")

	# the changing booth - back wall between the stairs (opens character select)
	var booth = _spawn_npc("res://items/custom/espresso_machine/espresso_machine.png",
			BOOTH_POS, tr("LOBBY_BOOTH"), tr("LOBBY_BOOTH_PROMPT"))
	var _e1 = booth.connect("interacted", self, "_on_booth_interacted")

	# the game-mode shrine (deck) - interact cycles the mode
	_shrine = _spawn_npc("res://items/custom_characters/special/special_icon.png",
			SHRINE_POS, tr("LOBBY_SHRINE"), "")
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
