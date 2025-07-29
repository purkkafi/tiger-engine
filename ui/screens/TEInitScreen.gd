class_name TEInitScreen extends ColorRect
# the first scene the engine loads
# responsible for reading configuration files and settings and
# displaying the language choice if game is booted for the first time;
# otherwise, the title screen will be displayed


# alternate scene to possibly load based on cmd args; Node or null
var instead_scene: Variant


func _ready():
	instead_scene = CmdArgs.handle_args()
	# TODO: handle instead_scene immediately instead of waiting for user input
	
	# rebuild UI if the user drops in a language pack
	TE.languages_changed.connect(display_language_choice)
	
	# load default theme or use an empty theme if not specified
	if TE.opts.default_theme != null:
		TETheme.set_theme(TE.opts.default_theme)
	
	# set initial window settings
	self.color = TETheme.background_color
	get_window().min_size = Vector2i(962, 542)
	
	# setup basic actions in input map
	VNInput.register_actions()
	
	# setup events for keyboard shortcuts
	for shortcut in Settings.KEYBOARD_SHORTCUTS.keys():
		InputMap.add_action(shortcut)
	
	# setup view registry
	TE.defs.view_registry['nvl'] = preload('res://tiger-engine/game/views/NVLView.tscn')
	TE.defs.view_registry['adv'] = preload('res://tiger-engine/game/views/ADVView.tscn')
	TE.defs.view_registry['input'] = preload('res://tiger-engine/game/views/InputView.tscn')
	TE.defs.view_registry['choice'] = preload('res://tiger-engine/game/views/ChoiceView.tscn')
	TE.defs.view_registry['cutscene'] = preload('res://tiger-engine/game/views/CutsceneView.tscn')
	TE.defs.view_registry['continue_point'] = preload('res://tiger-engine/game/views/ContinuePointView.tscn')
	
	# setup sprite object registry
	TE.defs.sprite_object_registry['simple_sprite'] = preload('res://tiger-engine/game/sprites/SimpleSprite.gd')
	TE.defs.sprite_object_registry['composite_sprite'] = preload('res://tiger-engine/game/sprites/CompositeSprite.gd')
	
	# install custom views
	for custom_view in TE.opts.custom_views:
		TE.defs.view_registry[custom_view] = load(TE.opts.custom_views[custom_view])
	
	# allow user to drag-and-drop mods & load them immediately
	TE.mod_files_dropped.connect(_files_dropped)
	
	# if specified in cmd args, execute non-game scene
	if instead_scene != null:
		TE.switch_scene(instead_scene as Node)
		return
	
	# if settings file exists, read it and switch to the specified language
	var loaded_settings = null if TE.ignore_settings else Settings.load_from_file()
	if loaded_settings is Settings:
		TE.settings = loaded_settings
		# save immediately in case settings were modified due to
		# the file being from an older version of the game
		TE.settings.save_to_file()
		TE.settings.change_settings()
		
		if TE.language == null:
			# couldn't load language, possibly as a result of it being in
			# a since-deleted language pack
			display_language_choice.call_deferred()
		else:
			_next_screen.call_deferred()
	else: # settings file not found
		# setup default settings and show the user the language choice
		TE.settings = Settings.default_settings()
		display_language_choice.call_deferred()
	
	# unlock auto-unlocks possibly not unlocked
	for id in TE.defs.unlocked_from_start:
		TE.persistent.unlock(id, true)


# changes to the appropriate next scene
func _next_screen():
	if TE.opts.splash_screen != null: # go to splash screen if specified
		TE.switch_scene(load(TE.opts.splash_screen).instantiate())
	else: # by default go to the title screen
		TE.switch_scene(Assets.noncached.get_resource(TE.opts.title_screen).instantiate())


func display_language_choice():
	# refresh list if displaying after user drops in translation package
	var previously_focused: String = ''
	for child in $LanguageOptions.get_children():
		if child.has_focus():
			previously_focused = child.get_meta('lang_id')
		$LanguageOptions.remove_child(child)
		child.queue_free()
	
	for lang in TE.all_languages:
		var btn = Button.new()
		
		btn.text = lang.full_name()
		btn.set_meta('lang_id', lang.id)
		
		if lang.icon_path != null:
			btn.icon = load(lang.icon_path) as Texture2D
		
		btn.set_h_size_flags(Control.SIZE_SHRINK_CENTER) 
		btn.connect('pressed', _language_selected.bind(lang))
		
		$LanguageOptions.add_child(btn)
	
	# grab focus, defaulting to the top entry
	if previously_focused == '':
		$LanguageOptions.get_child(0).grab_focus()
	else:
		for btn in $LanguageOptions.get_children():
			if btn.get_meta('lang_id') == previously_focused:
				btn.grab_focus()
	
	# set all to equal width
	var max_size: int = -1
	for btn in $LanguageOptions.get_children():
		max_size = max(max_size, btn.size.x)
	for btn in $LanguageOptions.get_children():
		btn.custom_minimum_size.x = max_size


func _language_selected(selected: Lang):
	TE.load_language(selected)
	TE.settings.lang_id = selected.id
	TE.settings.save_to_file()
	_next_screen()


func _change_mods_supported() -> bool:
	return true


func _files_dropped(files: Array[String]):
	TE.load_mods(files)


# clear signals
func _exit_tree():
	TE.languages_changed.disconnect(display_language_choice)
	TE.mod_files_dropped.disconnect(_files_dropped)
