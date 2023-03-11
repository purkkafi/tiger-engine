class_name View extends Control
# base class for Views, which are responsible for displaying Blocks sequentially
# and managing game text scrolling and other game state


var lines: Array[String] # lines in the current Block
var line_index: int = -1 # index of lines
var next_effect = RichTextNext.new() # effect that implements the ▶ effect
var pause_delta: float = 0.0 # delta to wait until pause is over
var next_letter_delta: float = 0.0 # delta until next letter is displayed
var advance_held: float = 0.0 # sum of delta for which game has been advanced
var line_switch_delta = 0.0 # delta until advancing to the next line if on FASTER speedup
var speedup: Speedup = Speedup.NORMAL # status of speedup
var state: State # current state
var waiting_tween: Tween = null # tween being waited for


const LINE_SWITCH_COOLDOWN: float = 0.1# 0.15 # initial threshold for line_switch_delta
const SPEEDUP_THRESHOLD_FAST: float = 0.25 # treshold to start speeding up
const SPEEDUP_THRESHOLD_FASTER: float = 1.15 # treshold to start speeding up faster
const LINE_END = '[next] ▶[/next]' # text to insert at the end of every line
const CHAR_WAIT_DELTAS: Dictionary = { # see _char_wait_delta()
	' ' : 0, '\n' : 0, '"' : 0, "'" : 0, '▶' : 0,
	'.' : 14, '!' : 14, '?' : 14, '–' : 14, ':' : 14,
	';' : 11,
	',' : 8
}


enum Speedup { NORMAL, FAST, FASTER }


# state of text scrolling
enum State {
	SCROLLING_TEXT, # not at end of line, text is being scrolled
	WAITING_ADVANCE, # at end of line, waiting for user to advance
	WAITING_UNADVANCE, # at end of line, waiting for user to not advance
	WAITING_LINE_SWITCH_DELTA, # at an end of line, waiting for line switch cooldown
	READY_TO_PROCEED # can proceed to next line/block
}


# adjusts the size of this View based on how the VNControls instance has
# decided to set its size. will be called with a null parameter if the View
# is run directly in the editor; in this case, the controls should be treated
# as if they had the height 0
func adjust_size(controls: VNControls) -> void:
	pass


# pauses the game for the given amount of time, preventing the View from updating
func pause(seconds: float):
	pause_delta = seconds


# pauses the game until the given Tween finishes
func wait_tween(tween: Tween):
	if waiting_tween != null and waiting_tween.is_running():
		push_error('already tweening!')
	waiting_tween = tween


# returns whether this View is waiting for a tween or a pause to finish
func _is_waiting():
	if waiting_tween != null and waiting_tween.is_running():
		return true
	if pause_delta > 0:
		return true
	return false


# returns whether parent should ask for next block by calling show_block()
func is_next_block_requested() -> bool:
	if line_index == -1: # true if no block has been shown yet
		return true
	# otherwise, true if there are no lines left, game isn't waiting for anything, and state is READY_TO_PROCEED 
	if line_index >= len(lines) and !_is_waiting():
		return state == State.READY_TO_PROCEED
	return false


# returns whether parent should ask for next line by calling next_line()
func is_next_line_requested():
	# true if there are lines left and not waiting for anything and state is READY_TO_PROCEED
	if line_index < len(lines) and !_is_waiting():
		return state == State.READY_TO_PROCEED
	return false



# displays the given block next
func show_block(block: Block) -> void:
	lines = block.resolve_parts()
	line_index = 0
	_next_block()
	next_line()


# proceeds to the next line
func next_line() -> void:
	_next_line(lines[line_index] + LINE_END)
	line_index += 1
	
	var label: RichTextLabel = _current_label()
	label.visible_characters = 0
	
	match speedup:
		Speedup.NORMAL, Speedup.FAST:
			# proceed normally
			state = State.SCROLLING_TEXT
		Speedup.FASTER:
			# skip to the end of the line, wait cooldown
			_to_end_of_line()
			line_switch_delta = LINE_SWITCH_COOLDOWN
			state = State.WAITING_LINE_SWITCH_DELTA


func _is_end_of_line() -> bool:
	var label: RichTextLabel = _current_label()
	return label.visible_characters >= label.get_total_character_count()


func _to_end_of_line():
	var label: RichTextLabel = _current_label()
	label.visible_characters = label.get_total_character_count()


# updates the state of the View according to the given delta
func update_state(delta: float):
	# if pausing, reduce counter
	if pause_delta >= 0:
		if speedup == Speedup.FASTER:
			pause_delta = 0
		pause_delta -= delta
		return
	
	if waiting_tween != null:
		if speedup == Speedup.FASTER:
			waiting_tween.set_speed_scale(5)
		
		if waiting_tween.is_running():
			return
	
	# if waiting for line switch cooldown, reduce counter
	if state == State.WAITING_LINE_SWITCH_DELTA:
		line_switch_delta -= delta
		if line_switch_delta <= 0:
			state = State.READY_TO_PROCEED
			return
	
	var label: RichTextLabel = _current_label()
	var text_speed: float = 20 + 50*Global.settings.text_speed
	
	# if not at end of line, scroll further
	if !_is_end_of_line():
		# instant text speed if setting is at max value
		if Global.settings.text_speed >= 0.999:
			text_speed = INF
		
		next_letter_delta -= text_speed * delta
		
		while next_letter_delta < 0 and !_is_end_of_line():
			var next_char = label.text[label.visible_characters]
			
			# no pause after final character is displayed
			# magic number -3 because the text should always end with ' ▶'
			if label.visible_characters != label.get_total_character_count()-3:
				next_letter_delta += _char_wait_delta(next_char)
			
			label.visible_characters += 1
		
	elif state == State.SCROLLING_TEXT: # reached end of line
		state = State.WAITING_ADVANCE


# returns the appropriate delta to wait for before displaying the given character
func _char_wait_delta(chr: String):
	if !Global.settings.dynamic_text_speed:
		return 1.0
	if chr in CHAR_WAIT_DELTAS:
		return CHAR_WAIT_DELTAS[chr]
	return 1.0


# should be called on frames when user is advancing the game via the mouse or keyboard
func game_advanced(delta: float):
	advance_held += delta
	
	if state == State.WAITING_ADVANCE:
		state = State.READY_TO_PROCEED
	
	if speedup == Speedup.FAST and advance_held >= SPEEDUP_THRESHOLD_FASTER:
		speedup = Speedup.FASTER
		_to_end_of_line()
		line_switch_delta = LINE_SWITCH_COOLDOWN
		state = State.WAITING_LINE_SWITCH_DELTA
	elif speedup == Speedup.NORMAL and advance_held >= SPEEDUP_THRESHOLD_FAST:
		speedup = Speedup.FAST
		_to_end_of_line()
		state = State.WAITING_UNADVANCE


# should be called on frames when user is not advancing the game
func game_not_advanced(delta: float):
	advance_held = 0.0
	speedup = Speedup.NORMAL
	
	# on FAST speedup, wait for user to unadvance first and then to advance
	# i.e. raise spacebar to end speedup and then press it again
	if state == State.WAITING_UNADVANCE:
		state = State.WAITING_ADVANCE
	
	# if advancing is stopped while waiting for line switch cooldown,
	# convert the remaining time to a regular pause and proceed
	if state == State.WAITING_LINE_SWITCH_DELTA:
		pause_delta = line_switch_delta
		state = State.READY_TO_PROCEED


# returns a new RichTextLabel with appropriate settings
# subclasses should call this instead of creating new instances by themselves
func create_label() -> RichTextLabel:
	var label: RichTextLabel = RichTextLabel.new()
	#label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.install_effect(next_effect)
	label.bbcode_enabled = true
	return label


# copies state from the previous View when switching over; used to ensure that
# advancing is smooth even when changing Views
func copy_state_from(old: View):
	advance_held = old.advance_held
	speedup = old.speedup
	state = old.state
	waiting_tween = old.waiting_tween


# internal implementation; Views should override to control how lines are shown
func _next_line(line: String):
	Global.log_error("view doesn't implement _next_line()")


# optionally, subclasses may respond to a new block starting
func _next_block():
	pass


# should return the RichTextLabel containing the current line
func _current_label():
	Global.log_error("view doesn't implement _current_label()")


# subclasses should call this via super if they override _enter_tree()
func _enter_tree():
	# do this if View is run directly in the editor
	if self in get_tree().root.get_children():
		adjust_size(null)
