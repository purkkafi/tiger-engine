extends Node
# central singleton object that contains utility methods and stores instances of
# global configuration objects


# global objects, set by THEInitScreen
var language: Lang = null # don't set directly, use load_language()
var localize: Localize = null
var savefile: Savefile = null
var settings: Settings = null
var seen_blocks: SeenBlocks = null
# audio singleton
# game config files and singletons, set by this object
var defs: Definitions = load('res://assets/definitions.tef')
var persistent: Persistent = Persistent.load_from_file()
var opts: Options = null
var audio: Audio = null
var captions: Captions = null
# the current scene, stored here for convenience
var current_scene: Node = null
# array containing all available languages
var all_languages: Array[Lang] = []
# whether debug mode should be force-enabled
var _force_debug: bool = false
# whether local settings file should be ignored
var ignore_settings: bool = false
# whether platform should be treated as mobile
var _force_mobile: bool = false
# whether platform should be treated as web
var _force_web: bool = false
# whether visual debug tools should be drawn
# toggling forces a global redraw of the current scene
var draw_debug: bool = false:
	set(enabled):
		draw_debug = enabled
		_redraw_all(current_scene)
# time of last 'game_rollback' or 'game_rollforward' input to limit their frequency
var _last_key_rollback_or_rollforward_time: int = 0


# screen size constants
const SCREEN_WIDTH = 1920
const SCREEN_HEIGHT = 1080


# signal when an unlockable is unlocked
@warning_ignore("unused_signal")
signal unlockable_unlocked(_namespace: String, id: String)
# signal sent when a toast notification is spawned
# a toast object has these entries:
# – 'bbcode': the text in bbcode
# – 'icon' (optional): path to icon
@warning_ignore("unused_signal")
signal toast_notification(toast: Dictionary)
# fired when a translation package is loaded
@warning_ignore("unused_signal")
signal languages_changed
# fired when the game displays the next line of text
@warning_ignore("unused_signal")
signal game_next_line
# user has opened an in-game overlay, i.e. the settings screen; everything should pause
@warning_ignore("unused_signal")
signal overlay_opened
# user has closed the in-game overlay
@warning_ignore("unused_signal")
signal overlay_closed


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
	
	# attempt to load known translation packs
	var remove: Array[String] = []
	for tp in persistent.translation_packages:
		var ok: bool = ProjectSettings.load_resource_pack(tp, false)
		if not ok:
			remove.append(tp)
			log_warning("Translation package '%s' was not found and will be removed from cache" % tp)
	
	# remove the bad ones that couldn't be loaded
	if len(remove) != 0:
		for bad_package in remove:
			persistent.translation_packages.erase(bad_package)
		persistent.save_to_file()
	
	# detect available languages
	detect_languages()
	
	# instantiate audio singleton
	audio = preload('res://tiger-engine/singletons/Audio.tscn').instantiate()
	add_child(audio)
	
	# instantiate captions singleton
	captions = preload('res://tiger-engine/singletons/Captions.tscn').instantiate()
	get_tree().root.add_child.call_deferred(captions)
	TE.audio.song_played.connect(_handle_song_played_caption)
	TE.audio.sound_played.connect(func(sound): captions.show_caption('%alt_sound_' + sound + '%', sound))
	TE.audio.sound_finished.connect(func(sound): captions.hide_caption(sound))
	
	get_tree().get_root().connect('files_dropped', _load_translation_package)
	
	# set current scene to be the initial scene
	var root = get_tree().root
	current_scene = root.get_child(root.get_child_count() - 1)
	
	# disable auto quit to save various game files with quit_game()
	get_tree().set_auto_accept_quit(false)


func _handle_song_played_caption(song_id: String):
	if song_id == '':
		captions.hide_caption('song')
	else:
		captions.show_caption('%alt_song_' + song_id + '%', 'song')


# sets the scene to the given scene and calls callback afterwards
# the old one will be freed if 'free_old' is true, else it will be given as an argument to 'after'
func switch_scene(new_scene: Node, after: Callable = func(): pass, free_old: bool = true):
	await get_tree().process_frame
	call_deferred('_switch_scene_deferred', new_scene, after, free_old)


func _switch_scene_deferred(new_scene: Node, after: Callable, free_old: bool):
	var old_scene = current_scene
	current_scene = new_scene
	#current_scene.theme = TETheme.current_theme
	get_tree().root.add_child(new_scene)
	get_tree().set_current_scene(new_scene)
	
	if free_old:
		get_tree().root.remove_child(old_scene)
		old_scene.queue_free()
		after.call()
	else:
		get_tree().root.remove_child(old_scene)
		after.call(old_scene)
	
	# move captions to front
	get_tree().root.move_child(captions, -1)


# detects all available languages by crawling the filesystem
# sorts them alphabetically, besides the one matching the user's locale,
# which is placed first (if any)
# returns whether new languages were discovered (i.e. an asset pack has been loaded)
func detect_languages() -> bool:
	var before: Array[Lang] = all_languages.duplicate()
	
	var lang_path = 'res://assets/lang'
	
	var langs_folder := DirAccess.open(lang_path)
	if langs_folder == null:
		push_error('cannot open langs folder')
		return false
	
	var found: Array[Lang] = []
	for folder in langs_folder.get_directories():
		var lang: Lang = load(lang_path + '/' + folder + '/lang.tef')
		lang.id = folder
		lang.path = lang_path + '/' + folder
		
		# TODO support other file types?
		var icon_path: String = '%s/icon.png' % lang.path
		if ResourceLoader.exists(icon_path):
			lang.icon_path = icon_path
		
		found.append(lang)

	# sort found languages, preferring the one matching user's locale
	var locale = OS.get_locale_language()
	var preferred = null
	
	for lang in found:
		if lang.id == locale:
			preferred = lang
			found.remove_at(found.find(lang))
	
	found.sort_custom(func(lang1: Lang, lang2: Lang): return lang2.name > lang1.name)
	
	if preferred != null:
		found.insert(0, preferred)
	
	all_languages = found
	
	return all_languages != before


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
		game_scene.rollback.set_rollback(rollback)
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
# true if it actually is or if '_force_mobile' is true
func is_mobile() -> bool:
	if _force_mobile:
		return true
	return OS.get_name() == 'Android'


# returns whether the game should use large GUI mode
# this is true if set in settings or if is_mobile() is true when settings aren't available
func is_large_gui() -> bool:
	if settings != null:
		return settings.gui_scale == Settings.GUIScale.LARGE
	return is_mobile()


# returns whether the game should act as if running on the web
# true if that is the actual underlying platform or if '_force_web' is true
func is_web() -> bool:
	if _force_web:
		return true
	return OS.get_name() == 'Web'


func _notification(what): # override default exit behavior
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST:
		quit_game(0)


# exits the game safely
func quit_game(exit_code=0):
	if seen_blocks != null:
		seen_blocks.write_to_disk()
	persistent.save_to_file()
	
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
	if _force_debug:
		return true
	return OS.is_debug_build()


# recursively redraws everything
func _redraw_all(node: Node):
	for child in node.get_children():
		_redraw_all(child)
	
	if node is CanvasItem:
		node.queue_redraw()


func _load_translation_package(files: Array[String]):
	for file in files:
		if not ProjectSettings.load_resource_pack(file, false):
			log_error(TE.Error.FILE_ERROR, "Could not load language package: '%s'" % file)
	
	if detect_languages():
		emit_signal('languages_changed')
		
		for file in files:
			if file not in persistent.translation_packages:
				persistent.translation_packages.append(file)
		persistent.save_to_file()


func _input(event: InputEvent) -> void:
	# limit frequency of 'game_rollback' and 'game_rollforward' events echoing
	if event.is_action(&'game_rollback', true) or event.is_action(&'game_rollforward', true):
		if event.is_echo():
			var now: int = Time.get_ticks_msec()
			# wait 150ms between events
			if now < _last_key_rollback_or_rollforward_time + 150:
				get_viewport().set_input_as_handled()
			else:
				_last_key_rollback_or_rollforward_time = now
