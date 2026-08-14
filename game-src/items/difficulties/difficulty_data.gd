class_name DifficultyData
extends ItemParentData


func get_name_text(_player_index: int = - 1) -> String:
	return Text.text(tr(name), [str(value)])
