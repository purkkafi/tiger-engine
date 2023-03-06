class_name TEInitScreen extends ColorRect
# the first scene the engine loads
# responsible for reading configuration files and settings and
# displaying the language choice if game is booted for the first time;
# otherwise, the title screen will be displayed


var title_screen: PackedScene = load(Global.options.title_screen)


func _ready():
	# run tests instead of launching game if cmd line arg is passed
	if OS.get_cmdline_user_args() == PackedStringArray(['--run-tests']):
		get_tree().quit(TestRunner.run_tests())
	
	self.color = Global.options.init_color
	
	# set initial window settings
	get_window().min_size = Vector2i(962, 542)
	get_window().set_title('')
	
	# load translation package from the file 'translation.zip' if it exists
	if FileAccess.file_exists('res://translation.zip'):
		var result = ProjectSettings.load_resource_pack('res://translation.zip', true)
		Global.log_info('translation package loaded, ok: ' + str(result))
	
	# read language options
	Global.all_languages = TEInitScreen.get_languages()
	
	# if settings file exists, read it and switch to the specified language
	if Settings.has_settings_file():
		Global.settings = Settings.load_from_file()
		Global.settings.change_settings()
		
		for lang in Global.all_languages:
			if lang.id == Global.settings.lang_id:
				Global.switch_language(lang)
				Global.switch_scene(title_screen.instantiate())
				return
		
		Global.log_error('language specified in settings not found: %s' % [Global.settings.lang_id])
	else:
		# setup default settings and show the user the language choice
		Global.settings = Settings.default_settings()
		display_language_choice()


func display_language_choice():
	for lang in Global.all_languages:
		var btn = Button.new()
		btn.text = lang.full_name()
		btn.set_h_size_flags(Control.SIZE_SHRINK_CENTER) 
		btn.connect('pressed', Callable(self, '_language_selected').bind(lang))
		
		$LanguageOptions.add_child(btn)


func _language_selected(selected):
	Global.switch_language(selected)
	Global.settings.save_to_file()
	Global.switch_scene(title_screen.instantiate())


# returns all defined languages
# if user's locale matches a language, it's returned first;
# the rest are sorted alphabetically
static func get_languages():
	var lang_path = 'res://assets/lang'
	
	var langs_folder := DirAccess.open(lang_path)
	if langs_folder == null:
		push_error('cannot open %s' % [lang_path])
		return
	
	var found = []
	for folder in langs_folder.get_directories():
		var lang: Lang = load(lang_path + '/' + folder + '/lang.tef')
		lang.id = folder
		lang.path = lang_path + '/' + folder
		
		found.append(lang)

	# sort found languages, preferring the one matching user's locale
	var locale = OS.get_locale_language()
	var preferred = null
	
	for lang in found:
		if lang.id == locale:
			preferred = lang
			found.remove_at(found.find(lang))
	
	found.sort_custom(Callable(TEInitScreen, '_sort_language'))
	
	if preferred != null:
		found.insert(0, preferred)
	
	return found


static func _sort_language(lang1: Lang, lang2: Lang) -> bool:
	return lang2.name > lang1.name
