extends "res://singletons/utils.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")


func _ready() -> void :
	C8.pad(last_elt_selected, "null")
	C8.pad(_stat_caches, "dict")
	C8.pad(_manual_aim_cache, "null")


func reset_last_elt_selected() -> void :
	last_elt_selected = [null, null, null, null, null, null, null, null]


func reset_stat_caches() -> void :
	_stat_caches = [{}, {}, {}, {}, {}, {}, {}, {}]


func is_manual_aim(player_index: int) -> bool:
	# Vanilla resets this cache to a 4-slot array every frame; re-pad on read.
	if _manual_aim_cache.size() <= player_index:
		C8.pad(_manual_aim_cache, "null")
	return .is_manual_aim(player_index)


func get_focus_emulator(player_index: int, root = get_scene_node()) -> FocusEmulator:
	if root == null:
		return null
	return .get_focus_emulator(player_index, root)


func focus_player_control(control: Control, player_index: int, focus_emulator: FocusEmulator = null) -> void :
	# Null-safe: screens like difficulty selection have no emulators for players
	# 5-8 on purpose (only player 1 chooses there).
	if focus_emulator == null:
		focus_emulator = get_focus_emulator(player_index)
	if focus_emulator == null and RunData.is_coop_run:
		return
	.focus_player_control(control, player_index, focus_emulator)
