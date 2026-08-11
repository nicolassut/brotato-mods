extends Control

# Gourmet DLC - The P2W chest-opening ceremony (CSGO case style). A dimmed
# fullscreen overlay: a clipped strip of rarity-colored item cards scrolls past a
# center ticker with a long cubic ease-out, ticks as each card crosses, and lands
# on the chest's PRE-ROLLED drop (rolled at purchase in run_data.p2w_arm_chest -
# the reel only reveals, exactly like the real thing). Filler cards are honest
# samples of the chest's odds table, never hype-weighted (user rule).
# base_shop instances this, yields on "reel_finished", then grants the drop.

signal reel_finished

const CARD_W: = 110.0
const CARD_H: = 132.0
const CARD_GAP: = 8.0
const N_CARDS: = 44
const WINNER_INDEX: = 36
const SPIN_TIME: = 4.5

var _entry: Dictionary
var _player_index: int = 0
var _strip: Control
var _window: Control
var _ticker: ColorRect
var _tween: Tween
var _tick_sound: AudioStreamPlayer
var _land_sound: AudioStreamPlayer
var _last_tick_card: int = - 1
var _can_dismiss: bool = false
var _winner_panel: Panel
var _reveal_label: Label
var _cursed_glow: ColorRect


func setup(entry: Dictionary, player_index: int) -> void :
	_entry = entry
	_player_index = player_index

	set_anchors_and_margins_preset(Control.PRESET_WIDE)
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL

	var dim: = ColorRect.new()
	dim.set_anchors_and_margins_preset(Control.PRESET_WIDE)
	# a cursed chest opens under a purple sky
	dim.color = Color(0.10, 0.02, 0.14, 0.88) if bool(_entry.get("cursed", false)) else Color(0, 0, 0, 0.82)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	var view_size: Vector2 = get_viewport_rect().size
	var window_w: float = min(view_size.x * 0.8, 1100.0)

	_window = Control.new()
	_window.rect_size = Vector2(window_w, CARD_H)
	_window.rect_position = Vector2((view_size.x - window_w) / 2.0, (view_size.y - CARD_H) / 2.0)
	_window.rect_clip_content = true
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window)

	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(_strip)
	_fill_strip()

	_ticker = ColorRect.new()
	_ticker.color = Color(1, 1, 1, 0.9)
	_ticker.rect_size = Vector2(3, CARD_H + 16)
	_ticker.rect_position = Vector2((view_size.x - 3) / 2.0, (view_size.y - CARD_H) / 2.0 - 8)
	_ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_ticker)

	_reveal_label = Label.new()
	_reveal_label.align = Label.ALIGN_CENTER
	_reveal_label.rect_position = Vector2(0, _window.rect_position.y + CARD_H + 28)
	_reveal_label.rect_size = Vector2(view_size.x, 40)
	_reveal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reveal_label)

	_tick_sound = AudioStreamPlayer.new()
	_tick_sound.stream = load("res://ui/sounds/clock_tick_01.wav")
	add_child(_tick_sound)
	_land_sound = AudioStreamPlayer.new()
	_land_sound.stream = load("res://ui/sounds/buy.wav")
	add_child(_land_sound)

	grab_focus()
	_spin()


# ---- strip construction -------------------------------------------------------

func _rung_of_drop(drop: Dictionary):
	# ItemParentData + its display rung for a rolled drop {"kind","id"}
	if drop.kind == "weapon":
		var weapon_data = ItemService.get_element_safe(ItemService.weapons, drop.id)
		if weapon_data != null:
			for r in ItemService.P2WData.RUNG_TIERS:
				if ItemService.P2WData.RUNG_TIERS[r] == weapon_data.tier:
					return [weapon_data, r]
		return [weapon_data, 1]
	var item_data = ItemService.get_element_safe(ItemService.items, drop.id)
	return [item_data, int(ItemService.P2WData.RUNG_BY_ID.get(drop.id, 1))]


func _make_card(data, rung: int, is_winner_cursed: bool) -> Panel:
	var tier_int: int = ItemService.P2WData.RUNG_TIERS[rung]
	var edge_color: Color = ItemService.get_color_from_tier(tier_int)
	if edge_color == Color.white:
		edge_color = Color(0.75, 0.75, 0.75)
	var back_color: Color = ItemService.get_color_from_tier(tier_int, true)
	if back_color == Color.white:
		back_color = Color(0.09, 0.09, 0.09)

	var card: = Panel.new()
	card.rect_size = Vector2(CARD_W, CARD_H)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: = StyleBoxFlat.new()
	style.bg_color = back_color
	style.border_color = Color(0.68, 0.35, 1.0) if is_winner_cursed else edge_color
	style.set_border_width_all(3)
	style.set_corner_radius_all(6)
	card.add_stylebox_override("panel", style)

	if data != null:
		var icon: = TextureRect.new()
		icon.texture = data.icon
		icon.expand = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.rect_position = Vector2(23, 14)
		icon.rect_size = Vector2(64, 64)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)

		var name_label: = Label.new()
		name_label.text = tr(data.name)
		name_label.align = Label.ALIGN_CENTER
		name_label.valign = Label.VALIGN_CENTER
		name_label.autowrap = true
		name_label.rect_position = Vector2(4, 80)
		name_label.rect_size = Vector2(CARD_W - 8, CARD_H - 86)
		name_label.add_color_override("font_color", edge_color)
		name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(name_label)
	return card


func _fill_strip() -> void :
	var chest_rung: int = int(_entry.rung)
	for i in N_CARDS:
		var card: Panel
		if i == WINNER_INDEX:
			var resolved: Array = _rung_of_drop(_entry)
			card = _make_card(resolved[0], resolved[1], bool(_entry.get("item_cursed", false)))
			_winner_panel = card
		else:
			var filler: Dictionary = ItemService.p2w_roll_chest_drop(chest_rung, _player_index, false)
			var resolved_f: Array = _rung_of_drop(filler)
			card = _make_card(resolved_f[0], resolved_f[1], false)
		card.rect_position = Vector2(i * (CARD_W + CARD_GAP), 0)
		_strip.add_child(card)


# ---- motion -------------------------------------------------------------------

func _spin() -> void :
	# start with card 2 at the ticker; land with the winner under it, offset a
	# random amount INSIDE the card so every landing looks a little different
	var ticker_in_window: float = _window.rect_size.x / 2.0
	var start_x: float = ticker_in_window - (2 * (CARD_W + CARD_GAP) + CARD_W / 2.0)
	var land_offset: float = rand_range(- CARD_W * 0.34, CARD_W * 0.34)
	var end_x: float = ticker_in_window - (WINNER_INDEX * (CARD_W + CARD_GAP) + CARD_W / 2.0 + land_offset)

	_strip.rect_position = Vector2(start_x, 0)
	_tween = Tween.new()
	add_child(_tween)
	_tween.interpolate_property(_strip, "rect_position:x", start_x, end_x, SPIN_TIME,
			Tween.TRANS_CUBIC, Tween.EASE_OUT)
	_tween.start()
	var _err = _tween.connect("tween_all_completed", self, "_on_landed")
	set_process(true)


func _process(_delta: float) -> void :
	if _strip == null:
		return
	var ticker_in_window: float = _window.rect_size.x / 2.0
	var card_under: int = int(floor((ticker_in_window - _strip.rect_position.x) / (CARD_W + CARD_GAP)))
	if card_under != _last_tick_card:
		_last_tick_card = card_under
		_tick_sound.pitch_scale = rand_range(0.92, 1.08)
		_tick_sound.play()


func _on_landed() -> void :
	set_process(false)
	_land_sound.play()

	# winner pops; everything else recedes
	for card in _strip.get_children():
		if card != _winner_panel:
			card.modulate = Color(0.45, 0.45, 0.45)
	_winner_panel.rect_pivot_offset = Vector2(CARD_W / 2.0, CARD_H / 2.0)
	var pop: = Tween.new()
	add_child(pop)
	pop.interpolate_property(_winner_panel, "rect_scale", Vector2.ONE, Vector2(1.18, 1.18), 0.25,
			Tween.TRANS_BACK, Tween.EASE_OUT)
	pop.start()

	var resolved: Array = _rung_of_drop(_entry)
	var got_name: String = tr(resolved[0].name) if resolved[0] != null else "???"
	if bool(_entry.get("item_cursed", false)):
		_reveal_label.add_color_override("font_color", Color(0.68, 0.35, 1.0))
		_reveal_label.text = got_name + "  [" + tr("P2W_CURSED") + "]"
	else:
		var tier_int: int = ItemService.P2WData.RUNG_TIERS[int(resolved[1])]
		_reveal_label.add_color_override("font_color", ItemService.get_color_from_tier(tier_int))
		_reveal_label.text = got_name
	_can_dismiss = true


func _finish() -> void :
	if not _can_dismiss:
		return
	_can_dismiss = false
	emit_signal("reel_finished")


func _gui_input(event: InputEvent) -> void :
	if event is InputEventMouseButton and event.pressed:
		accept_event()
		_finish()


func _unhandled_input(event: InputEvent) -> void :
	if event.is_action_pressed("ui_accept") or event.is_action_pressed("ui_cancel"):
		get_tree().set_input_as_handled()
		_finish()
