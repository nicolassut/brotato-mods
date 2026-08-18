class_name ItemServiceGetShopItemsArgs
extends Reference

var count: int
var prev_items: = []
var locked_items: = []
var player_index: = 0
var increase_tier: = 0


var owned_and_shop_items: = [] setget _set_owned_and_shop_items, _get_owned_and_shop_items
func _get_owned_and_shop_items() -> Array:
	return owned_and_shop_items
func _set_owned_and_shop_items(_v: Array) -> void :
	printerr("owned_and_shop_items is readonly")

func _init(shop_items_by_player: Array, p_player_index: int):
	player_index = p_player_index

	count = ItemService.NB_SHOP_ITEMS
	owned_and_shop_items = RunData.get_player_items(p_player_index)
	for shop_item in shop_items_by_player[p_player_index]:
		if shop_item[0] is ItemData:
			owned_and_shop_items.push_back(shop_item[0])
