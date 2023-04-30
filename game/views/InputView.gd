class_name InputView extends View
# a view that allows the user to type text and stores it into the result


@onready var prompt: Label = %Prompt
@onready var line_edit: LineEdit = %LineEdit
@onready var OK: Button = %OK
var width: float = get_theme_constant('width', 'InputView')
# text that will be displayed to tbe user above the LineEdit
var prompt_text: String = ''
# default value; used as the initial value of the LineEdit and as the result
# if the user inputs the empty string
var default_val: String = ''
var shadow: ColorRect
var finished: bool = false


func parse_options(options: Array[Tag]):
	for opt in options:
		match opt.name:
			'block':
				var _block: Block = Blocks.find(opt.get_string())
				prompt_text = Blocks.resolve_string(_block, '\n', game.context)
			'default':
				default_val = opt.get_string()
			_:
				TE.log_error('unknown option for input: %s' % opt)


func _ready():
	if width == 0: # default value in case theme doesn't set it
		width = 600
	
	line_edit.custom_minimum_size.x = width
	TE.ui_strings.translate(self)


func initialize(ctxt: InitContext):
	prompt.text = prompt_text
	line_edit.text = default_val
	shadow = Overlay.add_shadow(self, ctxt == InitContext.SAVESTATE)
	game.save_rollback()


# pointless argument allowing the method to be connected to both the LineEdit and the Button
func _finish(_new_string=null):
	result = line_edit.text
	if result == '': # use default value, if any, instead of the empty string
		result = default_val
	finished = true
	Overlay.remove_shadow(shadow, func(): pass)


func _waiting_custom_condition() -> bool:
	return !finished


# the view doesn't manage a label
func _current_label() -> RichTextLabel:
	return null


func _get_scene_path() -> String:
	return 'res://tiger-engine/game/views/InputView.tscn'


func get_state() -> Dictionary:
	var savestate: Dictionary = super.get_state()
	savestate['prompt_text'] = prompt_text
	savestate['default_val'] = default_val
	return savestate


func from_state(savestate: Dictionary):
	prompt_text = savestate['prompt_text']
	default_val = savestate['default_val']
	super.from_state(savestate)


func is_temporary() -> bool:
	return true


func get_skip_mode() -> SkipMode:
	return SkipMode.DISABLED
