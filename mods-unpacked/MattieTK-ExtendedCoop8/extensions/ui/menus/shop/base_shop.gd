extends "res://ui/menus/shop/base_shop.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")

# The shop runs unguarded with the full player count: every per-player lookup
# goes through virtual accessors that the coop_shop extension makes 8-slot
# aware, so only the member arrays need padding.


func _init() -> void :
	C8.pad(_shop_items, "array")
	C8.pad(_focused_shop_item, "null")
	C8.pad(_latest_focused_shop_item, "null")
	C8.pad(_player_pressed_go_button, "bool")
	C8.pad(_has_bonus_free_reroll, "bool")
	C8.pad(_reroll_price, "int")
	C8.pad(_initial_free_rerolls, "int")
	C8.pad(_free_rerolls, "int")
	C8.pad(_item_steals, "int")
	C8.pad(_reroll_count, "int")
	C8.pad(_paid_reroll_count, "int")
	C8.pad(_reroll_discount, "int")
