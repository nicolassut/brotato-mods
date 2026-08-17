class_name MainMenu
extends Control

signal options_button_pressed
signal credits_button_pressed
signal codex_button_pressed
signal profile_button_pressed
signal mods_button_pressed

onready var continue_button = $"%ContinueButton"
onready var profile_button = $"%ProfileButton"
onready var start_button = $"%StartButton"
onready var options_button = $"%OptionsButton"
onready var codex_button = $"%CodexButton"
onready var mods_button = $"%ModsButton"
onready var quit_button = $"%QuitButton"


onready var more_games_button = $"%MoreGamesButton"
onready var newsletter_button = $"%NewsletterButton"
onready var community_button = $"%CommunityButton"
onready var credits_button = $"%CreditsButton"

onready var error_label = $"%ErrorLabel"
onready var version_label = $"%VersionLabel"
onready var xbox_gamertag = $"%XboxGamerTag"
onready var logo_container = $"%LogoContainer"

onready var left_container = $"MarginContainer/VBoxContainer/HBoxContainer/ButtonsLeft"
onready var right_container = $"MarginContainer/VBoxContainer/HBoxContainer/ButtonsRight"

func testActivity(act: String) -> void :
	
	if act != "":
		ProgressData.reset_activity()
		if ProgressData.saved_run_state.has_run_state:
			
			_on_ContinueButton_pressed()
		else:
			
			_on_StartButton_pressed()
	else:
		ProgressData.reset_activity()

func _process(_delta: float) -> void :
	var act = ProgressData.get_pending_dlc_change()
	if act == true:
		print("DLC change, reinit menu")
		ProgressData.read_all_dlcs()

		if ProgressData.is_dlc_available("abyssal_terrors"):
			ProgressData.force_activate_dlc("abyssal_terrors")

		if ProgressData.is_dlc_available_and_active("abyssal_terrors"):
			start_button.grab_focus()

		if ProgressData.is_dlc_available("abyssal_terrors"):
			more_games_button.hide()
		else:
			more_games_button.show()

		var path_left_right = ""

		if Utils.on_gdk_desktop:
			if ProgressData.is_dlc_available_and_active("abyssal_terrors"):
				setup_dlc_desktop_menu()
				path_left_right = codex_button.get_path()
		else:
			codex_button.focus_neighbour_left = path_left_right
			codex_button.focus_neighbour_right = path_left_right
			credits_button.focus_neighbour_left = path_left_right
			credits_button.focus_neighbour_right = path_left_right

		continue_button.focus_neighbour_left = path_left_right
		continue_button.focus_neighbour_right = path_left_right
		start_button.focus_neighbour_left = path_left_right
		start_button.focus_neighbour_right = path_left_right
		options_button.focus_neighbour_left = path_left_right
		options_button.focus_neighbour_right = path_left_right
		quit_button.focus_neighbour_left = path_left_right
		quit_button.focus_neighbour_right = path_left_right

		var menu_gameplay_options = get_parent().find_node("MenuGameplayOptions")
		if menu_gameplay_options != null:
			menu_gameplay_options.refresh_dlc_button()

		start_button.grab_focus()

		if not ProgressData.is_dlc_available("abyssal_terrors"):
			print("DLC is not available anymore, kill any saved run")
			continue_button.hide()
			continue_button.disable()
			ProgressData.saved_run_state.has_run_state = false
			ProgressData.saved_run_state = ProgressData._get_empty_run_state()
		else:
			if ProgressData.saved_run_state.has_run_state and ProgressData.check_dlc_valid_for_saved_run_state() and not ProgressData.saved_run_state.get("is_streamplay_run", false):
				continue_button.show()
				continue_button.activate()

		setup_menu()


func refresh_menu() -> void :
	var path_left_right = ""

	if ProgressData.is_dlc_available("abyssal_terrors"):
		more_games_button.hide()
	else:
		more_games_button.show()

	if Utils.is_on_console():
		
		newsletter_button.hide()
		community_button.hide()
		mods_button.hide()

		if ProgressData.is_dlc_available_and_active("abyssal_terrors"):
			if Utils.on_gdk_desktop:
				setup_dlc_desktop_menu()
				path_left_right = codex_button.get_path()
			else:
				setup_console_with_dlc_menu()
				path_left_right = more_games_button.get_path()
		else:
			setup_console_no_dlc_menu()

		continue_button.focus_neighbour_left = path_left_right
		continue_button.focus_neighbour_right = path_left_right
		start_button.focus_neighbour_left = path_left_right
		start_button.focus_neighbour_right = path_left_right
		options_button.focus_neighbour_left = path_left_right
		options_button.focus_neighbour_right = path_left_right
		quit_button.focus_neighbour_left = path_left_right
		quit_button.focus_neighbour_right = path_left_right

func setup_menu() -> void :
	refresh_menu()

	if ProgressData.saved_run_state.has_run_state and not ProgressData.check_dlc_valid_for_saved_run_state():
		
		ProgressData.saved_run_state.has_run_state = false
		ProgressData.saved_run_state = ProgressData._get_empty_run_state()
		print("Killed run because it contains DLC maps or characters")


	if ProgressData.saved_run_state.has_run_state and ProgressData.check_dlc_valid_for_saved_run_state() and not ProgressData.saved_run_state.get("is_streamplay_run", false):
		
		continue_button.grab_focus()

		
		start_button.focus_neighbour_top = ""

		if Utils.is_on_console():
			
			if Utils.on_gdk_desktop:
				
				credits_button.focus_neighbour_bottom = ""
				quit_button.focus_neighbour_bottom = continue_button.get_path()
				continue_button.focus_neighbour_top = quit_button.get_path()
			else:
				
				credits_button.focus_neighbour_bottom = continue_button.get_path()
				continue_button.focus_neighbour_top = credits_button.get_path()

	else:
		
		start_button.grab_focus()

		if Utils.is_on_console():
			
			if Utils.on_gdk_desktop:
				
				credits_button.focus_neighbour_bottom = ""
				quit_button.focus_neighbour_bottom = start_button.get_path()
				start_button.focus_neighbour_top = quit_button.get_path()
			else:
				
				start_button.focus_neighbour_top = credits_button.get_path()
				credits_button.focus_neighbour_bottom = start_button.get_path()


func setup_console_no_dlc_menu() -> void :
	setup_console_common()

	credits_button.focus_neighbour_left = more_games_button.get_path()
	credits_button.focus_neighbour_right = more_games_button.get_path()

	codex_button.focus_neighbour_left = more_games_button.get_path()
	codex_button.focus_neighbour_right = more_games_button.get_path()


func setup_console_with_dlc_menu() -> void :
	setup_console_common()

	credits_button.focus_neighbour_left = ""
	credits_button.focus_neighbour_right = ""

	codex_button.focus_neighbour_left = ""
	codex_button.focus_neighbour_right = ""


func setup_console_common() -> void :
	var moved: = false

	
	if credits_button.get_parent() == right_container:
		right_container.remove_child(credits_button)
		left_container.add_child(credits_button)
		credits_button.size_flags_horizontal = 0
		moved = true

	
	if codex_button.get_parent() == right_container:
		right_container.remove_child(codex_button)
		left_container.add_child(codex_button)
		codex_button.size_flags_horizontal = 0
		moved = true

	if moved:
		
		left_container.move_child(credits_button, 6)
		left_container.move_child(codex_button, 4)


func setup_dlc_desktop_menu() -> void :
	
	if credits_button.get_parent() == left_container:
		left_container.remove_child(credits_button)
		right_container.add_child(credits_button)
		credits_button.size_flags_horizontal = 8

	
	if codex_button.get_parent() == left_container:
		left_container.remove_child(codex_button)
		right_container.add_child(codex_button)
		codex_button.size_flags_horizontal = 8

	credits_button.focus_neighbour_left = quit_button.get_path()
	credits_button.focus_neighbour_right = quit_button.get_path()

	codex_button.focus_neighbour_left = options_button.get_path()
	codex_button.focus_neighbour_right = options_button.get_path()

	
	right_container.move_child(credits_button, right_container.get_child_count() - 1)


func init() -> void :
	if Streamplay.playing():
		Streamplay.stop()
		RunData.reset()

	more_games_button.text = "MENU_DLC_AVAILABLE_STANDARD"
	more_games_button.add_color_override("font_color", Utils.DLC_BUTTON_TEXT_COLOR)
	more_games_button.theme = load("res://resources/themes/special_button_theme.tres")
	for dlc in ProgressData.available_dlcs:
		if dlc.my_id == "abyssal_terrors":
			more_games_button.text = "MENU_MORE_GAMES"
			more_games_button.remove_color_override("font_color")
			more_games_button.theme = null
			break

	reset_resume_state()
	setup_menu()


	
	if Utils.is_on_console():
		var newVersion = ProgressData.VERSION

		if Utils.on_nintendo_nx_or_ounce:
			newVersion = ProgressData.VERSION_SWITCH

		var newPos = newVersion.find("-")
		if newPos >= 0:
			newVersion = newVersion.substr(0, newPos)
		version_label.text = "version " + newVersion

		if Utils.on_gdk:
			xbox_gamertag.text = OS_Seaven.get_gamertag()
			xbox_gamertag.show()
		else:
			xbox_gamertag.hide()
	else:
		version_label.text = "version " + ProgressData.VERSION

	if not Utils.is_on_console() and ProgressData.load_status != LoadStatus.SAVE_OK:

		var status_text = "(!) "

		if ProgressData.load_status == LoadStatus.CORRUPTED_SAVE:
			status_text += tr("CORRUPTED_SAVE")
		elif ProgressData.load_status == LoadStatus.CORRUPTED_SAVE_LATEST:
			status_text += tr("CORRUPTED_SAVE_LATEST")
		elif ProgressData.load_status == LoadStatus.CORRUPTED_ALL_SAVES_STEAM:
			status_text += tr("CORRUPTED_ALL_SAVES_STEAM")
		elif ProgressData.load_status == LoadStatus.CORRUPTED_ALL_SAVES_NO_STEAM:
			status_text += tr("CORRUPTED_ALL_SAVES_NO_STEAM")
		elif ProgressData.load_status == LoadStatus.CORRUPTED_ALL_SAVES_EPIC:
			status_text += tr("CORRUPTED_ALL_SAVES_EPIC")
		elif ProgressData.load_status == LoadStatus.CORRUPTED_ALL_SAVES_NO_EPIC:
			status_text += tr("CORRUPTED_ALL_SAVES_NO_EPIC")
		elif ProgressData.load_status == LoadStatus.CORRUPTED_RUN_SAVE:
			status_text += tr("CORRUPTED_RUN_SAVE")

		error_label.text = status_text
		error_label.show()
	elif not Utils.is_on_console() and not CrashReporter.previous_crash_message.empty():
		var error_text = "(!) "
		if CrashReporter.previous_crashed_mod.empty():
			error_text += "%s %s" % [
				tr("CRASH_RECOVERY_MESSAGE_GENERAL"), 
				tr("CRASH_RECOVERY_MESSAGE_MODS_DISABLED")
			]
		else:
			error_text += "%s %s" % [
				tr("CRASH_RECOVERY_MESSAGE_MOD").replace("{0}", CrashReporter.previous_crashed_mod), 
				tr("CRASH_RECOVERY_MESSAGE_MODS_DISABLED")
			]
		error_label.text = error_text
		error_label.show()
	else:
		error_label.hide()

	var act = ProgressData.get_pending_activity()
	testActivity(act)


func reload_logo(screen: TitleScreenBackgroundData) -> void :
	for child in logo_container.get_children():
		child.queue_free()

	var instance = screen.logo_scene.instance()
	logo_container.add_child(instance)



func _on_StartButton_pressed() -> void :
	MusicManager.tween( - 5)
	ProgressData.start_activity()
	var _error = get_tree().change_scene(MenuData.character_selection_scene)


func _on_OptionsButton_pressed() -> void :
	emit_signal("options_button_pressed")


func _on_CommunityButton_pressed() -> void :
	var _error = OS.shell_open(MenuData.community_url)


func _on_QuitButton_pressed() -> void :
	if not Utils.is_on_console() or Utils.on_gdk_desktop:
		get_tree().notification(MainLoop.NOTIFICATION_WM_QUIT_REQUEST)


func _on_NewsletterButton_pressed() -> void :
	var _error = OS.shell_open(MenuData.newsletter_url)


func _on_MoreGamesButton_pressed() -> void :
	if Utils.is_on_console():
		ProgressData.show_store_dlc1()
	else:
		if more_games_button.text == "MENU_MORE_GAMES":
			Platform.open_store_page(MenuData.more_games_url)

		else:
			Platform.open_store_page(MenuData.dlc_url)


func _on_CreditsButton_pressed() -> void :
	emit_signal("credits_button_pressed")


func _on_CodexButton_pressed() -> void :
	emit_signal("codex_button_pressed")


func _on_ContinueButton_pressed() -> void :
	if ProgressData.saved_run_state.has_run_state and ProgressData.saved_run_state.get("is_streamplay_run", false):
		return
	if not ProgressData.saved_run_state.has_run_state or not ProgressData.check_dlc_valid_for_saved_run_state():
		return

	if not ChallengeService.is_challenge_completed(ChallengeService.chal_hourglass_hash) and ProgressData.data.has("chal_hourglass_quit_wave") and ProgressData.data["chal_hourglass_quit_wave"]:
		ChallengeService.complete_challenge(ChallengeService.chal_hourglass_hash)
	ProgressData.data["chal_hourglass_quit_wave"] = false

	ProgressData.start_activity()

	RunData.continue_current_run_in_shop()

	var scene: = "res://ui/menus/shop/coop_resume.tscn" if RunData.play_mode == RunData.PlayMode.COOP else "res://ui/menus/shop/shop.tscn"
	var _error = get_tree().change_scene(scene)


func _on_ModsButton_pressed() -> void :
	emit_signal("mods_button_pressed")


static func reset_resume_state() -> void :
	
	CoopService.clear()
	RunData.cancel_resume()


func _on_ProfileButton_pressed():
	emit_signal("profile_button_pressed")
