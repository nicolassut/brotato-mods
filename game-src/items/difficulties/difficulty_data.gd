class_name DifficultyData
extends ItemParentData


func get_name_text() -> String:
	return Text.text(tr(name), [str(value)])
