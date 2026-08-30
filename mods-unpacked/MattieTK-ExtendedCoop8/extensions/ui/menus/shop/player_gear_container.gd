extends "res://ui/menus/shop/player_gear_container.gd"

# _default_weapon_columns is indexed by player_count - 1; extend for 5-8 players.


func _ready() -> void :
	while _default_weapon_columns.size() < 8:
		_default_weapon_columns.push_back(6)
