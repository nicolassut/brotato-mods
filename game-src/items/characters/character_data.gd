class_name CharacterData
extends ItemData

export (Array, String) var wanted_tags
export (Array, String) var banned_item_groups
export (Array, String) var banned_items
export (Array, String) var banned_upgrades
export (Array, Resource) var starting_weapons
export (Array, Resource) var starting_items
# tint applied to the character's legs so they match a recoloured body (Color(1,1,1) = no change)
export (Color) var legs_modulate = Color( 1, 1, 1 )


func get_category() -> int:
	return Category.CHARACTER
