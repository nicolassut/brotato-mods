class_name ButtonWithIcon
extends MyMenuButtonParent

export var resize_x: = true
export var resize_y: = true

const MARGIN = 24.0

var _focused: = false
var _hovered: = false
var _pressed: = false
var _color_locked: = false
var _value: = 0
# Gourmet DLC - The Debtor buys on debt, so his prices show as "-N" in the negative colour.
var _debt_mode: = false

onready var _content = $HBoxContainer
onready var _label = $HBoxContainer / Label
onready var gold_icon = $HBoxContainer / GoldIcon
onready var additional_icon: TextureRect = $"%AdditionalIcon"


func _ready() -> void :
	on_content_resized()
	_content.connect("resized", self, "on_content_resized")


func _process(_delta):
	
	
	on_content_resized()


func reinitialize_colors(player_index: int) -> void :
	_color_locked = false
	_focused = false
	_hovered = false
	_pressed = false
	set_color_from_currency(RunData.get_player_currency(player_index))


func set_color_from_currency(currency: int) -> void :
	# Gourmet DLC - Debtor prices always read in the negative colour (bought on debt).
	if _debt_mode:
		_color_locked = true
		_update_focus_colors()
		return
	if currency < _value:
		_color_locked = true
	else:
		_color_locked = false
	_update_focus_colors()


func on_content_resized():
	if resize_x and get_content_size_x() != self.rect_min_size.x:
		self.rect_min_size.x = get_content_size_x() + MARGIN
	if resize_y and (_content.rect_size.y > self.rect_size.y):
		self.rect_min_size.y = _content.rect_size.y


func get_content_size_x() -> int:
	var size_x = 0
	for child in _content.get_children():
		size_x += child.rect_size.x
	return size_x


func set_text(new_text: String) -> void :
	_label.text = new_text


func set_value(value: int, currency: int) -> void :
	_value = value
	if _debt_mode:
		_label.text = "-" + str(value)
		_color_locked = true
		_update_focus_colors()
	else:
		_label.text = str(value)
		set_color_from_currency(currency)


func set_debt_mode(on: bool) -> void :
	_debt_mode = on


func _on_ButtonWithIcon_pressed() -> void :
	_pressed = true
	on_pressed()
	_update_focus_colors()


func _on_ButtonWithIcon_focus_entered() -> void :
	_focused = true
	on_focus_entered()
	_update_focus_colors()


func _on_ButtonWithIcon_focus_exited() -> void :
	_focused = false
	if not _hovered:
		_pressed = false
	_update_focus_colors()


func _on_ButtonWithIcon_mouse_entered() -> void :
	_hovered = true
	on_mouse_entered()
	_update_focus_colors()


func _on_ButtonWithIcon_mouse_exited() -> void :
	_hovered = false
	if not _focused:
		_pressed = false
	_update_focus_colors()


func set_material_icon(icon: Texture, color: Color = Color.white) -> void :
	gold_icon.set_icon(icon, color)


func set_additional_icon(icon: Texture) -> void :
	additional_icon.texture = icon
	additional_icon.rect_min_size.x = gold_icon.rect_min_size.x


func remove_additional_icon() -> void :
	additional_icon.texture = null
	self.rect_min_size.x -= additional_icon.rect_min_size.x
	additional_icon.rect_min_size.x = 0


const META_FONT_KEY: = "button_with_icon__original_font_override"
const META_FONT_COLOR_KEY: = "button_with_icon__original_font_color_override"
var _are_other_node_focus_colors_set: = false


func _update_focus_colors() -> void :
	if _focused or _hovered or _pressed:
		_set_other_node_focus_colors()
	else:
		_clear_other_node_focus_colors()

	var color = get_color("font_color")
	if _color_locked:
		color = Color(ProgressData.settings.color_negative)
	elif _focused:
		color = get_color("font_color_focus")
	elif _hovered:
		color = get_color("font_color_hover")
	elif _pressed:
		color = get_color("font_color_pressed")
	_label.add_color_override("font_color", color)

	if RunData.is_coop_run:
		if _color_locked:
			
			_label.set_meta(META_FONT_KEY, _label.get_font("font"))
			var font = _label.get_font("font").duplicate()
			font.outline_size = 1
			font.outline_color = Color(ProgressData.settings.color_negative).darkened(0.7)
			_label.add_font_override("font", font)
		else:
			if _label.has_meta(META_FONT_KEY):
				_label.add_font_override("font", _label.get_meta(META_FONT_KEY))


func _set_other_node_focus_colors() -> void :
	if _are_other_node_focus_colors_set:
		return
	_are_other_node_focus_colors_set = true
	for node in _get_other_stylable_nodes():
		var original_font = node.get_font("font")
		node.set_meta(META_FONT_KEY, original_font)
		var font = original_font.duplicate()
		font.outline_size = 0
		node.add_font_override("font", font)

		var original_color = node.get_color("font_color")
		node.set_meta(META_FONT_COLOR_KEY, original_color)
		node.add_color_override("font_color", original_color.inverted())


func _clear_other_node_focus_colors() -> void :
	if not _are_other_node_focus_colors_set:
		return
	_are_other_node_focus_colors_set = false
	for node in _get_other_stylable_nodes():
		node.add_font_override("font", node.get_meta(META_FONT_KEY))
		node.add_color_override("font_color", node.get_meta(META_FONT_COLOR_KEY))


func _get_other_stylable_nodes(node: Node = self, result: = []) -> Array:
	for child in node.get_children():
		if child == _label:
			continue
		elif child is Label or child is Button:
			result.push_back(child)
		else:
			var _result = _get_other_stylable_nodes(child, result)
	return result
