class_name TEGame extends Control
# main class for running the game
# handles user input and communication between different controls and objects
# that contain game state & lgoic


var vm: TEScriptVM # virtual machine that runs the game script
var rollback: Rollback # stores save states for Back button
var gamelog: Log # the game log
var next_rollback: Variant = null # next save state to add to rollback
var mouse_advancing: bool = false # whether game is being advanced by holding the mouse
var overlay_active: bool = false # whether there is an overlay and game should be paused
var last_save: Variant = null # last save state (may be null if game has not been saved)
var game_name: Variant = null # name of the game, can be set by the script and is visible in saves
# default views
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
	
	rollback = Rollback.new($VNControls.btn_back)
	gamelog = Log.new()
	
	$VNControls.btn_quit.connect('pressed', Callable(self, '_quit'))
	$VNControls.btn_skip.connect('pressed', Callable(self, '_skip'))
	$VNControls.btn_settings.connect('pressed', Callable(self, '_settings'))
	$VNControls.btn_save.connect('pressed', Callable(self, '_save_load').bind(SavingOverlay.SavingMode.SAVE))
	$VNControls.btn_load.connect('pressed', Callable(self, '_save_load').bind(SavingOverlay.SavingMode.LOAD))
	$VNControls.btn_back.connect('pressed', Callable(self, '_back'))
	$VNControls.btn_log.connect('pressed', Callable(self, '_log'))
	
	# initial View
	_replace_view(adv_view.instantiate())
	
	# vm is null if game is being loaded from the save
	# and in that case, the call is not needed
	if vm != null:
		next_blocking()


# advances to the next instruction that blocks the game, handling everything inbetween
func next_blocking():
	var instructions: Array = vm.to_next_blocking()
	var tween: Tween = null
	var ins_types: Dictionary = {}
	
	for ins in instructions:
		# check that same instruction isn't already active
		# (there can be problems with repeating instructions)
		if ins.name in ins_types:
			push_error('illegal instruction %s: already handling of same type' % ins)
		ins_types[ins.name] = true
		
		match ins.name:
			'PlaySong':
				Audio.play_song(ins.song_id, TE.defs.transitions[ins.transition_id].duration)
			
			'PlaySound':
				Audio.play_sound(ins.sound_id)
			
			'Meta':
				game_name = TE.ui_strings[ins.game_name_uistring]
			
			'BG':
				tween = $VNStage.set_background(ins.bg_id, TE.defs.transitions[ins.transition_id], tween)
			
			'FG':
				tween = $VNStage.set_foreground(ins.fg_id, TE.defs.transitions[ins.transition_id], tween)
			
			'HideUI':
				tween = _hide_ui(TE.defs.transitions[ins.transition_id].duration, tween)
			
			_:
				push_error('cannot handle non-blocking instruction: %s' % [ins])
	
	# if any instruction activated the tween, handle it
	if tween != null:
		$View.wait_tween(tween)
		return
	
	# else: handle the next blocking instruction
	var blocking = vm.next_blocking()
	match blocking.name:
		'Pause':
			$View.pause(blocking.duration)
		
		'Block':
			$View.show_block(Blocks.find(blocking.blockfile_id, blocking.block_id))
			_unhide_ui()
		
		'Break':
			pass
		
		'Nvl':
			var nvl = nvl_view.instantiate()
			nvl.options = blocking.options
			_replace_view(nvl)
		
		'Adv':
			_replace_view(adv_view.instantiate())
			
		_:
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
	new_view.gamelog = gamelog
	new_view.adjust_size($VNControls, TE.settings.gui_scale)
	$VNControls.btn_skip.toggle_mode = new_view.is_skip_toggleable()
	if old_view is View:
		new_view.copy_state_from(old_view as View)


func _gui_scale_changed(gui_scale: Settings.GUIScale):
	# needs to happen in this order to ensure View sees the updated VNControls size
	$VNControls._set_gui_size(gui_scale)
	$View.adjust_size($VNControls, gui_scale)


# hides the currently active View, returning the Tween used in the transition
# the tween can be given to chain it; it will be created if null is given
func _hide_ui(duration: float, tween: Tween) -> Tween:
	if tween == null:
		tween = create_tween()
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
		# current save state will be saved to rollback next time
		if next_rollback != null:
			rollback.push(next_rollback)
		next_rollback = create_save()
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
	
	# remember this save state in rollback
	next_rollback = save


func take_screenshot() -> Image:
	await RenderingServer.frame_post_draw
	var screenshot = get_viewport().get_texture().get_image()
	screenshot.convert(SavingOverlay.THUMB_FORMAT)
	screenshot.resize(SavingOverlay.THUMB_WIDTH, SavingOverlay.THUMB_HEIGHT, Image.INTERPOLATE_BILINEAR)
	return screenshot


func _back():
	TE.load_from_save(rollback.pop(), rollback, gamelog)


func _log():
	var log_overlay: LogOverlay = preload('res://tiger-engine/ui/screens/LogOverlay.tscn').instantiate()
	log_overlay.gamelog = gamelog
	log_overlay.animating_out_callback = func(): after_overlay()
	before_overlay()
	add_child(log_overlay)
