class_name WeaponData
extends ItemParentData

enum Type { MELEE, RANGED }

export(String) var weapon_id = ""
onready var weapon_id_hash = Keys.empty_hash
export(Type) var type := Type.MELEE
export(Array, Resource) var sets
export(PackedScene) var scene = null
export(Resource) var stats = null
export(Resource) var upgrades_into

var previous_upgrade : WeaponData

export(Array, String) var add_to_chars_as_starting = []

var dmg_dealt_last_wave := 0
var tracked_value := 0
var tracked_value_added_this_wave := 0

var _init_stats_args_data := WeaponServiceInitStatsArgs.new()


func _generate_hashes() -> void:
	._generate_hashes()
	weapon_id_hash = Keys.generate_hash(weapon_id)


func get_category() -> int:
	return Category.WEAPON



func get_weapon_id_hash():
	if weapon_id_hash == null:
		weapon_id_hash = Keys.generate_hash(weapon_id)
	return weapon_id_hash

func duplicate(subresources := false) -> Resource:
	var duplication = .duplicate(subresources)
	duplication.weapon_id_hash = weapon_id_hash
	return duplication

func get_weapon_stats_text(player_index: int, hide_if_non_unlock_in_codex : bool = false) -> String:
	if _is_locked_in_codex() and hide_if_non_unlock_in_codex : return ""
	_init_stats_args_data.sets = sets
	_init_stats_args_data.effects = effects
	var current_stats
	if type == Type.MELEE:
		current_stats = WeaponService.init_melee_stats(stats, player_index, _init_stats_args_data)
	else:
		current_stats = WeaponService.init_ranged_stats(stats, player_index, false, _init_stats_args_data)

	return current_stats.get_text(stats, player_index, effects)


func get_effects_text(player_index: int, with_tracking_text: bool = true) -> String:
	var text = .get_effects_text(player_index)

	if with_tracking_text and tracking_text != "":
		text += _get_tracking_text(player_index)

	return text

func _get_tracking_text(player_index: int) -> String:
	# Gourmet DLC - a food that credits a weapon (Frying Pan -> Fried Egg's permanent Luck)
	# accumulates through RunData.add_tracked_value under the UNTIERED weapon_id, because the
	# food's tracking_item_id cannot know which tier is equipped. WeaponData's own
	# tracked_value is fed ONLY by the three on_tracked_value_updated emitters in weapon.gd,
	# so without this bridge the Frying Pan card sat at "Luck gained: 0" for the whole run
	# while the real total piled up in a RunData bucket nothing ever read. Added, not
	# replaced, so vanilla weapons that do use tracked_value are unaffected.
	var displayed_value: int = tracked_value
	if player_index != RunData.DUMMY_PLAYER_INDEX and player_index < RunData.tracked_item_effects.size():
		var weapon_id_hash: int = Keys.generate_hash(weapon_id)
		if RunData.tracked_item_effects[player_index].has(weapon_id_hash):
			displayed_value += int(RunData.tracked_item_effects[player_index][weapon_id_hash])
	return "\n[color=#" + Utils.SECONDARY_FONT_COLOR.to_html() + "]" + Text.text(tracking_text.to_upper(), [str(displayed_value)]) + "[/color]"

func on_tracked_value_updated(value := 1) -> void:
	tracked_value += value
	tracked_value_added_this_wave += value

func on_tracked_value_set(value := 1) -> void:
	tracked_value = value
	tracked_value_added_this_wave = value


func get_name_text() -> String:
	var tier_number = ItemService.get_tier_number(tier, true)
	return tr(name) + (" " + tier_number if tier_number != "" else "")


func _is_locked_in_codex() -> bool:
	return ._is_locked_in_codex()


func _is_silhouette_in_codex() -> bool:
	var bought : int = _get_bought_times()
	if bought >= 1 : return false

	var prev_weapon : WeaponData = self
	while is_instance_valid(prev_weapon.previous_upgrade) :
		bought += prev_weapon.previous_upgrade._get_bought_times()
		prev_weapon = prev_weapon.previous_upgrade
	if bought >= 1 : return false

	var next_weapon : WeaponData = self
	while is_instance_valid(next_weapon.upgrades_into) :
		bought += next_weapon.upgrades_into._get_bought_times()
		next_weapon = next_weapon.upgrades_into
	if bought >= 1 : return false

	return true


func serialize() -> Dictionary:

	var serialized = .serialize()

	serialized.weapon_id = weapon_id
	serialized.type = str(type)
	serialized.stats = stats.serialize()
	serialized.dmg_dealt_last_wave = str(dmg_dealt_last_wave)
	serialized.tracked_value = str(tracked_value)
	serialized.tracked_value_added_this_wave = str(tracked_value_added_this_wave)
	serialized.add_to_chars_as_starting = add_to_chars_as_starting

	var serialized_sets = []

	for set in sets:
		serialized_sets.push_back(set.serialize())

	serialized.sets = serialized_sets

	return serialized


func deserialize_and_merge(serialized: Dictionary) -> void:
	.deserialize_and_merge(serialized)

	weapon_id = serialized.weapon_id
	weapon_id_hash = Keys.generate_hash(weapon_id)
	type = serialized.type as int
	dmg_dealt_last_wave = serialized.dmg_dealt_last_wave as int
	tracked_value = serialized.tracked_value as int
	tracked_value_added_this_wave = serialized.tracked_value_added_this_wave as int if "tracked_value_added_this_wave" in serialized else 0
	add_to_chars_as_starting = serialized.add_to_chars_as_starting if "add_to_chars_as_starting" in serialized else []

	var deserialized_sets = []

	for serialized_set in serialized.sets:
		var set = ItemService.get_element_safe(ItemService.sets, serialized_set.my_id)
		if set != null:
			set = set.duplicate()
			set.deserialize_and_merge(serialized_set)
			deserialized_sets.push_back(set)

	sets = deserialized_sets

	stats = serialized.stats
	var deserialized_stats = WeaponStats.new()

	if serialized.stats.type == "ranged":
		deserialized_stats = RangedWeaponStats.new()
	elif serialized.stats.type == "melee":
		deserialized_stats = MeleeWeaponStats.new()

	deserialized_stats.deserialize_and_merge(serialized.stats)
	stats = deserialized_stats
