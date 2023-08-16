class_name ContinuePointView extends View


var to: Variant = null
var ok_pressed: bool = false
var jumped: bool = false


func parse_options(tags: Array[Tag]):
	for tag in tags:
		match tag.name:
			'to':
				to = tag.get_string()
			_:
				TE.log_error(TE.Error.SCRIPT_ERROR, 'unknown argument for ContinuePointView: %s' % tag)
	
	if to == null:
		TE.log_error(TE.Error.SCRIPT_ERROR, "target continue point of ContinuePointView must be specified with 'to' parameter")
		return
	
	if TEScriptVM.is_continue_point_valid(to):
		game.jump_to_continue_point(to)
		jumped = true


func _ready():
	$BG.color = TETheme.background_color
	TE.ui_strings.translate(self)
	%OK.connect('pressed', func(): ok_pressed = true)


func _waiting_custom_condition() -> bool:
	return not jumped and not ok_pressed


func _current_label():
	return null


func _get_scene_path():
	return 'res://tiger-engine/game/views/ContinuePointView.tscn'


func get_skip_mode():
	return View.SkipMode.DISABLED


func continue_point() -> Variant:
	return to


func get_hidable_control():
	return null


func get_state() -> Dictionary:
	return super.get_state()


func from_state(savestate: Dictionary):
	super.from_state(savestate)


func cancel_replacement():
	return jumped
