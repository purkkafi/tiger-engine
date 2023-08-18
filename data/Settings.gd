class_name Settings extends RefCounted
# user-changeable settings


var music_volume: float # volume of music, in range [0, 1]
var sfx_volume: float # volume of sfx, in range [0, 1]
var text_speed: float # text speed, in range [0, 1]
var dynamic_text_speed: bool # dynamic text speed on/off
var fullscreen: bool # fullscreen on/off
var lang_id # language id; String or null if unset
# keyboard shortcuts; values should be dictionaries with keys 'keycode' and 'unicode'
var keys: Dictionary
var gui_scale: GUIScale # larger or smaller UI elements
var dyslexic_font: bool # whether dyslexia-friendly font is used

# hidden settings
# dict of ids of unlockables to bool (whether unlockeds)
var unlocked: Dictionary
# persistent data saved with settings for use by games
var persistent: Dictionary


# path of file where settings are stored
const SETTINGS_PATH: String = 'user://settings.cfg'
# properties that are not saved to disk
const TRANSIENT_PROPERTIES: Array[String] = [ 'RefCounted', 'script', 'Settings.gd' ]
# properties that have special handling when loaded
# (not automatically getting their default value if absent)
const NO_DEFAULT_PROPERTIES: Array[String] = [ 'lang_id', 'unlocked', 'keys', 'persistent' ]
# available keyboard shortcuts and their default values
# every shortcut is saved as a dict of:
# – the keycode, a Key
# – the key's unicode value or 0 if it doesn't correspond to a character
const KEYBOARD_SHORTCUTS: Dictionary = {
	'game_screenshot': { 'keycode': KEY_S, 'unicode': 83 },
	'game_hide': { 'keycode': KEY_H, 'unicode': 72 },
	'game_skip': { 'keycode': KEY_CTRL, 'unicode': 0 },
	'debug_toggle' : { 'keycode': KEY_F1, 'unicode': 0 }
}


enum GUIScale { NORMAL = 0, LARGE = 1 }


# unlocks the given unlockable and saves settings to the disk
# does nothing if it was already unlocked
func unlock(unlockable_id: String, no_toasts: bool = false):
	if not unlockable_id in TE.defs.unlockables:
		TE.log_error(TE.Error.ENGINE_ERROR, 'unknown unlockable: %s' % unlockable_id)
		return false
	if not unlockable_id in unlocked:
		unlocked[unlockable_id] = true
		TE.log_info('unlocked %s' % unlockable_id)
		
		if ':' in unlockable_id:
			var parts = unlockable_id.split(':', false, 2)
			var _namespace: String = parts[0]
			var id: String = parts[1]
			
			TE.emit_signal('unlockable_unlocked', _namespace, id)
			
			if _namespace in TE.opts.notify_on_unlock and not no_toasts:
				var noun: String = TE.localize['toast_unlocked_' + _namespace]
				var toast_title: String = TE.localize.toast_unlocked.replace('[]', noun)
				var toast_description: String = TE.localize['%s_%s' % [_namespace, id]]
				
				TE.send_toast_notification(toast_title, toast_description)
		else:
			TE.log_error(TE.Error.ENGINE_ERROR, 'unlockable not namespaced: %s' % unlockable_id)
		
		save_to_file()


# returns whether the given unlockable is unlocked
func is_unlocked(unlockable_id: String) -> bool:
	if not unlockable_id in TE.defs.unlockables:
		TE.log_error(TE.Error.ENGINE_ERROR, 'unknown unlockable: %s' % unlockable_id)
		return false
	return unlockable_id in unlocked and unlocked[unlockable_id]


# makes changes to game state
func change_settings():
	Settings.change_music_volume(music_volume)
	Settings.change_sfx_volume(sfx_volume)
	Settings.change_fullscreen(fullscreen)
	Settings.change_language(lang_id)
	TETheme.force_change_settings(gui_scale, dyslexic_font)
	Settings.change_keyboard_shortcuts(keys)


static func change_music_volume(vol_linear: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'), linear_to_db(vol_linear * 0.5))


static func change_sfx_volume(vol_linear: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('SFX'), linear_to_db(vol_linear * 0.5))


static func change_fullscreen(to_fullscreen: bool):
	var is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	
	if is_fullscreen != to_fullscreen:
		var mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if (to_fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)


static func change_keyboard_shortcuts(_keys: Dictionary):
	for key in _keys.keys():
		_setup_keyboard_shortcut(key, _keys[key]['keycode'])


static func _setup_keyboard_shortcut(eventName: String, keycode: Key):
	InputMap.action_erase_events(eventName)
	var event = InputEventKey.new()
	event.keycode = keycode
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


# returns whether the settings file exists
# it does not if the game is run for the first time
static func has_settings_file():
	return FileAccess.file_exists(SETTINGS_PATH)


# reads settings from file; returns the Settings or an error code
# if settings file is from an older version, it may be migrated;
# settings should be saved immediately after loading
# (an example of this kind of migration: a new auto-unlocked unlockable has been added,
# in case it gets added into the list of unlockables. also, new engine versions may add
# new settings, which means that their default values will be added.)
static func load_from_file():
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.READ)
	
	if file == null:
		push_error('cannot load settings: %d' % file.get_error())
		return file.get_error()
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error('error reading settings: %s' % json.get_error_message())
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
	
	# include auto-unlocks from default settings, overwriting them with whatever is in the given dict
	settings.unlocked = defaults['unlocked']
	settings.unlocked.merge(dict.get('unlocked', {}))
	
	# same for keys
	settings.keys = defaults['keys']
	settings.keys.merge(dict.get('keys', {}))
	
	# same for persistent
	settings.persistent = defaults['persistent']
	settings.persistent.merge(dict.get('persistent', {}))
	
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
	defs.dynamic_text_speed = true
	defs.fullscreen = false
	defs.lang_id = null # cannot provide sensible default
	defs.keys = KEYBOARD_SHORTCUTS.duplicate(true)
	defs.gui_scale = GUIScale.LARGE if TE.is_mobile() else GUIScale.NORMAL
	defs.dyslexic_font = false
	defs.persistent = {}
	defs.unlocked = {}
	
	return defs
