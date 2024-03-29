extends Node
# central singleton object that contains utility methods and stores instances of
# global configuration objects


# global objects, set by THEInitScreen
var language: Lang = null # don't set directly, use load_language()
var localize: Localize = null
var savefile: Savefile = null
var settings: Settings = null
var seen_blocks: SeenBlocks = null
var persistent: Persistent = Persistent.load_from_file()
# game config files, set by this object
var defs: Definitions = load('res://assets/definitions.tef')
var opts: Options = null
# the current scene, stored here for convenience
var current_scene: Node = null
# array of all recognized languages, set by TEInitScreen
var all_languages: Array[Lang] = []
# if set to a bool, force enables or disables debug mode
var _force_debug = null
# if set to a bool, force enables or disables mobile mode
var _force_mobile = null
# whether visual debug tools should be drawn
# toggling forces a global redraw of the current scene
var draw_debug: bool = false:
	set(enabled):
		draw_debug = enabled
		_redraw_all(current_scene)


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
	localize = Localize.of_lang(new_lang.id)
	var version: String = opts.version_callback.call()
	get_window().set_title(localize.game_title + ('' if version == '' else ' ' + version))
	
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
	
	# save seen_blocks of current language and load the new one
	if seen_blocks != null:
		seen_blocks.write_to_disk()
	seen_blocks = SeenBlocks.new(language.id)


# loads the game from a save state, switching the scene to TEGame
# rollback and gamelog can be provided to keep and update their values
# appropriately, which is used for implementing rollback
# stage objects can be reused if loading from in-game, see VNStage.get_node_cache()
func load_from_save(save: Dictionary, rollback: Rollback = null, gamelog: Log = null, stage_node_cache: Variant = null):
	var game_scene: TEGame = preload('res://tiger-engine/game/TEGame.tscn').instantiate()
	switch_scene(game_scene, _after_load_from_save.bind(game_scene, save, rollback, gamelog, stage_node_cache))


func _after_load_from_save(game_scene: TEGame, save: Dictionary, rollback: Rollback = null, gamelog: Log = null, stage_node_cache: Variant = null):
	if rollback != null and gamelog != null:
		game_scene.rollback.set_rollback(rollback.entries)
		gamelog.remove_last()
		game_scene.gamelog = gamelog
	
	game_scene.load_save.call(save, stage_node_cache if stage_node_cache != null else {})


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
	if _force_mobile == null:
		return OS.get_name() == 'Android'
	return _force_mobile


# returns whether the game should use large GUI mode
# this is true if set in settings or if is_mobile() is true when settings aren't available
func is_large_gui():
	if settings != null:
		return settings.gui_scale == Settings.GUIScale.LARGE
	return is_mobile()


# exits the game
func quit_game(exit_code=0):
	seen_blocks.write_to_disk()
	await get_tree().process_frame
	get_tree().quit(exit_code)


# sends a toast notification
func send_toast_notification(title: String, description: String, icon = null):
	var toast: Dictionary = {
		'bbcode': '[b]%s[/b]\n%s' % [title, description]
	}
	
	if icon != null:
		toast['icon'] = icon
	
	emit_signal('toast_notification', toast)


# returns whether in debug mode, which is based on OS.is_debug_build()
# unless overridden with _force_debug
func is_debug() -> bool:
	if _force_debug == null:
		return OS.is_debug_build()
	return _force_debug


# recursively redraws everything
func _redraw_all(node: Node):
	for child in node.get_children():
		_redraw_all(child)
	
	if node is CanvasItem:
		node.queue_redraw()
