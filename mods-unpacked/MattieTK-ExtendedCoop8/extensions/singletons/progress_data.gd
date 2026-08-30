extends "res://singletons/progress_data.gd"

# Run-save handling for 8 players, via an inner loader subclass (extending the
# ProgressDataLoaderV3 script through the ModLoader breaks its construction, so
# ProgressData's loader-constructing methods are overridden instead):
# 1. serialize/deserialize_run_state size the per-player shop arrays from the
#    data instead of the hardcoded [[], [], [], []].
# 2. Runs with more than 4 players are stored in run_coop8_v3_<profile>.json;
#    the vanilla run file gets an empty state so the unmodded game never sees
#    (and can never crash on) an 8-player run. Progression saves are shared.


class C8Loader:
	extends ProgressDataLoaderV3

	func _init(save_dir: = "", current_profile_id: int = 0).(save_dir, current_profile_id) -> void :
		pass

	func c8_run_path() -> String:
		return run_save_path.replace("run_v3_", "run_coop8_v3_")

	func c8_tmp_run_path() -> String:
		return _tmp_run_save_path.replace("run_v3_", "run_coop8_v3_")

	func _c8_state_player_count(state) -> int:
		if state != null and state is Dictionary and state.get("has_run_state", false) and state.has("players_data"):
			return state.players_data.size()
		return 0

	func save() -> void :
		if _c8_state_player_count(run_state_deserialized) <= 4:
			.save()
			var dir: = Directory.new()
			if dir.file_exists(c8_run_path()):
				var _err = dir.remove(c8_run_path())
			return

		var save_object_without_run_state = get_save_object()
		save_object_without_run_state.erase("current_run_state")
		var string_profile_id = String(profile_id)
		save_content("save_v3_" + string_profile_id, save_path, _tmp_path, save_object_without_run_state)
		save_content("run_v3_" + string_profile_id, run_save_path, _tmp_run_save_path, {
			"current_run_state": {"has_run_state": false}
		})
		save_content("run_coop8_v3_" + string_profile_id, c8_run_path(), c8_tmp_run_path(), {
			"current_run_state": serialize_run_state(run_state_deserialized)
		})

	func load_run_save_file(path: = "") -> void :
		if path.empty():
			var file: = File.new()
			if file.file_exists(c8_run_path()):
				.load_run_save_file(c8_run_path())
				if _c8_state_player_count(run_state_deserialized) > 0:
					return
		.load_run_save_file(path)

	func deserialize_run_state(state: Dictionary) -> Dictionary:
		var result = state.duplicate()

		if not state.has_run_state:
			return result

		result.players_data = []
		for serialized_player_data in state.players_data:
			if serialized_player_data is String:
				result.has_run_state = false
				return result
			result.players_data.push_back(PlayerRunData.new().deserialize(serialized_player_data))

		for bg in ItemService.backgrounds:
			if bg.name.to_lower() == state.current_background:
				result.current_background = bg
				break

		result.challenges_completed_this_run = []
		state.challenges_completed_this_run = Utils.convert_to_hash_array(state.challenges_completed_this_run.duplicate())

		for challenge_id in state.challenges_completed_this_run:
			for chal_data in ChallengeService.challenges:
				if chal_data.my_id_hash == challenge_id:
					result.challenges_completed_this_run.push_back(chal_data)
					break

		var nb_players: int = int(max(4, state.players_data.size()))

		result.locked_shop_items = []
		for _i in nb_players:
			result.locked_shop_items.push_back([])
		for player_index in int(min(state.locked_shop_items.size(), nb_players)):
			for locked_item in state.locked_shop_items[player_index]:
				var item_data = ItemService.get_element_safe(ItemService.items, locked_item[0].my_id)
				var weapon_data = ItemService.get_element_safe(ItemService.weapons, locked_item[0].my_id)

				if item_data != null:
					item_data = item_data.duplicate()
					item_data.deserialize_and_merge(locked_item[0])
					result.locked_shop_items[player_index].push_back([item_data, locked_item[1]])

				if weapon_data != null:
					weapon_data = weapon_data.duplicate()
					weapon_data.deserialize_and_merge(locked_item[0])
					result.locked_shop_items[player_index].push_back([weapon_data, locked_item[1]])

		result.shop_items = []
		for _i in nb_players:
			result.shop_items.push_back([])
		for player_index in int(min(state.shop_items.size(), nb_players)):
			for shop_item in state.shop_items[player_index]:

				if shop_item[0] is String:
					continue

				var item_data = ItemService.get_element_safe(ItemService.items, shop_item[0].my_id)
				var weapon_data = ItemService.get_element_safe(ItemService.weapons, shop_item[0].my_id)

				if item_data != null:
					item_data = item_data.duplicate()
					item_data.deserialize_and_merge(shop_item[0])
					result.shop_items[player_index].push_back([item_data, shop_item[1]])

				if weapon_data != null:
					weapon_data = weapon_data.duplicate()
					weapon_data.deserialize_and_merge(shop_item[0])
					result.shop_items[player_index].push_back([weapon_data, shop_item[1]])

		return result

	func serialize_run_state(state: Dictionary) -> Dictionary:
		var result = state.duplicate()

		if not state.has_run_state:
			return result

		if not "current_background" in state:
			result.has_run_state = false
			return result

		result.players_data = []
		for player_data in state.players_data:
			result.players_data.push_back(player_data.serialize())

		if state.current_background != null and state.current_background is BackgroundData:
			result.current_background = state.current_background.name.to_lower()

		result.challenges_completed_this_run = []
		for challenge in state.challenges_completed_this_run:
			result.challenges_completed_this_run.push_back(challenge.my_id_hash)

		var nb_players: int = int(max(4, state.players_data.size()))

		result.locked_shop_items = []
		for _i in nb_players:
			result.locked_shop_items.push_back([])
		for player_index in int(min(state.locked_shop_items.size(), nb_players)):
			var player_locked_items = state.locked_shop_items[player_index]
			for locked_item in player_locked_items:
				result.locked_shop_items[player_index].push_back([locked_item[0].serialize(), locked_item[1]])

		result.shop_items = []
		for _i in nb_players:
			result.shop_items.push_back([])
		for player_index in int(min(state.shop_items.size(), nb_players)):
			var player_shop_items = state.shop_items[player_index]
			for shop_item in player_shop_items:
				result.shop_items[player_index].push_back([shop_item[0].serialize(), shop_item[1]])

		return result


# --- ProgressData overrides: construct C8Loader instead of ProgressDataLoaderV3
# (bodies replicated from vanilla; the BETA branches never run on live builds).


func save() -> void :
	if BETA:
		.save()
		return
	if DebugService.disable_saving:
		return
	if load_status == LoadStatus.CORRUPTED_ALL_SAVES_NO_STEAM or load_status == LoadStatus.CORRUPTED_ALL_SAVES_NO_EPIC:
		printerr("Aborting save due to unrecoverable corruption")
		return
	save_settings()

	var loader_v3 = C8Loader.new(SAVE_DIR, current_profile_id)
	_set_loader_properties(loader_v3, saved_run_state)
	loader_v3.save()


func get_current_save_object() -> Dictionary:
	if BETA:
		return .get_current_save_object()

	var loader_v3 = C8Loader.new(SAVE_DIR, current_profile_id)
	_set_loader_properties(loader_v3, _get_current_run_state())
	return loader_v3.get_save_object()


func load_game_file(try_fallback: = true) -> void :
	if BETA:
		.load_game_file(try_fallback)
		return
	if DebugService.reinitialize_save:
		save()
		return

	print("--- Load game file (ExtendedCoop8) ---")
	print("Try to load save v3")
	var loader_v3 = C8Loader.new(SAVE_DIR, current_profile_id)
	load_with_generic_loader(loader_v3)
	if load_status == LoadStatus.SAVE_OK:
		return
	if load_status != LoadStatus.SAVE_MISSING:
		return

	# No v3 save: fall back to the vanilla migration chain (v2/v1/fallback).
	.load_game_file(try_fallback)


func reset_save_profile(id: int) -> void :
	if BETA:
		.reset_save_profile(id)
		return
	var loader = C8Loader.new(SAVE_DIR, id)
	loader.add_unlocked_by_default_from_blank_save()
	loader.run_state_deserialized = _get_empty_run_state()
	loader.save()
	if current_profile_id == id:
		load_with_generic_loader(loader)


func unlock_all_save_profile(id: int) -> void :
	if BETA:
		.unlock_all_save_profile(id)
		return
	var loader = C8Loader.new(SAVE_DIR, id)
	loader.load_game_file()
	loader.unlock_all()
	loader.run_state_deserialized = _get_empty_run_state()
	loader.save()
	if current_profile_id == id:
		load_with_generic_loader(loader)


func copy_save_profile(from_id: int, to_id: int) -> void :
	if BETA:
		.copy_save_profile(from_id, to_id)
		return
	var from_loader = C8Loader.new(SAVE_DIR, from_id)
	from_loader.load_game_file()
	if from_loader.load_status != LoadStatus.SAVE_OK:
		printerr("Could not copy save profile from id %s because it could not be loaded" % from_id)
		return

	var to_loader = C8Loader.new(SAVE_DIR, to_id)
	to_loader.zones_unlocked = from_loader.zones_unlocked.duplicate()
	to_loader.characters_unlocked = from_loader.characters_unlocked.duplicate()
	to_loader.upgrades_unlocked = from_loader.upgrades_unlocked.duplicate()
	to_loader.consumables_unlocked = from_loader.consumables_unlocked.duplicate()
	to_loader.weapons_unlocked = from_loader.weapons_unlocked.duplicate()
	to_loader.items_unlocked = from_loader.items_unlocked.duplicate()
	to_loader.challenges_completed = from_loader.challenges_completed.duplicate()
	to_loader.difficulties_unlocked_serialized.clear()
	for difficulty_unlocked in from_loader.difficulties_unlocked_serialized:
		to_loader.difficulties_unlocked_serialized.push_back(difficulty_unlocked)
	to_loader.inactive_mods = from_loader.inactive_mods.duplicate()
	to_loader.read_announcements = from_loader.read_announcements.duplicate()
	to_loader.run_state_deserialized = from_loader.run_state_deserialized.duplicate()
	to_loader.data = from_loader.data.duplicate()
	to_loader.killed_enemies = from_loader.killed_enemies.duplicate()
	to_loader.killed_by_enemies = from_loader.killed_by_enemies.duplicate()
	to_loader.items_bought = from_loader.items_bought.duplicate()
	to_loader.save()

	if current_profile_id == to_id:
		load_with_generic_loader(to_loader)
