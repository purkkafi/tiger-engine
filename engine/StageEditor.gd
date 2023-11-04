extends Control


@onready var stage: VNStage = $VNStage
var lexer: Lexer = Lexer.new()
var parser: Parser = Parser.new()


var DEFAULT_HANDLERS: Dictionary = {
	# the empty string is a good default value
	'bg': func(): return '',
	'fg': func(): return '',
	'trans': func(): return '',
	# null is a good default value
	'sprite_at': func(): return null,
	# no default value, just error
	'sprite_id': func(): show_error('Sprite ID must be specified'); return null,
	'sprite_as': func(): show_error('"as" must be specified'); return null
}


var BACKGROUNDS: Array[String] = []
var TRANSITIONS: Array[String] = []
var SPRITES: Array[String] = []


const SPRITE_AT_TOOLTIP = """
Sprite location descriptor, which can be:
– number in range [0, 1]
– "<n> of <m>" to place sprite in n:th of m points equidistant from edges and each other
"""


func _init():
	BACKGROUNDS.append_array(TE.defs.imgs.keys())
	BACKGROUNDS.append_array(TE.defs._colors.keys())
	
	TRANSITIONS.append_array(TE.defs._transitions.keys())
	
	SPRITES.append_array(TE.defs.sprites.keys())


func _on_set_bg_pressed():
	show_dialog('Set background', [
		{ 'id': 'bg', 'name': 'Background', 'suggestions': func(_state): return BACKGROUNDS },
		{ 'id': 'trans', 'name': 'Transition', 'suggestions': func(_state): return TRANSITIONS }
	], _change_bg)


func _change_bg(values: Dictionary):
	_wait_tween(stage.set_background(values['bg'], values['trans'], null))


func _on_set_fg_pressed():
	show_dialog('Set background', [
		{ 'id': 'fg', 'name': 'Foreground', 'suggestions': func(_state): return BACKGROUNDS },
		{ 'id': 'trans', 'name': 'Transition', 'suggestions': func(_state): return TRANSITIONS }
	], _change_fg)


func _change_fg(values: Dictionary):
	_wait_tween(stage.set_foreground(values['fg'], values['trans'], null))


func _on_enter_pressed():
	show_dialog('Enter sprite', [
		{ 'id': 'sprite_id', 'name': 'Sprite ID', 'suggestions': func(_state): return SPRITES },
		{ 'id': 'sprite_at', 'name': 'At', 'tooltip': SPRITE_AT_TOOLTIP },
		{ 'id': 'trans', 'name': 'With', 'suggestions': func(_state): return TRANSITIONS }
	], _enter_sprite)


func _enter_sprite(values: Dictionary):
	var sprite_id: String = values['sprite_id']
	var by: Variant = null
	
	var all_ids: Array[String] = stage.get_sprite_ids()
	
	if sprite_id in all_ids: # assign new id with by for duplicate sprites
		var i = 2
		while true:
			var new_id = '%s (%d)' % [sprite_id, i]
			if not new_id in all_ids:
				by = new_id
				break
			i = i + 1
	
	_wait_tween(stage.enter_sprite(sprite_id, values['sprite_at'], values['trans'], by, null))


func _on_move_pressed():
	show_dialog('Move sprite', [
		{ 'id': 'sprite_id', 'name': 'Sprite ID', 'suggestions': func(_state): return stage.get_sprite_ids() },
		{ 'id': 'sprite_at', 'name': 'To', 'tooltip': SPRITE_AT_TOOLTIP },
		{ 'id': 'trans', 'name': 'With', 'suggestions': func(_state): return TRANSITIONS }
	], _move_sprite)


func _move_sprite(values: Dictionary):
	_wait_tween(stage.move_sprite(values['sprite_id'], values['sprite_at'], values['trans'], null))


func _on_show_pressed():
	show_dialog('Show sprite', [
		{ 'id': 'sprite_id', 'name': 'Sprite ID', 'suggestions': func(_state): return stage.get_sprite_ids() },
		{ 'id': 'sprite_as', 'name': 'As', 'default': '\\as{}', 'suggestions': _get_sprite_as_suggestions },
		{ 'id': 'trans', 'name': 'With', 'suggestions': func(_state): return TRANSITIONS }
	], _show_sprite)


func _get_sprite_as_suggestions(state: Dictionary) -> Array:
	if 'sprite_id' in state and state['sprite_id'] in stage.get_sprite_ids():
		return stage.find_sprite(state['sprite_id']).stage_editor_hints()
	else:
		return []


func _show_sprite(values: Dictionary):
	# parse given 'as' value to Tag
	var tokens = lexer.tokenize_string(values['sprite_as'], '<input>')
	
	if tokens == null:
		show_error('Tokenization error: %s' % lexer.error_message)
		return
	
	var result = parser.parse(tokens)
	
	if result == null:
		show_error('Parse error: %s' % parser.error_message)
		return
	
	if not (result is Array and len(result) == 1 and result[0] is Tag):
		show_error('Expected single \\as tag, got %s' % result)
		return
	
	_wait_tween(stage.show_sprite(values['sprite_id'], result[0] as Tag, values['trans'], null))


func _on_exit_pressed():
	show_dialog('Exit sprite', [
		{ 'id': 'sprite_id', 'name': 'Sprite ID', 'suggestions': func(_state): return stage.get_sprite_ids() },
		{ 'id': 'trans', 'name': 'With', 'suggestions': func(_state): return TRANSITIONS }
	], _exit_sprite)


func _exit_sprite(values: Dictionary):
	_wait_tween(stage.exit_sprite(values['sprite_id'], values['trans'], null))

# disables UI until given tween finishes
func _wait_tween(tween: Tween):
	if tween == null:
		return
	
	for child in %Buttons.get_children():
		(child as Button).disabled = true
	
	tween.tween_callback(_tween_finished)


func _tween_finished():
	for child in %Buttons.get_children():
		(child as Button).disabled = false


# shows a dialog containing the given settings and finally calls the given callback
# settings is an array of dictionaries, their keys signifying:
# – 'id': the id; the callback will be given a state dict of ids -> values
# – 'name': the name, displayed to the user
# – 'suggestions': (optional) callback that, given the state, returns an array of
#                  suggested strings displayed to the user
# – 'default': (optional) the initial string
func show_dialog(title: String, settings: Array, callback: Callable):
	var grid: GridContainer = GridContainer.new()
	grid.columns = 2
	grid.custom_minimum_size = Vector2(750, 0)
	
	var edits: Array[Control] = []
	
	for setting in settings:
		var label: Label = Label.new()
		label.text = setting['name']
		grid.add_child(label)
		
		var edit: Control
		if 'suggestions' in setting: # spawn SuggestLineEdit
			edit = SuggestLineEdit.new()
			edit.suggestion_provider = _get_suggestions.bind(edits, setting['suggestions'])
			if 'default' in setting:
				edit.set_edit_text(setting['default'])
		else: # spawn LineEdit
			edit = LineEdit.new()
			if 'default' in setting:
				edit.text = setting['default']
		
		if 'tooltip' in setting:
			edit.tooltip_text = setting['tooltip']
		
		edit.set_meta('id', setting['id'])
		edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(edit)
		edits.append(edit)
	
	var dialog: AcceptDialog = Popups.info_dialog(title, grid)
	dialog.connect('confirmed', _call_callback.bind(edits, callback))


func _get_edit_text(edit: Control):
	if edit is SuggestLineEdit:
		return edit.edit_text()
	else:
		return (edit as LineEdit).text


# returns suggestions, given the list of setting controls and the provider
func _get_suggestions(edits: Array[Control], provider: Callable) -> Array:
	var state: Dictionary = {}
	
	for edit in edits:
		state[edit.get_meta('id')] = _get_edit_text(edit)
	
	return provider.call(state)


func _call_callback(edits: Array[Control], callback: Callable):
	var values: Dictionary = {}
	
	for edit in edits:
		var id: String = edit.get_meta('id')
		
		var value: Variant = _get_edit_text(edit)
		
		if value == '': # if nothing (empty string) is given, return default value
			if id not in DEFAULT_HANDLERS:
				push_error('no default handler for %s' % id)
			value = DEFAULT_HANDLERS[id].call()
			
		values[id] = value
	
	callback.call(values)


func show_error(msg: String):
	Popups.error_dialog(TE.Error.ENGINE_ERROR, msg)