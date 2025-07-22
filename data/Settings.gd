class_name Settings extends RefCounted
# user-changeable settings
# TODO refactor misc persistent data into its own file


var music_volume: float # volume of music, in range [0, 1]
var sfx_volume: float # volume of sfx, in range [0, 1]
var text_speed: float # text speed, in range [0, 1]
var skip_speed: float # speed of skipping, in range [0, 1]
var dynamic_text_speed: bool # dynamic text speed on/off
var skip_unseen_text: bool # skip allowed even when reading new text
var fullscreen: bool # fullscreen on/off
var lang_id # language id; String or null if unset
# keyboard shortcuts; values should be dictionaries with keys 'keycode' and 'string'
var keys: Dictionary
var gui_scale: GUIScale # larger or smaller UI elements
var dyslexic_font: bool # whether dyslexia-friendly font is used
var audio_captions: bool # whether audio captions are on
var format: int # current format


# path of file where settings are stored
const SETTINGS_PATH: String = 'user://settings.cfg'
# properties that are not saved to disk
const TRANSIENT_PROPERTIES: Array[String] = [ 'RefCounted', 'script', 'Settings.gd' ]
# properties that have special handling when loaded
# (not automatically getting their default value if absent)
const NO_DEFAULT_PROPERTIES: Array[String] = [ 'lang_id', 'keys', 'format' ]
# available keyboard shortcuts and their default values
# every shortcut is saved as a dict of:
# – 'keycode', a Key
# – 'string', a string representing the key
# – 'shift', 'alt', 'ctrl', bools representing the modifiers
static var KEYBOARD_SHORTCUTS: Dictionary = {
	&'game_screenshot': {
		'keycode': KEY_S,
		'string': key_to_string(KEY_S),
		'shift': false, 'alt': false, 'ctrl': false },
	&'game_hide': {
		'keycode': KEY_H,
		'string': key_to_string(KEY_H),
		'shift': false, 'alt': false, 'ctrl': false },
	&'game_rollback': {
		'keycode': KEY_PAGEUP,
		'string': key_to_string(KEY_PAGEUP),
		'shift': false, 'alt': false, 'ctrl': false },
	&'game_rollforward': {
		'keycode': KEY_PAGEDOWN,
		'string': key_to_string(KEY_PAGEDOWN),
		'shift': false, 'alt': false, 'ctrl': false },
	&'game_skip': {
		'keycode': KEY_CTRL,
		'string': key_to_string(KEY_CTRL),
		'shift': false, 'alt': false, 'ctrl': false },
	&'debug_toggle': {
		'keycode': KEY_F1,
		'string': key_to_string(KEY_F1),
		'shift': false, 'alt': false, 'ctrl': false },
}
# current settings file format number
const SETTINGS_FORMAT: int = 1
# an illegal placeholder value for 'format', signifying that it is absent
const ILLEGAL_FORMAT: int = -1


enum GUIScale { NORMAL = 0, LARGE = 1 }


# makes changes to game state
func change_settings():
	Settings.change_music_volume(music_volume)
	Settings.change_sfx_volume(sfx_volume)
	Settings.change_fullscreen(fullscreen)
	Settings.change_language(lang_id)
	TETheme.force_change_settings(gui_scale, dyslexic_font)
	Settings.change_keyboard_shortcuts(keys)
	TE.captions.set_captions_on(audio_captions)


static func change_music_volume(vol_linear: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'), linear_to_db(vol_linear * 0.5))


static func change_sfx_volume(vol_linear: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('SFX'), linear_to_db(vol_linear * 0.5))


static func change_fullscreen(to_fullscreen: bool):
	# NOOP on web because toggling fullscreen doesn't work
	# NOOP on android because it messes with immersive mode
	if TE.is_web() or TE.is_mobile():
		return
	
	var is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN
	
	if is_fullscreen != to_fullscreen:
		var mode = DisplayServer.WINDOW_MODE_FULLSCREEN if (to_fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)


static func change_keyboard_shortcuts(_keys: Dictionary):
	for key in _keys:
		_setup_keyboard_shortcut(key, _keys[key])


static func _setup_keyboard_shortcut(eventName: String, data: Dictionary):
	InputMap.action_erase_events(eventName)
	var event = InputEventKey.new()
	event.keycode = data['keycode']
	event.shift_pressed = data['shift']
	event.alt_pressed = data['alt']
	event.ctrl_pressed = data['ctrl']
	InputMap.action_add_event(eventName, event)


# changes language unless the given id is the current language;
# returns whether it was changed
static func change_language(id: String):
	if TE.language == null or TE.language.id != id:
		for lang in TE.all_languages:
			if lang.id == id:
				TE.load_language(lang)
				return true
	return false


# writes settings to the disk (see SETTINGS_PATH)
# returns OK or error code
func save_to_file():
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	
	if file == null:
		TE.log_error(TE.Error.ENGINE_ERROR, 'cannot write settings: %d' % file.get_error())
		return file.get_error()
	
	file.store_line(JSON.stringify(_to_dict(), '  '))
	return OK


func _to_dict() -> Dictionary:
	var dict: Dictionary = {}
	
	for p in get_property_list():
		if p.name not in TRANSIENT_PROPERTIES:
			dict[p.name] = get(p.name)
	
	return dict


# reads settings from file; returns the Settings or an error code
# setting files containing an unsupported format number will not be loaded
# TODO: implement format conversion
static func load_from_file() -> Variant:
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	
	if file == null:
		return FileAccess.get_open_error()
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		TE.log_warning('settings file cannot be parsed')
		return FAILED
	
	# do not accept files that have an unsupported format
	if 'format' not in json.data:
		json.data['format'] = ILLEGAL_FORMAT
	if json.data['format'] != SETTINGS_FORMAT:
		TE.log_warning('settings file has an unsupported format, reverting to default settings')
		return FAILED
	
	return _of_dict(json.data)


# returns a Settings representing the options in the given dict
# missing values will be filled with default settings (see default_settings())
static func _of_dict(dict: Dictionary) -> Settings:
	var settings = Settings.new()
	var defaults = default_settings()
	
	for p in settings.get_property_list():
		if p.name not in TRANSIENT_PROPERTIES and p.name not in NO_DEFAULT_PROPERTIES:
			settings.set(p.name, dict.get(p.name, defaults[p.name]))
	
	# must be set, no possible default value
	settings.lang_id = dict['lang_id']
	settings.format = dict['format'] if 'format' in dict else ILLEGAL_FORMAT
	
	# include keys from default settings, overwriting them with whatever is in the given dict
	settings.keys = defaults['keys']
	settings.keys.merge(dict.get('keys', {}), true)
	
	return settings


static func default_settings():
	var defs = Settings.new()
	
	# volume defaults to 50 % on Windows
	if OS.get_name() == 'Windows':
		defs.music_volume = 0.5
		defs.sfx_volume = 0.5
	else:
		defs.music_volume = 1
		defs.sfx_volume = 1
	
	defs.text_speed = 0.5
	defs.skip_speed = 0.5
	defs.dynamic_text_speed = true
	defs.skip_unseen_text = false
	defs.fullscreen = false
	defs.lang_id = null # cannot provide sensible default
	defs.keys = KEYBOARD_SHORTCUTS.duplicate(true)
	defs.gui_scale = GUIScale.LARGE if TE.is_mobile() else GUIScale.NORMAL
	defs.dyslexic_font = false
	defs.audio_captions = false
	defs.format = SETTINGS_FORMAT
	
	return defs


# converts a Key constant or an InputEventKey to a standardized string
static func key_to_string(key: Variant) -> String:
	if key is Key:
		return OS.get_keycode_string(key)
	elif key is InputEventKey:
		# if there is a usable, non-letter unicode character, use it
		if key.unicode != 0 and char(key.unicode).to_upper() == char(key.unicode).to_lower():
			return char(key.unicode)
		else:
			# else default to Godot-provided string
			# need to use this with letters to handle modifiers gracefully
			return OS.get_keycode_string(key.get_key_label_with_modifiers())
	
	push_error("key_to_string() expected Key or InputEventKey, got '%s'" % key)
	return ''
