extends "res://singletons/input_service.gd"

# Extends the per-device InputMap generation from 8 to 10 virtual device slots:
#   virtual 0..5 -> physical pads 0..5 (6 = pad 0 remapped, 7 = keyboard, as vanilla)
#   virtual 8    -> physical pad 6
#   virtual 9    -> physical pad 7
# This is what lets 8 gamepads (or 7 gamepads + keyboard) act independently.

const C8_REMAP_END := 10


func _c8_physical_device_for(remapped_device: int) -> int:
	if remapped_device == CoopService.GAMEPAD_REMAPPED_DEVICE_ID:
		return 0
	if remapped_device == 8:
		return 6
	if remapped_device == 9:
		return 7
	return remapped_device


func _copy_device_actions():
	_set_bug_report_key()

	var action_names = InputMap.get_actions()
	for action_name in action_names:
		var action_events = InputMap.get_action_list(action_name)
		var deadzone = InputMap.action_get_deadzone(action_name)
		for event in action_events:
			if event is InputEventJoypadButton:
				for remapped_device in range(0, C8_REMAP_END):
					if remapped_device == CoopService.KEYBOARD_REMAPPED_DEVICE_ID:
						# The keyboard player's action must exist (gameplay code
						# polls it every frame) but gets no joypad binding —
						# physical pad 7 belongs to player 8's virtual id 9.
						_c8_ensure_action(action_name, remapped_device, deadzone)
						continue
					var new_event = InputEventJoypadButton.new()
					new_event.device = _c8_physical_device_for(remapped_device)
					new_event.button_index = event.button_index
					new_event.pressed = event.pressed
					add_action(action_name, remapped_device, deadzone, new_event)

			elif event is InputEventJoypadMotion:
				for remapped_device in range(0, C8_REMAP_END):
					if remapped_device == CoopService.KEYBOARD_REMAPPED_DEVICE_ID:
						_c8_ensure_action(action_name, remapped_device, deadzone)
						continue
					var new_event = InputEventJoypadMotion.new()
					new_event.device = _c8_physical_device_for(remapped_device)
					new_event.axis = event.axis
					new_event.axis_value = event.axis_value
					add_action(action_name, remapped_device, deadzone, new_event)

			elif event is InputEventKey:
				for remapped_device in range(0, C8_REMAP_END):
					var device = 0 if remapped_device == CoopService.KEYBOARD_REMAPPED_DEVICE_ID else remapped_device
					add_key_action(action_name, remapped_device, device, event)

	if DebugService.coop_multiple_keyboard_inputs:
		var debug_device_id = 12
		var debug_key_mappings = {
			KEY_W: [debug_device_id, "up"],
			KEY_A: [debug_device_id, "left"],
			KEY_S: [debug_device_id, "down"],
			KEY_D: [debug_device_id, "right"],
			KEY_E: [debug_device_id, "accept"],
			KEY_Q: [debug_device_id, "pause"],
			KEY_Z: [debug_device_id, "cancel"],
			KEY_X: [debug_device_id, "info"],
			KEY_C: [debug_device_id, "select"],
			KEY_T: [debug_device_id + 1, "up"],
			KEY_F: [debug_device_id + 1, "left"],
			KEY_G: [debug_device_id + 1, "down"],
			KEY_H: [debug_device_id + 1, "right"],
			KEY_Y: [debug_device_id + 1, "accept"],
			KEY_R: [debug_device_id + 1, "pause"],
			KEY_V: [debug_device_id + 1, "cancel"],
			KEY_B: [debug_device_id + 1, "info"],
			KEY_N: [debug_device_id + 1, "select"],
			KEY_I: [debug_device_id + 2, "up"],
			KEY_J: [debug_device_id + 2, "left"],
			KEY_K: [debug_device_id + 2, "down"],
			KEY_L: [debug_device_id + 2, "right"],
			KEY_O: [debug_device_id + 2, "accept"],
			KEY_U: [debug_device_id + 2, "pause"],
			KEY_M: [debug_device_id + 2, "cancel"],
			KEY_COMMA: [debug_device_id + 2, "info"],
			KEY_PERIOD: [debug_device_id + 2, "select"],
			KEY_UP: [debug_device_id + 3, "up"],
			KEY_LEFT: [debug_device_id + 3, "left"],
			KEY_DOWN: [debug_device_id + 3, "down"],
			KEY_RIGHT: [debug_device_id + 3, "right"],
			KEY_PAGEUP: [debug_device_id + 3, "accept"],
			KEY_INSERT: [debug_device_id + 3, "pause"],
			KEY_DELETE: [debug_device_id + 3, "cancel"],
			KEY_END: [debug_device_id + 3, "info"],
			KEY_PAGEDOWN: [debug_device_id + 3, "select"],
		}

		for key in debug_key_mappings:
			var remapped_device = debug_key_mappings[key][0]
			var action_suffix = debug_key_mappings[key][1]
			for prefix in ["ui", "move"]:
				var action_name = prefix + "_" + action_suffix
				if not InputMap.has_action(action_name):
					continue
				var device: = 0
				var new_event = InputEventKey.new()
				new_event.device = device
				new_event.physical_scancode = key
				InputMap.action_add_event(action_name, new_event)
				add_key_action(action_name, remapped_device, device, new_event)


func _c8_ensure_action(action_name: String, remapped_device: int, deadzone: float) -> void :
	var new_action_name = action_name + "_" + str(remapped_device)
	if not InputMap.has_action(new_action_name):
		InputMap.add_action(new_action_name, deadzone)


func _emulate_action(device: int, input, action: String) -> void :
	var input_type = "axis" if input in [JOY_AXIS_0, JOY_AXIS_1] else "button"
	if not _is_input_pressed(device, input, input_type):
		return

	var remapped_device = device
	if device <= 0:
		remapped_device = CoopService.GAMEPAD_REMAPPED_DEVICE_ID
	elif device == 6:
		remapped_device = 8
	elif device == 7:
		remapped_device = 9
	var suffix = ("_%s" % remapped_device) if CoopService.is_device_assigned(remapped_device) else ""

	var a = InputEventAction.new()
	a.action = action + suffix
	a.device = device
	a.pressed = true
	Input.parse_input_event(a)
