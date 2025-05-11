class_name TEGame extends Control
# main class for running the game
# handles user input and communication between different controls and objects
# that contain game state & lgoic


var vm: TEScriptVM # virtual machine that runs the game script
var rollback: Rollback # stores save states for Back button
var gamelog: Log # the game log
var context: InGameContext # stores in-game variables
var next_rollback: Variant = null # next save state to add to rollback
var advancing: bool = false # whether game is being advanced by mouse or keys
var overlay_active: bool = false # whether there is an overlay and game should be paused
var last_save: Variant = null # last save state (may be null if game has not been saved)
var game_name: Variant = null # name of the game, can be set by the script and is visible in saves
var _custom_data: Dictionary = {} # persistent, game-specific custom save data
var debug_mode: DebugMode = DebugMode.NONE # active debug overlay
var focus_now: WeakRef # control that last had focus
var tabbing: bool = false # whether user is navigating buttons by tabbing
var focus_before_overlay: Control # the Control that had focus before an overlay was spawned
var custom_controls: Variant = null # custom controls or null if not specified
var user_hiding: bool = false # whether user is hiding game UI with H key


enum DebugMode { NONE, AUDIO, SPRITES }


# sets the 'main' script in the given ScriptFile to be run
# call this before switching to the scene
func run_script(script_file: ScriptFile):
	vm = TEScriptVM.new(script_file, 'main')


func _ready():
	TE.localize.translate(self)
	TETheme.connect('theme_changed', _theme_changed)
	
	get_viewport().connect('gui_focus_changed', _gui_focus_changed)
	grab_focus()
	
	rollback = Rollback.new($VNControls.btn_back)
	gamelog = Log.new()
	
	$VNControls.btn_back.connect('pressed', _back)
	$VNControls.btn_save.connect('pressed', _save_load.bind(SavingOverlay.SavingMode.SAVE))
	$VNControls.btn_load.connect('pressed', _save_load.bind(SavingOverlay.SavingMode.LOAD))
	$VNControls.btn_log.connect('pressed', _log)
	$VNControls.btn_skip.connect('pressed', _skip)
	$VNControls.btn_settings.connect('pressed', _settings)
	$VNControls.btn_quit.connect('pressed', _quit)
	
	# add custom controls, if specified
	if TE.opts.ingame_custom_controls != null:
		custom_controls = load(TE.opts.ingame_custom_controls).instantiate()
		custom_controls.game = self
		add_child(custom_controls)
	
	# fill default values of variables
	var var_names: Array[String] = []
	var var_values: Array[Variant] = []
	
	for _var in TE.defs.variables.keys():
		var_names.append(_var)
		var_values.append(TE.defs.variables[_var])
	
	context = InGameContext.new(var_names, var_values, self)
	
	# initial View
	_replace_view(TE.defs.view_registry['adv'].instantiate())
	$View.initialize(View.InitContext.NEW_VIEW)
	
	# vm is null if game is being loaded from the save
	# and in that case, the call is not needed
	if vm != null and vm.current_script != null:
		next_blocking()


func _gui_focus_changed(ctrl: Control):
	focus_now = weakref(ctrl);
	
	# clear tabbing state when focus moves back to game
	if ctrl == self:
		tabbing = false
	
	# don't allow disabled buttons to gain focus unless explicitly tabbing
	if not tabbing and ctrl is Button and ctrl.disabled:
		self.grab_focus()


# advances to the next instruction that blocks the game, handling everything inbetween
func next_blocking():
	var instructions: Array = vm.to_next_blocking()
	var tween: Tween = null
	var repeat_ids: Dictionary = {}
	
	if context != null and $View.result != null: # store the result of the current View
		context.view_result = $View.result
	
	# autoreplace the view with previous one if it was temporary
	if $View.is_temporary() and $View.previous_state != null:
		# save this here before View is replaced
		var previous_state: Dictionary = $View.previous_state
		var saved_view = load(previous_state['scene']).instantiate()
		_replace_view(saved_view)
		saved_view.from_state(previous_state)
		saved_view.initialize(View.InitContext.NEW_VIEW)
	
	# whether ui is being hidden with HideUI instruction
	var hiding_ui: bool = false
	
	for ins in instructions:
		# check that same instruction isn't already active
		# (the user probably doesn't want to do this)
		if ins.repeat_id() in repeat_ids:
			push_error("illegal repeat of instruction '%s': already handling" % ins)
		if ins.repeat_id() != '':
			repeat_ids[ins.repeat_id()] = true
		
		match ins.name:
			'Music':
				TE.audio.play_song(ins.song_id, TE.defs.transition(ins.transition_id).duration, ins.local_volume)
			
			'Sound':
				TE.audio.play_sound(ins.sound_id)
			
			'Meta':
				game_name = TE.localize[ins.game_name_uistring]
			
			'BG':
				tween = $VNStage.set_background(ins.bg_id, ins.transition_id, tween)
			
			'FG':
				tween = $VNStage.set_foreground(ins.fg_id, ins.transition_id, tween)
			
			'HideUI':
				hiding_ui = true
				# TODO: use other transition data than just the duration?
				tween = _hide_ui(TE.defs.transition(ins.transition_id).duration, tween)
			
			'Enter':
				tween = $VNStage.enter_sprite(ins.sprite, ins._as, ins.at_x, ins.at_y, ins.at_zoom, ins.at_order, ins.with, ins.by, tween)
			
			'Move':
				tween = $VNStage.move_sprite(ins.sprite, ins.to_x, ins.to_y, ins.to_zoom, ins.to_order, ins.with, tween)
			
			'Show':
				tween = $VNStage.show_sprite(ins.sprite, ins._as, ins.with, tween)
			
			'Exit':
				tween = $VNStage.exit_sprite(ins.sprite, ins.with, tween)
			
			'ControlExpr':
				ControlExpr.exec(ins.string, context)
			
			'Vfx':
				tween = $VNStage.add_vfx(ins.vfx, ins.to, ins._as, ins.initial_state, tween)
			
			'SetVfx':
				tween = $VNStage.set_vfx_state(ins.id, ins.state, tween)
			
			'ClearVfx':
				tween = $VNStage.clear_vfx(ins.id, tween)
			
			_:
				push_error('cannot handle non-blocking instruction: %s' % [ins])
	
	# if any instruction activated the tween, handle it
	if tween != null:
		# dummy callback so that Godot doesn't complain about an empty tween
		# if we're only doing instanteous things
		tween.parallel().tween_callback(func(): pass)
		
		$View.wait_tween(tween)
		
		# make sure to hide ui even if HideUI instruction was not present
		if not hiding_ui:
			_hide_ui(0, null)
		
		return
	
	# else: handle the next blocking instruction
	var blocking = vm.next_blocking()
	match blocking.name:
		'Pause':
			var duration: float = TE.defs.transition((blocking as TEScript.IPause).transition).duration
			$View.pause(duration)
		
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
			new_view.game = self
			
			if len(blocking.options) != 0:
				new_view.parse_options(blocking.options)
			
			if not new_view.cancel_replacement():
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
	
	# store  previous_state for temporary views
	if new_view.is_temporary():
		# retain the original state if multiple temporary Views are used in succession
		if old_view.is_temporary():
			new_view.previous_state = old_view.previous_state
		else:
			var state: Dictionary = old_view.get_state()
			# TODO: this is a temporary hack
			# need to rearchitecture the thing to be able to produce states
			# that do not store block information
			state.erase('block')
			state.erase('blockfile')
			new_view.previous_state = state
	
	new_view.adjust_size($VNControls)
	
	if old_view is View:
		new_view.copy_state_from(old_view as View)


func _theme_changed():
	%ToastContainer._adjust_toast_size()
	# needs to happen in this order to ensure View sees the updated VNControls size
	$VNControls.adjust_size()
	$View.adjust_size($VNControls)


# updates the state of the toggle button according to the current View's skip mode
# and speedup_enabled
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
		tween.set_parallel(true)
	tween.tween_property($View, 'modulate:a', 0.0, duration)
	return tween


# unhides the currently active View
func _unhide_ui():
	$View.modulate.a = 1.0


func _unhandled_key_input(event):
	if event.is_action_pressed('game_screenshot', false, true):
		take_user_screenshot()
	
	# hide when key pressed
	if event.is_action_pressed('game_hide', false, true) and not user_hiding:
		toggle_user_hide()
	
	# show when key released
	if event.is_action_released('game_hide', true) and user_hiding:
		toggle_user_hide()
	
	if event.is_action_pressed('debug_toggle', false, true) and TE.is_debug():
		toggle_debug_mode()
		update_debug_mode_text()


func _process(delta):
	# alert on script errors
	while len(vm.errors) != 0:
		TE.log_error(TE.Error.SCRIPT_ERROR, vm.errors.pop_front())
		return
	
	# hack for some weird bullshit!	
	# sometimes end of 'game_advance_mouse' is not detected properly
	# this should help
	# TODO: was from old Godot 3 version, might be fixed now?
	if advancing and !(Input.is_action_pressed('game_advance_mouse') or Input.is_action_pressed('game_advance_keys')):
		advancing = false
	
	if debug_mode != DebugMode.NONE:
		update_debug_mode_text()
	
	if overlay_active:
		return
	
	if focus_now.get_ref() == null: # return focus to TEGame if it was lost
		grab_focus()
	
	var skip_mode: View.SkipMode = $View.get_skip_mode()
	
	# handle skipping via the keyboard shortcut
	if skip_mode == View.SkipMode.PRESS and Input.is_action_just_pressed('game_skip', true):
		$VNControls.btn_skip.emit_signal('pressed')
	elif skip_mode == View.SkipMode.TOGGLE:
		if Input.is_action_just_pressed('game_skip', true) and not $VNControls.btn_skip.button_pressed:
			$VNControls.btn_skip.button_pressed = true
			$View.skip_toggled(true)
		elif Input.is_action_just_released('game_skip', true) and $VNControls.btn_skip.button_pressed:
			$VNControls.btn_skip.button_pressed = false
			$View.skip_toggled(false)
	
	# notify View of user input by calling either game_advanced or game_not_advanced
	if advancing:
		$View.game_advanced(delta)
	else:
		$View.game_not_advanced(delta)
	
	# move to next block and/or move to next line, or just update state if neither is requested
	if $View.is_next_block_requested() and not vm.is_end_of_script():
		next_blocking()
		# also do the initial line
		if $View.is_next_line_requested():
			$View.next_line()
			save_rollback()
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
	# the button flickers less if it's only updated here
	update_skip_button()


# advances rollback, saving the current state for later and appending the
# previously saved state
func save_rollback():
	if next_rollback != null:
		rollback.push(next_rollback)
	next_rollback = create_save()


# detect if mouse is held to advance the game
func _gui_input(event):
	if event.is_action_pressed('game_advance_mouse') or event.is_action_pressed('game_advance_keys'):
		advancing = true
	if event.is_action_released('game_advance_mouse') or event.is_action_released('game_advance_keys'):
		advancing = false
	if event is InputEventKey and event.pressed and event.keycode == KEY_TAB:
		tabbing = true


func before_overlay():
	TE.emit_signal('overlay_opened')
	
	overlay_active = true
	self.focus_mode = Control.FOCUS_NONE
	if custom_controls != null:
		custom_controls.set_disabled(true)
	$VNControls.set_buttons_disabled(true)
	focus_before_overlay = focus_now.get_ref()


func after_overlay():
	TE.emit_signal('overlay_closed')
	
	overlay_active = false
	self.focus_mode = Control.FOCUS_ALL
	if custom_controls != null:
		custom_controls.set_disabled(false)
	$VNControls.set_buttons_disabled(false)
	if tabbing:
		focus_before_overlay.grab_focus()


func _quit():
	before_overlay()
	
	var popup = Popups.warning_dialog(TE.localize['game_quit_game'])
	popup.wrap_controls = true
	
	popup.get_ok_button().text = TE.localize.general_quit
	popup.get_ok_button().theme_type_variation = 'DangerButton'
	popup.add_button(TE.localize.general_to_title, true, 'to_title').theme_type_variation = 'DangerButton'
	
	popup.connect('canceled', _quit_cancel_pressed)
	popup.connect('confirmed', TE.quit_game)
	popup.connect('custom_action', _quit_to_title_pressed)
	
	if TE.is_web():
		popup.get_ok_button().hide()
	
	# HORRIBLE HACK: set min_size to an approximation manually because Godot didn't want to
	# resize the dialog automatically for some reason
	var min_width: float = 40
	var panel_style: StyleBox = get_theme_stylebox('panel', 'PanelContainer')
	min_width += panel_style.get_margin(SIDE_LEFT) + panel_style.get_margin(SIDE_RIGHT)
	for popup_child in popup.get_children(true):
		if popup_child is HBoxContainer:
			for btn in popup_child.get_children():
				min_width += btn.size.x
				min_width += get_theme_constant('separation', 'HBoxContainer')
	popup.min_size = Vector2(min_width, 10)
	
	popup.popup_centered()


func _quit_to_title_pressed(action: String):
	if action == 'to_title':
		TE.switch_scene(load(TE.opts.title_screen).instantiate())


func _quit_cancel_pressed():
	after_overlay()
	if not tabbing:
		self.grab_focus()


func _skip():
	if $View.get_skip_mode() == View.SkipMode.TOGGLE:
		$View.skip_toggled($VNControls.btn_skip.button_pressed)
	else:
		$View.skip_pressed()
	
	if not tabbing:
		self.grab_focus()


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
		'variables' : var_dict,
		'view_result' : context.view_result,
		'game_name' : game_name,
		'game_version' : TE.opts.version_callback.call(),
		'audio' : TE.audio.get_state(),
		'save_name' : null,
		'save_datetime' : null, # these 2 should be handled by saving screen
		'save_utime' : null,
	}
	
	# save VM, View, and Stage state if the save does not refer to a continue point
	if $View.continue_point() == null:
		save['vm'] = vm.get_state()
		save['view'] = $View.get_state()
		save['stage'] = $VNStage.get_state()
	else: # otherwise, save just the continue point
		save['continue_point'] = $View.continue_point()
	
	# do last to allow Views to write custom data during the get_state() call
	save['custom_data'] = _custom_data.duplicate(true)
	return save


# jumps to a continue point, also clearing the stage
func jump_to_continue_point(continue_point: String):
	vm = TEScriptVM.from_continue_point(continue_point)
	$VNStage.clear()


# loads the game from the given save
# call this after switching the scene to TEGame
func load_save(save: Dictionary, stage_cache: Dictionary):
	last_save = save
	game_name = save['game_name']
	
	context.view_result = save['view_result']
	
	# set variables
	var vars: Dictionary = save['variables']
	for var_name in vars.keys():
		context._assign(var_name, vars[var_name])
	
	# custom save data
	_custom_data = save['custom_data'].duplicate(true)
	
	TE.audio.set_state(save['audio'])
	
	# if starting from a continue point, skip rest of the initialization
	if 'continue_point' in save:
		jump_to_continue_point(save['continue_point'])
		return
	
	# otherwise, initialize state normally
	vm = TEScriptVM.from_state(save['vm'])
	$VNStage.set_state(save['stage'], stage_cache)
	
	# replace View with the correct scene first
	var view_scene = load(save['view']['scene'])
	if view_scene == null:
		TE.log_error(TE.Error.ENGINE_ERROR, 'cannot load View: %s' % save['view']['scene'], true)
		return
	
	var view = view_scene.instantiate()
	_replace_view(view)
	view.from_state(save['view'])
	view.initialize(View.InitContext.SAVESTATE)
	
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
	TE.log_info("Saved screenshot: '%s'" % path)


func _back():
	# TODO implement caching for expensive View instances
	TE.load_from_save(rollback.pop(), rollback, gamelog, $VNStage.get_node_cache())


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
	user_hiding = not user_hiding
	
	$VNControls.visible = !user_hiding
	if custom_controls != null:
		custom_controls.set_hidden(user_hiding)
	
	var hidable_view_control = $View.get_hidable_control()
	if hidable_view_control != null:
		if hidable_view_control is Control:
			hidable_view_control.visible = !user_hiding
		elif hidable_view_control is Array:
			for ctrl in hidable_view_control:
				(ctrl as Control).visible = !user_hiding
		else:
			TE.log_error(TE.Error.ENGINE_ERROR, "View.get_hidable_control() returned '%s', not Control or Array" % hidable_view_control)


func toggle_debug_mode():
	debug_mode = (debug_mode + 1 as DebugMode)
	
	if debug_mode >= len(DebugMode.values()):
		debug_mode = (0 as DebugMode)
	
	if debug_mode == DebugMode.SPRITES:
		TE.draw_debug = true
	else:
		TE.draw_debug = false


func update_debug_mode_text():
	match debug_mode:
		DebugMode.NONE:
			%DebugMsg.text = ''
		DebugMode.AUDIO:
			%DebugMsg.text = TE.audio.debug_text()
		DebugMode.SPRITES:
			%DebugMsg.text = $VNStage._sprite_debug_msg()


func stage() -> VNStage:
	return $VNStage
