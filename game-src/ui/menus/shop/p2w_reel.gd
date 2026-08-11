extends Control

# Gourmet DLC - The P2W chest-opening ceremony (CSGO case style).
#
# Flow (user spec 2026-08-11): buying a chest opens this overlay IMMEDIATELY in an
# idle state - the carousel of square, icon-only rarity cards is visible with an
# OPEN button underneath. Pressing OPEN accelerates the strip, it spins, then
# slowly lands on the chest's PRE-ROLLED drop (rolled at purchase; the reel only
# reveals). Landing shows the crate-pickup choice, same as the vanilla item box:
# Take, or Recycle (+materials). Cancelling before the spin (ESC) leaves the
# chest armed on its shop card. Filler cards are honest samples of the chest's
# odds table, never hype-weighted (user rule).
#
# base_shop instances this and yields on reel_done(outcome):
#   "cancel"  - nothing claimed, chest stays armed
#   "take"    - claim the drop through the shop's own buy pipeline
#   "recycle" - claim, refund ItemService.get_recycling_value instead

signal reel_done(outcome)

const CARD: = 150.0
const CARD_GAP: = 10.0
const ICON: = 104.0
const N_CARDS: = 80
const WINNER_INDEX: = 70
# park deep enough that the idle window is full of cards on BOTH sides of the
# ticker (2 left the strip's real edge visible on wide screens)
const IDLE_INDEX: = 6
# two-phase spin (user tuning 2026-08-11): a quick quadratic ramp-up, then a
# long cubic coast-down - reads as "accelerates, whirls, slowly lands"
# the OPEN press YANKS the strip: almost half the whole run blurs past in the
# first 0.4s, then the quartic coast-down takes over
const ACCEL_TIME: = 0.4
# quartic coast-down: most of the distance flies by early, then the last 2-3
# cards CREEP past the ticker for seconds - the near-miss agony is the point
const DECEL_TIME: = 6.5
const ACCEL_FRACTION: = 0.45

var _entry: Dictionary
var _player_index: int = 0
var _strip: Control
var _window: Control
var _tween: Tween
var _tick_sound: AudioStreamPlayer
var _land_sound: AudioStreamPlayer
var _last_tick_card: int = - 1
var _winner_panel: Panel
var _reveal_label: Label
var _open_button: Button
var _take_button: Button
var _recycle_button: Button
var _spinning: bool = false
var _landed: bool = false
var _spin_end_x: float = 0.0


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
	var window_w: float = min(view_size.x * 0.86, 1240.0)

	_window = Control.new()
	_window.rect_size = Vector2(window_w, CARD)
	_window.rect_position = Vector2((view_size.x - window_w) / 2.0, (view_size.y - CARD) / 2.0 - 30)
	_window.rect_clip_content = true
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window)

	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(_strip)
	_fill_strip()

	var ticker: = ColorRect.new()
	ticker.color = Color(1, 1, 1, 0.9)
	ticker.rect_size = Vector2(3, CARD + 18)
	ticker.rect_position = Vector2((view_size.x - 3) / 2.0, _window.rect_position.y - 9)
	ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ticker)

	_reveal_label = Label.new()
	_reveal_label.align = Label.ALIGN_CENTER
	_reveal_label.rect_position = Vector2(0, _window.rect_position.y + CARD + 34)
	_reveal_label.rect_size = Vector2(view_size.x, 40)
	_reveal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reveal_label)

	# idle state: the carousel waits behind a single OPEN button
	_open_button = Button.new()
	_open_button.text = tr("P2W_OPEN")
	_open_button.rect_min_size = Vector2(220, 56)
	_open_button.rect_position = Vector2((view_size.x - 220) / 2.0, _window.rect_position.y + CARD + 104)
	var _e1 = _open_button.connect("pressed", self, "_on_open_pressed")
	add_child(_open_button)

	_take_button = Button.new()
	_take_button.text = tr("MENU_TAKE")
	_take_button.rect_min_size = Vector2(220, 56)
	_take_button.visible = false
	var _e2 = _take_button.connect("pressed", self, "_on_take_pressed")
	add_child(_take_button)

	_recycle_button = Button.new()
	_recycle_button.rect_min_size = Vector2(220, 56)
	_recycle_button.visible = false
	var _e3 = _recycle_button.connect("pressed", self, "_on_recycle_pressed")
	add_child(_recycle_button)

	_tick_sound = AudioStreamPlayer.new()
	_tick_sound.stream = load("res://ui/sounds/clock_tick_01.wav")
	add_child(_tick_sound)
	_land_sound = AudioStreamPlayer.new()
	_land_sound.stream = load("res://ui/sounds/buy.wav")
	add_child(_land_sound)

	# park the strip so real cards already fill the window in the idle state
	var ticker_in_window: float = _window.rect_size.x / 2.0
	_strip.rect_position = Vector2(ticker_in_window - (IDLE_INDEX * (CARD + CARD_GAP) + CARD / 2.0), 0)

	set_process(false)
	_open_button.call_deferred("grab_focus")


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
	# square, icon-only: rarity reads from the border, the name only shows on landing
	var tier_int: int = ItemService.P2WData.RUNG_TIERS[rung]
	var edge_color: Color = ItemService.get_color_from_tier(tier_int)
	if edge_color == Color.white:
		edge_color = Color(0.75, 0.75, 0.75)
	var back_color: Color = ItemService.get_color_from_tier(tier_int, true)
	if back_color == Color.white:
		back_color = Color(0.09, 0.09, 0.09)

	var card: = Panel.new()
	card.rect_size = Vector2(CARD, CARD)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style: = StyleBoxFlat.new()
	style.bg_color = back_color
	style.border_color = Color(0.68, 0.35, 1.0) if is_winner_cursed else edge_color
	style.set_border_width_all(4)
	style.set_corner_radius_all(6)
	card.add_stylebox_override("panel", style)

	if data != null:
		var icon: = TextureRect.new()
		icon.texture = data.icon
		icon.expand = true
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.rect_position = Vector2((CARD - ICON) / 2.0, (CARD - ICON) / 2.0)
		icon.rect_size = Vector2(ICON, ICON)
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(icon)
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
		card.rect_position = Vector2(i * (CARD + CARD_GAP), 0)
		_strip.add_child(card)


# ---- motion -------------------------------------------------------------------

func _on_open_pressed() -> void :
	if _spinning:
		return
	_spinning = true
	_open_button.visible = false

	# phase 1 ramps up hard (quad ease-in over the first stretch), phase 2 coasts
	# down long (cubic ease-out to the winner), offset a random amount INSIDE the
	# card so every landing differs
	var ticker_in_window: float = _window.rect_size.x / 2.0
	var land_offset: float = rand_range(- CARD * 0.34, CARD * 0.34)
	var end_x: float = ticker_in_window - (WINNER_INDEX * (CARD + CARD_GAP) + CARD / 2.0 + land_offset)
	var start_x: float = _strip.rect_position.x
	var mid_x: float = start_x + (end_x - start_x) * ACCEL_FRACTION
	_spin_end_x = end_x

	_tween = Tween.new()
	add_child(_tween)
	_tween.interpolate_property(_strip, "rect_position:x", start_x, mid_x, ACCEL_TIME,
			Tween.TRANS_QUAD, Tween.EASE_IN)
	_tween.start()
	var _err = _tween.connect("tween_all_completed", self, "_on_accel_done")
	set_process(true)


func _on_accel_done() -> void :
	_tween.disconnect("tween_all_completed", self, "_on_accel_done")
	_tween.interpolate_property(_strip, "rect_position:x", _strip.rect_position.x, _spin_end_x, DECEL_TIME,
			Tween.TRANS_QUART, Tween.EASE_OUT)
	_tween.start()
	var _err = _tween.connect("tween_all_completed", self, "_on_landed")


func _process(_delta: float) -> void :
	if _strip == null:
		return
	var ticker_in_window: float = _window.rect_size.x / 2.0
	var card_under: int = int(floor((ticker_in_window - _strip.rect_position.x) / (CARD + CARD_GAP)))
	if card_under != _last_tick_card:
		_last_tick_card = card_under
		_tick_sound.pitch_scale = rand_range(0.92, 1.08)
		_tick_sound.play()


func _on_landed() -> void :
	set_process(false)
	_landed = true
	_land_sound.play()

	for card in _strip.get_children():
		if card != _winner_panel:
			card.modulate = Color(0.45, 0.45, 0.45)
	# the winner gets a thick, unmissable frame: cursed purple, or its rung color
	# lifted to full white for the white rung (the pale gray vanished on the dim)
	var winner_style = _winner_panel.get_stylebox("panel")
	if winner_style is StyleBoxFlat:
		if bool(_entry.get("item_cursed", false)):
			winner_style.border_color = Color(0.68, 0.35, 1.0)
		elif winner_style.border_color.is_equal_approx(Color(0.75, 0.75, 0.75)):
			winner_style.border_color = Color(1, 1, 1)
		winner_style.set_border_width_all(7)
		winner_style.bg_color = winner_style.bg_color.lightened(0.08)
	_winner_panel.rect_pivot_offset = Vector2(CARD / 2.0, CARD / 2.0)
	var pop: = Tween.new()
	add_child(pop)
	pop.interpolate_property(_winner_panel, "rect_scale", Vector2.ONE, Vector2(1.16, 1.16), 0.25,
			Tween.TRANS_BACK, Tween.EASE_OUT)
	pop.start()

	var resolved: Array = _rung_of_drop(_entry)
	var drop_data = resolved[0]
	var got_name: String = tr(drop_data.name) if drop_data != null else "???"
	if bool(_entry.get("item_cursed", false)):
		_reveal_label.add_color_override("font_color", Color(0.68, 0.35, 1.0))
		_reveal_label.text = got_name + "  [" + tr("P2W_CURSED") + "]"
	else:
		var tier_int: int = ItemService.P2WData.RUNG_TIERS[int(resolved[1])]
		_reveal_label.add_color_override("font_color", ItemService.get_color_from_tier(tier_int))
		_reveal_label.text = got_name

	# the vanilla crate choice: Take, or Recycle for materials
	var refund: int = 0
	if drop_data != null:
		refund = ItemService.get_recycling_value(RunData.current_wave, drop_data.value, _player_index, drop_data is WeaponData)
	_recycle_button.text = tr("MENU_RECYCLE") + " (+" + str(refund) + ")"
	var view_size: Vector2 = get_viewport_rect().size
	var buttons_y: float = _window.rect_position.y + CARD + 104
	_take_button.rect_position = Vector2(view_size.x / 2.0 - 232, buttons_y)
	_recycle_button.rect_position = Vector2(view_size.x / 2.0 + 12, buttons_y)
	_take_button.visible = true
	_recycle_button.visible = true
	_take_button.call_deferred("grab_focus")


# ---- outcomes -----------------------------------------------------------------

func _on_take_pressed() -> void :
	if _landed:
		emit_signal("reel_done", "take")


func _on_recycle_pressed() -> void :
	if _landed:
		emit_signal("reel_done", "recycle")


func _unhandled_input(event: InputEvent) -> void :
	# before the spin, backing out is allowed: the chest stays armed on its card
	if event.is_action_pressed("ui_cancel") and not _spinning:
		get_tree().set_input_as_handled()
		emit_signal("reel_done", "cancel")
