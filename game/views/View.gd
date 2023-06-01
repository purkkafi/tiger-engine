class_name View extends Control
# base class for Views, which are responsible for displaying Blocks sequentially
# and managing game text scrolling and other game state


var lines: Array[String] # lines in the current Block
var block: Block # the current Block
var line_index: int = -1 # index of lines
var next_effect = RichTextNext.new() # effect that implements the ▶ effect
var pause_delta: float = 0.0 # delta to wait until pause is over
var next_letter_delta: float = 0.0 # delta until next letter is displayed
var advance_held: float = 0.0 # sum of delta for which game has been advanced
var line_switch_delta = 0.0 # delta until advancing to the next line if on FASTER speedup
var speedup: Speedup = Speedup.NORMAL # status of speedup
var state: State = State.READY_TO_PROCEED # current state
var waiting_tween: Tween = null # tween being waited for
var game: TEGame = null # TEGame object used to access various game data
var result: Variant = null # the optional value this View resulted in
var previous_path: String = '' # the resource path of the previous View (for temporary Views)
var previous_state: Dictionary = {} # the state of the previous View (for temporary Views)


# TODO implement setting for skip speed?
const LINE_SWITCH_COOLDOWN: float = 0.1 # cooldown for moving to next line on speedup
const SKIP_TWEEN_SCALE: float = 10.0 # factor to multiply tweening speed with
const SPEEDUP_THRESHOLD_FAST: float = 0.25 # treshold to start speeding up
const SPEEDUP_THRESHOLD_FASTER: float = 1.15 # treshold to start speeding up faster
const LINE_END = '[next] ▶[/next]' # text to insert at the end of every line
const DEL = '\u007F' # Unicode delete character
const CHAR_WAIT_DELTAS: Dictionary = { # see _char_wait_delta()
	' ' : 0, '\n' : 0, '"' : 0, "'" : 0, '▶' : 0,
	'.' : 14, '!' : 14, '?' : 14, '–' : 14, ':' : 14,
	';' : 11,
	',' : 8,
	DEL : 5
}
var GET_SPEAKER_REGEX = RegEx.create_from_string('\\[speaker\\](.+)\\[\\/speaker\\]')


# current speedup state; will move continuously to faster speedup as input is held down
enum Speedup {
	NORMAL, # no speedup
	# scroll to end of current line and set state to WAITING_UNADVANCE (which will then set state
	# to WAITING_ADVANCE i.e. user has to release spacebar and/or mouse and then press it again)
	FAST,
	# accelerate tweens, scroll to end of line & set state to WAITING_LINE_SWITCH_DELTA
	FASTER,
	# should be as fast as FASTER
	SKIP
}


# state of text scrolling
enum State {
	SCROLLING_TEXT, # not at end of line, text is being scrolled
	WAITING_ADVANCE, # at end of line, waiting for user to advance (press spacebar/mouse)
	WAITING_UNADVANCE, # at end of line, waiting for user to not advance (release spacebar/mouse)
	WAITING_LINE_SWITCH_COOLDOWN, # at an end of line, waiting for cooldown
	READY_TO_PROCEED, # can proceed to next line/block
}

# how the skip button should behave
enum SkipMode {
	TOGGLE, # skip can be toggled on and off
	PRESS, # skip can be pressed (not a toggle button)
	DISABLED # skip is disabled
}


# in which context initialize() is called
enum InitContext {
	NEW_VIEW, # the View is newly created
	SAVESTATE # the View is loaded from a save state in some way (load screen, back button...)
}


# adjusts the size of this View based on how the VNControls instance has
# decided to set its size. will be called with a null parameter if the View
# is run directly in the editor; in this case, the controls should be treated
# as if they had the height 0
# automatically connected to TETheme's relevant signal by TEGame
func adjust_size(_controls: VNControls, _gui_scale: Settings.GUIScale) -> void:
	pass


# pauses the game for the given amount of time, preventing the View from updating
func pause(seconds: float):
	_game_paused()
	pause_delta = seconds


# pauses the game until the given Tween finishes
func wait_tween(tween: Tween):
	if waiting_tween != null and waiting_tween.is_running():
		push_error('already tweening!')
	waiting_tween = tween


# returns whether this View is waiting for a tween or a pause to finish
func _is_waiting():
	if _waiting_custom_condition():
		return true
	if waiting_tween != null and waiting_tween.is_running():
		return true
	if pause_delta > 0:
		return true
	if line_switch_delta > 0:
		return true
	return false


# returns whether parent should ask for next block by calling show_block()
func is_next_block_requested() -> bool:
	if _is_waiting():
		return false
	if line_index == -1: # true if no block has been shown yet
		return true
	# otherwise, true if there are no lines left, game isn't waiting for anything, and state is READY_TO_PROCEED 
	if line_index >= len(lines):
		return state == State.READY_TO_PROCEED
	return false


# returns whether parent should ask for next line by calling next_line()
func is_next_line_requested():
	# true if there are lines left and not waiting for anything and state is READY_TO_PROCEED
	if line_index < len(lines) and !_is_waiting():
		return state == State.READY_TO_PROCEED
	return false



# displays the given block next
func show_block(_block: Block) -> void:
	block = _block
	lines = Blocks.resolve_parts(block, game.context)
	line_index = 0
	_block_started()


# proceeds to the next line
func next_line(ignore_log: bool = false) -> void:
	# parse speaker specification
	var speaker = null
	var search: RegExMatch = GET_SPEAKER_REGEX.search(lines[line_index])
	if search != null:
		var id: String = search.strings[1]
		if id in TE.defs.speakers:
			speaker = TE.defs.speakers[id]
			lines[line_index] = TE.ui_strings.autoquote(lines[line_index].substr(search.get_end()))
		else:
			TE.log_error('speaker not rezognized: %s' % id)
	
	if not ignore_log:
		game.gamelog.add_line(process_line(lines[line_index]), speaker) # TODO speaker is not handled yet
	_next_line(lines[line_index] + LINE_END, speaker)
	line_index += 1
	next_effect.reset()
	
	var label: RichTextLabel = _current_label()
	label.visible_characters = 0
	
	match speedup:
		Speedup.NORMAL, Speedup.FAST:
			# proceed normally
			state = State.SCROLLING_TEXT
		Speedup.FASTER, Speedup.SKIP:
			# skip to the end of the line, wait cooldown
			_to_end_of_line()
			
			line_switch_delta = LINE_SWITCH_COOLDOWN
			state = State.WAITING_LINE_SWITCH_COOLDOWN


func _is_end_of_line() -> bool:
	var label: RichTextLabel = _current_label()
	return label.visible_characters >= label.get_total_character_count()


func _to_end_of_line():
	var label: RichTextLabel = _current_label()
	if label != null:
		label.visible_characters = label.get_total_character_count()
		# handles DEL characters
		label.text = process_line(label.text)


# converts the given line to a form that is suitable to display,
# handling DEL characters properly
func process_line(line: String):
	while line.find(View.DEL) != -1:
		var index = line.find(View.DEL)
		line = line.substr(0, index-1) + line.substr(index+1)
	return line


# updates the state of the View according to the given delta
func update_state(delta: float):
	# if pausing, reduce counter
	if pause_delta > 0:
		if speedup == Speedup.FASTER or speedup == Speedup.SKIP:
			pause_delta = 0
			
		pause_delta -= delta
		
		if pause_delta <= 0:
			state = State.READY_TO_PROCEED
		return
	
	if waiting_tween != null:
		if speedup == Speedup.FASTER or speedup == Speedup.SKIP:
			waiting_tween.set_speed_scale(SKIP_TWEEN_SCALE)
		
		if waiting_tween.is_running():
			return
	
	# if waiting for line switch cooldown, reduce counter
	if state == State.WAITING_LINE_SWITCH_COOLDOWN or speedup == Speedup.SKIP:
		line_switch_delta -= delta
		if line_switch_delta < 0:
			if line_index == len(lines):
				_block_ended()
			state = State.READY_TO_PROCEED
		return
	else:
		line_switch_delta = 0
	
	var label: RichTextLabel = _current_label()
	var text_speed: float = 20 + 50*TE.settings.text_speed
	
	if label == null:
		return   
	
	# if not at end of line, scroll further
	if !_is_end_of_line():
		# instant text speed if setting is at max value
		if TE.settings.text_speed >= 0.999:
			text_speed = INF
		
		next_letter_delta -= text_speed * delta
		
		while next_letter_delta < 0 and !_is_end_of_line():
			var next_char = label.get_parsed_text()[label.visible_characters]
			
			# no pause after final character is displayed
			# magic number -3 because the text should always end with ' ▶'
			if label.visible_characters != label.get_total_character_count()-3:
				next_letter_delta += _char_wait_delta(next_char)
			
			# handle delete character by erasing it & the previous character
			if next_char == DEL:
				var index = label.text.find(DEL)
				var text = label.text
				label.text = text.substr(0, index-1) + text.substr(index+1)
				label.visible_characters -= 1 # need to go back since the current char is deleted
			else: # else, proceed normally
				label.visible_characters += 1
		
	elif state == State.SCROLLING_TEXT:
		# reached end of line normally
		state = State.WAITING_ADVANCE


# returns the appropriate delta to wait for before displaying the given character
func _char_wait_delta(chr: String):
	if !TE.settings.dynamic_text_speed:
		return 1.0
	if chr in CHAR_WAIT_DELTAS:
		return CHAR_WAIT_DELTAS[chr]
	return 1.0


# should be called on frames when user is advancing the game via the mouse or keyboard
func game_advanced(delta: float):
	advance_held += delta
	
	if state == State.WAITING_ADVANCE:
		# call callback if this is the end of the current block
		if line_index == len(lines):
			_block_ended()
		state = State.READY_TO_PROCEED
	
	if speedup == Speedup.FAST and advance_held >= SPEEDUP_THRESHOLD_FASTER:
		speedup = Speedup.FASTER
		_to_end_of_line()
		line_switch_delta = LINE_SWITCH_COOLDOWN
		state = State.WAITING_LINE_SWITCH_COOLDOWN
		
		if line_index == len(lines):
			_block_ended()
		
	elif speedup == Speedup.NORMAL and advance_held >= SPEEDUP_THRESHOLD_FAST:
		speedup = Speedup.FAST
		_to_end_of_line()
		if not _is_waiting(): # could lead to state being WAITING_ADVANCE in pauses
			state = State.WAITING_UNADVANCE


# should be called on frames when user is not advancing the game
func game_not_advanced(_delta: float):
	advance_held = 0.0
	if speedup != Speedup.SKIP:
		speedup = Speedup.NORMAL
	
	# on FAST speedup, wait for user to unadvance first and then to advance
	# i.e. raise spacebar to end speedup and then press it again
	if state == State.WAITING_UNADVANCE:
		state = State.WAITING_ADVANCE
	
	# if advancing is stopped while waiting for line switch cooldown,
	# convert the remaining time to a regular pause and proceed
	if state == State.WAITING_LINE_SWITCH_COOLDOWN:
		pause_delta = line_switch_delta
		state = State.READY_TO_PROCEED


# returns a new RichTextLabel with appropriate settings
# subclasses should call this instead of creating new instances by themselves
func create_label() -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.install_effect(next_effect)
	label.bbcode_enabled = true
	label.fit_content = true
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.text = ''
	return label


# copies state from the previous View when switching over; used to ensure that
# advancing is smooth even when changing Views
func copy_state_from(old: View):
	advance_held = old.advance_held
	speedup = old.speedup
	
	# don't keep skip toggled accross Views that don't treat it as a toggle button
	if not get_skip_mode() == SkipMode.TOGGLE:
		speedup = Speedup.NORMAL
	
	state = old.state
	waiting_tween = old.waiting_tween


# how the skip button should work with this View
# by default is toggleable and affects speedup
# subclasses can override this and skip_toggled() / skip_pressed() to
# control skip behaviour
func get_skip_mode() -> SkipMode:
	return SkipMode.TOGGLE


func skip_toggled(on: bool):
	if on:
		speedup = Speedup.SKIP
		_to_end_of_line()
	else:
		speedup = Speedup.NORMAL


func skip_pressed():
	TE.log_error("view doesn't implement skip_pressed()")


# internal implementation; Views should override to control how lines are shown
# a Speaker may also additionally be specified
func _next_line(_line: String, _speaker: Definitions.Speaker = null):
	TE.log_error("view doesn't implement _next_line()")


# subclasses can override to respond to the game being paused with the \pause instruction
# for now, there is no _game_unpaused() counterpart
# if desired, the effects can be undone in a method like _next_line()
func _game_paused():
	pass


# optionally, subclasses may respond to a new block starting
func _block_started():
	pass


# callback for when a Block ends
func _block_ended():
	pass


# should return the RichTextLabel containing the current line
func _current_label():
	TE.log_error("view doesn't implement _current_label()")


# should return the path of the scene this View is attached to
func _get_scene_path():
	TE.log_error("view doesn't implement _get_scene_path()")


# returns whether the View is in waiting state and the game should not move on
# subclasses can override to manage their life cycle in case they don't
# interact with text via the mechanisms this class provides
func _waiting_custom_condition() -> bool:
	return false


# Views may initialize themselves in this method
# called after _ready(), parse_options() and from_state(); as such,
# the View should have any state it maintains available for use
func initialize(_ctxt: InitContext):
	pass


# handles options passed to the view
# overriding is not mandatory if the view doesn't want to handle options
func parse_options(_options: Array[Tag]):
	if len(_options) != 0:
		TE.log_error("view doesn't implement parse_options(), given %s" % [_options])


# if true, the View will be automatically replaced with the previous one
# Views that don't intend to handle text can override this to conveniently
# auto-dispose themselves after being finished
func is_temporary() -> bool:
	return false


# returns the current state of this View as a dict
func get_state() -> Dictionary:
	var savestate = {
			'scene' : _get_scene_path(),
	}
	
	if is_temporary():
		savestate['previous_path'] = previous_path
		savestate['previous_state'] = previous_state
	
	if block != null: # no block info for Views that do not show blocks
		savestate.merge({
			'line_index' : line_index,
			'hash' : Assets.blockfiles.hashes[block.blockfile_path + ':' + block.id],
			'blockfile' : block.blockfile_path,
			'block' : block.id,
			'scene' : _get_scene_path()
		})
	
	return savestate


# sets the current state based on the given Dictionary
# note: when loading game from a save state created with the help of get_state(),
# the correct View scene is saved in the field 'scene'
# you can load and instantiate it and then call this object
func from_state(savestate: Dictionary):
	if is_temporary():
		previous_path = savestate['previous_path']
		previous_state = savestate['previous_state']
	
	# NOP if View didn't save block information
	if not 'block' in savestate:
		return
	
	if not FileAccess.file_exists(savestate['blockfile']):
		TE.log_error('blockfile %s not found' % savestate['blockfile'])
		Popups.error_dialog(Popups.GameError.BAD_SAVE)
		return
	
	var blockfile: BlockFile = Assets.blockfiles.get_resource(savestate['blockfile'])
	
	if not savestate['block'] in blockfile.blocks:
		TE.log_error('block %s not found in blockfile %s' % [savestate['block'], savestate['blockfile']])
		Popups.error_dialog(Popups.GameError.BAD_SAVE)
		return
	
	var _block: Block = blockfile.blocks[savestate['block']]
	
	show_block(_block)
	
	if savestate['line_index']-1 > len(lines):
		TE.log_error('line index out of range')
		Popups.error_dialog(Popups.GameError.BAD_SAVE)
		return
	
	# skip to the correct line
	while line_index <= savestate['line_index']-1:
		next_line(true)
		_to_end_of_line()


# resets speedup-related data; may be needed if a View alternates between showing
# text and doing something else
func reset_speedup():
	speedup = Speedup.NORMAL
	state = State.READY_TO_PROCEED
	advance_held = 0
