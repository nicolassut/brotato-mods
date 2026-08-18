class_name RunOptionsPanel
extends PanelContainer


onready var _run_options: Label = $"%RunOptions"
onready var _endless_button: EndlessButton = $"%EndlessButton"
onready var _coop_button: CoopButton = $"%CoopButton"


func init():
	var _e = _coop_button.connect("coop_initialized", self, "on_coop_toggled")
	on_coop_toggled(_coop_button.pressed)


func on_coop_toggled(button_pressed: bool) -> void :
	if button_pressed:
		_run_options.clip_text = true
		_coop_button.clip_text = true
	else:
		_run_options.clip_text = false
		_coop_button.clip_text = false
