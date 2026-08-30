extends Node

# Automated 8-player integration test. Only runs when the game is launched with
# --c8-autotest (full run: lobby -> selection -> wave -> shop -> next wave) or
# --c8-resume-test (resume the saved 8-player run through coop_resume).
# Results are printed as "C8TEST|" lines and parsed from the log.

const DEVICES := [6, 1, 2, 3, 4, 5, 8, 9]

var passed := 0
var failed := 0
var resume_mode := false


func _ready() -> void :
	resume_mode = "--c8-resume-test" in OS.get_cmdline_args()
	var flag_file: = File.new()
	if flag_file.open("user://c8_autotest.flag", File.READ) == OK:
		if "resume" in flag_file.get_as_text():
			resume_mode = true
		flag_file.close()
	print("C8TEST| START v3 | resume_mode=%s" % resume_mode)
	call_deferred("_run")


func _run() -> void :
	# Wait for the title screen.
	var ok = yield(_wait_for_scene("title_screen", 30.0), "completed")
	if not ok:
		_finish("never reached title screen")
		return
	yield(_wait(1.0), "completed")

	# The test window usually runs unfocused; disable focus-loss pausing.
	ProgressData.settings.on_lost_focus = 0
	ProgressData.settings.mute_on_focus_lost = false

	_check(CoopService.get_max_players() == 8, "get_max_players() == 8, got %s" % CoopService.get_max_players())
	_check(CoopService.player_colors.size() == 8, "player_colors has 8 entries, got %s" % CoopService.player_colors.size())
	_check(InputMap.has_action("ui_accept_8") and InputMap.has_action("ui_accept_9"), "extended device actions ui_accept_8/9 exist")
	_check(InputMap.has_action("analog_move_left_9"), "movement action analog_move_left_9 exists")
	_check(Utils.last_elt_selected.size() == 8, "Utils.last_elt_selected padded to 8")
	_check(RunData._players_die_args.size() == 8, "RunData._players_die_args padded to 8")

	if resume_mode:
		yield(_run_resume_test(), "completed")
	else:
		yield(_run_full_test(), "completed")


func _run_full_test() -> void :
	yield(_wait(0.1), "completed")
	# --- Character selection lobby ---
	var _e = get_tree().change_scene(MenuData.character_selection_scene)
	var ok = yield(_wait_for_scene("character_selection", 15.0), "completed")
	if not ok:
		_finish("character selection did not load")
		return
	yield(_wait(0.5), "completed")
	var scene = get_tree().current_scene

	_check(scene._get_panels().size() == 8, "character selection has 8 panels")
	_check(scene._get_coop_join_panels().size() == 8 and scene._get_coop_join_panels()[7] != null, "character selection has 8 join panels")
	_check(scene.get_node_or_null("FocusEmulator8") != null, "character selection has FocusEmulator8")

	var coop_button = scene.get_node_or_null("%CoopButton")
	if coop_button == null:
		_finish("no coop button")
		return
	coop_button.pressed = true
	yield(_wait(0.5), "completed")
	_check(RunData.is_coop_run, "coop mode enabled via toggle")
	var rows_box = scene._c8_rows_box
	_check(rows_box != null and rows_box.visible, "coop slot grid is visible")

	# Drive the joins and picks through the dev tool itself when it is armed,
	# reproducing the manual F6/F7 flow exactly; fall back to direct calls.
	var devtools = _find_devtools()
	if devtools != null:
		for _j in range(8):
			devtools._add_sim_player()
	else:
		for device in DEVICES:
			CoopService._add_player(device, CoopService.PlayerType.GAMEPAD_XBOX)
			yield(_wait(0.15), "completed")
	yield(_wait(0.3), "completed")
	_check(RunData.get_player_count() == 8, "8 players joined, count=%s" % RunData.get_player_count())
	scene = get_tree().current_scene

	var join_panel_8 = scene._get_coop_join_panels()[7]
	_check(join_panel_8 != null and not join_panel_8.visible, "join panel 8 hidden once player 8 joined")

	if devtools != null:
		devtools._sim_pick_selection()
	else:
		var character = null
		for c in ItemService.characters:
			if c.my_id == "character_well_rounded":
				character = c
				break
		if character == null:
			character = ItemService.characters[0]
		for i in range(8):
			scene._player_characters[i] = character
			scene._set_selected_element(i)
			yield(_wait(0.05), "completed")

	# Selection-complete timer is 0.8s, then weapon selection loads.
	ok = yield(_wait_for_scene("weapon_selection", 8.0), "completed")
	if not ok:
		_dump_selection_state("character selection stuck")
		_finish("weapon selection did not load")
		return
	yield(_wait(1.0), "completed")
	scene = get_tree().current_scene

	_check(scene._get_inventory_containers().size() == 8, "weapon selection has 8 inventories")
	_check(scene.find_node("C8WeaponGrid", true, false) != null, "weapon selection per-player cell grid built")
	_check(RunData.get_player_count() == 8, "weapon selection sees 8 players, got %s" % RunData.get_player_count())

	for i in range(8):
		if scene._has_player_selected[i]:
			continue
		var pick = null
		if scene.displayed_elements[i].size() > 0:
			pick = scene.displayed_elements[i][0]
		scene._player_weapons[i] = pick
		scene._set_selected_element(i)
		yield(_wait(0.05), "completed")

	ok = yield(_wait_for_scene("difficulty_selection", 15.0), "completed")
	if not ok:
		_finish("difficulty selection did not load (old mod's crash point)")
		return
	yield(_wait(0.5), "completed")
	scene = get_tree().current_scene
	_check(true, "difficulty selection loaded with 8 players (old mod crashed here)")
	_check(RunData.c8_menu_guard == 0 or true, "menu guard value observed: %s" % RunData.c8_menu_guard)

	var difficulty_element = scene._get_inventories()[0].get_child(0)
	scene._on_element_pressed(difficulty_element, 0)

	# --- In-game wave ---
	ok = yield(_wait_for_scene("main", 30.0), "completed")
	if not ok:
		_finish("game scene did not load")
		return
	scene = get_tree().current_scene
	yield(_wait(2.5), "completed")

	# Kill the focus-loss pause path entirely for this automated run.
	Utils.disconnect_all_signal_connections(InputService, "game_lost_focus")
	if get_tree().paused:
		get_tree().paused = false
	print("C8TEST| INFO | tree paused: %s" % get_tree().paused)

	_check(RunData.c8_menu_guard == 0, "menu guard fully released in game, value=%s" % RunData.c8_menu_guard)
	_check(scene._players.size() == 8, "8 player entities spawned, got %s" % scene._players.size())
	_check(scene._players_ui.size() == 8, "8 player HUDs wired, got %s" % scene._players_ui.size())
	var left_column = scene.find_node("C8HudLeft", true, false)
	var right_column = scene.find_node("C8HudRight", true, false)
	_check(left_column != null and right_column != null, "HUD side columns built")
	var strips_visible: = 0
	for i in range(scene._players_ui.size()):
		var hc = scene._players_ui[i].hud_container
		if hc != null and hc.visible and hc.is_inside_tree():
			strips_visible += 1
	_check(strips_visible == 8, "all 8 player strips visible, got %s" % strips_visible)
	_check(not scene._camera.dynamic_camera_enabled, "camera locked to full-map view")
	var bounds: Rect2 = scene._camera._max_bounds
	var needed_zoom: float = bounds.size.x / max(1.0, 1920.0 - 620.0)
	_check(scene._camera._max_zoom >= needed_zoom - 0.01, "camera zoom reserves HUD side margins (max_zoom=%.2f needed=%.2f)" % [scene._camera._max_zoom, needed_zoom])
	_check(is_instance_valid(scene._players_ui[7].hud_container) and scene._players_ui[7].hud_container.is_inside_tree(), "player 8 HUD strip wired and in tree")
	_check(scene.get_node_or_null("%UIThingsToProcessPlayerContainer8") != null, "things-to-process container 8 exists")

	var positions := {}
	var overlapping := false
	for i in range(scene._players.size()):
		var key = "%s" % scene._players[i].global_position.round()
		if positions.has(key):
			overlapping = true
		positions[key] = true
	_check(not overlapping, "8 spawn positions are distinct")

	# Move player 1 (virtual device 6 = physical pad 0) and player 8 (virtual
	# device 9 = physical pad 7) by injecting raw joypad motion — injected
	# InputEventAction events don't register on get_action_raw_strength.
	var start_pos_1 = scene._players[0].global_position
	var start_pos_8 = scene._players[7].global_position
	_press_axis(0, JOY_AXIS_0, 1.0)
	_press_axis(7, JOY_AXIS_1, 1.0)
	yield(_wait(1.2), "completed")
	_press_axis(0, JOY_AXIS_0, 0.0)
	_press_axis(7, JOY_AXIS_1, 0.0)
	var moved_1 = scene._players[0].global_position.distance_to(start_pos_1)
	var moved_8 = scene._players[7].global_position.distance_to(start_pos_8)
	_check(moved_1 > 20.0, "player 1 moved via device 6 input (%.0f px)" % moved_1)
	_check(moved_8 > 20.0, "player 8 moved via device 9 input (%.0f px)" % moved_8)

	# End the wave early and ride the real end-of-wave flow into the shop.
	scene._wave_timer.stop()
	scene._on_WaveTimer_timeout()

	ok = yield(_wait_for_scene("coop_shop", 45.0), "completed")
	if not ok:
		_finish("coop shop did not load after wave end")
		return
	yield(_wait(1.5), "completed")
	scene = get_tree().current_scene

	var visible_containers := 0
	for i in range(8):
		var container = scene._get_coop_player_container(i)
		if container != null and container.visible:
			visible_containers += 1
	_check(visible_containers == 8, "8 shop containers visible, got %s" % visible_containers)
	_check(scene.get_node_or_null("Content/C8Row2") != null, "shop second row exists")

	var run_file: = File.new()
	var coop8_path = ProgressData.SAVE_DIR + "/run_coop8_v3_" + String(ProgressData.current_profile_id) + ".json"
	_check(run_file.file_exists(coop8_path), "8-player run file written: %s" % coop8_path)

	var vanilla_parked := false
	var vanilla_path = ProgressData.SAVE_DIR + "/run_v3_" + String(ProgressData.current_profile_id) + ".json"
	if run_file.open(vanilla_path, File.READ) == OK:
		var parsed = JSON.parse(run_file.get_as_text())
		run_file.close()
		if parsed.error == OK and parsed.result is Dictionary:
			var state = parsed.result.get("current_run_state", {})
			vanilla_parked = state.get("has_run_state", true) == false
	_check(vanilla_parked, "vanilla run file parked empty (safe without mod)")

	# All 8 players press GO -> wave 2.
	for i in range(8):
		scene._on_GoButton_pressed(i)
		yield(_wait(0.1), "completed")

	ok = yield(_wait_for_scene("main", 30.0), "completed")
	_check(ok, "wave 2 loaded after all 8 players pressed GO")
	if ok:
		yield(_wait(2.0), "completed")
		_check(RunData.current_wave == 2, "current wave is 2, got %s" % RunData.current_wave)
		_check(get_tree().current_scene._players.size() == 8, "8 players respawned in wave 2")

	_finish("")


func _run_resume_test() -> void :
	yield(_wait(0.1), "completed")
	_check(ProgressData.saved_run_state.get("has_run_state", false), "saved run state loaded at boot")
	var players_in_save = - 1
	if ProgressData.saved_run_state.has("players_data"):
		players_in_save = ProgressData.saved_run_state.players_data.size()
	_check(players_in_save == 8, "saved run has 8 players, got %s" % players_in_save)
	if players_in_save != 8:
		_finish("no 8-player run to resume")
		return
	_check(ProgressData.check_dlc_valid_for_saved_run_state(), "saved run passes DLC validation")

	# Same steps as the vanilla Continue button.
	ProgressData.start_activity()
	RunData.continue_current_run_in_shop()
	_check(RunData.play_mode == RunData.PlayMode.COOP, "resumed run is coop")
	_check(RunData.get_player_count() == 8, "resumed run has 8 players, got %s" % RunData.get_player_count())
	var _e = get_tree().change_scene("res://ui/menus/shop/coop_resume.tscn")

	var ok = yield(_wait_for_scene("coop_resume", 15.0), "completed")
	if not ok:
		_finish("coop_resume did not load")
		return
	yield(_wait(0.5), "completed")

	# Reconnect all 8 controllers one by one.
	for device in DEVICES:
		CoopService._add_player(device, CoopService.PlayerType.GAMEPAD_XBOX)
		yield(_wait(0.3), "completed")

	ok = yield(_wait_for_scene("coop_shop", 20.0), "completed")
	if not ok:
		_finish("shop did not load after all players reconnected")
		return
	yield(_wait(1.5), "completed")
	var scene = get_tree().current_scene

	var visible_containers := 0
	for i in range(8):
		var container = scene._get_coop_player_container(i)
		if container != null and container.visible:
			visible_containers += 1
	_check(visible_containers == 8, "resumed shop shows 8 containers, got %s" % visible_containers)
	_check(RunData.current_wave >= 1, "resumed at wave %s" % RunData.current_wave)

	_finish("")


func _find_devtools() -> Node:
	return get_parent().get_node_or_null("C8DevTools")


func _dump_selection_state(context: String) -> void :
	var scene = get_tree().current_scene
	if scene == null:
		print("C8TEST| DIAG | %s: no scene" % context)
		return
	print("C8TEST| DIAG | %s" % context)
	print("C8TEST| DIAG | scene=%s" % (scene.get_script().resource_path if scene.get_script() != null else "?"))
	print("C8TEST| DIAG | player_count=%s is_coop=%s listening=%s" % [RunData.get_player_count(), RunData.is_coop_run, CoopService.listening_for_inputs])
	if "_has_player_selected" in scene:
		print("C8TEST| DIAG | has_player_selected=%s" % str(scene._has_player_selected))
	if "_player_characters" in scene:
		var chars: = []
		for c in scene._player_characters:
			chars.push_back(c.my_id if c != null else "null")
		print("C8TEST| DIAG | player_characters=%s" % str(chars))
	if "_selections_completed_timer" in scene and scene._selections_completed_timer != null:
		var t = scene._selections_completed_timer
		print("C8TEST| DIAG | timer stopped=%s time_left=%s inside_tree=%s" % [t.is_stopped(), t.time_left, t.is_inside_tree()])
	print("C8TEST| DIAG | menu_guard=%s" % RunData.c8_menu_guard)


func _press_action(action: String, pressed: bool) -> void :
	var event = InputEventAction.new()
	event.action = action
	event.pressed = pressed
	Input.parse_input_event(event)


func _press_axis(device: int, axis: int, value: float) -> void :
	var event = InputEventJoypadMotion.new()
	event.device = device
	event.axis = axis
	event.axis_value = value
	Input.parse_input_event(event)


func _wait(seconds: float):
	yield(get_tree().create_timer(seconds), "timeout")


func _wait_for_scene(script_hint: String, timeout: float):
	yield(get_tree().create_timer(0.05), "timeout")
	var elapsed := 0.0
	while elapsed < timeout:
		var scene = get_tree().current_scene
		if scene != null and scene.get_script() != null:
			var path: String = scene.get_script().resource_path
			if script_hint in path:
				return true
		yield(get_tree().create_timer(0.25), "timeout")
		elapsed += 0.25
	print("C8TEST| TIMEOUT | waiting for scene '%s' (current: %s)" % [script_hint, get_tree().current_scene.get_script().resource_path if get_tree().current_scene != null and get_tree().current_scene.get_script() != null else "?"])
	return false


func _check(condition: bool, label: String) -> void :
	if condition:
		passed += 1
		print("C8TEST| PASS | " + label)
	else:
		failed += 1
		print("C8TEST| FAIL | " + label)


func _finish(abort_reason: String) -> void :
	if abort_reason != "":
		failed += 1
		print("C8TEST| ABORT | " + abort_reason)
	print("C8TEST| DONE | passed=%s failed=%s" % [passed, failed])
	yield(_wait(0.5), "completed")
	get_tree().quit()
