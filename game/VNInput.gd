class_name VNInput


# advancing the game via mouse, keys, or controller input
static var GAME_ADVANCE: String = &'game_advance'

# if focus is not obtained, shift focus to first or last element of the GUI
static var GAIN_FOCUS_START: String = &'gain_focus_start'
static var GAIN_FOCUS_END: String = &'gain_focus_end'

# scroll history back and forth
static var SCROLL_FORWARD: String = &'scroll_forward'
static var SCROLL_BACK: String = &'scroll_back'


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
	
	var numpad_enter = InputEventKey.new()
	numpad_enter.keycode = KEY_KP_ENTER
	InputMap.action_add_event(GAME_ADVANCE, numpad_enter)
	
	var controller_advance = InputEventJoypadButton.new()
	controller_advance.button_index = JOY_BUTTON_B
	InputMap.action_add_event(GAME_ADVANCE, controller_advance)

	InputMap.add_action(GAIN_FOCUS_START)
	
	var right_key = InputEventKey.new()
	right_key.keycode = KEY_RIGHT
	InputMap.action_add_event(GAIN_FOCUS_START, right_key)
	
	var dpad_right = InputEventJoypadButton.new()
	dpad_right.button_index = JOY_BUTTON_DPAD_RIGHT
	InputMap.action_add_event(GAIN_FOCUS_START, dpad_right)
	
	var joystick1_right = InputEventJoypadMotion.new()
	joystick1_right.axis = JOY_AXIS_LEFT_X
	joystick1_right.axis_value = -1.0
	InputMap.action_add_event(GAIN_FOCUS_START, joystick1_right)
	
	var joystick2_right = InputEventJoypadMotion.new()
	joystick2_right.axis = JOY_AXIS_RIGHT_X
	joystick2_right.axis_value = -1.0
	InputMap.action_add_event(GAIN_FOCUS_START, joystick2_right)
	
	InputMap.add_action(GAIN_FOCUS_END)
	
	var left_key = InputEventKey.new()
	left_key.keycode = KEY_LEFT
	InputMap.action_add_event(GAIN_FOCUS_END, left_key)
	
	var dpad_left = InputEventJoypadButton.new()
	dpad_left.button_index = JOY_BUTTON_DPAD_LEFT
	InputMap.action_add_event(GAIN_FOCUS_END, dpad_left)
	
	var joystick1_left = InputEventJoypadMotion.new()
	joystick1_left.axis = JOY_AXIS_LEFT_X
	joystick1_left.axis_value = 1.0
	InputMap.action_add_event(GAIN_FOCUS_END, joystick1_left)
	
	var joystick2_left = InputEventJoypadMotion.new()
	joystick2_left.axis = JOY_AXIS_RIGHT_X
	joystick2_left.axis_value = 1.0
	InputMap.action_add_event(GAIN_FOCUS_END, joystick2_left)
	
	InputMap.add_action(SCROLL_FORWARD)
	
	var scroll_down = InputEventMouseButton.new()
	scroll_down.button_index = MOUSE_BUTTON_WHEEL_DOWN
	InputMap.action_add_event(SCROLL_FORWARD, scroll_down)
	
	InputMap.add_action(SCROLL_BACK)
	
	var scroll_up = InputEventMouseButton.new()
	scroll_up.button_index = MOUSE_BUTTON_WHEEL_UP
	InputMap.action_add_event(SCROLL_BACK, scroll_up)
