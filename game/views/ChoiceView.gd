class_name ChoiceView extends View


@onready var vbox: VBoxContainer = %VBox
var width: float = get_theme_constant('width', 'ChoiceView')
var shadow: ColorRect
var finished: bool = false
var choice_strings: Array[String] = []
var choice_values: Array[Variant] = []


func parse_options(options: Array[Tag], ctxt: ControlExpr.GameContext):
	for opt in options:
		match opt.name:
			'block':
				var _block: Block = Blocks.find(opt.get_string_at(0), opt.get_string_at(1))
				choice_strings.append(Blocks.resolve_string(_block, '\n', ctxt))
				var value: Variant = ControlExpr.exec(opt.get_control_at(2), ctxt)
				choice_values.append(value)


func initialize():
	if width == 0: # default value in case theme doesn't set it
		width = 800
	
	vbox.custom_minimum_size.x = width
	
	for i in range(len(choice_strings)):
		var btn: Button = Button.new()
		btn.text = choice_strings[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.connect('pressed', Callable(self, '_finish').bind(i))
		vbox.add_child(btn)
	
	TE.ui_strings.translate(self)
	shadow = Overlay.add_shadow(self)


func _finish(chosen_index: int):
	result = choice_values[chosen_index]
	Overlay.remove_shadow(shadow, Callable(self, '_finished'))


func _finished():
	finished = true


func _waiting_custom_condition() -> bool:
	return !finished


func _current_label() -> RichTextLabel:
	return null


func _get_scene_path() -> String:
	return 'res://tiger-engine/game/views/ChoiceView.tscn'


func get_state() -> Dictionary:
	var savestate: Dictionary = super.get_state()
	savestate['strings'] = choice_strings
	savestate['values'] = choice_values
	return savestate


func from_state(savestate: Dictionary, ctxt: ControlExpr.GameContext):
	for string in savestate['strings']:
		choice_strings.append(string)
	for value in savestate['values']:
		choice_values.append(value)
	super.from_state(savestate, ctxt)
