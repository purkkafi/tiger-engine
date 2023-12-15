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
@onready var dyn_text_speed: CheckBox = %DynTextSpeed
@onready var skip_unseen_text: CheckBox = %SkipUnseenText
@onready var lang_options: OptionButton = %LangOptions
@onready var keys_section: MarginContainer = %Keys
@onready var keys_grid: GridContainer = %KeysGrid
@onready var gui_scale_container: HBoxContainer = %GUIScaleContainer
@onready var gui_scale: OptionButton = %GUIScale
@onready var dyslexic_font: CheckButton = %DyslexicFont
@onready var save_exit: Button = %SaveExit
@onready var discard: Button = %Discard

var unhandled_input_callback = null
var key_buttons: Array[Button] = []


func _initialize_overlay():
	if TE.is_mobile(): # no fullscreen setting on mobile
		video_section.get_parent().remove_child(video_section)
	else:
		if TE.settings.fullscreen:
			window_options.selected = WM_FULLSCREEN
		else:
			window_options.selected = WM_WINDOWED
	
	music_volume.value = TE.settings.music_volume
	music_volume.connect('value_changed', Callable(Settings, 'change_music_volume'))
	
	sfx_volume.value = TE.settings.sfx_volume
	sfx_volume.connect('value_changed', Callable(Settings, 'change_sfx_volume'))
	
	text_speed.value = TE.settings.text_speed
	dyn_text_speed.button_pressed = TE.settings.dynamic_text_speed
	skip_unseen_text.button_pressed = TE.settings.skip_unseen_text
	
	var selected_lang_index = null
	for i in len(TE.all_languages):
		var lang = TE.all_languages[i]
		lang_options.add_item(lang.full_name(), i)
		if lang == TE.language:
			selected_lang_index = i
	lang_options.selected = selected_lang_index
	
	# language setting can be disabled when overlay is created in-game
	if language_disabled:
		lang_options.disabled = true
	
	# hide button settings on mobile
	if TE.is_mobile():
		keys_section.get_parent().remove_child(keys_section)
	
	# setup keyboard shortcut controls
	for key in Settings.KEYBOARD_SHORTCUTS.keys():
		if key.begins_with('debug') and not TE.is_debug():
			continue
		
		var label: Label = Label.new()
		label.text = '%key_' + key +'%'
		keys_grid.add_child(label)
		
		var button: Button = Button.new()
		button.set_meta('key_id', key)
		button.set_meta('key', TE.settings.keys[key])
		_update_key_button_text(button)
		button.connect('pressed', _key_button_pressed.bind(button))
		keys_grid.add_child(button)
		key_buttons.append(button)
	
	gui_scale.selected = TE.settings.gui_scale
	dyslexic_font.button_pressed = TE.settings.dyslexic_font
	
	save_exit.grab_focus()


func disable_language():
	lang_options.disabled = true


func _language_selected(index):
	Settings.change_language(TE.all_languages[index].id)
	TE.localize.translate(TE.current_scene)


func _window_mode_selected(selection):
	if selection == WM_FULLSCREEN:
		Settings.change_fullscreen(true)
	else:
		Settings.change_fullscreen(false)


func _key_button_pressed(btn: Button):
	btn.text = '_'
	unhandled_input_callback = _key_button_changed.bind(btn)


func _key_button_changed(event: InputEventKey, btn: Button):
	# do a swap if the keycode is already in use
	for other in key_buttons:
		if other.get_meta('key')['keycode'] == event.keycode:
			other.set_meta('key', btn.get_meta('key'))
			_update_key_button_text(other)
	
	btn.set_meta('key', { 'keycode': event.keycode, 'unicode': event.unicode })
	_update_key_button_text(btn)


func _update_key_button_text(btn: Button):
	var unicode: int = btn.get_meta('key')['unicode']
	if unicode != 0:
		btn.text = char(int(unicode)).to_upper()
	else:
		btn.text = OS.get_keycode_string(btn.get_meta('key')['keycode'])


func _unhandled_key_input(event):
	if event is InputEventKey and unhandled_input_callback != null:
		unhandled_input_callback.call(event)
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


func _save_exit():
	TE.settings.music_volume = music_volume.value
	TE.settings.sfx_volume = sfx_volume.value
	TE.settings.text_speed = text_speed.value
	TE.settings.dynamic_text_speed = dyn_text_speed.button_pressed
	TE.settings.skip_unseen_text = skip_unseen_text.button_pressed
	TE.settings.lang_id = TE.language.id
	
	for btn in key_buttons:
		if btn is Button:
			TE.settings.keys[btn.get_meta('key_id')] = btn.get_meta('key')
	
	TE.settings.gui_scale = gui_scale.selected as Settings.GUIScale
	TE.settings.dyslexic_font = dyslexic_font.button_pressed
	
	if not TE.is_mobile():
		TE.settings.fullscreen = window_options.selected == WM_FULLSCREEN
	
	TE.settings.save_to_file()
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
