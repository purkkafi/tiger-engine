class_name ChoiceView extends View


@onready var vbox: VBoxContainer = %VBox
var shadow: ColorRect
var finished: bool = false
var choice_strings: Array[String] = []
var choice_values: Array[Variant] = []


func parse_options(options: Array[Tag]):
	for opt in options:
		match opt.name:
			'block':
				var _block: Block = Blocks.find(opt.get_string_at(0))
				choice_strings.append(Blocks.resolve_string(_block, '\n', game.context))
				var value: Variant = ControlExpr.exec(opt.get_control_at(1), game.context)
				choice_values.append(value)


func adjust_size(_controls: VNControls):
	var width: float = get_theme_constant('width', 'ChoiceView')
	vbox.custom_minimum_size.x = width


func initialize(ctxt: InitContext):
	for i in range(len(choice_strings)):
		var btn: Button = Button.new()
		btn.text = choice_strings[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.theme_type_variation = 'ChoiceButton'
		btn.connect('pressed', Callable(self, '_finish').bind(i))
		vbox.add_child(btn)
	
	TE.localize.translate(self)
	shadow = Overlay.add_shadow(self, ctxt == InitContext.SAVESTATE)
	game.save_rollback()


func _finish(chosen_index: int):
	result = choice_values[chosen_index]
	finished = true
	Overlay.remove_shadow(shadow, func(): pass)


func _waiting_custom_condition() -> bool:
	return !finished


func _current_label() -> RichTextLabel:
	return null


func get_state() -> Dictionary:
	var savestate: Dictionary = super.get_state()
	savestate['strings'] = choice_strings
	savestate['values'] = choice_values
	return savestate


func from_state(savestate: Dictionary):
	for string in savestate['strings']:
		choice_strings.append(string)
	for value in savestate['values']:
		choice_values.append(value)
	super.from_state(savestate)


func is_temporary() -> bool:
	return true


func get_skip_mode() -> SkipMode:
	return SkipMode.DISABLED

