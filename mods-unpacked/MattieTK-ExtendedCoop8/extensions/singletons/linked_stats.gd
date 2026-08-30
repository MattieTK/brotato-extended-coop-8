extends "res://singletons/linked_stats.gd"

const C8L = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")


func _ready() -> void :
	C8L.pad(update_for_player_every_half_sec, "bool")
