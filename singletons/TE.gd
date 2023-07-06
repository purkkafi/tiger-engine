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


# signal when an unlockable is unlocked
signal unlockable_unlocked(_namespace: String, id: String)
# signal sent when a toast notification is spawned
# a toast object has these entries:
# – 'bbcode': the text in bbcode
# – 'icon' (optional): path to icon
signal toast_notification(toast: Dictionary)


# standard errors
enum Error {
	BAD_SAVE, # save cannot be loaded
	SCRIPT_ERROR, # developer made a fucky wucky while writing the game script
	FILE_ERROR, # something is wrong with the game files in general
	ENGINE_ERROR, # error from the engine's inernal mechanisms
	TEST_FAILED, # used when a unit test fails
	TEST_ERROR # error for debug purposes
}


func _ready():
	# load options, fall back to defaults if not successfull
	opts = load('res://assets/options.tef')
	if opts == null:
		opts = Options.new()
	
	# set current scene to be the initial scene
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)


# sets the scene to the given scene and calls callback afterwards
# the old one will be freed if 'free_old' is true, else it will be given as an argument to 'after'
func switch_scene(new_scene: Node, after: Callable = func(): pass, free_old: bool = true):
	await get_tree().process_frame
	call_deferred('_switch_scene_deferred', new_scene, after, free_old)


func _switch_scene_deferred(new_scene: Node, after: Callable, free_old: bool):
	var old_scene = current_scene
	current_scene = new_scene
	current_scene.theme = TETheme.current_theme
	get_tree().root.add_child(new_scene)
	get_tree().set_current_scene(new_scene)
	
	if free_old:
		old_scene.queue_free()
		after.call()
	else:
		get_tree().root.remove_child(old_scene)
		after.call(old_scene)


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


# loads the game from a save state, switching the scene to TEGame
# rollback and gamelog can be provided to keep and update their values
# appropriately, which is used for implementing rollback
func load_from_save(save: Dictionary, rollback: Rollback = null, gamelog: Log = null):
	var game_scene: TEGame = preload('res://tiger-engine/game/TEGame.tscn').instantiate()
	switch_scene(game_scene, _after_load_from_save.bind(game_scene, save, rollback, gamelog))


func _after_load_from_save(game_scene: TEGame, save: Dictionary, rollback: Rollback = null, gamelog: Log = null):
	if rollback != null and gamelog != null:
		game_scene.rollback.set_rollback(rollback.entries)
		gamelog.remove_last()
		game_scene.gamelog = gamelog
	
	game_scene.load_save.call(save)#_deferred(save) # was deferred


func _log_time() -> String:
	return '[' + Time.get_time_string_from_system() + '] '


# logs info if in debug mode
func log_info(msg: String):
	if is_debug():
		print(_log_time() + msg)


# logs a warning if in debug mode
func log_warning(msg: String):
	if is_debug():
		push_warning(_log_time() + msg)


# logs error message and crashes (if not in debug mode)
# if there is no sensible way to proceed, a crash can be forced with the force_crash parameter
func log_error(type: TE.Error, msg: String, force_crash: bool = false):
	push_error(_log_time() + msg)
	if (not is_debug()) or force_crash:
		Popups.error_dialog(type, msg)


# returns whether game should act as if running on a mobile platform
# in addition to running on mobile normally, this is true if the hidden secret
# pretend_mobile has been set to true
func is_mobile():
	return OS.get_name() == 'Android' or (settings != null and settings.pretend_mobile)


# returns whether the game should use large GUI mode
# this is true on mobile and on desktop if the setting is on
func is_large_gui():
	return is_mobile() or (settings != null and settings.gui_scale == Settings.GUIScale.LARGE)


# exits the game
func quit_game():
	get_tree().get_root().propagate_notification(NOTIFICATION_WM_CLOSE_REQUEST)
	await get_tree().process_frame
	get_tree().quit()


# sends a toast notification
func send_toast_notification(title: String, description: String, icon = null):
	var toast: Dictionary = {
		'bbcode': '[b]%s[/b]\n%s' % [title, description]
	}
	
	if icon != null:
		toast['icon'] = icon
	
	emit_signal('toast_notification', toast)


# returns whether in debug mode (currently as defined by Godot)
func is_debug() -> bool:
	return OS.is_debug_build()
