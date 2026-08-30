extends "res://global/stats_manager.gd"


func _init() -> void :
	while _structure_queues.size() < 8:
		_structure_queues.push_back({})
	while _pet_queues.size() < 8:
		_pet_queues.push_back({})
