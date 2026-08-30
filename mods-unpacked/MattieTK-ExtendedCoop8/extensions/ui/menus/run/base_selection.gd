extends "res://ui/menus/run/base_selection.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")

# While the selection screens run their vanilla _ready code (which contains
# local 4-slot arrays we cannot patch), RunData.get_player_count() is capped at
# 4 via a guard. A deferred finalize then redoes the count-dependent setup for
# the real player count and releases the guard — always in the same frame.

var _c8_guarding: = false
var _c8_saved_last_elt: = []


func _init() -> void :
	RunData.c8_guard_inc()
	_c8_guarding = true


func _enter_tree() -> void :
	C8.pad(displayed_elements, "array")
	C8.pad(_has_player_selected, "bool")
	C8.pad(_displayed_panel_data_element, "null")
	C8.pad(_latest_focused_element, "null")
	_c8_saved_last_elt = Utils.last_elt_selected.duplicate()


func _ready() -> void :
	call_deferred("_c8_finalize_menu")


func _exit_tree() -> void :
	_c8_release_guard()


func _c8_release_guard() -> void :
	if _c8_guarding:
		_c8_guarding = false
		RunData.c8_guard_dec()


func _c8_finalize_menu() -> void :
	_c8_release_guard()
	if not is_inside_tree():
		return
	var count = RunData.get_player_count()
	if not RunData.is_coop_run or count <= 4:
		_c8_after_finalize(count)
		return

	_set_base_ui_player_count(count, RunData.is_coop_run, false)

	# Focus for players 5-8 (vanilla only handled 1-4 while the guard was on).
	var inventories = _get_inventories()
	for player_index in range(4, count):
		var focused: = false
		var last_elt = _c8_saved_last_elt[player_index] if player_index < _c8_saved_last_elt.size() else null
		if last_elt != null:
			var element: = _find_inventory_element_by_id(last_elt.my_id_hash, player_index)
			if element != null:
				Utils.call_deferred("focus_player_control", element, player_index)
				focused = true
		if not focused and inventories.size() > 0:
			var inventory = inventories[player_index % inventories.size()]
			if inventory.get_child_count() > 0:
				Utils.call_deferred("focus_player_control", inventory.get_child(0), player_index)

	_c8_after_finalize(count)


func _c8_after_finalize(_count: int) -> void :
	# Hook for derived-screen extensions.
	pass


func _get_focus_emulator(player_index: int) -> FocusEmulator:
	return get_node_or_null("FocusEmulator%s" % (player_index + 1)) as FocusEmulator
