extends Node2D

# OFF DUTY mode dialog as a SPEECH BUBBLE (user 2026-08-22: "dialogue bubbles
# over the characters ... a brotato styled bubble, not the very low grade html").
#
# It lives in WORLD space, parented to the lobby above the YSort world, so it
# sits over the guy who is talking and pans with the camera instead of covering
# the screen. The chrome is vanilla Brotato: the game's own tooltip stylebox
# (near-black fill, 5px pure-black border, radius 8) and base_theme, so the
# fonts, buttons and CheckButton tick graphics are the real ones - nothing here
# invents its own widget look.
#
# The tail is drawn by this node (Node2D._draw runs BEFORE its children), so the
# panel covers the tail's flat top and the two read as one shape. Light comes
# from the left (project law), so the drop shadow falls right.

const BODY_COLOR: = Color(0.0588235, 0.0588235, 0.0588235, 0.94)
const BORDER_COLOR: = Color(0, 0, 0, 1)
const SHADOW_COLOR: = Color(0, 0, 0, 0.34)
const BORDER: = 5.0
const TAIL_HALF: = 17.0
const TAIL_LEN: = 26.0
const HEAD_CLEARANCE: = 92.0   # the guy's head, measured from his base
const CHEST: = 46.0            # where a side tail points
const SIDE_GAP: = 34.0   # the guy's head, measured from his base
const GAP: = 8.0
const SHADOW_OFFSET: = Vector2(7.0, 8.0)

var panel: PanelContainer = null
var content: VBoxContainer = null
# the bubble may not hang off the edge of the world the camera can reach
var view_bounds: = Rect2(-1400, -1330, 2800, 2470)

var _tail_base_a: = Vector2.ZERO
var _tail_base_b: = Vector2.ZERO
var _tail_tip: = Vector2.ZERO
var _has_tail: bool = false


func _ready() -> void :
	z_index = 200
	z_as_relative = false
	var theme: Theme = load("res://resources/themes/base_theme.tres")
	panel = PanelContainer.new()
	panel.theme = theme
	panel.add_stylebox_override("panel", load("res://resources/themes/panel/tooltip_style.tres"))
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(panel)
	content = VBoxContainer.new()
	content.add_constant_override("separation", 6)
	panel.add_child(content)
	set_process(true)


# base_theme's default font is size 40 - a card built with it is taller than
# the screen (measured 2026-08-22). The bubble uses the game's smaller cuts.
const FONT_TITLE: = "res://resources/fonts/actual/base/font_26.tres"
const FONT_BODY: = "res://resources/fonts/actual/base/font_smallest_text.tres"
const FONT_SMALL: = "res://resources/fonts/actual/base/font_very_smallest_text.tres"


func font_title() -> Font:
	return load(FONT_TITLE) as Font


func font_body() -> Font:
	return load(FONT_BODY) as Font


func font_small() -> Font:
	return load(FONT_SMALL) as Font


func _process(_delta: float) -> void :
	if panel == null:
		return
	var size: Vector2 = panel.rect_size
	if size.x < 1.0 or size.y < 1.0:
		return
	# clamp against what the camera can ACTUALLY see this frame, not a guessed
	# world box: the guys sit against the north wall, where the camera stops.
	var view: Rect2 = _visible_world_rect()
	var margin: = 16.0
	var head: float = position.y - HEAD_CLEARANCE
	var chest: float = position.y - CHEST
	var placed: = false
	var top: float = 0.0
	var left: float = 0.0
	_has_tail = false
	# 1. OVER HIS HEAD, the way a speech bubble should sit
	var above_top: float = head - GAP - TAIL_LEN - size.y
	if above_top >= view.position.y + margin:
		top = above_top
		left = clamp(position.x - size.x / 2.0,
				view.position.x + margin, view.end.x - margin - size.x)
		placed = true
		_tail_base_a = Vector2(0, top + size.y) - position
		_tail_base_b = _tail_base_a
		_tail_tip = Vector2(0, head) - position
	if not placed:
		# 2. BESIDE him (whichever side has room), tail pointing at his chest
		top = clamp(chest - size.y / 2.0,
				view.position.y + margin, view.end.y - margin - size.y)
		var right_left: float = position.x + SIDE_GAP + TAIL_LEN
		var left_left: float = position.x - SIDE_GAP - TAIL_LEN - size.x
		if right_left + size.x <= view.end.x - margin:
			left = right_left
			placed = true
			_tail_tip = Vector2(position.x + SIDE_GAP, chest) - position
			_tail_base_a = Vector2(left, 0) - position
		elif left_left >= view.position.x + margin:
			left = left_left
			placed = true
			_tail_tip = Vector2(position.x - SIDE_GAP, chest) - position
			_tail_base_a = Vector2(left + size.x, 0) - position
		if placed:
			var edge_y: float = clamp(chest, top + TAIL_HALF + BORDER + 4.0,
					top + size.y - TAIL_HALF - BORDER - 4.0) - position.y
			_tail_base_a = Vector2(_tail_base_a.x, edge_y - TAIL_HALF)
			_tail_base_b = Vector2(_tail_base_a.x, edge_y + TAIL_HALF)
			_has_tail = true
	elif placed:
		# finish the over-the-head tail now that `left` is known
		var edge_x: float = clamp(0.0,
				left - position.x + TAIL_HALF + BORDER + 4.0,
				left - position.x + size.x - TAIL_HALF - BORDER - 4.0)
		_tail_base_a = Vector2(edge_x - TAIL_HALF, top + size.y - position.y)
		_tail_base_b = Vector2(edge_x + TAIL_HALF, top + size.y - position.y)
		_has_tail = true
	if not placed:
		# 3. nowhere clean to go: sit on him, no tail to fake
		top = clamp(head - size.y, view.position.y + margin, view.end.y - margin - size.y)
		left = clamp(position.x - size.x / 2.0,
				view.position.x + margin, view.end.x - margin - size.x)
	panel.rect_position = Vector2(left, top) - position
	update()


func _visible_world_rect() -> Rect2:
	var viewport: = get_viewport()
	var canvas: Transform2D = viewport.canvas_transform
	var scale: Vector2 = canvas.get_scale()
	if scale.x == 0.0 or scale.y == 0.0:
		return Rect2(-1400, -1330, 2800, 2470)
	return Rect2(- canvas.origin / scale, viewport.size / scale)


func _draw() -> void :
	if panel == null:
		return
	var rect: = Rect2(panel.rect_position, panel.rect_size)
	# drop shadow (light comes from the left, so it falls right)
	var shadow: = StyleBoxFlat.new()
	shadow.bg_color = SHADOW_COLOR
	shadow.set_corner_radius_all(8)
	draw_style_box(shadow, Rect2(rect.position + SHADOW_OFFSET, rect.size))
	if not _has_tail:
		return
	# TAIL: black skirt first, body inside it. Its base is tucked a couple of
	# pixels under the card, which draws after this (children paint over
	# Node2D._draw), so the two read as one shape.
	var base_mid: = (_tail_base_a + _tail_base_b) * 0.5
	var point_dir: Vector2 = (_tail_tip - base_mid).normalized()
	var along: Vector2 = (_tail_base_b - _tail_base_a).normalized()
	var tuck: Vector2 = point_dir * - 3.0
	draw_colored_polygon(PoolVector2Array([
		_tail_base_a - along * BORDER + tuck,
		_tail_base_b + along * BORDER + tuck,
		_tail_tip,
	]), BORDER_COLOR)
	draw_colored_polygon(PoolVector2Array([
		_tail_base_a + tuck,
		_tail_base_b + tuck,
		_tail_tip - point_dir * (BORDER * 1.3),
	]), BODY_COLOR)
