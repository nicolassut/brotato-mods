class_name UpgradeData
extends ItemData

export (String) var upgrade_id = ""
var upgrade_id_hash: int = Keys.empty_hash

func duplicate(subresources: = false) -> Resource:
	var duplication = .duplicate(subresources)
	duplication.upgrade_id_hash = upgrade_id_hash
	return duplication

func _generate_hashes() -> void :
	._generate_hashes()
	upgrade_id_hash = Keys.generate_hash(upgrade_id)


func get_name_text() -> String:
	var tier_number = ItemService.get_tier_number(tier)
	return tr(name) + (" " + tier_number if tier_number != "" else "")
