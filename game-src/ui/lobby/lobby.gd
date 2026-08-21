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

const FLOOR_COLOR: = Color(0.259, 0.239, 0.224, 1.0)    # plaza: crash-zone dirt (measured)
const DECK_COLOR: = Color(0.204, 0.216, 0.243, 1.0)     # deck: metal plating
const CLIFF_COLOR: = Color(0.08, 0.065, 0.055, 1.0)     # cliff face strip
const WALL_COLOR: = Color(0.055, 0.045, 0.04, 1.0)      # perimeter
const PAD_COLOR: = Color(0.19, 0.19, 0.16, 1.0)         # shuttle pad decal
const SLOT_COLOR: = Color(0.13, 0.11, 0.10, 1.0)        # building footprints
const DEFAULT_CHARACTER: = "character_well_rounded"

# ALL rects come from HUB_ART_SPEC.md section 1 - placeholder footprints are
# the FINAL art footprints (placeholder law). Change the spec first.
const DECK_RECT: = Rect2(-1376, -1176, 2752, 560)
const CLIFF_RECT: = Rect2(-1376, -616, 2752, 384)
const PLAZA_RECT: = Rect2(-1376, -232, 2752, 1344)
const STAIR_WEST: = Rect2(-672, -712, 256, 576)
const STAIR_EAST: = Rect2(416, -712, 256, 576)
const SHUTTLE_PAD_RECT: = Rect2(-280, -1176, 560, 384)
const SHUTTLE_POS: = Vector2(0, -984)
const SHRINE_POS: = Vector2(-880, -890)
const SHRINE_RECT: = Rect2(-976, -1000, 192, 224)
const BOARD_RECT: = Rect2(688, -1000, 384, 224)
const BOOTH_POS: = Vector2(0, -300)
const BOOTH_RECT: = Rect2(-112, -340, 224, 256)
# booth sprite is 221x300 (bake_booth.py); base at -124, backed close to the
# cliff wall (user 2026-08-20). Screen tube (blanked in the art) consts come
# from bake_booth.py output - node coords relative to the base origin.
const BOOTH_SCREEN_OFFSET: = Vector2(0, -246)
const BOOTH_SCREEN_SIZE: = Vector2(45, 35)
const FOUNTAIN_RECT: = Rect2(-192, 180, 384, 320)
const GATE_RECT: = Rect2(-192, 1064, 384, 160)
const SLOT_SIZE: = Vector2(416, 352)
# 2+2+2: two per side column, two flanking the entrance (slot RECT centers)
const SLOT_POSITIONS: = [
	Vector2(-1140, 80), Vector2(-1140, 520), Vector2(-550, 800),
	Vector2(1140, 80), Vector2(1140, 520), Vector2(550, 800),
]
const SPAWN_POINT: = Vector2(0, 1000)

var _players: = []
var _world: YSort = null
var _camera: Camera2D = null
var _shrine = null
var _mode_popup: CanvasLayer = null
var _booth_screen: Sprite = null
var _booth_faces: = []
var _booth_static: = []
var _booth_tick: int = 0
var _booth_face_index: int = 0
var _booth_bulbs: Sprite = null
var _booth_bulb_frames: = []
var _booth_bulb_index: int = 0


func _ready() -> void :
	_build_floor()
	_build_slots()
	_build_players()
	_build_camera()
	_build_npcs()
	# art build stamp: the mtime of the stairs texture identifies which art
	# build this running instance loaded (stale-window confusion killer)
	var art_file: = File.new()
	var art_stamp: String = "?"
	if art_file.open("res://ui/lobby/art/stairs.png", File.READ) == OK:
		art_stamp = str(art_file.get_len())
		art_file.close()
	var stamp_label: = Label.new()
	stamp_label.text = "art build " + art_stamp
	stamp_label.rect_position = Vector2(8, 8)
	stamp_label.modulate = Color(1, 1, 1, 0.35)
	var stamp_layer: = CanvasLayer.new()
	stamp_layer.add_child(stamp_label)
	add_child(stamp_layer)
	print("Lobby ready: %d station(s), %d building(s), %d slots" % [
		get_tree().get_nodes_in_group("lobby_npcs").size(),
		get_tree().get_nodes_in_group("lobby_buildings").size(),
		get_tree().get_nodes_in_group("lobby_slots").size()])


func _build_floor() -> void :
	_rect(Rect2(-1440, -1240, 2880, 2480), WALL_COLOR)
	_rect(DECK_RECT, DECK_COLOR)
	_rect(CLIFF_RECT, CLIFF_COLOR)
	_rect(PLAZA_RECT, FLOOR_COLOR)
	# the staircases are drawn ENTIRELY by their sprite overlays - no rect
	# fill (2026-08-20: the old DECK_COLOR fill peeked out past the sprite
	# as gray slivers beside the rails)
	_rect(SHUTTLE_PAD_RECT, PAD_COLOR)
	_rect(BOARD_RECT, SLOT_COLOR)
	_rect(SHRINE_RECT, SLOT_COLOR)
	_rect(GATE_RECT, CLIFF_COLOR)
	# ground overlays (HUB_ART_SPEC 1c: vanilla-language decals/seams/torn lip)
	_ground_overlay("res://ui/lobby/art/ground_plaza.png", PLAZA_RECT)
	_ground_overlay("res://ui/lobby/art/ground_deck.png", DECK_RECT)
	_ground_overlay("res://ui/lobby/art/ground_cliff.png", CLIFF_RECT)
	# NORTH WALL (W2, user 2026-08-21): rock face + riveted ribs along the
	# deck's back edge, drawn in the void band above the deck (no walkable
	# area lost); its 14px contact shadow overhangs onto the deck slabs
	_ground_overlay("res://ui/lobby/art/wall_north.png", Rect2(-1376, -1356, 2752, 194))
	_ground_overlay("res://ui/lobby/art/stairs.png", STAIR_WEST)
	_ground_overlay("res://ui/lobby/art/stairs_e.png", STAIR_EAST)
	# OFF DUTY corner decals (flat on ground/wall, under the YSort world).
	# Placement tuned VISUALLY in layout_offduty.py (the compositor renders
	# the corner offline; coordinates here MIRROR it exactly)
	_decal("res://ui/lobby/art/od_rug.png", Vector2(-1160, -700))
	_decal("res://ui/lobby/art/od_scorch.png", Vector2(-1270, -786))
	_decal("res://ui/lobby/art/od_cards.png", Vector2(-868, -1022))
	_decal("res://ui/lobby/art/od_chips.png", Vector2(-832, -1008))
	_decal("res://ui/lobby/art/od_sign.png", Vector2(-1040, -1245))
	_decal("res://ui/lobby/art/od_dartboard.png", Vector2(-925, -1240))
	_decal("res://ui/lobby/art/od_scorch.png", Vector2(-1330, -1230))
	_decal("res://ui/lobby/art/od_tally.png", Vector2(-1160, -1300))
	# object ground shadows (drawn under the YSort world): decent ellipse
	# under the hovering shuttle, subtle silhouette cast right of the booth
	_object_shadow("res://ui/lobby/art/shuttle_shadow.png", Vector2(0, -898))
	_object_shadow("res://ui/lobby/art/booth_shadow.png", BOOTH_POS + Vector2(26, 8))
	# everything that stands ON the ground y-sorts: lower on screen = in front
	_world = YSort.new()
	add_child(_world)
	_build_slot_buildings()
	_build_offduty_corner()
	# the north wall is solid at its base - the deck ends at the wall face
	_add_wall(Rect2(-1376, -1196, 2752, 20))
	# collision: cliff strip blocks deck<->plaza except through the stairs
	_add_wall(Rect2(CLIFF_RECT.position.x, CLIFF_RECT.position.y,
			STAIR_WEST.position.x - CLIFF_RECT.position.x, CLIFF_RECT.size.y))
	_add_wall(Rect2(STAIR_WEST.end.x, CLIFF_RECT.position.y,
			STAIR_EAST.position.x - STAIR_WEST.end.x, CLIFF_RECT.size.y))
	_add_wall(Rect2(STAIR_EAST.end.x, CLIFF_RECT.position.y,
			CLIFF_RECT.end.x - STAIR_EAST.end.x, CLIFF_RECT.size.y))
	# the MONUMENT (plaza centerpiece): relief plaque on its stone platform,
	# sprite 340x313 base-anchored at (0, 460). It is a raised slab seen from
	# above - the WHOLE footprint is solid (unlike tall buildings, none of
	# the sprite is "up in the air")
	_add_wall(Rect2(-170, 147, 340, 313))
	var statue_path: = "res://ui/lobby/art/statue.png"
	if ResourceLoader.exists(statue_path):
		var statue: = Sprite.new()
		statue.texture = load(statue_path)
		statue.position = Vector2(0, 460)
		statue.offset = Vector2(0, -156)
		_world.add_child(statue)
	# booth: backed against the cliff (base -150), and NO walk-behind (user
	# 2026-08-20) - the wall spans from the cliff base to the booth base,
	# matched to the body width at ground level (159, crown overhangs)
	_add_wall(Rect2(-77, -232, 155, 82))
	# 2.5D hitbox law (2026-08-20 playtest): standing objects block at their
	# BASE BAND only - the ground their footprint occupies - never the full
	# sprite, so you can walk behind them and the YSort draws you behind.
	# Shuttle: sprite 171x165 base-anchored at SHUTTLE_POS.y + 82 - the wall
	# is the bottom 56px of the hull.
	_add_wall(Rect2(SHUTTLE_POS.x - 86, SHUTTLE_POS.y + 26, 172, 56))
	# stair railings are solid: posts + pole occupy sprite x 37..83 and
	# 237..283 (the 320px stairs sprite is centered on the 256px rect), from
	# the top newel (row 8) down to the bottom newel base (row 672 - the
	# staircase lands four steps out on the plaza)
	for stair_rect in [STAIR_WEST, STAIR_EAST]:
		var sx: float = stair_rect.position.x - 32.0
		_add_wall(Rect2(sx + 37.0, stair_rect.position.y + 8.0, 46.0, 664.0))
		_add_wall(Rect2(sx + 237.0, stair_rect.position.y + 8.0, 46.0, 664.0))


func _ground_overlay(path: String, rect: Rect2) -> void :
	if not ResourceLoader.exists(path):
		return
	var sprite: = Sprite.new()
	sprite.texture = load(path)
	# TOP-aligned to the rect, centered horizontally: an overlay taller than
	# its rect (the stairs hang 96px past their rect onto the plaza) keeps
	# its rows pinned to the rect top. Same-size overlays are unaffected.
	sprite.position = Vector2(rect.position.x + rect.size.x / 2.0,
			rect.position.y + sprite.texture.get_height() / 2.0)
	add_child(sprite)


func _offduty_prop(name: String, base: Vector2) -> void :
	# standing prop: base-anchored sprite in the YSort world
	var path: String = "res://ui/lobby/art/" + name + ".png"
	if not ResourceLoader.exists(path):
		return
	var s: = Sprite.new()
	var tex: Texture = load(path)
	s.texture = tex
	s.position = base
	s.offset = Vector2(0, -tex.get_height() / 2.0)
	_world.add_child(s)


func _offduty_sit(guy) -> void :
	# SITTING pose (user 2026-08-21): body lowered, legs splayed to the
	# side, and the idle bounce at HALF strength (the idle animation's value
	# tracks are rescaled toward their first key by 0.5 at runtime).
	if guy._visual == null:
		return
	var anim_node = guy._visual.get_node_or_null("Animation")
	if anim_node == null:
		return
	anim_node.position.y = -10
	var legs = anim_node.get_node_or_null("Legs")
	if legs != null and legs.get_child_count() >= 2:
		var leg_a = legs.get_child(0)
		leg_a.position = Vector2(26, 22)
		leg_a.rotation_degrees = -58
		var leg_b = legs.get_child(1)
		leg_b.position = Vector2(8, 26)
		leg_b.rotation_degrees = -74
	if guy._anim_player == null:
		return
	var idle: Animation = guy._anim_player.get_animation("idle")
	if idle == null:
		return
	var calm: Animation = idle.duplicate(true)
	for ti in range(calm.get_track_count()):
		if calm.track_get_type(ti) != Animation.TYPE_VALUE:
			continue
		if calm.track_get_key_count(ti) < 2:
			continue
		var base_val = calm.track_get_key_value(ti, 0)
		for ki in range(1, calm.track_get_key_count(ti)):
			var v = calm.track_get_key_value(ti, ki)
			if v is Vector2 and base_val is Vector2:
				calm.track_set_key_value(ti, ki, base_val + (v - base_val) * 0.5)
			elif (v is float or v is int) and (base_val is float or base_val is int):
				calm.track_set_key_value(ti, ki, base_val + (v - base_val) * 0.5)
	guy._anim_player.add_animation("sit_idle", calm)
	guy._anim_player.play("sit_idle")


func _offduty_guy(char_id: String, base: Vector2, face_left: bool = false, sitting: bool = false) -> void :
	# a mode guy lounging in the corner: the REAL in-game body (same
	# dress_as construction as player avatars - potato + legs + appearance
	# pieces + idle animation), physics disabled so he never reads input.
	# Pack disabled -> he simply is not at the camp (un-gate law).
	var character = ItemService.get_element_safe(ItemService.characters, char_id)
	if character == null:
		return
	var guy = KinematicBody2D.new()
	guy.set_script(LobbyPlayer)
	_world.add_child(guy)
	guy.position = base
	guy.dress_as(character)
	guy.set_physics_process(false)
	if face_left and guy._visual != null:
		guy._visual.scale.x = -1.0
	if sitting:
		_offduty_sit(guy)
	var plate: = Label.new()
	plate.text = tr(str(character.name))
	plate.align = Label.ALIGN_CENTER
	plate.grow_horizontal = Control.GROW_DIRECTION_BOTH
	plate.rect_position = Vector2(-200, -86)
	plate.rect_min_size = Vector2(400, 0)
	guy.add_child(plate)


func _build_offduty_corner() -> void :
	# OFF DUTY corner v4: coordinates mirror layout_offduty.py exactly
	# (visually tuned + bbox-checked there before landing here).
	# BURN BARREL (user 2026-08-21: no cooking pot - a barrel with fire in
	# it in the middle of the camp): flames emitted at the rim, above the
	# barrel sprite (base -790, sprite h 76)
	var torch_scene = load("res://particles/burning/torch_burning_particles.tscn")
	if torch_scene != null:
		var fire = torch_scene.instance()
		fire.position = Vector2(-1270, -858)
		fire.scale = Vector2(1.6, 1.6)
		_world.add_child(fire)
	# fire camp (SW): burn barrel + skewer rack + X7 crate
	_offduty_prop("od_barrel", Vector2(-1270, -790))
	_offduty_prop("od_skewers", Vector2(-1340, -770))
	_offduty_prop("od_crate2", Vector2(-1330, -880))
	# rug lounge (bottom-left): cooler + dice on the cloth
	_offduty_prop("od_cooler", Vector2(-1080, -742))
	_offduty_prop("od_dice", Vector2(-1090, -640))
	# card circle (up under the wall): crate + barrel seats, the game on
	# the ground in front of the seated players
	_offduty_prop("od_crate", Vector2(-920, -1085))
	_offduty_prop("od_barrel", Vector2(-790, -1080))
	# hammock by the wall + plant
	_offduty_prop("od_hammock", Vector2(-1280, -1055))
	_offduty_prop("od_plant", Vector2(-720, -1120))
	# the mode guys, lounging (HUB_PLAN 4c lineup)
	_offduty_guy("character_gourmet", Vector2(-1180, -835), true)
	# Wildcard + Mole SITTING side by side on the carpet, facing each other
	_offduty_guy("character_special", Vector2(-1210, -680), false, true)
	_offduty_guy("character_mole", Vector2(-1120, -675), true, true)
	# P2W + Smith SEATED against their crate/barrel, cards between them
	_offduty_guy("character_p2w", Vector2(-935, -1030), false, true)
	_offduty_guy("character_blacksmith", Vector2(-775, -1025), true, true)
	_offduty_guy("character_demon", Vector2(-740, -680), true)
	# collision: base bands (2.5D hitbox law) for the solid props
	_add_wall(Rect2(-1298, -812, 56, 24))
	_add_wall(Rect2(-1380, -790, 80, 22))
	_add_wall(Rect2(-1361, -902, 62, 24))
	_add_wall(Rect2(-955, -1106, 70, 24))
	_add_wall(Rect2(-818, -1102, 56, 24))
	_add_wall(Rect2(-1375, -1078, 190, 24))


func _decal(path: String, at: Vector2) -> void :
	if not ResourceLoader.exists(path):
		return
	var s: = Sprite.new()
	s.texture = load(path)
	s.position = at
	add_child(s)


func _object_shadow(path: String, at: Vector2) -> void :
	if not ResourceLoader.exists(path):
		return
	var s: = Sprite.new()
	s.texture = load(path)
	s.position = at
	add_child(s)


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


# HUB_PLAN slot registry: which pack owns which slot anchor. Unassigned
# slots show the RESERVED building; an assigned-but-unavailable/disabled
# pack shows the VACANT building. New packs claim a free slot here only.
const SLOT_ASSIGNMENT: = {
	1: "forge", 2: "ledger", 4: "food", 6: "roster",
}


func _build_slot_buildings() -> void :
	for i in SLOT_POSITIONS.size():
		var slot_index: int = i + 1
		var slot_rect: = Rect2(SLOT_POSITIONS[i] - SLOT_SIZE / 2.0, SLOT_SIZE)
		var pack_id: String = str(SLOT_ASSIGNMENT.get(slot_index, ""))
		if pack_id == "":
			_spawn_building_placeholder(slot_rect, tr("LOBBY_BLDG_RESERVED"), "", false)
			continue
		var pack = Utils.packs.available_packs.get(pack_id)
		if pack == null or not Utils.packs.is_pack_enabled(pack_id):
			_spawn_building_placeholder(slot_rect, tr("LOBBY_BLDG_VACANT"), "", false)
			continue
		var bldg = _spawn_building_placeholder(slot_rect, tr(str(pack.lobby_building_name)),
				str(pack.lobby_building_icon), true)
		bldg.near_radius = 300.0
		bldg.set_prompt(tr("LOBBY_BLDG_PROMPT"))
		var _eb = bldg.connect("interacted", self, "_on_building_interacted", [pack_id, str(pack.lobby_building_name)])


func _spawn_building_placeholder(slot_rect: Rect2, display_name: String,
		icon_path: String, active: bool):
	# placeholder-law rendering: the EXACT final footprint as a flat rect,
	# an existing icon, and the station name plate. Interactions arrive in
	# step 3; the real carnival-register art is a pure texture swap later.
	_rect(slot_rect, SLOT_COLOR if active else Color(0.10, 0.085, 0.075, 1.0))
	_add_wall(slot_rect)
	var npc = LobbyNpc.new()
	var texture: Texture = null
	if icon_path != "" and ResourceLoader.exists(icon_path):
		texture = load(icon_path)
	npc.setup(texture, display_name, "")
	npc.position = slot_rect.position + Vector2(slot_rect.size.x / 2.0,
			slot_rect.size.y / 2.0 + npc.base_offset())
	if active:
		npc.add_to_group("lobby_buildings")
	_world.add_child(npc)
	return npc


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
		# returning from a menu: stand exactly where you were (captured on exit)
		if player_index < MenuData.lobby_return_positions.size():
			avatar.position = MenuData.lobby_return_positions[player_index]
		else:
			avatar.position = SPAWN_POINT + Vector2((player_index - (count - 1) / 2.0) * 90.0, 0)
		_world.add_child(avatar)
		avatar.dress_as(_resolve_character(str(last_played[player_index]) if player_index < last_played.size() else ""))
		_players.push_back(avatar)
	MenuData.lobby_return_positions = []


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
	_camera.limit_left = - 1440
	_camera.limit_right = 1440
	_camera.limit_top = - 1360
	_camera.limit_bottom = 1176
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
	var shuttle = _spawn_npc("res://ui/lobby/art/shuttle.png",
			SHUTTLE_POS, tr("LOBBY_SHUTTLE"), tr("LOBBY_SHUTTLE_PROMPT"))
	shuttle.near_radius = 190.0
	var _e0 = shuttle.connect("interacted", self, "_on_shuttle_interacted")

	# the changing booth - back wall between the stairs (opens character select)
	var booth = _spawn_npc("res://ui/lobby/art/booth.png",
			BOOTH_POS, tr("LOBBY_BOOTH"), tr("LOBBY_BOOTH_PROMPT"))
	booth.near_radius = 260.0
	var _e1 = booth.connect("interacted", self, "_on_booth_interacted")
	_build_booth_screen(booth)

	# the unlock board (deck east) - challenge progress
	var board = _spawn_npc("res://items/all/pile_of_books/pile_of_books_icon.png",
			BOARD_RECT.position + BOARD_RECT.size / 2.0, tr("LOBBY_BOARD"), tr("LOBBY_BOARD_PROMPT"))
	var _e3 = board.connect("interacted", self, "_on_board_interacted")

	# the game-mode shrine (deck) - interact cycles the mode
	_shrine = _spawn_npc("res://items/custom_characters/special/special_icon.png",
			SHRINE_POS, tr("LOBBY_SHRINE"), "")
	_update_shrine_prompt()
	var _e2 = _shrine.connect("interacted", self, "_on_shrine_interacted")


func _build_booth_screen(booth) -> void :
	# the blanked CRT tube broadcasts the roster: every character's select
	# icon in a loop, with a burst of static between faces (user 2026-08-20).
	# Modded characters appear automatically - the faces come live from
	# ItemService.characters.
	for character in ItemService.characters:
		if character != null and character.icon != null:
			_booth_faces.push_back(character.icon)
	for path in ["res://ui/lobby/art/booth_static_0.png", "res://ui/lobby/art/booth_static_1.png"]:
		if ResourceLoader.exists(path):
			_booth_static.push_back(load(path))
	if _booth_faces.empty() or _booth_static.empty():
		return
	_booth_screen = Sprite.new()
	_booth_screen.position = BOOTH_SCREEN_OFFSET
	booth.add_child(_booth_screen)
	var timer: = Timer.new()
	timer.wait_time = 0.14
	timer.autostart = true
	booth.add_child(timer)
	var _et = timer.connect("timeout", self, "_on_booth_screen_tick")
	# marquee chase lights: two frames (odd bulbs off / even bulbs off),
	# flipped twice a second (user 2026-08-20)
	for path in ["res://ui/lobby/art/booth_bulbs_a.png", "res://ui/lobby/art/booth_bulbs_b.png"]:
		if ResourceLoader.exists(path):
			_booth_bulb_frames.push_back(load(path))
	if _booth_bulb_frames.size() == 2:
		_booth_bulbs = Sprite.new()
		_booth_bulbs.position = Vector2(0, -150)
		_booth_bulbs.texture = _booth_bulb_frames[0]
		booth.add_child(_booth_bulbs)
		var bulb_timer: = Timer.new()
		bulb_timer.wait_time = 0.5
		bulb_timer.autostart = true
		booth.add_child(bulb_timer)
		var _eb = bulb_timer.connect("timeout", self, "_on_booth_bulbs_tick")


func _on_booth_bulbs_tick() -> void :
	if _booth_bulbs == null:
		return
	_booth_bulb_index = 1 - _booth_bulb_index
	_booth_bulbs.texture = _booth_bulb_frames[_booth_bulb_index]


func _on_booth_screen_tick() -> void :
	if _booth_screen == null:
		return
	_booth_tick += 1
	var phase: int = _booth_tick % 18
	if phase < 3:
		_booth_screen.texture = _booth_static[_booth_tick % _booth_static.size()]
		_booth_screen.scale = Vector2.ONE
		if phase == 2:
			_booth_face_index = (_booth_face_index + 1) % _booth_faces.size()
	else:
		var tex: Texture = _booth_faces[_booth_face_index]
		_booth_screen.texture = tex
		var s: float = min(BOOTH_SCREEN_SIZE.x / tex.get_width(), BOOTH_SCREEN_SIZE.y / tex.get_height()) * 0.92
		_booth_screen.scale = Vector2(s, s)


func _spawn_npc(texture_path: String, at: Vector2, display_name: String, prompt: String):
	var npc = LobbyNpc.new()
	var texture: Texture = null
	if ResourceLoader.exists(texture_path):
		texture = load(texture_path)
	npc.setup(texture, display_name, prompt)
	npc.position = at + Vector2(0, npc.base_offset())
	npc.add_to_group("lobby_npcs")
	_world.add_child(npc)
	return npc


func _remember_positions() -> void :
	MenuData.lobby_return_positions = []
	for avatar in _players:
		MenuData.lobby_return_positions.push_back(avatar.position)


func _on_shuttle_interacted() -> void :
	# HUB_PLAN flow law: the hub character IS the run character. Apply every
	# active player's hub character to RunData exactly like character
	# selection's confirm does, then enter the flow at weapon select.
	_remember_positions()
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
	_remember_positions()
	MenuData.run_flow_from_lobby = true
	MenuData.character_select_for_lobby = true
	ProgressData.start_activity()
	var _error = get_tree().change_scene(MenuData.character_selection_scene)


func _on_shrine_interacted() -> void :
	# run-wide MULTI-SELECT (user 2026-08-18): toggle any number of special
	# modes; persisted immediately, stamped onto every player at run start.
	if _mode_popup != null:
		return
	_mode_popup = _build_mode_popup()
	add_child(_mode_popup)


func _build_mode_popup() -> CanvasLayer:
	var layer: = CanvasLayer.new()
	var panel: = Panel.new()
	panel.rect_min_size = Vector2(560, 0)
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	layer.add_child(panel)
	var box: = VBoxContainer.new()
	box.rect_min_size = Vector2(520, 0)
	box.rect_position = Vector2(20, 20)
	panel.add_child(box)
	var title: = Label.new()
	title.text = tr("LOBBY_SHRINE_TITLE")
	box.add_child(title)
	var selected: Array = Utils.game_modes.selected_mode_ids()
	var first_button: Button = null
	for mode in Utils.game_modes.available_modes():
		var mode_id: String = str(mode["id"])
		var toggle: = Button.new()
		toggle.toggle_mode = true
		toggle.pressed = selected.has(mode_id)
		toggle.text = _mode_toggle_text(str(mode["name"]), toggle.pressed)
		var _e = toggle.connect("toggled", self, "_on_mode_toggled", [toggle, mode_id, str(mode["name"])])
		box.add_child(toggle)
		if first_button == null:
			first_button = toggle
	if first_button == null:
		var empty: = Label.new()
		empty.text = tr("LOBBY_SHRINE_EMPTY")
		box.add_child(empty)
	var close: = Button.new()
	close.text = tr("MENU_BACK")
	var _e2 = close.connect("pressed", self, "_close_mode_popup")
	box.add_child(close)
	if first_button != null:
		first_button.call_deferred("grab_focus")
	else:
		close.call_deferred("grab_focus")
	# size the panel to its content once the box lays out
	box.connect("resized", self, "_fit_mode_popup", [panel, box])
	return layer


func _fit_mode_popup(panel: Panel, box: VBoxContainer) -> void :
	panel.rect_size = box.rect_size + Vector2(40, 40)
	panel.rect_position = - panel.rect_size / 2.0
	panel.margin_left = - panel.rect_size.x / 2.0
	panel.margin_top = - panel.rect_size.y / 2.0


func _mode_toggle_text(mode_name: String, on: bool) -> String:
	return "%s  [%s]" % [mode_name, tr("LOBBY_MODE_ON") if on else tr("LOBBY_MODE_OFF")]


func _on_mode_toggled(pressed: bool, toggle: Button, mode_id: String, mode_name: String) -> void :
	Utils.game_modes.set_mode_selected(mode_id, pressed)
	toggle.text = _mode_toggle_text(mode_name, pressed)
	_update_shrine_prompt()


func _close_mode_popup() -> void :
	if _mode_popup != null:
		_mode_popup.queue_free()
		_mode_popup = null


func _update_shrine_prompt() -> void :
	var count: int = Utils.game_modes.selected_mode_ids().size()
	_shrine.set_prompt(tr("LOBBY_SHRINE_PROMPT") % count)


func _open_info_popup(title_text: String, lines: Array) -> void :
	if _mode_popup != null:
		return
	var layer: = CanvasLayer.new()
	var panel: = Panel.new()
	panel.anchor_left = 0.5
	panel.anchor_top = 0.5
	panel.anchor_right = 0.5
	panel.anchor_bottom = 0.5
	layer.add_child(panel)
	var box: = VBoxContainer.new()
	box.rect_position = Vector2(20, 20)
	panel.add_child(box)
	var title: = Label.new()
	title.text = title_text
	box.add_child(title)
	var scroll: = ScrollContainer.new()
	scroll.rect_min_size = Vector2(620, 0)
	box.add_child(scroll)
	var body: = VBoxContainer.new()
	scroll.add_child(body)
	for line in lines:
		var label: = Label.new()
		label.text = str(line)
		body.add_child(label)
	var close: = Button.new()
	close.text = tr("MENU_BACK")
	var _e = close.connect("pressed", self, "_close_mode_popup")
	box.add_child(close)
	close.call_deferred("grab_focus")
	var height: = int(min(60 + lines.size() * 28, 760))
	scroll.rect_min_size = Vector2(620, height - 100)
	panel.rect_size = Vector2(660, height)
	panel.margin_left = - 330
	panel.margin_top = - height / 2.0
	_mode_popup = layer
	add_child(layer)


func _on_building_interacted(pack_id: String, name_key: String) -> void :
	var lines: = []
	match pack_id:
		"forge":
			var p2w = load("res://items/custom/p2w/p2w_data.gd")
			lines.push_back(tr("LOBBY_FORGE_LADDER"))
			for rung in range(1, 9):
				var tier_value: int = int(p2w.RUNG_TIERS[rung])
				var count: = 0
				for weapon in ItemService.weapons:
					if int(weapon.tier) == tier_value:
						count += 1
				lines.push_back("  %d. %s - %d weapons" % [rung, str(p2w.RUNG_NAMES[rung]), count])
			lines.push_back("")
			lines.push_back(tr("LOBBY_FORGE_ODDS"))
			for chest in range(1, 9):
				var parts: = []
				for pair in p2w.CHEST_ODDS[chest]:
					parts.push_back("%s %d%%" % [str(p2w.RUNG_NAMES[int(pair[0])]), int(pair[1])])
				lines.push_back("  Chest %d: %s" % [chest, PoolStringArray(parts).join(", ")])
		"food":
			lines.push_back(tr("LOBBY_DINER_INTRO") % ItemService.foods.size())
			for food in ItemService.foods:
				lines.push_back("  " + tr(str(food.name)))
		"ledger":
			lines.push_back(tr("LOBBY_BANK_L1"))
			lines.push_back(tr("LOBBY_BANK_L2"))
			lines.push_back(tr("LOBBY_BANK_L3"))
		"roster":
			var pack = Utils.packs.available_packs.get("roster")
			for character in pack.characters:
				var unlocked: bool = ProgressData.characters_unlocked.has(character.my_id_hash)
				lines.push_back("  %s - %s" % [tr(str(character.name)),
						tr("LOBBY_UNLOCKED") if unlocked else tr("LOBBY_LOCKED")])
		_:
			return
	_open_info_popup(tr(name_key), lines)


func _on_board_interacted() -> void :
	var total: int = ChallengeService.challenges.size()
	var done: = 0
	var todo: = []
	for challenge in ChallengeService.challenges:
		if ProgressData.challenges_completed.has(challenge.my_id_hash):
			done += 1
		elif todo.size() < 8:
			todo.push_back("  " + str(challenge.get_name_text()))
	var lines: = [tr("LOBBY_BOARD_DONE") % [done, total], ""]
	if not todo.empty():
		lines.push_back(tr("LOBBY_BOARD_NEXT"))
		for entry in todo:
			lines.push_back(entry)
	_open_info_popup(tr("LOBBY_BOARD"), lines)


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		if _mode_popup != null:
			_close_mode_popup()
			return
		_remember_positions()
		var _error = get_tree().change_scene(MenuData.title_screen_scene)
