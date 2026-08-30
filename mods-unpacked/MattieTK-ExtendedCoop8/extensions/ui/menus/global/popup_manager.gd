extends "res://ui/menus/global/popup_manager.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")


func _init() -> void :
	C8.pad(_item_popups, "null")
	C8.pad(_elements_hovered, "null")
	C8.pad(_elements_focused, "null")
	C8.pad(_elements_pressed, "null")
	C8.pad(_stat_popups, "null")
