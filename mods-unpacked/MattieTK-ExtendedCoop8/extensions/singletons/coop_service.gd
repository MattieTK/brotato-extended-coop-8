extends "res://singletons/coop_service.gd"

# 8-player support:
# - get_max_players() -> 8 on PC
# - 8 player colors
# - physical gamepads 6 and 7 (which vanilla cannot bind: their virtual ids 6/7
#   are reserved for remapped-pad-0 and keyboard) join via virtual ids 8/9.

const C8_MAX_PLAYERS := 8
const C8_GAMEPAD_6_VIRTUAL := 8
const C8_GAMEPAD_7_VIRTUAL := 9
const C8_DEBUG_FIRST := 12

var _c8_extra_colors := [
	Color("fca1e0"),
	Color("b8a1fc"),
	Color("fc9d9d"),
	Color("e0e0e0"),
]


func _ready() -> void :
	while player_colors.size() < C8_MAX_PLAYERS:
		player_colors.push_back(_c8_extra_colors[player_colors.size() - 4])
	var _e = connect("connected_players_updated", self, "_c8_fix_player_types")


func get_max_players():
	if Utils.on_console:
		return .get_max_players()
	return C8_MAX_PLAYERS


func _input(event: InputEvent) -> void :
	# Runs in addition to the vanilla _input (multilevel call). Vanilla ignores
	# physical devices 6/7 because their per-device actions are bound to virtual
	# ids 8/9 by our InputService extension — we add the hold timers here.
	if Utils.on_console:
		return
	if not (event is InputEventJoypadButton or event is InputEventJoypadMotion):
		return
	if event.device != 6 and event.device != 7:
		return
	var device_to_add = event.device + 2
	if event.is_action_pressed("ui_accept_%s" % device_to_add) and not _hold_timers.has(device_to_add):
		_hold_timers[device_to_add] = 0.0
		set_process(true)


func _c8_fix_player_types(players: Array) -> void :
	# Vanilla's join flow can't resolve the joy name for virtual ids 8/9 and
	# registers those players as keyboard users; fix their type in place.
	for player in players:
		var device: int = player[0]
		if device != C8_GAMEPAD_6_VIRTUAL and device != C8_GAMEPAD_7_VIRTUAL:
			continue
		if player[1] != PlayerType.KEYBOARD_AND_MOUSE:
			continue
		var joy_name: String = Input.get_joy_name(device - 2)
		var joy_name_components = joy_name.to_lower().split(" ")
		if "ps4" in joy_name_components or "ps5" in joy_name_components or "playstation" in joy_name_components or "dualsense" in joy_name_components:
			player[1] = PlayerType.GAMEPAD_PLAYSTATION
		elif "nintendo" in joy_name_components or "switch" in joy_name_components:
			player[1] = PlayerType.GAMEPAD_SWITCH
		else:
			player[1] = PlayerType.GAMEPAD_XBOX


func _get_next_free_debug_device() -> int:
	# Vanilla debug devices 8-11 collide with our virtual gamepad ids; move them.
	for device_id in range(C8_DEBUG_FIRST, C8_DEBUG_FIRST + DEBUG_DEVICE_COUNT):
		if not is_device_assigned(device_id):
			return device_id
	return - 1
