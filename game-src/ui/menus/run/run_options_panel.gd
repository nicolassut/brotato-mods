class_name RunOptionsPanel
extends PanelContainer


onready var _run_options: Label = $"%RunOptions"
onready var _endless_button: EndlessButton = $"%EndlessButton"
onready var _coop_button: CoopButton = $"%CoopButton"


# Gourmet ecosystem - pre-lobby game-mode selector (ECOSYSTEM.md Phase 6).
# Global for now (stamps every player at run start in difficulty_selection);
# the lobby mode shrine takes over per-player selection in Phase 7.
var _mode_button: OptionButton = null

func init():
	var _e = _coop_button.connect("coop_initialized", self, "on_coop_toggled")
	on_coop_toggled(_coop_button.pressed)
	_init_mode_selector()


func _init_mode_selector() -> void :
	if _mode_button != null:
		return
	var modes: Array = GameModes.available_modes()
	if modes.empty():
		return
	_mode_button = OptionButton.new()
	_mode_button.add_item(tr("MODE_NONE"), 0)
	_mode_button.set_item_metadata(0, "")
	var selected_index: int = 0
	for mode in modes:
		var item_index: int = _mode_button.get_item_count()
		_mode_button.add_item(str(mode["name"]), item_index)
		_mode_button.set_item_metadata(item_index, str(mode["id"]))
		if str(ProgressData.settings.get("selected_game_mode", "")) == str(mode["id"]):
			selected_index = item_index
	_mode_button.selected = selected_index
	var _err = _mode_button.connect("item_selected", self, "_on_mode_selected")
	_endless_button.get_parent().add_child(_mode_button)


func _on_mode_selected(item_index: int) -> void :
	ProgressData.settings.selected_game_mode = str(_mode_button.get_item_metadata(item_index))
	ProgressData.save_settings()


func on_coop_toggled(button_pressed: bool) -> void :
	if button_pressed:
		_run_options.clip_text = true
		_coop_button.clip_text = true
	else:
		_run_options.clip_text = false
		_coop_button.clip_text = false
