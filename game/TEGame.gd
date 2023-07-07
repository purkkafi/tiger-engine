class_name TEGame extends Control
# main class for running the game
# handles user input and communication between different controls and objects
# that contain game state & lgoic


var vm: TEScriptVM # virtual machine that runs the game script
var rollback: Rollback # stores save states for Back button
var gamelog: Log # the game log
var context: GameContext # stores in-game variables
var next_rollback: Variant = null # next save state to add to rollback
var mouse_advancing: bool = false # whether game is being advanced by holding the mouse
var overlay_active: bool = false # whether there is an overlay and game should be paused
var last_save: Variant = null # last save state (may be null if game has not been saved)
var game_name: Variant = null # name of the game, can be set by the script and is visible in saves
var _custom_data: Dictionary = {} # persistent, game-specific custom save data
var last_skip_mode: View.SkipMode # skip mode of previous frame
var toast_queue: Array[Dictionary] # queue of toast notifications to show
var debug_mode: DebugMode = DebugMode.NONE # active debug overlay


enum DebugMode { NONE, AUDIO }


# sets the 'main' script in the given ScriptFile to be run
# call this before switching to the scene
func run_script(script_file: ScriptFile):
	if not 'main' in script_file.scripts:
		TE.log_error(TE.Error.SCRIPT_ERROR, "no 'main' script in %s, scriptfile probably doesn't support being run directly" % script_file.resource_path)
	vm = TEScriptVM.new(script_file, 'main')


func _ready():
	TE.ui_strings.translate(self)
	TETheme.connect('theme_changed', Callable(self, '_theme_changed'))
	
	rollback = Rollback.new($VNControls.btn_back)
	gamelog = Log.new()
	
	$VNControls.btn_quit.connect('pressed', Callable(self, '_quit'))
	$VNControls.btn_skip.connect('pressed', Callable(self, '_skip'))
	$VNControls.btn_settings.connect('pressed', Callable(self, '_settings'))
	$VNControls.btn_save.connect('pressed', Callable(self, '_save_load').bind(SavingOverlay.SavingMode.SAVE))
	$VNControls.btn_load.connect('pressed', Callable(self, '_save_load').bind(SavingOverlay.SavingMode.LOAD))
	$VNControls.btn_back.connect('pressed', Callable(self, '_back'))
	$VNControls.btn_log.connect('pressed', Callable(self, '_log'))
	
	%ToastClose.icon = get_theme_icon('close', 'Toast')
	%ToastClose.connect('mouse_entered', func(): %ToastClose.icon = get_theme_icon('close_hover', 'Toast'))
	%ToastClose.connect('mouse_exited', func(): %ToastClose.icon = get_theme_icon('close', 'Toast'))
	_adjust_toast_size()
	TE.connect('toast_notification', func(toast): toast_queue.append(toast))
	
	# no hide button on desktop
	if not TE.is_mobile():
		%MobileHideContainer.visible = false
	
	# initial View
	_replace_view(TE.defs.view_registry['adv'].instantiate())
	$View.initialize(View.InitContext.NEW_VIEW)
	
	# vm is null if game is being loaded from the save
	# and in that case, the call is not needed
	if vm != null:
		next_blocking()
	
	# fill default values of variables
	var var_names: Array[String] = []
	var var_values: Array[Variant] = []
	
	for _var in TE.defs.variables.keys():
		var_names.append(_var)
		var_values.append(TE.defs.variables[_var])
	
	context = GameContext.new(var_names, var_values)


# advances to the next instruction that blocks the game, handling everything inbetween
func next_blocking():
	var instructions: Array = vm.to_next_blocking()
	var tween: Tween = null
	var repeat_ids: Dictionary = {}
	
	if context != null and $View.result != null: # store the result of the current View
		context.view_result = $View.result
	
	# autoreplace the view with previous one if it was temporary
	if $View.is_temporary() and $View.previous_path != '':
		var saved_view = load($View.previous_path).instantiate()
		_replace_view(saved_view)
		saved_view.from_state($View.previous_state)
		saved_view.initialize(View.InitContext.NEW_VIEW)
	
	for ins in instructions:
		# check that same instruction isn't already active
		# (the user probably doesn't want to do this)
		if ins.repeat_id() in repeat_ids:
			push_error('illegal repeat of instruction %s: already handling' % ins)
		if ins.repeat_id() != '':
			repeat_ids[ins.repeat_id()] = true
		
		match ins.name:
			'PlaySong':
				Audio.play_song(ins.song_id, TE.defs.transition(ins.transition_id).duration)
			
			'PlaySound':
				Audio.play_sound(ins.sound_id)
			
			'Meta':
				game_name = TE.ui_strings[ins.game_name_uistring]
			
			'BG':
				tween = $VNStage.set_background(ins.bg_id, TE.defs.transition(ins.transition_id), tween)
			
			'FG':
				tween = $VNStage.set_foreground(ins.fg_id, TE.defs.transition(ins.transition_id), tween)
			
			'HideUI':
				tween = _hide_ui(TE.defs.transition(ins.transition_id).duration, tween)
			
			'Enter':
				tween = $VNStage.enter_sprite(ins.sprite, ins.at, ins.with, ins.by, tween)
			
			'Move':
				tween = $VNStage.move_sprite(ins.sprite, ins.to, ins.with, tween)
			
			'Show':
				tween = $VNStage.show_sprite(ins.sprite, ins._as, ins.with, tween)
			
			'Exit':
				tween = $VNStage.exit_sprite(ins.sprite, ins.with, tween)
			
			'ControlExpr':
				ControlExpr.exec(ins.string, context)
			
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
			var block: Block = Blocks.find(blocking.block_id)
			$View.show_block(block)
			_unhide_ui()
		
		'Break':
			pass
		
		'View':
			if blocking.view_id not in TE.defs.view_registry:
				TE.log_error(TE.Error.SCRIPT_ERROR, "unknown view or instruction: '%s'" % blocking.view_id)
				return
			var new_view: View = TE.defs.view_registry[blocking.view_id].instantiate()
			if len(blocking.options) != 0:
				new_view.game = self
				new_view.parse_options(blocking.options)
			_replace_view(new_view)
			new_view.initialize(View.InitContext.NEW_VIEW)
		
		'Jmp':
			if blocking.in_file == null:
				vm.jump_to(blocking.to)
			else:
				var scriptfile = Assets.scripts.get_resource(blocking.in_file + '.tef', 'res://assets/scripts')
				vm.jump_to_file(scriptfile, blocking.to)
		
		'JmpIf':
			var comp = ControlExpr.exec(blocking.condition, context)
			if comp is bool:
				if comp:
					vm.jump_to(blocking.to)
			else:
				TE.log_error(TE.Error.SCRIPT_ERROR, "condition {{ %s }} didn't resolve to bool, got %s" % [blocking.condition, comp])
			
		_:
			TE.log_error(TE.Error.SCRIPT_ERROR, 'cannot handle blocking instruction: %s' % [blocking])


# replaces the current View with a new one, copying state over
func _replace_view(new_view: Node):
	var old_view: Node = $View
	
	# save the result of this view
	if old_view is View and context != null:
		context.view_result = old_view.result
	
	var old_pos: int = get_children().find(old_view)
	remove_child(old_view)
	old_view.queue_free()
	add_child(new_view)
	move_child(new_view, old_pos)
	
	new_view.name = old_view.name
	new_view.game = self
	
	# store previous_path and previous_state for temporary views
	if new_view.is_temporary():
		# retain the original if multiple temporary Views are used in succession
		if old_view.is_temporary():
			new_view.previous_path = old_view.previous_path
			new_view.previous_state = old_view.previous_state
		else:
			new_view.previous_path = old_view._get_scene_path()
			new_view.previous_state = old_view.get_state()
	
	new_view.adjust_size($VNControls)
	
	update_skip_button()
	
	if old_view is View:
		new_view.copy_state_from(old_view as View)


func _theme_changed():
	_adjust_toast_size()
	# needs to happen in this order to ensure View sees the updated VNControls size
	$VNControls.adjust_size()
	$View.adjust_size($VNControls)


func _adjust_toast_size():
	%ToastIcon.custom_minimum_size.x = get_theme_constant('height', 'Toast')
	# BUG: Godot doesn't recalc the sizes of the controls for whatever reason
	# no idea how to fix, toggling visiblity etc didn't work :(
	%ToastPanel.custom_minimum_size = Vector2(
		get_theme_constant('width', 'Toast'),
		get_theme_constant('height', 'Toast')
	)


# updates the state of the toggle button according to the current View's skip mode
func update_skip_button():
	if $View.get_skip_mode() == View.SkipMode.DISABLED:
		$VNControls.btn_skip.set_pressed_no_signal(false)
		$VNControls.btn_skip.disabled = true
	else:
		$VNControls.btn_skip.disabled = false
		$VNControls.btn_skip.toggle_mode = $View.get_skip_mode() == View.SkipMode.TOGGLE


# hides the currently active View, returning the Tween used in the transition
# the tween can be given to chain it; it will be created if null is given
func _hide_ui(duration: float, tween: Tween) -> Tween:
	if tween == null:
		tween = create_tween()
	tween.parallel().tween_property($View, 'modulate:a', 0.0, duration)
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
	
	if debug_mode != DebugMode.NONE:
		update_debug_mode_text()
	
	if overlay_active:
		return
	
	if len(toast_queue) != 0 and not %ToastContainer.visible:
		show_toast(toast_queue.pop_front())
	
	if Input.is_action_just_pressed('game_screenshot'):
		take_user_screenshot()
	
	# hide is active while the key is being held down
	if Input.is_action_just_pressed('game_hide') or Input.is_action_just_released('game_hide'):
		toggle_user_hide()
	
	if Input.is_action_just_pressed('debug_toggle') and TE.is_debug():
		toggle_debug_mode()
		update_debug_mode_text()
	
	var skip_mode: View.SkipMode = $View.get_skip_mode()
	if skip_mode != last_skip_mode:
		update_skip_button()
		last_skip_mode = skip_mode
	
	# handle skipping via the keyboard shortcut
	if skip_mode == View.SkipMode.PRESS and Input.is_action_just_pressed('game_skip'):
		$VNControls.btn_skip.emit_signal('pressed')
	elif skip_mode == View.SkipMode.TOGGLE:
		if Input.is_action_just_pressed('game_skip') and not $VNControls.btn_skip.button_pressed:
			$VNControls.btn_skip.button_pressed = true
			$View.skip_toggled(true)
		elif Input.is_action_just_released('game_skip') and $VNControls.btn_skip.button_pressed:
			$VNControls.btn_skip.button_pressed = false
			$View.skip_toggled(false)
	
	# notify View of user input by calling either game_advanced or game_not_advanced
	if Input.is_action_pressed('game_advance_keys') or mouse_advancing:
		$View.game_advanced(delta)
	else:
		$View.game_not_advanced(delta)
	
	# move to next block, move to next line, or just update state if neither is requested
	
	if $View.is_next_block_requested() and not vm.is_end_of_script():
		next_blocking()
		return
		
	if $View.is_next_line_requested():
		$View.next_line()
		# current save state will be saved to rollback next time
		save_rollback()
		return
	
	if vm.is_end_of_script():
		if $View.is_next_block_requested():
			TE.switch_scene(load(TE.opts.title_screen).instantiate())
			return
	
	$View.update_state(delta)


# advances rollback, saving the current state for later and appending the
# previously saved state
func save_rollback():
	if next_rollback != null:
		rollback.push(next_rollback)
	next_rollback = create_save()


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
	TE.quit_game()


func _skip():
	if $View.get_skip_mode() == View.SkipMode.TOGGLE:
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
		overlay.screenshot = await take_save_screenshot()
		overlay.saved_callback = Callable(self, '_record_last_save')
	overlay.warn_about_progress = Savefile.is_progress_made(last_save, create_save())
	overlay.animating_out_callback = func(): after_overlay()
	before_overlay()
	add_child(overlay)


func _record_last_save(save: Dictionary):
	last_save = save


# produces a dict containing the current state
func create_save() -> Dictionary:
	var var_dict: Dictionary = {}
	for i in len(context.var_names):
		# only store variables that don't have their default values
		# this allows the game programmer to change the defaults later
		# without breaking old saves
		# (also saves some memory/processing time but that's not as important)
		if context.var_values[i] != TE.defs.variables[context.var_names[i]]:
			var_dict[context.var_names[i]] = context.var_values[i]
	
	var save = {
		'vm' : vm.get_state(),
		'view' : $View.get_state(),
		'stage' : $VNStage.get_state(),
		'variables' : var_dict,
		'view_result' : context.view_result,
		'game_name' : game_name,
		'game_version' : TE.opts.version_callback.call(),
		'song_id' : Audio.song_id,
		'save_name' : null,
		'save_datetime' : null, # these 2 should be handled by saving screen
		'save_utime' : null,
	}
	
	# do last to allow Views to write custom data during the get_state() call
	save['custom_data'] = _custom_data.duplicate(true)
	return save


# loads the game from the given save
# call this after switching the scene to TEGame
func load_save(save: Dictionary):
	last_save = save
	game_name = save['game_name']
	
	$VNStage.set_state(save['stage'])
	
	vm = TEScriptVM.from_state(save['vm'])
	context.view_result = save['view_result']
	
	# set variables
	var vars: Dictionary = save['variables']
	for var_name in vars.keys():
		context._assign(var_name, vars[var_name])
	
	# replace View with the correct scene first
	var view_scene = load(save['view']['scene'])
	if view_scene == null:
		TE.log_error(TE.Error.ENGINE_ERROR, 'cannot load View: %s' % save['view']['scene'], true)
		return
	
	# custom save data
	_custom_data = save['custom_data'].duplicate(true)
	
	var view = view_scene.instantiate()
	_replace_view(view)
	view.from_state(save['view'])
	view.initialize(View.InitContext.SAVESTATE)
	
	# keep song playing if it is currently playing
	if Audio.song_id != save['song_id']:
		Audio.play_song(save['song_id'], 0)
	
	# remember this save state in rollback
	next_rollback = save


func take_save_screenshot() -> Image:
	await RenderingServer.frame_post_draw
	var screenshot = get_viewport().get_texture().get_image()
	screenshot.convert(SavingOverlay.THUMB_FORMAT)
	screenshot.resize(SavingOverlay.THUMB_WIDTH, SavingOverlay.THUMB_HEIGHT, Image.INTERPOLATE_BILINEAR)
	return screenshot


func take_user_screenshot():
	await RenderingServer.frame_post_draw
	var screenshot: Image = get_viewport().get_texture().get_image()
	var path: String = ''
	var timestamp: String = Time.get_datetime_string_from_datetime_dict(Time.get_datetime_dict_from_system(), true)
	
	if OS.has_feature('editor'):
		path = ProjectSettings.globalize_path('res://')
	else:
		path = OS.get_executable_path().get_base_dir() + '/'
	path = path + timestamp + '.png'
	
	screenshot.save_png(path)
	print('Saved screenshot %s' % path)


func _back():
	TE.load_from_save(rollback.pop(), rollback, gamelog)


func _log():
	var log_overlay: LogOverlay = preload('res://tiger-engine/ui/screens/LogOverlay.tscn').instantiate()
	log_overlay.gamelog = gamelog
	log_overlay.animating_out_callback = func(): after_overlay()
	before_overlay()
	add_child(log_overlay)


# sets the custom data associated with the given key
func set_custom_data(key: String, value: Variant):
	_custom_data[key] = value


# returns whether custom data is associated with the given key
func has_custom_data(key: String):
	return key in _custom_data


# returns the custom data set with set_custom_data() or null if empty
func get_custom_data(key: String):
	return _custom_data[key]


# toggles whether VNControls and the view are hidden
func toggle_user_hide():
	var show: bool = not $VNControls.visible
	$VNControls.visible = show
	# modulate instead because visibility messes with the input events
	%MobileHideContainer.modulate = Color.WHITE if show else Color.TRANSPARENT
	
	var hidable_view_control = $View.get_hidable_control()
	if hidable_view_control != null:
		if hidable_view_control is Control:
			hidable_view_control.visible = show
		elif hidable_view_control is Array:
			for ctrl in hidable_view_control:
				ctrl.visible = show
		else:
			TE.log_error(TE.Error.ENGINE_ERROR, "toggle_hide() given '%s', not Control or Array" % hidable_view_control)


func show_toast(toast: Dictionary):
	%ToastContainer.visible = true
	%ToastContainer.modulate.a = 1.0
	%ToastText.text = toast['bbcode']
	%ToastClose.icon = get_theme_icon('close', 'Toast')
	
	if 'icon' in toast:
		%ToastIcon.custom_minimum_size.x = get_theme_constant('height', 'Toast')
		%ToastIcon.texture = load(toast['icon'])
	else:
		%ToastIcon.texture = null
		%ToastIcon.custom_minimum_size.x = 0
	
	var tween: Tween = %ToastContainer.create_tween()
	%ToastClose.connect('pressed', _toast_closed.bind(tween))
	
	# animate sliding in
	%ToastContainer.position.y = -%ToastContainer.size.y
	tween.tween_property(%ToastContainer, 'position:y', 0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# animate fading out
	tween.tween_property(%ToastContainer, 'modulate:a', 0.0, 1).set_delay(5)
	tween.tween_callback(func(): %ToastContainer.visible = false)
	tween.tween_callback(func(): %ToastClose.disconnect('pressed', _toast_closed))


func _toast_closed(tween: Tween):
	tween.set_speed_scale(INF)


func toggle_debug_mode():
	debug_mode = (debug_mode + 1 as DebugMode)
	if debug_mode >= len(DebugMode.values()):
		debug_mode = (0 as DebugMode)
	

func update_debug_mode_text():
	match debug_mode:
		DebugMode.NONE:
			%DebugMsg.text = ''
		DebugMode.AUDIO:
			%DebugMsg.text = Audio.debug_text()
