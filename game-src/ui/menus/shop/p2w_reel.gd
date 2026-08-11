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
# vertical headroom inside the clip window: without it the winner's pop-scale
# grew past the clip rect and its top/bottom borders were sliced off
const STRIP_PAD: = 26.0

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
var _drop_card: Panel
var _drop_card_scroll: ScrollContainer
var _drop_card_desc: Control
# must-resolve mode (wave-end lootboxes): full Take/Recycle UI, but backing out
# is blocked - a picked-up box has no shop card to stay armed on
var _block_cancel: bool = false
# per-rung radial glow textures (built once, cached): nothing at white, growing
# glow up the ladder, radiant rays at gold
var _glow_cache: = {}
const GLOW_STRENGTH = {1: 0.0, 2: 0.22, 3: 0.32, 4: 0.42, 5: 0.55, 6: 0.7, 7: 0.85, 8: 1.0}
# the animated aura around the WON card: appears on landing, spins and breathes
var _outer_glow: TextureRect
var _glow_phase: float = 0.0


func setup(entry: Dictionary, player_index: int, block_cancel: bool = false) -> void :
	_entry = entry
	_player_index = player_index
	_block_cancel = block_cancel

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
	_window.rect_size = Vector2(window_w, CARD + 2.0 * STRIP_PAD)
	_window.rect_position = Vector2((view_size.x - window_w) / 2.0, (view_size.y - CARD) / 2.0 - 30 - STRIP_PAD)
	_window.rect_clip_content = true
	_window.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_window)

	_strip = Control.new()
	_strip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_window.add_child(_strip)
	_fill_strip()

	var ticker: = ColorRect.new()
	ticker.color = Color(1, 1, 1, 0.9)
	ticker.rect_size = Vector2(3, CARD + 2.0 * STRIP_PAD)
	ticker.rect_position = Vector2((view_size.x - 3) / 2.0, _window.rect_position.y)
	ticker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(ticker)

	_reveal_label = Label.new()
	_reveal_label.align = Label.ALIGN_CENTER
	_reveal_label.rect_position = Vector2(0, _window.rect_position.y + CARD + 2.0 * STRIP_PAD + 14)
	_reveal_label.rect_size = Vector2(view_size.x, 40)
	_reveal_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_reveal_label)

	# idle state: the carousel waits behind a single OPEN button
	_open_button = Button.new()
	_open_button.text = tr("P2W_OPEN")
	_open_button.rect_min_size = Vector2(220, 56)
	_open_button.rect_position = Vector2((view_size.x - 220) / 2.0, _window.rect_position.y + CARD + 2.0 * STRIP_PAD + 84)
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

	# the chest's honest odds: crate icon + colored rows, centered as one group
	# below the OPEN button (top-right collided with the pickup HUD - user)
	var odds_rows: Array = ItemService.P2WData.CHEST_ODDS[int(_entry.rung)]
	var odds_panel_w: float = 440.0
	var odds_panel_h: float = 34.0 + odds_rows.size() * 44.0
	var odds_icon_size: float = 120.0
	var odds_group_w: float = odds_icon_size + 20.0 + odds_panel_w
	var odds_group_x: float = (view_size.x - odds_group_w) / 2.0
	var odds_group_y: float = _window.rect_position.y + CARD + 2.0 * STRIP_PAD + 84 + 56 + 24

	var odds_icon: = TextureRect.new()
	odds_icon.texture = load("res://items/custom/p2w/chest_%d/chest_%d.png" % [int(_entry.rung), int(_entry.rung)])
	odds_icon.expand = true
	odds_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	odds_icon.rect_size = Vector2(odds_icon_size, odds_icon_size)
	odds_icon.rect_position = Vector2(odds_group_x, odds_group_y + (odds_panel_h - odds_icon_size) / 2.0)
	odds_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(odds_icon)

	var odds_panel: = Panel.new()
	var odds_style: = StyleBoxFlat.new()
	odds_style.bg_color = Color(0.05, 0.05, 0.05, 0.92)
	odds_style.border_color = Color(0.35, 0.35, 0.35)
	odds_style.set_border_width_all(2)
	odds_style.set_corner_radius_all(6)
	odds_panel.add_stylebox_override("panel", odds_style)
	odds_panel.rect_size = Vector2(odds_panel_w, odds_panel_h)
	odds_panel.rect_position = Vector2(odds_group_x + odds_icon_size + 20.0, odds_group_y)
	odds_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(odds_panel)
	# rarity order, lowest rung first. NO font override: the game theme styles
	# these rows, so they match the stat-sheet text exactly (overriding with a
	# pre-tree get_font() was what forced Godot's tiny builtin font before)
	var odds_sorted: Array = odds_rows.duplicate()
	for oi in odds_sorted.size():
		var od: Array = odds_sorted[oi]
		var od_label: = Label.new()
		var od_tier: int = ItemService.P2WData.RUNG_TIERS[int(od[0])]
		var od_color: Color = ItemService.get_color_from_tier(od_tier)
		if od_color == Color.white:
			od_color = Color(0.85, 0.85, 0.85)
		od_label.text = str(ItemService.P2WData.RUNG_NAMES[int(od[0])]) + " chance: " + str(od[1]) + "%"
		od_label.add_color_override("font_color", od_color)
		od_label.rect_position = Vector2(22, 16 + oi * 44)
		od_label.rect_size = Vector2(odds_panel_w - 44, 40)
		od_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		odds_panel.add_child(od_label)

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


func _get_glow_texture(rung: int) -> Texture:
	if _glow_cache.has(rung):
		return _glow_cache[rung]
	var strength: float = GLOW_STRENGTH[rung]
	if strength <= 0.0:
		_glow_cache[rung] = null
		return null
	var tier_int: int = ItemService.P2WData.RUNG_TIERS[rung]
	var glow_color: Color = ItemService.get_color_from_tier(tier_int)
	if glow_color == Color.white:
		glow_color = Color(0.85, 0.85, 0.85)
	var size: = 128
	var half: float = size / 2.0
	var img: = Image.new()
	img.create(size, size, false, Image.FORMAT_RGBA8)
	img.lock()
	var with_rays: bool = rung >= 8
	for y in size:
		for x in size:
			var dx: float = x - half
			var dy: float = y - half
			var dist: float = sqrt(dx * dx + dy * dy) / half
			if dist >= 1.0:
				continue
			var falloff: float = pow(max(0.0, 1.0 - dist), 2.2)
			var alpha: float = falloff * 0.55 * strength
			if with_rays and dist > 0.05:
				# baked shining rays: 8 wedges around the ring
				var ray: float = pow(abs(cos(atan2(dy, dx) * 4.0)), 14.0)
				alpha += ray * max(0.0, 1.0 - dist) * 0.5
			if alpha > 0.003:
				img.set_pixel(x, y, Color(glow_color.r, glow_color.g, glow_color.b, min(alpha, 0.9)))
	img.unlock()
	var tex: = ImageTexture.new()
	tex.create_from_image(img, Texture.FLAG_FILTER)
	_glow_cache[rung] = tex
	return tex


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

	var glow_tex: Texture = _get_glow_texture(rung)
	if glow_tex != null:
		var glow: = TextureRect.new()
		glow.texture = glow_tex
		glow.expand = true
		var glow_size: float = CARD * (0.9 + 0.35 * GLOW_STRENGTH[rung])
		glow.rect_size = Vector2(glow_size, glow_size)
		glow.rect_position = Vector2((CARD - glow_size) / 2.0, (CARD - glow_size) / 2.0)
		glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(glow)

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
	var winner_id: String = str(_entry.id)
	var prev_id: String = ""
	for i in N_CARDS:
		var card: Panel
		if i == WINNER_INDEX:
			var resolved: Array = _rung_of_drop(_entry)
			card = _make_card(resolved[0], resolved[1], bool(_entry.get("item_cursed", false)))
			_winner_panel = card
			prev_id = winner_id
		else:
			# no identical neighbors on the carousel: reroll while this filler
			# matches the previous card (or the winner it will sit next to).
			# Fillers inherit the chest's cursed state, so a cursed chest's reel
			# honestly shows ~1 in 3 cards cursed (was hard-coded uncursed).
			var chest_cursed: bool = bool(_entry.get("cursed", false))
			var filler: Dictionary = ItemService.p2w_roll_chest_drop(chest_rung, _player_index, chest_cursed)
			for _retry in 8:
				var clashes_prev: bool = str(filler.id) == prev_id
				var clashes_winner: bool = i == WINNER_INDEX - 1 and str(filler.id) == winner_id
				if not clashes_prev and not clashes_winner:
					break
				filler = ItemService.p2w_roll_chest_drop(chest_rung, _player_index, chest_cursed)
			var resolved_f: Array = _rung_of_drop(filler)
			card = _make_card(resolved_f[0], resolved_f[1], bool(filler.get("item_cursed", false)))
			prev_id = str(filler.id)
		card.rect_position = Vector2(i * (CARD + CARD_GAP), STRIP_PAD)
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
	if _landed:
		# post-landing: the outer aura slowly spins and breathes
		if _outer_glow != null:
			_glow_phase += _delta
			_outer_glow.rect_rotation = _glow_phase * 10.0
			var glow_pulse: float = 1.0 + 0.07 * sin(_glow_phase * 2.2)
			_outer_glow.rect_scale = Vector2(glow_pulse, glow_pulse)
		return
	var ticker_in_window: float = _window.rect_size.x / 2.0
	var card_under: int = int(floor((ticker_in_window - _strip.rect_position.x) / (CARD + CARD_GAP)))
	if card_under != _last_tick_card:
		# the card under the ticker glows while everything else sits at neutral
		if _last_tick_card >= 0 and _last_tick_card < _strip.get_child_count():
			_strip.get_child(_last_tick_card).modulate = Color(1, 1, 1)
		if card_under >= 0 and card_under < _strip.get_child_count():
			_strip.get_child(card_under).modulate = Color(1.35, 1.35, 1.35)
		_last_tick_card = card_under
		_tick_sound.pitch_scale = rand_range(0.92, 1.08)
		_tick_sound.play()


func _on_landed() -> void :
	_landed = true
	_land_sound.play()

	for card in _strip.get_children():
		card.modulate = Color(1, 1, 1)
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

	# animated OUTER aura around the winning box (cursed drops glow curse-purple,
	# via the purple rung's texture). Lives on the root, tucked under the strip
	# window, so it halos past the clip edges instead of being sliced by them.
	var aura_rung: int = 5 if bool(_entry.get("item_cursed", false)) else int(resolved[1])
	var aura_tex: Texture = _get_glow_texture(aura_rung)
	if aura_tex != null:
		_outer_glow = TextureRect.new()
		_outer_glow.texture = aura_tex
		_outer_glow.expand = true
		var aura_size: float = CARD * 2.1
		_outer_glow.rect_size = Vector2(aura_size, aura_size)
		_outer_glow.rect_pivot_offset = Vector2(aura_size / 2.0, aura_size / 2.0)
		_outer_glow.rect_position = _window.rect_position + _strip.rect_position + _winner_panel.rect_position + Vector2(CARD / 2.0 - aura_size / 2.0, CARD / 2.0 - aura_size / 2.0)
		_outer_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(_outer_glow)
		move_child(_outer_glow, _window.get_index())

	var got_name: String = tr(drop_data.name) if drop_data != null else "???"
	if bool(_entry.get("item_cursed", false)):
		_reveal_label.add_color_override("font_color", Color(0.68, 0.35, 1.0))
		_reveal_label.text = got_name + "  [" + tr("P2W_CURSED") + "]"
	else:
		var tier_int: int = ItemService.P2WData.RUNG_TIERS[int(resolved[1])]
		_reveal_label.add_color_override("font_color", ItemService.get_color_from_tier(tier_int))
		_reveal_label.text = got_name

	# the full item card above the strip (user request), height-capped to the
	# free space so it never covers other UI; taller cards scroll
	if drop_data != null:
		var view_now: Vector2 = get_viewport_rect().size
		# top margin keeps the card clear of the wave counter; it bottom-aligns
		# against the strip after shrinking, so short cards hug the reel
		var card_top: float = 200.0
		var avail_h: float = _window.rect_position.y - card_top - 16.0
		var card_w: float = 560.0
		_drop_card = Panel.new()
		var card_style: = StyleBoxFlat.new()
		card_style.bg_color = Color(0.055, 0.055, 0.055, 0.97)
		var winner_box = _winner_panel.get_stylebox("panel")
		card_style.border_color = winner_box.border_color if winner_box is StyleBoxFlat else Color(0.75, 0.75, 0.75)
		card_style.set_border_width_all(3)
		card_style.set_corner_radius_all(8)
		_drop_card.add_stylebox_override("panel", card_style)
		_drop_card.rect_position = Vector2((view_now.x - card_w) / 2.0, card_top)
		_drop_card.rect_size = Vector2(card_w, avail_h)
		add_child(_drop_card)
		_drop_card_scroll = ScrollContainer.new()
		_drop_card_scroll.rect_position = Vector2(12, 12)
		_drop_card_scroll.rect_size = Vector2(card_w - 24, avail_h - 24)
		_drop_card.add_child(_drop_card_scroll)
		_drop_card_desc = preload("res://ui/menus/shop/item_description.tscn").instance()
		_drop_card_desc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		_drop_card_scroll.add_child(_drop_card_desc)
		# the P2W sees the ASSIGNED rarity on the card (retiered display copy);
		# everyone else keeps the vanilla name color, per the coop rules
		var card_data = drop_data
		if RunData.is_p2w(_player_index):
			card_data = ItemService.p2w_retier_item(drop_data)
		_drop_card_desc.set_item(card_data, _player_index, 1)
		call_deferred("_shrink_drop_card")

	# the vanilla crate choice: Take, or Recycle for materials
	var refund: int = 0
	if drop_data != null:
		refund = ItemService.get_recycling_value(RunData.current_wave, drop_data.value, _player_index, drop_data is WeaponData)
	_recycle_button.text = tr("MENU_RECYCLE") + " (+" + str(refund) + ")"

	# a weapon that can neither fit a slot nor merge with an owned copy cannot be
	# taken - offering Take and vanishing the weapon was wrong (user): the only
	# choice left is recycling it
	var can_take: bool = true
	if drop_data is WeaponData:
		var slot_max: int = int(RunData.get_player_effect(Keys.weapon_slot_hash, _player_index))
		if RunData.get_player_weapons_ref(_player_index).size() >= slot_max:
			can_take = false
			for owned_weapon in RunData.get_player_weapons_ref(_player_index):
				if owned_weapon.my_id == drop_data.my_id and drop_data.upgrades_into != null:
					can_take = true

	var view_size: Vector2 = get_viewport_rect().size
	var buttons_y: float = _window.rect_position.y + CARD + 2.0 * STRIP_PAD + 84
	if can_take:
		_take_button.rect_position = Vector2(view_size.x / 2.0 - 232, buttons_y)
		_recycle_button.rect_position = Vector2(view_size.x / 2.0 + 12, buttons_y)
		_take_button.visible = true
		_recycle_button.visible = true
		_take_button.call_deferred("grab_focus")
	else:
		_recycle_button.rect_position = Vector2(view_size.x / 2.0 - 110, buttons_y)
		_recycle_button.visible = true
		_recycle_button.call_deferred("grab_focus")


# once the description has laid itself out, shrink the panel to its REAL
# content height (rect_size lies inside a ScrollContainer - it reports the
# expanded scroll height, which is why the card used to sit half empty) and
# bottom-align it just above the strip, far from the wave counter
func _shrink_drop_card() -> void :
	if _drop_card == null or _drop_card_desc == null:
		return
	var content_h: float = _drop_card_desc.get_combined_minimum_size().y + 24.0
	if content_h < _drop_card.rect_size.y:
		_drop_card.rect_size.y = content_h
		_drop_card_scroll.rect_size.y = content_h - 24.0
	_drop_card.rect_position.y = _window.rect_position.y - 16.0 - _drop_card.rect_size.y


# ---- outcomes -----------------------------------------------------------------

func _on_take_pressed() -> void :
	if _landed:
		emit_signal("reel_done", "take")


func _on_recycle_pressed() -> void :
	if _landed:
		emit_signal("reel_done", "recycle")


func _unhandled_input(event: InputEvent) -> void :
	# before the spin, backing out is allowed: the chest stays armed on its card
	if event.is_action_pressed("ui_cancel"):
		if _block_cancel:
			# wave-end boxes MUST resolve: swallow ESC entirely so nothing behind
			# the reel (pause, wave-end UI) can react to it either
			get_tree().set_input_as_handled()
			return
		if not _spinning:
			# shop: backing out is allowed - the chest stays armed on its card
			get_tree().set_input_as_handled()
			emit_signal("reel_done", "cancel")
