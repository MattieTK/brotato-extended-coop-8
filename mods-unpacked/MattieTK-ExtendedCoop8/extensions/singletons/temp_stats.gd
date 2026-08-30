extends "res://singletons/temp_stats.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")


func _ready() -> void :
	while player_stats.size() < C8.MAX_PLAYERS:
		player_stats.push_back(init_stats())
	C8.pad(are_player_stats_dirty, "bool")
