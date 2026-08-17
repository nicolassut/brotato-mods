class_name MenuOptions
extends MarginContainer

signal general_button_pressed
signal gameplay_button_pressed
signal back_button_pressed

signal hp_bar_on_character_changed(value)
signal darken_screen_changed(value)
signal character_highlighting_changed(value)
signal weapon_highlighting_changed(value)
signal turret_highlighting_changed(value)
signal pet_highlighting_changed(value)
signal pet_transparency_changed(value)
signal lock_coop_camera_changed(value)

export (bool) var is_in_a_run: = false

onready var focus_before_created: Control = null

onready var gameplayVBoxContainer = $"%GameplayVBoxContainer" as VBoxContainer
onready var accessibility_container = $"%Accessibility_Container" as ScrollContainer
onready var accessibility_slider_container = $"%accessibility_slider_container" as VBoxContainer
onready var video_container = $"%VideoContainer"
onready var audio_container = $"%AudioContainer"


onready var master_slider = $"%MasterSlider"
onready var sound_slider = $"%SoundSlider"
onready var music_slider = $"%MusicSlider"
onready var old_tracks_warning_label = $"%OldTracksWarningLabel" as Label

onready var main_screen_keyart = $"%MainScreenArt" as OptionButton
onready var language_button = $"%LanguageButton" as OptionButton
onready var screenshake_button = $"%ScreenshakeButton" as CheckButton
onready var fullscreen_button = $"%FullScreenButton" as CheckButton
onready var visual_effects_button = $"%VisualEffectsButton" as CheckButton
onready var background_button = $"%BackgroundButton" as OptionButton
onready var damage_display_button = $"%DamageDisplayButton" as CheckButton
onready var optimize_end_waves_button = $"%OptimizeEndWavesButton" as CheckButton
onready var limit_fps_button = $"%LimitFPSButton" as CheckButton

onready var mute_on_focus_lost_button = $"%MuteOnFocusLostButton" as CheckButton
onready var on_lost_focus_button = $"%OnLostFocusButton" as OptionButton
onready var new_tracks_button = $"%NewTracksButton" as CheckButton
onready var old_tracks_button = $"%OldTracksButton" as CheckButton
onready var abyssal_terrors_tracks_button = $"%AbyssalTerrorsTracksButton" as CheckButton

onready var mouse_only_button = $"%MouseOnlyButton" as CheckButton
onready var manual_aim_button = $"%ManualAimButton" as CheckButton
onready var manual_aim_on_mouse_press_button = $"%ManualAimOnMousePressButton" as CheckButton
onready var movement_with_gamepad: CheckButton = $"%MovementWithGamepad"
onready var hp_bar_button = $"%HPbarOnCharacterButton" as CheckButton
onready var boss_hp_bar_button = $"%BossHPBarButton" as CheckButton
onready var keep_lock_button = $"%KeepLockButton" as CheckButton
onready var lock_coop_camera_button = $"%LockCoopCameraButton" as CheckButton
onready var score_storing_button = $"%ScoreStoringButton" as OptionButton
onready var share_coop_loot_button = $"%ShareCoopLootButton" as CheckButton
onready var abyssal_terrors_dlc_button = $"%AbyssalTerrorsDLCButton" as CheckButton

onready var enemy_health_slider = $"%EnemyHealthSlider"
onready var enemy_damage_slider = $"%EnemyDamageSlider"
onready var enemy_speed_slider = $"%EnemySpeedSlider"
onready var constant_projectile_button = $"%ConstantProjectileButton" as OptionButton
onready var explosion_opacity_slider = $"%ExplosionOpacitySlider"
onready var projectile_opacity_slider = $"%ProjectileOpacitySlider"
onready var pet_opacity_slider = $"%PetOpacitySlider"
onready var effects_icons_description_button = $"%EffectsIconsInDescriptionButton"
onready var font_size_slider = $"%FontSizeSlider"
onready var color_positive: ColorOption = $"%ColorPositiveText"
onready var color_negative: ColorOption = $"%ColorNegativeText"
onready var color_tier0: ColorOption = $"%Color_tier0"
onready var color_tier1: ColorOption = $"%Color_tier1"
onready var color_tier2: ColorOption = $"%Color_tier2"
onready var color_tier3: ColorOption = $"%Color_tier3"
onready var color_tier4: ColorOption = $"%Color_tier4"
onready var color_tier5: ColorOption = $"%Color_tier5"
onready var character_highlighting_button = $"%CharacterHighlightingButton" as CheckButton
onready var weapon_highlighting_button = $"%WeaponHighlightingButton" as CheckButton
onready var projectile_highlighting_button = $"%ProjectileHighlightingButton" as CheckButton
onready var pet_highlighting_button = $"%PetHighlightingButton" as CheckButton
onready var turret_highlighting_button = $"%TurretHighlightingButton" as CheckButton
onready var gold_sounds_button = $"%GoldSoundsButton" as CheckButton
onready var darken_screen_button = $"%DarkenScreenButton" as CheckButton
onready var retry_wave_button = $"%RetryWaveButton" as CheckButton
onready var green_skins_button: CheckButton = $"%GreenSkinsButton"
onready var no_item_appearance: CheckButton = $"%NoItemAppearanceButton" as CheckButton
onready var holding_button: CheckButton = $"%NoHoldingButton" as CheckButton

onready var lb_texture: InputIcon = $"%lb_texture"
onready var rb_texture: InputIcon = $"%rb_texture"

var all_check_buttons = []
var small_font = preload("res://resources/fonts/actual/base/font_32_outline.tres")
var normal_font = preload("res://resources/fonts/actual/base/font_40_outline.tres")

var all_slider_labels = []
var small_slider_font = preload("res://resources/fonts/actual/base/font_35_outline.tres")
var normal_slider_font = preload("res://resources/fonts/actual/base/font_menus.tres")


func _input(event):
	if self.visible and event.is_action_released("ui_cancel"):
		_on_BackButton_pressed()
		get_tree().set_input_as_handled()


func init() -> void :
	if focus_before_created == null:
		var focus_emulator: = Utils.get_focus_emulator(0)
		if focus_emulator != null:
			focus_before_created = focus_emulator.focused_control
		else:
			focus_before_created = get_focus_owner()
	$"%Audio_but".grab_focus()

	if RunData.is_coop_run:
		lb_texture.player_index = Utils.get_focus_emulator(0).player_index
		rb_texture.player_index = Utils.get_focus_emulator(0).player_index

	var all_children = video_container.get_children()
	all_children.append_array(audio_container.get_children())

	for child in all_children:
		if child is CheckButton:
			all_check_buttons.push_back(child)

	adjust_buttons_font_size()

	master_slider.set_value(ProgressData.settings.volume.master )
	sound_slider.set_value(ProgressData.settings.volume.sound)
	music_slider.set_value(ProgressData.settings.volume.music)

	var i = 0

	for language in ProgressData.languages:
		if language == ProgressData.settings.language:
			language_button.select(i)
			break
		i += 1

	var selected_background = ProgressData.settings.background
	if selected_background > ItemService.backgrounds.size():
		selected_background = 0

	background_button.select(selected_background)
	background_button._on_BackgroundButton_item_selected(selected_background)

	if not ItemService.is_connected("backgrounds_updated", background_button, "on_backgrounds_updated"):
		var _e = ItemService.connect("backgrounds_updated", background_button, "on_backgrounds_updated")

	visual_effects_button.pressed = ProgressData.settings.visual_effects
	screenshake_button.pressed = ProgressData.settings.screenshake
	fullscreen_button.pressed = ProgressData.settings.fullscreen
	damage_display_button.pressed = ProgressData.settings.damage_display
	optimize_end_waves_button.pressed = ProgressData.settings.optimize_end_waves
	limit_fps_button.pressed = ProgressData.settings.limit_fps

	mute_on_focus_lost_button.pressed = ProgressData.settings.mute_on_focus_lost
	on_lost_focus_button.select(ProgressData.settings.on_lost_focus)
	new_tracks_button.set_pressed_no_signal(ProgressData.settings.streamer_mode_tracks)
	old_tracks_button.set_pressed_no_signal(ProgressData.settings.legacy_tracks)

	color_positive._init_color(Color(ProgressData.settings.color_positive))
	color_negative._init_color(Color(ProgressData.settings.color_negative))
	color_tier0._init_color(Color(ProgressData.settings.tier_0_color))
	color_tier1._init_color(Color(ProgressData.settings.tier_1_color))
	color_tier2._init_color(Color(ProgressData.settings.tier_2_color))
	color_tier3._init_color(Color(ProgressData.settings.tier_3_color))
	color_tier4._init_color(Color(ProgressData.settings.tier_4_color))
	color_tier5._init_color(Color(ProgressData.settings.tier_5_color))

	var id: int = ProgressData.settings.main_screen_keyart
	var indx: int = main_screen_keyart.get_item_index(id)
	main_screen_keyart.select(indx)

	if not ProgressData.is_dlc_available("abyssal_terrors"):
		abyssal_terrors_tracks_button.hide()

	abyssal_terrors_tracks_button.set_pressed_no_signal( not ProgressData.settings.deactivated_dlc_tracks.has("abyssal_terrors"))
	init_values_from_progress_data()

	if is_in_a_run:
		for node in get_tree().get_nodes_in_group("hide_in_run"):
			node.hide()



func _on_BackButton_pressed() -> void :
	focus_before_created.grab_focus()
	emit_signal("back_button_pressed")


func _on_MenuOptions_hide() -> void :
	ProgressData.save_settings()


func adjust_buttons_font_size() -> void :
	var all_children = gameplayVBoxContainer.get_children()
	all_children.append_array(accessibility_container.get_children())

	for child in all_children:
		if child is CheckButton:
			all_check_buttons.push_back(child)

	for check_button in all_check_buttons:
		if tr(check_button.text).length() > 30:
			check_button.add_font_override("font", small_font)
		else:
			check_button.add_font_override("font", normal_font)

	var slider_children = accessibility_slider_container.get_children()

	for child in slider_children:
		if child._label.text.to_lower() == "menu_font_size":
			continue

		if tr(child._label.text).length() > 18:
			child._label.add_font_override("font", small_slider_font)
		else:
			child._label.add_font_override("font", normal_slider_font)


func init_values_from_progress_data() -> void :
	mouse_only_button.pressed = ProgressData.settings.mouse_only
	manual_aim_button.pressed = ProgressData.settings.manual_aim
	manual_aim_on_mouse_press_button.pressed = ProgressData.settings.manual_aim_on_mouse_press
	movement_with_gamepad.pressed = ProgressData.settings.movement_with_gamepad
	hp_bar_button.pressed = ProgressData.settings.hp_bar_on_character
	boss_hp_bar_button.pressed = ProgressData.settings.hp_bar_on_bosses
	keep_lock_button.pressed = ProgressData.settings.keep_lock
	lock_coop_camera_button.pressed = ProgressData.settings.lock_coop_camera
	score_storing_button.select(ProgressData.settings.endless_score_storing)
	enemy_health_slider.set_value(ProgressData.settings.enemy_scaling.health)
	enemy_damage_slider.set_value(ProgressData.settings.enemy_scaling.damage)
	enemy_speed_slider.set_value(ProgressData.settings.enemy_scaling.speed)
	constant_projectile_button.select(ProgressData.settings.constant_projectile_option)
	explosion_opacity_slider.set_value(ProgressData.settings.explosion_opacity)
	projectile_opacity_slider.set_value(ProgressData.settings.projectile_opacity)
	pet_opacity_slider.set_value(ProgressData.settings.pet_opacity)
	effects_icons_description_button.pressed = ProgressData.settings.effects_icons_in_description
	font_size_slider.set_value(ProgressData.settings.font_size)
	color_positive._init_color(Color(ProgressData.settings.color_positive))
	color_negative._init_color(Color(ProgressData.settings.color_negative))
	color_tier0._init_color(Color(ProgressData.settings.tier_0_color))
	color_tier1._init_color(Color(ProgressData.settings.tier_1_color))
	color_tier2._init_color(Color(ProgressData.settings.tier_2_color))
	color_tier3._init_color(Color(ProgressData.settings.tier_3_color))
	color_tier4._init_color(Color(ProgressData.settings.tier_4_color))
	color_tier5._init_color(Color(ProgressData.settings.tier_5_color))
	character_highlighting_button.pressed = ProgressData.settings.character_highlighting
	weapon_highlighting_button.pressed = ProgressData.settings.weapon_highlighting
	projectile_highlighting_button.pressed = ProgressData.settings.projectile_highlighting
	turret_highlighting_button.pressed = ProgressData.settings.turret_highlighting
	pet_highlighting_button.pressed = ProgressData.settings.pet_highlighting
	gold_sounds_button.pressed = ProgressData.settings.alt_gold_sounds
	darken_screen_button.pressed = ProgressData.settings.darken_screen
	retry_wave_button.pressed = ProgressData.settings.retry_wave
	share_coop_loot_button.pressed = ProgressData.settings.share_coop_loot
	no_item_appearance.pressed = ProgressData.settings.no_item_appearance
	holding_button.pressed = ProgressData.settings.holding_button

	if not ProgressData.is_dlc_available("abyssal_terrors"):
		abyssal_terrors_dlc_button.hide()
	abyssal_terrors_dlc_button.set_pressed_no_signal( not ProgressData.settings.deactivated_dlcs.has("abyssal_terrors"))

	_init_pack_toggles()

	if not SkinManager.is_skin_set_available("green"):
		green_skins_button.hide()
	green_skins_button.set_pressed_no_signal( not ProgressData.settings.deactivated_skin_sets.has("green"))


func _on_MasterSlider_value_changed(value: float) -> void :
	ProgressData.settings.volume.master = value
	set_volume(value, "Master")


func _on_SoundSlider_value_changed(value: float) -> void :
	ProgressData.settings.volume.sound = value
	set_volume(value, "Sound")


func _on_MusicSlider_value_changed(value: float) -> void :
	ProgressData.settings.volume.music = value
	set_volume(value, "Music")


func set_volume(value: float, bus: String) -> void :
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index(bus), linear2db(value))


func _on_LanguageButton_item_selected(index: int) -> void :
	var language: String = ProgressData.languages[index]
	ProgressData.change_language(language)
	adjust_buttons_font_size()


func _on_ScreenshakeButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.screenshake = button_pressed


func _on_FullScreenButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.fullscreen = button_pressed
	OS.window_fullscreen = button_pressed


func _on_BackgroundButton_item_selected(index: int) -> void :
	ProgressData.settings.background = index
	RunData.reset_background()


func _on_VisualEffectsButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.visual_effects = button_pressed


func _on_DamageDisplayButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.damage_display = button_pressed


func _on_MuteOnFocusLostButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.mute_on_focus_lost = button_pressed



func _on_OptimizeEndWavesButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.optimize_end_waves = button_pressed


func _on_LimitFPSButton_toggled(button_pressed: bool) -> void :
	ProgressData.set_fps_limit(button_pressed)


func _on_StreamerModeTracksButton_toggled(button_pressed):
	ProgressData.settings.streamer_mode_tracks = button_pressed
	MusicManager.set_shuffled_tracks()
	MusicManager.play()


func _on_LegacyTracksButton_toggled(button_pressed):
	ProgressData.settings.legacy_tracks = button_pressed
	MusicManager.set_shuffled_tracks()
	MusicManager.play()


func _on_AbyssalTerrorsTracksButton_toggled(button_pressed):
	if button_pressed:
		ProgressData.settings.deactivated_dlc_tracks.erase("abyssal_terrors")
	else:
		ProgressData.settings.deactivated_dlc_tracks.push_back("abyssal_terrors")
	MusicManager.set_shuffled_tracks()
	MusicManager.play()


func _on_OldTracksButton_focus_entered():
	old_tracks_warning_label.modulate = Color(1, 1, 1, 1)


func _on_OldTracksButton_focus_exited():
	old_tracks_warning_label.modulate = Color(1, 1, 1, 0)


func _on_OldTracksButton_mouse_entered():
	old_tracks_warning_label.modulate = Color(1, 1, 1, 1)


func _on_OldTracksButton_mouse_exited():
	old_tracks_warning_label.modulate = Color(1, 1, 1, 0)


func _on_MouseOnlyButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.mouse_only = button_pressed


func _on_ManualAimButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.manual_aim = button_pressed


func _on_ManualAimOnMousePressButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.manual_aim_on_mouse_press = button_pressed


func _on_MovementWithGamepad_toggled(button_pressed: bool) -> void :
	ProgressData.settings.movement_with_gamepad = button_pressed
	if button_pressed:
		InputService.enable_gamepad_movement()
	else:
		InputService.disable_gamepad_movement()


func _on_HPbarOnCharacterButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.hp_bar_on_character = button_pressed
	emit_signal("hp_bar_on_character_changed", button_pressed)


func _on_BossHPBarButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.hp_bar_on_bosses = button_pressed


func _on_KeepLockButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.keep_lock = button_pressed


func _on_LockCoopCameraButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.lock_coop_camera = button_pressed
	emit_signal("lock_coop_camera_changed", button_pressed)


func _on_ScoreButton_item_selected(index: int) -> void :
	ProgressData.settings.endless_score_storing = index


func _on_EnemyHealthSlider_value_changed(value) -> void :
	ProgressData.settings.enemy_scaling.health = value


func _on_EnemyDamageSlider_value_changed(value) -> void :
	ProgressData.settings.enemy_scaling.damage = value


func _on_EnemySpeedSlider_value_changed(value) -> void :
	ProgressData.settings.enemy_scaling.speed = value


func _on_ExplosionOpacitySlider_value_changed(value) -> void :
	ProgressData.settings.explosion_opacity = value


func _on_ProjectileOpacitySlider_value_changed(value) -> void :
	ProgressData.settings.projectile_opacity = value


func _on_PetOpacitySlider_value_changed(value):
	ProgressData.settings.pet_opacity = value
	emit_signal("pet_transparency_changed", value)


func _on_FontSizeSlider_value_changed(value) -> void :
	ProgressData.set_font_size(value)


func _on_CharacterHighlightingButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.character_highlighting = button_pressed
	emit_signal("character_highlighting_changed", button_pressed)


func _on_WeaponHighlightingButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.weapon_highlighting = button_pressed
	emit_signal("weapon_highlighting_changed", button_pressed)


func _on_ProjectileHighlightingButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.projectile_highlighting = button_pressed


func _on_TurretHighlightingButton_toggled(button_pressed):
	ProgressData.settings.turret_highlighting = button_pressed
	emit_signal("turret_highlighting_changed", button_pressed)


func _on_PetHighlightingButton_toggled(button_pressed):
	ProgressData.settings.pet_highlighting = button_pressed
	emit_signal("pet_highlighting_changed", button_pressed)


func _on_GoldSoundsButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.alt_gold_sounds = button_pressed


func _on_DarkenScreenButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.darken_screen = button_pressed
	emit_signal("darken_screen_changed", button_pressed)


func _on_RetryWaveButton_toggled(button_pressed: bool) -> void :
	ProgressData.settings.retry_wave = button_pressed


func _on_ShareCoopLootButton_toggled(button_pressed):
	ProgressData.settings.share_coop_loot = button_pressed


# Gourmet ecosystem - one CheckButton per pack, generated beside the DLC toggle
# (same opt-out semantics). Title-screen only: toggling packs mid-run is
# unsupported, so the buttons are disabled anywhere but the title screen.
# Continue-safety lives in ProgressData.check_dlc_valid_for_saved_run_state.
var _pack_buttons: = {}
func _init_pack_toggles() -> void :
	var packs_allowed: bool = get_tree().current_scene != null and get_tree().current_scene.name == "TitleScreen"
	if _pack_buttons.empty():
		var packs_parent = abyssal_terrors_dlc_button.get_parent()
		var insert_index: int = abyssal_terrors_dlc_button.get_index() + 1
		for pack_id in Packs.available_packs:
			var pack_button: = CheckButton.new()
			pack_button.text = str(Packs.available_packs[pack_id].display_name) + " pack"
			pack_button.connect("toggled", self, "_on_pack_toggled", [pack_id])
			packs_parent.add_child(pack_button)
			packs_parent.move_child(pack_button, insert_index)
			insert_index += 1
			_pack_buttons[pack_id] = pack_button
	for pack_id in _pack_buttons:
		_pack_buttons[pack_id].set_pressed_no_signal(Packs.is_pack_enabled(pack_id))
		_pack_buttons[pack_id].disabled = not packs_allowed


func _on_pack_toggled(button_pressed: bool, pack_id: String) -> void :
	if button_pressed:
		Packs.activate_pack(pack_id)
	else:
		Packs.deactivate_pack(pack_id)


func _on_AbyssalTerrorsDLCButton_toggled(button_pressed):
	if button_pressed:
		ProgressData.activate_dlc("abyssal_terrors")
	else:
		ProgressData.deactivate_dlc("abyssal_terrors")


func _on_GreenSkinsButton_toggled(button_pressed: bool) -> void :
	var skin_set: SkinSetData = SkinManager.get_skin_set("green")
	if button_pressed:
		SkinManager.activate_skins(skin_set)
	else:
		SkinManager.deactivate_skins(skin_set)


func _on_NoItemAppearanceButton_toggled(button_pressed):
	ProgressData.settings.no_item_appearance = button_pressed


func _on_ColorPositiveText_color_changed(color: Color):
	ProgressData.settings.color_positive = color.to_html()
	UIService._on_update_color_positive()


func _on_ColorNegativeText_color_changed(color: Color):
	ProgressData.settings.color_negative = color.to_html()
	UIService._on_update_color_negative()


func _on_button_reset_accessibility_pressed() -> void :
	ProgressData.settings.merge(ProgressData.init_accessibilities_options(), true)
	init_values_from_progress_data()


func _on_button_reset_gameplay_pressed():
	ProgressData.settings.merge(ProgressData.init_gameplay_options(), true)
	init_values_from_progress_data()


func _on_EffectsIconsInDescriptionButton_toggled(button_pressed):
	ProgressData.settings.effects_icons_in_description = button_pressed
	UIService.emit_signal("icon_effect_in_description_changed", button_pressed)


func _on_Color_tiers0_color_changed(color):
	ProgressData.settings.tier_0_color = color.to_html()
	ProgressData.settings.tier_0_color_dark = lerp(color, Color(0, 0, 0, 1), 0.9).to_html()


func _on_Color_tiers1_color_changed(color):
	ProgressData.settings.tier_1_color = color.to_html()
	ProgressData.settings.tier_1_color_dark = lerp(color, Color(0, 0, 0, 1), 0.9).to_html()


func _on_Color_tiers2_color_changed(color):
	ProgressData.settings.tier_2_color = color.to_html()
	ProgressData.settings.tier_2_color_dark = lerp(color, Color(0, 0, 0, 1), 0.9).to_html()


func _on_Color_tiers3_color_changed(color):
	ProgressData.settings.tier_3_color = color.to_html()
	ProgressData.settings.tier_3_color_dark = lerp(color, Color(0, 0, 0, 1), 0.9).to_html()


func _on_Color_tiers4_color_changed(color):
	ProgressData.settings.tier_4_color = color.to_html()
	ProgressData.settings.tier_4_color_dark = lerp(color, Color(0, 0, 0, 1), 0.9).to_html()


func _on_Color_tiers5_color_changed(color):
	ProgressData.settings.tier_5_color = color.to_html()
	ProgressData.settings.tier_5_color_dark = lerp(color, Color(0, 0, 0, 1), 0.9).to_html()


func _on_MainScreenArt_item_selected(index):
	var id_keyart: int = main_screen_keyart.get_item_id(index)
	ProgressData.settings.main_screen_keyart = id_keyart
	ProgressData.emit_signal("change_keyart")


func _on_ColorPositiveText_color_reset():
	ProgressData.settings.color_positive = Color.green.to_html()
	color_positive._init_color(Color(ProgressData.settings.color_positive))

func _on_ColorNegativeText_color_reset():
	ProgressData.settings.color_negative = Color.red.to_html()
	color_negative._init_color(Color(ProgressData.settings.color_negative))

func _on_Color_tier0_color_reset():
	ProgressData.settings.tier_0_color = ProgressData.DEFAULT_TIER_COLOR_0.to_html()
	color_tier0._init_color(Color(ProgressData.settings.tier_0_color))

func _on_Color_tier1_color_reset():
	ProgressData.settings.tier_1_color = ProgressData.DEFAULT_TIER_COLOR_1.to_html()
	color_tier1._init_color(Color(ProgressData.settings.tier_1_color))

func _on_Color_tier2_color_reset():
	ProgressData.settings.tier_2_color = ProgressData.DEFAULT_TIER_COLOR_2.to_html()
	color_tier2._init_color(Color(ProgressData.settings.tier_2_color))

func _on_Color_tier3_color_reset():
	ProgressData.settings.tier_3_color = ProgressData.DEFAULT_TIER_COLOR_3.to_html()
	color_tier3._init_color(Color(ProgressData.settings.tier_3_color))

func _on_Color_tier4_color_reset():
	ProgressData.settings.tier_4_color = ProgressData.DEFAULT_TIER_COLOR_4.to_html()
	color_tier4._init_color(Color(ProgressData.settings.tier_4_color))

func _on_Color_tier5_color_reset():
	ProgressData.settings.tier_5_color = ProgressData.DEFAULT_TIER_COLOR_5.to_html()
	color_tier5._init_color(Color(ProgressData.settings.tier_5_color))


func _on_NoHoldingButton_toggled(button_pressed):
	ProgressData.settings.holding_button = button_pressed

func _on_CompletedChallengeCheckButton_pressed():
	for challenge in ChallengeService.challenges:
		if ChallengeService.is_challenge_completed(challenge.my_id) and (challenge.reward_type == RewardType.ITEM or challenge.reward_type == RewardType.WEAPON):
			ChallengeService.unlock_reward(challenge)
		if not ChallengeService.is_challenge_completed(challenge.my_id):
			if challenge.reward_type == RewardType.ITEM and ProgressData.items_unlocked.has((challenge.reward as ItemData).my_id):
				ProgressData.items_unlocked.erase((challenge.reward as ItemData).my_id)
			if challenge.reward_type == RewardType.WEAPON and ProgressData.weapons_unlocked.has((challenge.reward as WeaponData).weapon_id):
				ProgressData.weapons_unlocked.erase((challenge.reward as WeaponData).weapon_id)

	ProgressData.save()


func _on_ConstantProjectileButton_item_selected(index):
	ProgressData.settings.constant_projectile_option = index
	RunData.constant_projectile = index

func _on_OnLostFocusButton_item_selected(index):
	if index > 0:
		ProgressData.settings.pause_on_focus_lost = true
	else:
		ProgressData.settings.pause_on_focus_lost = false
	ProgressData.settings.on_lost_focus = index
