class_name SettingsOverlay extends Overlay


const WM_FULLSCREEN: int = 0
const WM_WINDOWED: int = 1


# whether changing language should be disabled
var language_disabled: bool = false

@onready var scroll: ScrollContainer = %Scroll
@onready var video_section: MarginContainer = %Video
@onready var window_mode_container: HBoxContainer = %WindowModeContainer
@onready var window_options: OptionButton = %WindowOptions
@onready var music_volume: Slider = %MusicVolSlider
@onready var sfx_volume: Slider = %SFXVolSlider
@onready var text_speed: Slider = %TextSpeedSlider
@onready var skip_speed: Slider = %SkipSpeedSlider
@onready var dyn_text_speed: CheckBox = %DynTextSpeed
@onready var skip_unseen_text: CheckBox = %SkipUnseenText
@onready var lang_options: OptionButton = %LangOptions
@onready var keys_section: MarginContainer = %Keys
@onready var keys_flow: HFlowContainer = %KeysFlow
@onready var gui_scale_container: HBoxContainer = %GUIScaleContainer
@onready var gui_scale: OptionButton = %GUIScale
@onready var dyslexic_font: CheckButton = %DyslexicFont
@onready var audio_captions: CheckButton = %AudioCaptions
@onready var add_mod: Button = %AddModButton
@onready var mods_grid: GridContainer = %ModsGrid
@onready var save_exit: Button = %SaveExit
@onready var discard: Button = %Discard

var unhandled_input_callback = null
var key_buttons: Array[Button] = []
var initial_mods: Array[String]
var mods_now: Array[String]


func _initialize_overlay():
	size_to_small()
	
	%Scroll.scroll_vertical_custom_step = 3 * TETheme.current_theme.default_font_size
	
	if TE.is_mobile(): # no fullscreen setting on mobile
		video_section.get_parent().remove_child(video_section)
		video_section.queue_free()
	else:
		if TE.settings.fullscreen:
			window_options.selected = WM_FULLSCREEN
		else:
			window_options.selected = WM_WINDOWED
		window_options.get_popup().transparent_bg = true
	
	# different fullscreen buttons for web & other platforms
	if TE.is_web():
		%WindowModeLabel.hide()
		%WindowOptions.hide()
	elif not TE.is_mobile():
		%WebFullscreen.hide()
	
	music_volume.value = TE.settings.music_volume
	music_volume.connect('value_changed', Callable(Settings, 'change_music_volume'))
	
	sfx_volume.value = TE.settings.sfx_volume
	sfx_volume.connect('value_changed', Callable(Settings, 'change_sfx_volume'))
	
	text_speed.value = TE.settings.text_speed
	skip_speed.value = TE.settings.skip_speed
	dyn_text_speed.button_pressed = TE.settings.dynamic_text_speed
	skip_unseen_text.button_pressed = TE.settings.skip_unseen_text
	
	_refresh_language_options()
	TE.connect('languages_changed', _refresh_language_options)
	
	# language setting can be disabled when overlay is created in-game
	if language_disabled:
		lang_options.disabled = true
	lang_options.get_popup().transparent_bg = true
	
	# hide button settings on mobile
	if TE.is_mobile():
		keys_section.get_parent().remove_child(keys_section)
		keys_section.queue_free()
	
	# setup keyboard shortcut controls
	for key in Settings.KEYBOARD_SHORTCUTS.keys():
		if key.begins_with('debug') and not TE.is_debug():
			continue
		
		var hbox: HBoxContainer = HBoxContainer.new()
		hbox.custom_minimum_size = Vector2(get_theme_constant('min_width', 'SettingsKeysFlow'), 0)
		
		var label: Label = Label.new()
		label.text = '%key_' + key +'%'
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)
		
		var button: Button = Button.new()
		button.set_meta('key_id', key)
		button.set_meta('key', TE.settings.keys[key])
		button.set_meta('shift_held', false)
		button.set_meta('alt_held', false)
		button.set_meta('ctrl_held', false)
		_update_key_button_text(button)
		button.connect('pressed', _key_button_pressed.bind(button))
		hbox.add_child(button)
		key_buttons.append(button)
		
		keys_flow.add_child(hbox)
	
	gui_scale.selected = TE.settings.gui_scale
	gui_scale.get_popup().transparent_bg = true
	dyslexic_font.button_pressed = TE.settings.dyslexic_font
	audio_captions.button_pressed = TE.settings.audio_captions
	
	initial_mods = TE.persistent.mods.duplicate()
	mods_now = TE.persistent.mods.duplicate()
	add_mod.connect('pressed', _add_mod)
	
	if TE.change_mods_supported():
		TE.mod_files_dropped.connect(_mod_files_dropped)
	
	# disabled on web while godot web builds don't support native file chooser
	if TE.is_web() or not TE.change_mods_supported():
		add_mod.disabled = true
	
	_populate_mods_grid()
	
	save_exit.grab_focus()


func _refresh_language_options():
	var selected_lang_index = null
	
	# needed if refreshing when the user drops in a translation package
	lang_options.clear()
	
	for i in len(TE.all_languages):
		var lang: Lang = TE.all_languages[i]
		lang_options.add_item(lang.full_name(), i)
		
		if lang.icon_path != null:
			lang_options.set_item_icon(i, load(lang.icon_path) as Texture2D)
		
		if lang == TE.language:
			selected_lang_index = i
	
	lang_options.selected = selected_lang_index


func disable_language():
	lang_options.disabled = true


func _language_selected(index):
	Settings.change_language(TE.all_languages[index].id)
	for child in TE.get_tree().root.get_children():
		if child is Control:
			TE.localize.translate(child)


func _window_mode_selected(selection):
	if selection == WM_FULLSCREEN:
		Settings.change_fullscreen(true)
	else:
		Settings.change_fullscreen(false)


func _web_fullscreen_pressed() -> void:
	DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)


func _key_button_pressed(btn: Button):
	btn.text = '...'
	unhandled_input_callback = _key_button_changed.bind(btn)


# returns whether a change was actually applied, no if just a modifier was pressed
func _key_button_changed(event: InputEventKey, btn: Button) -> bool:
	const MODIFIER_KEYS: Dictionary = {
		KEY_CTRL: 'ctrl_held',
		KEY_ALT: 'alt_held',
		KEY_SHIFT: 'shift_held'
	}
	
	# check if modifier key is pressed
	for mod_key in MODIFIER_KEYS:
		if event.keycode == mod_key:
			if event.pressed: # if pressed, change button state and return
				btn.set_meta(MODIFIER_KEYS[mod_key], true)
				btn.text = Settings.key_to_string(event) + '...'
				return false
			else: # if released, cancel and accept
				btn.set_meta(MODIFIER_KEYS[mod_key], false)
	
	var meta: Dictionary = {
		'keycode': event.keycode,
		'shift': btn.get_meta('shift_held'),
		'alt': btn.get_meta('alt_held'),
		'ctrl': btn.get_meta('ctrl_held'),
		'string': Settings.key_to_string(event)
	}
	
	# do a swap if the key is already in use
	for other in key_buttons:
		if other.get_meta('key')['string'] == meta['string']:
			other.set_meta('key', btn.get_meta('key'))
			_update_key_button_text(other)
	
	btn.set_meta('key', meta)
	_update_key_button_text(btn)
	btn.set_meta('shift_held', false)
	btn.set_meta('alt_held', false)
	btn.set_meta('ctrl_held', false)
	return true


func _update_key_button_text(btn: Button):
	btn.text = btn.get_meta('key')['string']


func _unhandled_key_input(event):
	if event is InputEventKey and unhandled_input_callback != null:
		if unhandled_input_callback.call(event):
			unhandled_input_callback = null


func _change_theme_settings():
	TETheme.force_change_settings(
		gui_scale.selected as Settings.GUIScale,
		dyslexic_font.button_pressed
	)


func _gui_scale_selected(_selection):
	_change_theme_settings()
	await get_tree().process_frame
	scroll.ensure_control_visible(gui_scale)


func _dyslexic_font_toggled(_pressed):
	_change_theme_settings()
	await get_tree().process_frame
	scroll.ensure_control_visible(dyslexic_font)


func _audio_captions_toggled(toggled_on: bool) -> void:
	TE.captions.set_captions_on(toggled_on)


func _add_mod():
	var popup: FileDialog = Popups.file_dialog(FileDialog.FILE_MODE_OPEN_FILE, ["*.zip,*.pck"])
	popup.connect('file_selected', func(file): _mod_added(file))


func _mod_added(files: Variant):
	if files is String:
		var the_file: String = files
		if the_file not in mods_now and TE.is_valid_mod_extension(the_file):
			mods_now.append(the_file)
	else:
		for file in files as Array[String]:
			if file not in mods_now and TE.is_valid_mod_extension(file):
				mods_now.append(file)
	
	_populate_mods_grid()


func _mod_removed(file: String):
	mods_now.erase(file)
	_populate_mods_grid()


func _mod_files_dropped(files: Array[String]):
	_mod_added(files)


func _populate_mods_grid():
	var prev_children: Array[Node] = mods_grid.get_children().duplicate()
	for child in prev_children:
		mods_grid.remove_child(child)
		child.queue_free()
	
	mods_grid.columns = 2
	
	var buttons_disabled: bool = not TE.change_mods_supported()
	
	for mod in mods_now:
		var label_text: String = mod
		if '/' in label_text:
			label_text = label_text.split('/', false)[-1]
		
		var path_label: Label = Label.new()
		path_label.text = label_text
		path_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		path_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		path_label.tooltip_text = mod
		path_label.mouse_filter = Control.MOUSE_FILTER_PASS
		mods_grid.add_child(path_label)
		
		var delete: Button = Button.new()
		delete.size_flags_horizontal = Control.SIZE_SHRINK_END
		delete.disabled = buttons_disabled
		delete.text = TE.localize.settings_mod_delete
		delete.connect('pressed', _mod_removed.bind(mod))
		mods_grid.add_child(delete)


func _save_exit():
	TE.settings.music_volume = music_volume.value
	TE.settings.sfx_volume = sfx_volume.value
	TE.settings.text_speed = text_speed.value
	TE.settings.skip_speed = skip_speed.value
	TE.settings.dynamic_text_speed = dyn_text_speed.button_pressed
	TE.settings.skip_unseen_text = skip_unseen_text.button_pressed
	TE.settings.lang_id = TE.language.id
	
	TE.settings.gui_scale = gui_scale.selected as Settings.GUIScale
	TE.settings.dyslexic_font = dyslexic_font.button_pressed
	TE.settings.audio_captions = audio_captions.button_pressed
	
	if not TE.is_mobile():
		TE.settings.fullscreen = window_options.selected == WM_FULLSCREEN
		
		for btn in key_buttons:
			if btn is Button:
				TE.settings.keys[btn.get_meta('key_id')] = btn.get_meta('key')
				Settings.change_keyboard_shortcuts(TE.settings.keys)
	
	TE.settings.save_to_file()
	
	initial_mods.sort()
	mods_now.sort()
	if initial_mods != mods_now:
		TE.persistent.mods = mods_now
		TE.persistent.save_to_file()
		
		var restart_info: Label = Label.new()
		restart_info.text = TE.localize.settings_mod_restart_info
		var popup: AcceptDialog = Popups.info_dialog(TE.localize.settings_mod_restart_title, restart_info)
		popup.connect('confirmed', TE.quit_game)
		popup.connect('canceled', TE.quit_game)
			
	_exit()


func _discard():
	# switch language back in case it was changed
	if Settings.change_language(TE.settings.lang_id):
		TE.localize.translate(TE.current_scene)
	# reset changes by implementing saved settings
	TE.settings.change_settings()
	_exit()


func _exit():
	discard.disabled = true
	save_exit.disabled = true
	_close_overlay()
