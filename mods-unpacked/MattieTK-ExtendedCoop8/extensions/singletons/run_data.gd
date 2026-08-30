extends "res://singletons/run_data.gd"

const C8 = preload("res://mods-unpacked/MattieTK-ExtendedCoop8/c8.gd")

# Menu guard: while > 0, get_player_count() reports at most 4 so that vanilla
# _ready code with hardcoded 4-slot local arrays (selection screens) can run
# safely; our extensions then finish the job for players 5-8 and release the
# guard in the same frame. Balanced by construction (see base_selection ext).
var c8_menu_guard := 0


func get_player_count() -> int:
	var count = .get_player_count()
	if c8_menu_guard > 0 and count > 4:
		return 4
	return count


func c8_true_player_count() -> int:
	return .get_player_count()


func c8_guard_inc() -> void :
	c8_menu_guard += 1


func c8_guard_dec() -> void :
	c8_menu_guard = int(max(0, c8_menu_guard - 1))


func _ready() -> void :
	c8_pad_arrays()


func c8_pad_arrays() -> void :
	while _players_die_args.size() < C8.MAX_PLAYERS:
		_players_die_args.push_back(Utils.default_die_args)
	C8.pad(remove_speed_effect_cache, "dict")
	C8.pad(items_nb_cache, "dict")
	C8.pad(different_items_nb_cache, "dict")
	C8.pad(duplicate_items_cache, "null")
	C8.pad(max_consumable_stats_gained_this_wave, "array")
	C8.pad(tracked_item_effects, "dict")
	C8.pad(_are_player_stats_dirty, "bool")
	C8.pad(current_charmed_enemies, "int")
	C8.pad(steps_taken_this_wave, "int")
	C8.pad(locked_shop_items, "array")


func _reset_per_wave_properties() -> void :
	._reset_per_wave_properties()
	c8_pad_arrays()


func reset(restart: bool = false) -> void :
	.reset(restart)
	c8_pad_arrays()


func reset_run_caches() -> void :
	.reset_run_caches()
	c8_pad_arrays()


func resume_from_state(state) -> void :
	.resume_from_state(state)
	c8_pad_arrays()
