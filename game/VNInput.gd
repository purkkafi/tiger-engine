class_name VNInput


static var GAME_ADVANCE: String = &'game_advance'


# initializes input map with basic actions
static func register_actions() -> void:
	InputMap.add_action(GAME_ADVANCE)
	
	# left mouse click to advance
	var left_click = InputEventMouseButton.new()
	left_click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(GAME_ADVANCE, left_click)
	
	# space to advance
	var space_pressed = InputEventKey.new()
	space_pressed.keycode = KEY_SPACE
	InputMap.action_add_event(GAME_ADVANCE, space_pressed)
	
	# enter to advance
	var enter_pressed = InputEventKey.new()
	enter_pressed.keycode = KEY_ENTER
	InputMap.action_add_event(GAME_ADVANCE, enter_pressed)
	
	# controller button to advance
	var controller_advance = InputEventJoypadButton.new()
	controller_advance.button_index = JOY_BUTTON_B
	InputMap.action_add_event(GAME_ADVANCE, controller_advance)
	
	
