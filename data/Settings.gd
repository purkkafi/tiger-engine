class_name Settings extends RefCounted
# user-changeable settings


var music_volume: float # volume of music, in range [0, 1]
var sfx_volume: float # volume of sfx, in range [0, 1]
var text_speed: float # text speed, in range [0, 1]
var dynamic_text_speed: bool # dynamic text speed on/off
var fullscreen: bool # fullscreen on/off
var pretend_android: bool # emulate android
var lang_id # language id; String or null if unset


# path of file where settings are stored
const SETTINGS_PATH: String = 'user://settings.cfg'


# makes changes to game state
func change_settings():
	Settings.change_music_volume(music_volume)
	Settings.change_sfx_volume(sfx_volume)
	Settings.change_fullscreen(fullscreen)


static func change_music_volume(vol_linear: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'), linear_to_db(vol_linear * 0.5))


static func change_sfx_volume(vol_linear: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('SFX'), linear_to_db(vol_linear * 0.5))


static func change_fullscreen(is_fullscreen: bool):
	var mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if (is_fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
	DisplayServer.window_set_mode(mode)


# writes settings to the disk (see SETTINGS_PATH)
# returns OK or error code
func save_to_file():
	var file: FileAccess = FileAccess.open(SETTINGS_PATH, FileAccess.WRITE)
	
	if file == null:
		Global.log_error('cannot write settings: %d' % file.get_error())
		return file.get_error()
	
	file.store_line(JSON.stringify(_to_dict(), '  '))
	return OK


func _to_dict() -> Dictionary:
	return {
		'music_volume' : music_volume,
		'sfx_volume' : sfx_volume,
		'text_speed' : text_speed,
		'dynamic_text_speed' : dynamic_text_speed,
		'fullscreen' : fullscreen,
		'pretend_android' : pretend_android,
		'lang_id' : lang_id
	}


# returns whether the settings file exists
# it does not if the game is run for the first time
static func has_settings_file():
	return FileAccess.file_exists(SETTINGS_PATH)


# reads settings from file
# returns the Settings or an error code
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
	
	settings.music_volume = dict.get('music_volume', defaults['music_volume'])
	settings.sfx_volume = dict.get('sfx_volume', defaults['sfx_volume'])
	settings.text_speed = dict.get('text_speed', defaults['text_speed'])
	settings.dynamic_text_speed = dict.get('dynamic_text_speed', defaults['dynamic_text_speed'])
	settings.fullscreen = dict.get('fullscreen', defaults['fullscreen'])
	settings.pretend_android = dict.get('pretend_android', defaults['pretend_android'])
	settings.lang_id = dict['lang_id']
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
	defs.pretend_android = false
	defs.lang_id = null # cannot provide sensible default
	return defs
