extends "res://singletons/debug_service.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")


func _ready() -> void :
	C8.pad(debug_items_added, "bool")
	C8.pad(debug_weapons_added, "bool")
	C8.pad(starting_weapons_removed, "bool")


func log_run_info(upgrades: Array = [[], [], [], []], consumables: Array = [[], [], [], []]) -> void :
	C8.pad(upgrades, "array")
	C8.pad(consumables, "array")
	.log_run_info(upgrades, consumables)
