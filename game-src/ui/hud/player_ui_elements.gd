class_name PlayerUIElements
extends Reference


var player_index: int
var player_life_bar: UIProgressBar
var player_life_bar_container: Node2D
var hud_container: Container
var life_bar: UIProgressBar
var life_label: Label
var hit_protection: UIHitProtection
var xp_bar: UIProgressBar
var level_label: Label
var gold: UIGold


var hud_visible: = false setget _set_hud_visible
func _set_hud_visible(value: bool) -> void :
	hud_visible = value
	life_bar.visible = value
	xp_bar.visible = value
	gold.visible = value


func set_hud_position(position_index: int) -> void :
	var left = position_index == 0 or position_index == 2
	var top = position_index <= 1
	hud_container.size_flags_horizontal = 0 if left else Control.SIZE_SHRINK_END
	hud_container.size_flags_vertical = 0 if top else Control.SIZE_SHRINK_END
	hud_container.move_child(gold, xp_bar.get_index() + 1 if top else 0)
	gold.alignment = BoxContainer.ALIGN_BEGIN if left else BoxContainer.ALIGN_END


func update_hud(player: Player) -> void :
	if RunData.is_coop_run:
		
		life_bar.self_modulate.a = 0.75
		xp_bar.self_modulate.a = 0.75

		var player_color = CoopService.get_player_color(player_index)
		gold.gold_label.add_color_override("font_color", player_color)
		gold.icon.modulate = player_color

	life_bar.update_value(player.current_stats.health, player.max_stats.health)
	var die_in_one_hit = RunData.get_player_effect(Keys.die_in_one_hit_hash, player_index)
	if die_in_one_hit == 1:
		hide_life_label(player)
	else:
		update_life_label(player)
	var hit_protection_count = player._hit_protection
	update_hit_protection_count(player, hit_protection_count)
	xp_bar.update_value(int(RunData.get_player_xp(player_index)), int(RunData.get_next_level_xp_needed(player_index)))
	update_level_label()
	gold.update_value(RunData.get_player_gold(player_index))
	gold.update_debt(RunData.get_player_debt(player_index))  # Gourmet DLC - debt readout

func update_hit_protection_count(player: Player, hit_protection_count: int) -> void :
	hit_protection.hit_protection_label.text = str(hit_protection_count)
	if (hit_protection_count == 0):
		hit_protection.hide()
	elif (hit_protection_count > 0):
		hit_protection.show()

func hide_life_label(player: Player) -> void :
	life_label.hide()

func update_life_label(player: Player) -> void :
	life_label.text = str(max(player.current_stats.health, 0.0)) + " / " + str(player.max_stats.health)


func update_level_label() -> void :
	level_label.text = "LV." + str(RunData.get_player_level(player_index))
