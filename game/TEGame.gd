class_name TEGame extends Control
# main class for running the game
# handles user input and communication between different controls and objects
# that contain game state & lgoic


var vm: TEScriptVM # virtual machine that runs the game script
var mouse_advancing: bool = false # whether game is being advanced by holding the mouse
# default views
var overlay_active: bool = false # whether there is an overlay and game should be paused
var last_save: Variant = null # last save state (may be null if game has not been saved)
var game_name: Variant = null # name of the game, can be set by the script and is visible in saves
var nvl_view = preload('res://tiger-engine/game/views/NVLView.tscn')
var adv_view = preload('res://tiger-engine/game/views/ADVView.tscn')


# sets the 'main' script in the given ScriptFile to be run
# call this before switching to the scene
func run_script(script_file: ScriptFile):
	vm = TEScriptVM.new(script_file, 'main')


func _ready():
	TE.ui_strings.translate(self)
	MobileUI.initialize_gui(self)
	MobileUI.connect('gui_scale_changed', Callable(self, '_gui_scale_changed'))
	
	$VNControls.btn_quit.connect('pressed', Callable(self, '_quit'))
	$VNControls.btn_skip.connect('pressed', Callable(self, '_skip'))
	$VNControls.btn_settings.connect('pressed', Callable(self, '_settings'))
	$VNControls.btn_save.connect('pressed', Callable(self, '_save_load').bind(SavingOverlay.SavingMode.SAVE))
	$VNControls.btn_load.connect('pressed', Callable(self, '_save_load').bind(SavingOverlay.SavingMode.LOAD))
	
	# vm is null if game is being loaded from the save
	# and in that case, the call is not needed
	if vm != null:
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
		
		elif ins is TEScript.IMeta:
			game_name = TE.ui_strings[ins.game_name_uistring]
		
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
	old_view.queue_free()
	add_child(new_view)
	move_child(new_view, old_pos)
	
	new_view.name = old_view.name
	new_view.adjust_size($VNControls, TE.settings.gui_scale)
	$VNControls.btn_skip.toggle_mode = new_view.is_skip_toggleable()
	if old_view is View:
		new_view.copy_state_from(old_view as View)


func _gui_scale_changed(gui_scale: Settings.GUIScale):
	# needs to happen in this order to ensure View sees the updated VNControls size
	$VNControls._set_gui_size(gui_scale)
	$View.adjust_size($VNControls, gui_scale)


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


func _save_load(mode):
	var overlay: SavingOverlay = preload('res://tiger-engine/ui/screens/SavingOverlay.tscn').instantiate()
	overlay.additional_navigation = true
	overlay.mode = mode
	if mode == SavingOverlay.SavingMode.SAVE:
		overlay.save = create_save()
		overlay.screenshot = await take_screenshot()
		overlay.saved_callback = Callable(self, '_record_last_save')
	overlay.warn_about_progress = Savefile.is_progress_made(last_save, create_save())
	overlay.animating_out_callback = func(): after_overlay()
	before_overlay()
	add_child(overlay)


func _record_last_save(save: Dictionary):
	last_save = save


# produces a dict containing the current state
func create_save() -> Dictionary:
	var save = {
		'vm' : vm.get_state(),
		'view' : $View.get_state(),
		'stage' : $VNStage.get_state(),
		'game_name' : game_name,
		'game_version' : TE.opts.version_callback.call(),
		'song_id' : Audio.song_id,
		'save_name' : null,
		'save_datetime' : null, # these 2 should be handled by saving screen
		'save_utime' : null
	}
	return save


# loads the game from the given save
# call this after switching the scene to TEGame
func load_save(save: Dictionary):
	last_save = save
	game_name = save['game_name']
	
	$VNStage.set_state(save['stage'])   
	
	vm = TEScriptVM.from_state(save['vm'])
	
	# replace View with the correct scene first
	var view_scene = load(save['view']['scene'])
	if view_scene == null:
		TE.log_error('cannot load View: %s' % save['view']['scene'])
		Popups.error_dialog(Popups.GameError.BAD_SAVE)
		return
	_replace_view(view_scene.instantiate())
	$View.from_state(save['view'])
	
	# keep song playing if it is currently playing
	if Audio.song_id != save['song_id']:
		Audio.play_song(save['song_id'], 0)


func take_screenshot() -> Image:
	await RenderingServer.frame_post_draw
	var screenshot = get_viewport().get_texture().get_image()
	screenshot.convert(SavingOverlay.THUMB_FORMAT)
	screenshot.resize(SavingOverlay.THUMB_WIDTH, SavingOverlay.THUMB_HEIGHT, Image.INTERPOLATE_BILINEAR)
	return screenshot