class_name Consumable
extends Item

var consumable_data: Resource = null


func _ready() -> void :
	._ready()


func pickup(player_index: int) -> void :
	.pickup(player_index)
	SoundManager.play(Utils.get_rand_element(consumable_data.pickup_sounds))


func has_healing_effect() -> bool:
	for effect in consumable_data.effects:
		if effect is ConsumableHealingEffect:
			return true
	return false


func has_damage_effect() -> bool:
	for effect in consumable_data.effects:
		if effect is ConsumableDamageEffect:
			return true
	return false
