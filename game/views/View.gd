class_name View extends Control
# base class for Views, which are responsible for displaying Blocks sequentially
# and managing game text scrolling and other game state


# lines in the current Block
# note that since they are parsed before being shown to account for formatting,
# values may not be in a usable form, but length can be releid on
var _lines: Array[String]
var block: Block # the current Block
# stores previous blocks if previous_block_policy is RETAIN
var _previous_blocks: Array[Block] = []
var line_index: int = -1 # index of lines
var next_effect = RichTextNext.new() # effect that implements the ▶ effect
var pause_delta: float = 0.0 # delta to wait until pause is over
var next_letter_delta: float = 0.0 # delta until next letter is displayed
var advance_held: float = 0.0 # sum of delta for which game has been advanced
var advance_held_this_line: float = 0.0 # like 'advance_held' but reset on each line
var cooldown = 0.0 # cooldown time remaining
var speedup: Speedup = Speedup.NORMAL # status of speedup
# whether current line has been read previously by the player
var previously_seen_line: bool = false
var state: State = State.READY_TO_PROCEED # current state
var waiting_tween: Tween = null # tween being waited for
var game: TEGame = null # TEGame object used to access various game data
var result: Variant = null # the optional value this View resulted in
# the state of the previous View (for temporary Views); Dictionary or null for none
var previous_state: Variant = null


# TODO implement setting for skip speed?
const SKIP_COOLDOWN: float = 0.1 # cooldown when moving to next line on speedup
const JUMP_TO_LINE_END_COOLDOWN: float = 0.75 # cooldown after scrolling text is skipped to line end

const SKIP_TWEEN_SCALE: float = 10.0 # factor to multiply tweening speed with
const SKIP_TO_LINE_END_THRESHOLD: float = 0.05 # treshold to skip to line end
const SPEEDUP_THRESHOLD_FASTER: float = 1.5 # treshold to start speeding up faster
const DEL = '\u007F' # Unicode delete character
const CHAR_WAIT_DELTAS: Dictionary = { # see _char_wait_delta()
	' ' : 0, '\n' : 0, '"' : 0, "'" : 0, '▶' : 0,
	'.' : 14, '!' : 14, '?' : 14, '–' : 14, ':' : 14,
	';' : 11,
	',' : 8,
	DEL : 5
}


# parses a bbcode tag surrounding a string
static var GET_BBCODE: RegEx = RegEx.create_from_string('\\[(?<tag>.+?)\\](?<content>.+?)\\[\\/(?P=tag)\\]')


# current speedup state; will move continuously to faster speedup as input is held down
enum Speedup {
	NORMAL, # no speedup
	# speedup when advance is held, skips forward
	SPEEDUP,
	# should work like SPEEDUP but via the skip button
	SKIP
}


# state of text scrolling
enum State {
	SCROLLING_TEXT, # not at end of line, text is being scrolled
	WAITING_ADVANCE, # at end of line, waiting for user to advance (press spacebar/mouse)
	SKIPPING_COOLDOWN, # at an end of line, waiting for cooldown
	READY_TO_PROCEED, # can proceed to next line/block
	JUMPED_TO_LINE_END_COOLDOWN # cooldown after jumping scrolling text to end of line
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


# how previous Blocks are treated
enum PreviousBlocksPolicy {
	DISCARD, # they are simply discarded
	RETAIN # they are stored in _previous_blocks and persist in save data
}


# emitted when pause() is called
@warning_ignore("unused_signal")
signal game_paused
# emitted when a pause ends
@warning_ignore("unused_signal")
signal game_unpaused


# adjusts the size of this View based on how the VNControls instance has
# decided to set its size. will be called with a null parameter if the View
# is run directly in the editor; in this case, the controls should be treated
# as if they had the height 0
# automatically connected to TETheme's relevant signal by TEGame
func adjust_size(_controls: VNControls) -> void:
	pass


# pauses the game for the given amount of time, preventing the View from updating
func pause(seconds: float):
	emit_signal('game_paused')
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
	if _is_tweening():
		return true
	if _is_paused():
		return true
	if cooldown > 0:
		return true
	return false


func _is_tweening():
	return waiting_tween != null and waiting_tween.is_running()


func _is_paused():
	return pause_delta > 0


# returns whether parent should ask for next block by calling show_block()
func is_next_block_requested() -> bool:
	if _is_waiting():
		return false
	if line_index == -1: # true if no block has been shown yet
		return true
	# otherwise, true if there are no lines left, game isn't waiting for anything, and state is READY_TO_PROCEED 
	if line_index >= len(_lines):
		return state == State.READY_TO_PROCEED
	return false


# returns whether parent should ask for next line by calling next_line()
func is_next_line_requested():
	# true if there are lines left and not waiting for anything and state is READY_TO_PROCEED
	if len(_lines) != 0 and line_index < len(_lines) and !_is_waiting():
		return state == State.READY_TO_PROCEED
	return false


# displays the given block next
func show_block(new_block: Block) -> void:
	var old_block: Variant = block
	if old_block != null:
		_previous_blocks.append(old_block)
	
	block = new_block
	_lines = Blocks.resolve_parts(block, game.context)
	line_index = 0
	_block_started(old_block, block)


# proceeds to the next line
func next_line(loading_from_save: bool = false) -> void:
	previously_seen_line = TE.seen_blocks.is_read(block, line_index)
	TE.emit_signal('game_next_line')
	
	# if skipping with button/skip hotkey but skip mode was just set to DISABLED, stop
	if get_skip_mode() == SkipMode.DISABLED and speedup == Speedup.SKIP:
		skip_toggled(false)
	
	TE.seen_blocks.mark_read(block, line_index)
	
	var line: String = _lines[line_index]
	
	# parse lines containing engine-specific bbcode
	var tag_bbcode: RegExMatch = GET_BBCODE.search(line)	
	
	# parse custom tag and let subclass decide what to do with the line
	if tag_bbcode != null and tag_bbcode.get_string('tag') in _supported_custom_tags():
		_parse_custom_tag_line(line, tag_bbcode, loading_from_save)
		
	else: # no custom tags, display normally
		# handle speaker tag if present
		var speaker: Speaker = null
		if tag_bbcode != null and tag_bbcode.get_string('tag') == 'speaker':
			var _result: Dictionary  = _parse_speaker_line(line, tag_bbcode)
			line = _result['line']
			speaker = _result['speaker']
		
		if not loading_from_save:
			game.gamelog.add_line(convert_line_to_finished_form(line), speaker)
		
		_display_line(line + line_end_string(), speaker)
	
	line_index += 1
	next_effect.reset()
	
	var label: RichTextLabel = _current_label()
	label.visible_characters = 0
	next_letter_delta = 0 # reset to avoid bugs with infinite text speed
	advance_held_this_line = 0
	
	match speedup:
		Speedup.NORMAL:
			# proceed normally
			state = State.SCROLLING_TEXT
		Speedup.SPEEDUP, Speedup.SKIP:
			# skip to the end of the line, wait cooldown
			_to_end_of_line()
			
			cooldown = SKIP_COOLDOWN
			state = State.SKIPPING_COOLDOWN


func _parse_speaker_line(line: String, tag_bbcode: RegExMatch) -> Dictionary:
	var speaker_declaration: String = tag_bbcode.get_string('content')
	
	return {
		'line': Localize.autoquote(line.substr(tag_bbcode.get_end(0)).strip_edges()),
		'speaker': Speaker.resolve(speaker_declaration, game.context)
	}


# returns an Array of custom bbcode tags this View is able to parse with
# _parse_custom_tag_line()
func _supported_custom_tags() -> Array[String]:
	return []


# parses lines with custom bbcode the View claims to support
# should call _display_line() and game.gamelog.add_line() if needed
# – line is the full line, as a String
# – tag_bbcode is a RegExMatch resulting from GET_BBCODE.search()
# – loading_from_save is whether game is being loaded from a save file/state
func _parse_custom_tag_line(_line: String, _tag_bbcode: RegExMatch, _loading_from_save: bool) -> void:
	TE.log_error(TE.Error.FILE_ERROR, "View doesn't override _parse_custom_tag_line() despite overriding _supported_custom_tags()")


func _is_end_of_line() -> bool:
	var label: RichTextLabel = _current_label()
	return label.visible_characters >= label.get_total_character_count()


func _to_end_of_line():
	var label: RichTextLabel = _current_label()
	if label != null:
		label.visible_characters = label.get_total_character_count()
		# handles DEL characters
		label.text = convert_line_to_finished_form(label.text)


# converts the given line to a form that is suitable to display,
# handling DEL characters properly
func convert_line_to_finished_form(line: String):
	while line.find(View.DEL) != -1:
		var index = line.find(View.DEL)
		line = line.substr(0, index-1) + line.substr(index+1)
	return line


# updates the state of the View according to the given delta
func update_state(delta: float):
	# if pausing, reduce counter
	if pause_delta > 0:
		if speedup == Speedup.SPEEDUP or speedup == Speedup.SKIP:
			pause_delta = 0
			
		pause_delta -= delta
		
		if pause_delta <= 0:
			emit_signal('game_unpaused')
			state = State.READY_TO_PROCEED
		return
	
	# make tween faster on skip
	if waiting_tween != null:
		if speedup == Speedup.SPEEDUP or speedup == Speedup.SKIP:
			waiting_tween.set_speed_scale(SKIP_TWEEN_SCALE)
		
		if waiting_tween.is_running():
			return
	
	# if waiting for cooldown of jumping to end of line, reduce counter
	if state == State.JUMPED_TO_LINE_END_COOLDOWN:
		cooldown -= delta
		if cooldown < 0:
			state = State.WAITING_ADVANCE
		return
	
	# if waiting for line switch cooldown, reduce counter
	if state == State.SKIPPING_COOLDOWN or speedup == Speedup.SKIP:
		cooldown -= delta
		if cooldown < 0:
			state = State.READY_TO_PROCEED
		return
	else:
		cooldown = 0
	
	var label: RichTextLabel = _current_label()
	var text_speed: float = 30 + 80*TE.settings.text_speed
	
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
	advance_held_this_line += delta
	
	# accelerate tween and move past pauses if advance is held
	if waiting_tween != null and waiting_tween.is_running() and advance_held >= SKIP_TO_LINE_END_THRESHOLD:
		waiting_tween.custom_step(INF)
	
	if pause_delta > 0:
		pause_delta = SKIP_TO_LINE_END_THRESHOLD
	
	if state == State.WAITING_ADVANCE and advance_held_this_line >= SKIP_TO_LINE_END_THRESHOLD:
		# move to next line
		cooldown = SKIP_COOLDOWN
		state = State.SKIPPING_COOLDOWN
	
	elif state == State.SCROLLING_TEXT and advance_held_this_line >= SKIP_TO_LINE_END_THRESHOLD:
		# skip to end of line
		_to_end_of_line()
		state = State.JUMPED_TO_LINE_END_COOLDOWN
		cooldown = JUMP_TO_LINE_END_COOLDOWN
	
	if advance_held >= SPEEDUP_THRESHOLD_FASTER:
		speedup = Speedup.SPEEDUP


# should be called on frames when user is not advancing the game
func game_not_advanced(_delta: float):
	advance_held = 0.0
	
	if speedup != Speedup.SKIP:
		# reset speedup when advance is not held
		speedup = Speedup.NORMAL
		# clear advance cooldowns
		if cooldown > 0:
			cooldown = 0


# returns a new RichTextLabel with appropriate settings
# subclasses should call this instead of creating new instances by themselves
func create_label() -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	label.install_effect(next_effect)
	label.bbcode_enabled = true
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	label.text = ''
	label.clip_contents = false
	label.theme_type_variation = 'GameTextLabel'
	label.focus_mode = Control.FOCUS_NONE
	
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
# by default is toggleable and controlled by whether
# the current line has been read before
# subclasses can override this and skip_toggled() / skip_pressed() to
# control skip behaviour
func get_skip_mode() -> SkipMode:
	if not TE.settings.skip_unseen_text:
		var has_block: bool = block != null and block != Blocks.EMPTY_BLOCK
		
		if has_block and not _is_tweening() and not previously_seen_line:
			return SkipMode.DISABLED
	
	return SkipMode.TOGGLE


func skip_toggled(on: bool):
	if on: # skip toggled on
		speedup = Speedup.SKIP
		_to_end_of_line()
	else: # skip toggled off
		speedup = Speedup.NORMAL
		if waiting_tween != null and waiting_tween.is_running():
			# if waiting a tween, just move on
			state = State.READY_TO_PROCEED
		else:
			# else wait until user proceeds manually
			state = State.WAITING_ADVANCE


func skip_pressed():
	TE.log_error(TE.Error.ENGINE_ERROR, "view doesn't implement skip_pressed()")


# internal implementation; Views should override to control how lines are shown
# a Speaker may also additionally be specified
func _display_line(_line: String, _speaker: Speaker = null):
	TE.log_error(TE.Error.ENGINE_ERROR, "view doesn't implement _display_line()")


# optionally, subclasses may respond to a new block starting
# old is the previously displayed Block (may be null) and new is the new one
func _block_started(_old: Variant, _new: Block):
	pass


# should return the RichTextLabel containing the current line
func _current_label():
	TE.log_error(TE.Error.ENGINE_ERROR, "view doesn't implement _current_label()")


# if saving from View creates a continue point, it is returned; otherwise
# returns null
# see TEScriptVM.is_continue_point_valid() for format
func continue_point() -> Variant:
	return null


# returns the control that should be hidden when the hide keyboard shortcut
# the return value can be:
# – null to hide nothing
# – a single Control to hide
# – an Array of Controls to hide
# the default implementation returns 'self', i.e. the entire scene is hidden
func get_hidable_control() -> Variant:
	return self


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


# if returns true after parse_options() is called, View will not replace
# the current View or be initialized
# useful for Views that do not want to display anything
func cancel_replacement():
	return false


# handles options passed to the view
# overriding is not mandatory if the view doesn't want to handle options
func parse_options(_options: Array[Tag]):
	if len(_options) != 0:
		TE.log_error(TE.Error.ENGINE_ERROR, "view doesn't implement parse_options(), given %s" % [_options])


# if true, the View will be automatically replaced with the previous one
# Views that don't intend to handle text can override this to conveniently
# auto-dispose themselves after being finished
func is_temporary() -> bool:
	return false


# returns the current state of this View as a dict
func get_state() -> Dictionary:
	var savestate = {
		'scene' : self.scene_file_path
	}
	
	if is_temporary():
		savestate['previous_state'] = previous_state
	
	if block != null and block != Blocks.EMPTY_BLOCK: # no block info for Views that do not show blocks
		savestate.merge({
			'line_index': line_index,
			'hash': Assets.blockfiles.hashes[block.full_id()],
			'blockfile': block.blockfile_path,
			'block': block.id
		})
		
		if previous_block_policy() == PreviousBlocksPolicy.RETAIN:
			savestate['previous_blocks'] = []
			for old_block in _previous_blocks:
				savestate['previous_blocks'].append({
					'hash': Assets.blockfiles.hashes[block.full_id()],
					'blockfile': old_block.blockfile_path,
					'block': block.id
				})
	
	return savestate


# returns the PreviousBlocksPolicy of this View; should return a constant value
func previous_block_policy() -> PreviousBlocksPolicy:
	return PreviousBlocksPolicy.DISCARD


# sets the current state based on the given Dictionary
# note: when loading game from a save state created with the help of get_state(),
# the correct View scene is saved in the field 'scene'
# you can load and instantiate it and then call this object
func from_state(savestate: Dictionary):
	if is_temporary():
		previous_state = savestate['previous_state']
	
	# NOP if View didn't save block information
	if not 'block' in savestate:
		return
	
	# restore previously displayed Blocks
	if previous_block_policy() == PreviousBlocksPolicy.RETAIN:
		_previous_blocks = []
		for old_block in savestate['previous_blocks']:
			var _block = _resolve_block(old_block)
			_previous_blocks.append(_block)
			
			var lines = Blocks.resolve_parts(_block, game.context)
			
			for line in lines:
				_display_line(line, null)
	
	show_block(_resolve_block(savestate))
	
	if savestate['line_index']-1 > len(_lines):
		TE.log_error(TE.Error.BAD_SAVE, "block line index out of range in block '%s' in '%s'" % [savestate['block'], savestate['blockfile']], true)
		return
	
	# skip to the correct line
	while line_index <= savestate['line_index']-1:
		next_line(true)
		_to_end_of_line()


# resolves a dict with keys 'blockfile' and 'block' into a Block instance
func _resolve_block(dict: Dictionary) -> Block:
	if not FileAccess.file_exists(dict['blockfile']):
		TE.log_error(TE.Error.BAD_SAVE, "blockfile '%s' not found" % dict['blockfile'], true)
		return
	
	var blockfile: BlockFile = Assets.blockfiles.get_resource(dict['blockfile'])
	
	if not dict['block'] in blockfile.blocks:
		TE.log_error(TE.Error.BAD_SAVE, "block '%s' not found in blockfile '%s'" % [dict['block'], dict['blockfile']], true)
		return
	
	return blockfile.blocks[dict['block']]


# resets speedup-related data; may be needed if a View alternates between showing
# text and doing something else
func reset_speedup():
	speedup = Speedup.NORMAL
	state = State.READY_TO_PROCEED
	advance_held = 0


# returns the string put at the end of each line
func line_end_string() -> String:
	var symbol_font = get_theme_font('line_end_symbol', 'Global')
	# detects that not godot default font
	if symbol_font != null and symbol_font.resource_path != '':
		return '[next] [font=%s]▶[/font][/next]' % symbol_font.resource_path
	else:
		return '[next] ▶[/next]'


const STATE_TO_STR: Dictionary[State, String] = {
	State.SCROLLING_TEXT: 'SCROLLING_TEXT', 
	State.WAITING_ADVANCE: 'WAITING_ADVANCE',
	State.SKIPPING_COOLDOWN: 'SKIPPING_COOLDOWN',
	State.READY_TO_PROCEED: 'READY_TO_PROCEED',
	State.JUMPED_TO_LINE_END_COOLDOWN: 'JUMPED_TO_LINE_END_COOLDOWN'
}


const SPEEDUP_TO_STR: Dictionary[Speedup, String] = {
	Speedup.NORMAL: 'NORMAL',
	Speedup.SPEEDUP: 'SPEEDUP',
	Speedup.SKIP: 'SKIP'
}


func _debug_msg() -> String:
	var msg: String = ''
	msg += 'state: %s\n' % STATE_TO_STR[state]
	msg += 'speedup: %s' % SPEEDUP_TO_STR[speedup]
	
	return msg
