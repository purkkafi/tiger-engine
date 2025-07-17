class_name VNInput


static var GAME_ADVANCE_MOUSE: String = &'game_advance_mouse'
static var GAME_ADVANCE_KEYS: String = &'game_advance_keys'


# initializes input map with basic actions
static func register_actions() -> void:
	# left mouse click to advance
	var left_click = InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	
	InputMap.add_action(GAME_ADVANCE_MOUSE)
	InputMap.action_add_event(GAME_ADVANCE_MOUSE, left_click)
	
	# space & enter to advance
	var space_pressed = InputEventKey.new()
	space_pressed.keycode = KEY_SPACE
	
	var enter_pressed = InputEventKey.new()
	enter_pressed.keycode = KEY_ENTER
	
	InputMap.add_action(GAME_ADVANCE_KEYS)
	InputMap.action_add_event(GAME_ADVANCE_KEYS, space_pressed)
	InputMap.action_add_event(GAME_ADVANCE_KEYS, enter_pressed)
	
	
