class_name Settings extends RefCounted
# user-changeable settings


var music_volume: float # volume of music, in range [0, 1]
var sfx_volume: float # volume of sfx, in range [0, 1]
var text_speed: float # text speed, in range [0, 1]
var dynamic_text_speed: bool # dynamic text speed on/off
var fullscreen: bool # fullscreen on/off
var lang_id # language id; String or null if unset
var gui_scale: GUIScale # larger or smaller UI elements

# hidden settings
var pretend_mobile: bool # act as mobile even on desktop
# dict of ids of unlockables to bool (whether unlockeds)
var unlocked: Dictionary


# path of file where settings are stored
const SETTINGS_PATH: String = 'user://settings.cfg'


enum GUIScale { NORMAL = 0, LARGE = 1 }


# unlocks the given unlockable and saves settings to the disk
# does nothing if it was already unlocked
func unlock(unlockable_id: String):
	if not unlockable_id in TE.defs.unlockables:
		TE.log_error('unknown unlockable: %s' % unlockable_id)
		return false
	if not unlockable_id in unlocked:
		unlocked[unlockable_id] = true
		save_to_file()


# returns whether the given unlockable is unlocked
func is_unlocked(unlockable_id: String) -> bool:
	if not unlockable_id in TE.defs.unlockables:
		TE.log_error('unknown unlockable: %s' % unlockable_id)
		return false
	return unlockable_id in unlocked and unlocked[unlockable_id]


# makes changes to game state
func change_settings():
	Settings.change_music_volume(music_volume)
	Settings.change_sfx_volume(sfx_volume)
	Settings.change_fullscreen(fullscreen)
	Settings.change_gui_scale(gui_scale)
	Settings.change_language(lang_id)


static func change_music_volume(vol_linear: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('Music'), linear_to_db(vol_linear * 0.5))


static func change_sfx_volume(vol_linear: float):
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index('SFX'), linear_to_db(vol_linear * 0.5))


static func change_fullscreen(to_fullscreen: bool):
	var is_fullscreen = DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	
	if is_fullscreen != to_fullscreen:
		var mode = DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN if (to_fullscreen) else DisplayServer.WINDOW_MODE_WINDOWED
		DisplayServer.window_set_mode(mode)


static func change_gui_scale(scale: GUIScale):
	MobileUI.change_gui_scale(TE.current_scene, scale)


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
		TE.log_error('cannot write settings: %d' % file.get_error())
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
		'pretend_mobile' : pretend_mobile,
		'lang_id' : lang_id,
		'gui_scale' : gui_scale,
		'unlocked' : unlocked
	}


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
	
	settings.music_volume = dict.get('music_volume', defaults['music_volume'])
	settings.sfx_volume = dict.get('sfx_volume', defaults['sfx_volume'])
	settings.text_speed = dict.get('text_speed', defaults['text_speed'])
	settings.dynamic_text_speed = dict.get('dynamic_text_speed', defaults['dynamic_text_speed'])
	settings.fullscreen = dict.get('fullscreen', defaults['fullscreen'])
	settings.pretend_mobile = dict.get('pretend_mobile', defaults['pretend_mobile'])
	settings.lang_id = dict['lang_id']
	settings.gui_scale = dict.get('gui_scale', defaults['gui_scale'])
	# include auto-unlocks from default settings, overwriting them with whatever is in the given dict
	settings.unlocked = dict.get('unlocked', {})
	settings.unlocked.merge(defaults['unlocked'])
	
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
	defs.pretend_mobile = false
	defs.lang_id = null # cannot provide sensible default
	defs.gui_scale = GUIScale.LARGE if TE.is_mobile() else GUIScale.NORMAL
	
	defs.unlocked = {} # include auto-unlocks by default
	for id in TE.defs.unlocked_from_start:
		defs.unlocked[id] = true
	
	return defs
