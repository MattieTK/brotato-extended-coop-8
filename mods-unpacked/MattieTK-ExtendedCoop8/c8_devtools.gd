extends Node

# Interactive simulation tool for testing the 8-player UI without physical
# controllers. Armed by the file  %APPDATA%/Brotato/c8_dev.flag  (delete it to
# turn the tool off). Join yourself normally (hold Enter on the keyboard),
# then drive simulated players with the hotkeys:
#
#   F5  toggle this help overlay
#   F6  add one simulated player (character select; enables coop if needed)
#   F7  pick characters/weapons for all simulated players (selection screens)
#   F4  advance: pick difficulty 1 / sim players choose upgrades / sim players
#       press GO in the shop
#   F9  end the current wave immediately (in game)
#   F10 give every player +150 materials and +40 XP (in game)

const SIM_DEVICES := [6, 1, 2, 3, 4, 5, 8, 9]

var _sim_devices: = []
var _overlay: CanvasLayer
var _label: Label


var _c8_keys_down: = {}


func _ready() -> void :
	pause_mode = Node.PAUSE_MODE_PROCESS
	_build_overlay()
	set_process(true)
	print("C8DEV| simulation tool armed (F5 for help overlay)")


func _process(_delta: float) -> void :
	# Polled, not event-driven: the game's focus emulators consume key events
	# with set_input_as_handled() on selection screens once everyone has locked
	# in, which would silence event-based hotkeys exactly when they're needed.
	for scancode in [KEY_F4, KEY_F5, KEY_F6, KEY_F7, KEY_F9, KEY_F10]:
		var down: bool = Input.is_key_pressed(scancode)
		var was_down: bool = _c8_keys_down.get(scancode, false)
		_c8_keys_down[scancode] = down
		if down and not was_down:
			_on_hotkey(scancode)


func _build_overlay() -> void :
	_overlay = CanvasLayer.new()
	_overlay.layer = 100
	add_child(_overlay)

	var panel = PanelContainer.new()
	panel.anchor_left = 1
	panel.anchor_right = 1
	panel.margin_left = - 460
	panel.margin_right = - 8
	panel.margin_top = 8
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.modulate = Color(1, 1, 1, 0.85)
	_overlay.add_child(panel)

	_label = Label.new()
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(_label)
	_refresh_overlay()


func _refresh_overlay() -> void :
	if _label == null:
		return
	_label.text = (
		"C8 DEV  —  players: %s (sim: %s)\n" % [RunData.get_player_count(), _sim_devices.size()]
		+ "F5 hide  |  F6 add sim player  |  F7 sim picks chars/weapons\n"
		+ "F4 advance (difficulty/upgrades/shop GO)\n"
		+ "F9 end wave  |  F10 +materials/+XP\n"
		+ "Join yourself first: hold Enter (keyboard) or A (pad)"
	)


func _on_hotkey(scancode: int) -> void :
	match scancode:
		KEY_F5:
			_overlay.visible = not _overlay.visible
		KEY_F6:
			_add_sim_player()
		KEY_F7:
			_sim_pick_selection()
		KEY_F4:
			_advance()
		KEY_F9:
			_end_wave()
		KEY_F10:
			_give_resources()
	_refresh_overlay()


func _scene() -> Node:
	return get_tree().current_scene


func _scene_is(hint: String) -> bool:
	var scene = _scene()
	if scene == null or scene.get_script() == null:
		return false
	return hint in scene.get_script().resource_path


func _is_sim_player(player_index: int) -> bool:
	return CoopService.get_remapped_player_device(player_index) in _sim_devices


func _add_sim_player() -> void :
	if not _scene_is("character_selection"):
		print("C8DEV| F6 only works on the character selection screen")
		return
	var scene = _scene()
	if not RunData.is_coop_run:
		var coop_button = scene.get_node_or_null("%CoopButton")
		if coop_button != null:
			coop_button.pressed = true
	if RunData.get_player_count() >= CoopService.get_max_players():
		print("C8DEV| lobby full")
		return
	for device in SIM_DEVICES:
		if not CoopService.is_device_assigned(device):
			_sim_devices.push_back(device)
			CoopService._add_player(device, CoopService.PlayerType.GAMEPAD_XBOX)
			print("C8DEV| sim player joined on device %s (players: %s)" % [device, RunData.get_player_count()])
			return
	print("C8DEV| no free device")


func _sim_pick_selection() -> void :
	var scene = _scene()
	if _scene_is("character_selection"):
		var characters: = []
		for c in ItemService.characters:
			if ProgressData.characters_unlocked.has(c.my_id_hash) or ProgressData.characters_unlocked.has(c.my_id):
				characters.push_back(c)
		if characters.empty():
			characters = ItemService.characters
		for i in range(RunData.get_player_count()):
			if scene._has_player_selected[i] or not _is_sim_player(i):
				continue
			scene._player_characters[i] = characters[i % characters.size()]
			scene._set_selected_element(i)
		print("C8DEV| sim players picked characters")
	elif _scene_is("weapon_selection"):
		for i in range(RunData.get_player_count()):
			if scene._has_player_selected[i] or not _is_sim_player(i):
				continue
			var pick = null
			if i < scene.displayed_elements.size() and scene.displayed_elements[i].size() > 0:
				pick = scene.displayed_elements[i][0]
			scene._player_weapons[i] = pick
			scene._set_selected_element(i)
		print("C8DEV| sim players picked weapons")
	else:
		print("C8DEV| F7 works on the character/weapon selection screens")


func _advance() -> void :
	var scene = _scene()
	if _scene_is("difficulty_selection"):
		var inventories = scene._get_inventories()
		if inventories.size() > 0 and inventories[0].get_child_count() > 0:
			scene._on_element_pressed(inventories[0].get_child(0), 0)
			print("C8DEV| difficulty selected")
	elif _scene_is("main.gd") or _scene_is("res://main"):
		_auto_choose_upgrades()
	elif _scene_is("coop_shop"):
		for i in range(RunData.get_player_count()):
			if _is_sim_player(i) and not scene._player_pressed_go_button[i]:
				scene._on_GoButton_pressed(i)
		print("C8DEV| sim players pressed GO")
	else:
		print("C8DEV| F4 works on difficulty, upgrades and shop screens")


func _auto_choose_upgrades() -> void :
	var scene = _scene()
	var upgrades_ui = scene.get_node_or_null("UI/CoopUpgradesUI")
	if upgrades_ui == null or not upgrades_ui.visible:
		print("C8DEV| no upgrade/item screen open")
		return
	var acted: = 0
	for i in range(RunData.get_player_count()):
		if not upgrades_ui._player_is_choosing[i] or not _is_sim_player(i):
			continue
		var container = upgrades_ui._get_player_container(i)
		if container == null:
			continue
		if container._items_container.visible and container._item_data != null:
			container.emit_signal("item_take_button_pressed", container._item_data)
			acted += 1
		elif container._upgrades_container.visible and container._old_upgrades.size() > 0:
			container.emit_signal("choose_button_pressed", container._old_upgrades[0])
			acted += 1
	print("C8DEV| auto-chose for %s sim players" % acted)


func _end_wave() -> void :
	if not (_scene_is("main.gd") or _scene_is("res://main")):
		print("C8DEV| F9 only works during a wave")
		return
	var scene = _scene()
	if scene._wave_timer != null:
		scene._wave_timer.stop()
	scene._on_WaveTimer_timeout()
	print("C8DEV| wave ended")


func _give_resources() -> void :
	if not (_scene_is("main.gd") or _scene_is("res://main")):
		print("C8DEV| F10 only works during a wave")
		return
	for i in range(RunData.get_player_count()):
		RunData.add_gold(150, i)
		RunData.add_xp(40, i)
	print("C8DEV| resources granted to all players")
