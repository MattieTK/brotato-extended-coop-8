extends "res://ui/menus/ingame/coop_player_selector.gd"


func _ready() -> void :
	var player_count = RunData.get_player_count()
	if player_count <= 4:
		return
	var prefab = load("res://ui/menus/ingame/coop_player_label.tscn")
	for i in range(4, player_count):
		var label = prefab.instance()
		label.player_index = i
		_headings.add_child(label)
