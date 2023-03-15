class_name TEGame extends Control
# main class for running the game
# handles user input and communication between different controls and objects
# that contain game state & lgoic


var vm: TEScriptVM # virtual machine that runs the game script
var mouse_advancing: bool = false # whether game is being advanced by holding the mouse
# default views
var overlay_active: bool = false # whether there is an overlay and game should be paused
var nvl_view = preload('res://tiger-engine/game/views/NVLView.tscn')
var adv_view = preload('res://tiger-engine/game/views/ADVView.tscn')


# sets the 'main' script in the given ScriptFile to be run
# call this before switching to the scene
func run_script(script_file: ScriptFile):
	vm = TEScriptVM.new(script_file.scripts['main'])


func _ready():
	TE.ui_strings.translate(self)
	MobileUI.initialize_gui(self)
	MobileUI.connect('gui_scale_changed', Callable(self, '_gui_scale_changed'))
	
	$VNControls.btn_quit.connect('pressed', Callable(self, '_quit'))
	$VNControls.btn_skip.connect('pressed', Callable(self, '_skip'))
	$VNControls.btn_settings.connect('pressed', Callable(self, '_settings'))
	
	next_blocking()


# advances to the next instruction that blocks the game, handling everything inbetween
func next_blocking():
	var instructions: Array = vm.to_next_blocking()
	
	for ins in instructions:
		if ins is TEScript.IPlaySong:
			Audio.play_song(ins.song_id, TE.defs.transitions[ins.transition_id].duration)
		
		elif ins is TEScript.IPlaySound:
			Audio.play_sound(ins.sound_id)
			
		elif ins is TEScript.INvl:
			_replace_view(nvl_view.instantiate())
		
		elif ins is TEScript.IAdv:
			_replace_view(adv_view.instantiate())
		
		else:
			push_error('cannot handle non-blocking instruction: %s' % [ins])
	
	var blocking = vm.next_blocking()
	if blocking is TEScript.IPause:
		$View.pause(blocking.duration)
		
	elif blocking is TEScript.IBlock:
		$View.show_block(Blocks.find(blocking.blockfile_id, blocking.block_id))
		_unhide_ui()
		
	elif blocking is TEScript.IBG:
		var tween = $VNStage.set_background(blocking.bg_id, TE.defs.transitions[blocking.transition_id])
		if tween != null:
			$View.wait_tween(tween)
			
	elif blocking is TEScript.IHideUI:
		var tween: Tween = _hide_ui(TE.defs.transitions[blocking.transition_id].duration)
		$View.wait_tween(tween)
		
	else:
		push_error('cannot handle blocking instruction: %s' % [blocking])


# replaces the current View with a new one, copying state over
func _replace_view(new_view: Node):
	var old_view: Node = $View
	
	var old_pos: int = get_children().find(old_view)
	remove_child(old_view)
	add_child(new_view)
	move_child(new_view, old_pos)
	
	new_view.name = old_view.name
	new_view.adjust_size($VNControls, TE.settings.gui_scale)
	$VNControls.btn_skip.toggle_mode = new_view.is_skip_toggleable()
	if old_view is View:
		new_view.copy_state_from(old_view as View)
	
	old_view.queue_free()


func _gui_scale_changed(scale: Settings.GUIScale):
	# needs to happen in this order to ensure View sees the updated VNControls size
	$VNControls._set_gui_size(scale)
	$View.adjust_size($VNControls, scale)


# hides the currently active View, returning the Tween used in the transition
func _hide_ui(duration: float) -> Tween:
	var tween = create_tween()
	tween.tween_property($View, 'modulate:a', 0.0, duration)
	return tween


# unhides the currently active View
func _unhide_ui():
	$View.modulate.a = 1.0


func _process(delta):
	# hack for some weird bullshit!	
	# sometimes end of 'game_advance_mouse' is not detected properly
	# this should help
	# TODO: was from old Godot 3 version, might be fixed now?
	if mouse_advancing and !Input.is_action_pressed('game_advance_mouse'):
		mouse_advancing = false
	
	if overlay_active:
		return
	
	# notify View of user input by calling either game_advanced or game_not_advanced
	if Input.is_action_pressed('game_advance_keys') or mouse_advancing:
		$View.game_advanced(delta)
	else:
		$View.game_not_advanced(delta)
	
	# move to next block, move to next line, or just update state is neither is requested
	
	if $View.is_next_block_requested():
		next_blocking()
		return
		
	if $View.is_next_line_requested():
		$View.next_line()
		return
	
	$View.update_state(delta)


# detect if mouse is held to advance the game
func _gui_input(event):
	if event.is_action_pressed('game_advance_mouse'):
		mouse_advancing = true
	if event.is_action_released('game_advance_mouse'):
		mouse_advancing = false


func before_overlay():
	overlay_active = true
	$VNControls.set_buttons_disabled(true)


func after_overlay():
	overlay_active = false
	$VNControls.set_buttons_disabled(false)


func _quit():
	var popup = Popups.warning_dialog(TE.ui_strings['game_quit_game'])
	popup.get_ok_button().connect('pressed', Callable(self, '_do_quit'))


func _do_quit():
	get_tree().quit()


func _skip():
	if $View.is_skip_toggleable():
		$View.skip_toggled($VNControls.btn_skip.button_pressed)
	else:
		$View.skip_pressed()


func _settings():
	var settings: SettingsOverlay = preload('res://tiger-engine/ui/screens/SettingsOverlay.tscn').instantiate()
	settings.language_disabled = true
	# TODO: considering enabling switching language in-game
	# probably requires restarting the current block, which could be too unsatisfying
	settings.animating_out_callback = func(): after_overlay()
	before_overlay()
	add_child(settings)
