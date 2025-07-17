class_name VNInput


# advancing the game via mouse, keys, or controller input
static var GAME_ADVANCE: String = &'game_advance'

# if focus is not obtained, shift focus to first or last element of the GUI
static var GAIN_FOCUS_START: String = &'gain_focus_start'
static var GAIN_FOCUS_END: String = &'gain_focus_end'


# initializes input map with basic actions
static func register_actions() -> void:
	InputMap.add_action(GAME_ADVANCE)
	
	var left_click = InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(GAME_ADVANCE, left_click)
	
	var space = InputEventKey.new()
	space.keycode = KEY_SPACE
	InputMap.action_add_event(GAME_ADVANCE, space)
	
	var enter = InputEventKey.new()
	enter.keycode = KEY_ENTER
	InputMap.action_add_event(GAME_ADVANCE, enter)
	
	var controller_advance = InputEventJoypadButton.new()
	controller_advance.button_index = JOY_BUTTON_B
	InputMap.action_add_event(GAME_ADVANCE, controller_advance)
	
	# TODO add joystick controls for these
	
	InputMap.add_action(GAIN_FOCUS_START)
	
	var right_key = InputEventKey.new()
	right_key.keycode = KEY_RIGHT
	InputMap.action_add_event(GAIN_FOCUS_START, right_key)
	
	var dpad_right = InputEventJoypadButton.new()
	dpad_right.button_index = JOY_BUTTON_DPAD_RIGHT
	InputMap.action_add_event(GAIN_FOCUS_START, dpad_right)
	
	InputMap.add_action(GAIN_FOCUS_END)
	
	var left_key = InputEventKey.new()
	left_key.keycode = KEY_LEFT
	InputMap.action_add_event(GAIN_FOCUS_END, left_key)
	
	var dpad_left = InputEventJoypadButton.new()
	dpad_left.button_index = JOY_BUTTON_DPAD_LEFT
	InputMap.action_add_event(GAIN_FOCUS_END, dpad_left)
	
	
