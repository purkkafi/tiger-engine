extends Node
# central singleton object that contains utility methods and stores instances of
# global configuration objects


# global objects, set by THEInitScreen
var language: Lang = null # don't set directly, use load_language()
var ui_strings: UIStrings = null
var savefile: Savefile = null
var settings: Settings = null
# game config files, set by this object
var defs: Definitions = load('res://assets/definitions.tef')
var opts: Options = null
# the current scene, stored here for convenience
var current_scene: Node = null
# array of all recognized languages, set by TEInitScreen
var all_languages: Array[Lang] = []


# screen size constants
const SCREEN_WIDTH = 1920
const SCREEN_HEIGHT = 1080


func _ready():
	# load options, fall back to defaults if not successfull
	opts = load('res://assets/options.tef')
	if opts == null:
		opts = Options.new()
	
	# set current scene to be the initial scene
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)


# sets the scene to the gien scene
# the old one will be freed automatically
func switch_scene(new_scene: Node):
	call_deferred('_switch_scene_deferred', new_scene)


func _switch_scene_deferred(new_scene: Node):
	current_scene.queue_free()
	current_scene = new_scene
	get_tree().root.add_child(new_scene)
	get_tree().set_current_scene(new_scene)


# switches the language by loading files associated with it and configures
# language-dependent game state, such as the window title
func load_language(new_lang: Lang):
	language = new_lang
	ui_strings = load(language.path + '/ui_strings.tef')
	var version: String = opts.version_callback.call()
	get_window().set_title(ui_strings.game_title + ('' if version == '' else ' ' + version))
	
	# create language saved data directory if it doesn't exist
	var user_dir: DirAccess = DirAccess.open('user://')
	if not user_dir.dir_exists(language.id):
		user_dir.make_dir(language.id)
	
	# if save file doesn't exist, create a blank one and save it
	var save = Savefile.new()
	save.lang_id = language.id
	
	if !FileAccess.file_exists(save.path()):
		save.write_saves()
		savefile = save
	else:
		savefile = load(save.path())
		savefile.lang_id = language.id


func load_from_save(save: Dictionary, rollback: Rollback = null):
	var game_scene: TEGame = preload('res://tiger-engine/game/TEGame.tscn').instantiate()
	switch_scene(game_scene)
	
	if rollback != null:
		await get_tree().process_frame
		game_scene.rollback.set_rollback(rollback.entries)
	
	game_scene.load_save.call_deferred(save)


func _log_time() -> String:
	return '[' + Time.get_time_string_from_system() + '] '


# logs info if in debug mode
func log_info(msg: String):
	if OS.is_debug_build():
		print(_log_time() + msg)


# logs error message
func log_error(msg: String):
	push_error(_log_time() + msg)


# returns whether game should act as if running on a mobile platform
# in addition to running on mobile normally, this is true if the hidden secret
# pretend_mobile has been set to true
func is_mobile():
	return OS.get_name() == 'Android' or (settings != null and settings.pretend_mobile)


# returns whether the game should use large GUI mode
# this is true on mobile and on desktop if the setting is on
func is_large_gui():
	return is_mobile() or (settings != null and settings.gui_scale == Settings.GUIScale.LARGE)
