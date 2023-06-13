class_name SettingsOverlay extends Overlay


const WM_FULLSCREEN: int = 0
const WM_WINDOWED: int = 1


# whether changing language should be disabled
var language_disabled: bool = false

@onready var scroll: ScrollContainer = %Scroll
@onready var window_mode_container: HBoxContainer = %WindowModeContainer
@onready var window_options: OptionButton = %WindowOptions
@onready var music_volume: Slider = %MusicVolSlider
@onready var sfx_volume: Slider = %SFXVolSlider
@onready var text_speed: Slider = %TextSpeedSlider
@onready var dyn_text_speed: CheckBox = %DynTextSpeed
@onready var lang_options: OptionButton = %LangOptions
@onready var gui_scale_container: HBoxContainer = %GUIScaleContainer
@onready var gui_scale: OptionButton = %GUIScale
@onready var dyslexic_font: CheckButton = %DyslexicFont
@onready var save_exit: Button = %SaveExit
@onready var discard: Button = %Discard


func _initialize_overlay():
	if TE.is_mobile(): # no fullscreen setting on mobile
		window_mode_container.visible = false
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
	
	gui_scale.selected = TE.settings.gui_scale
	dyslexic_font.button_pressed = TE.settings.dyslexic_font
	
	save_exit.grab_focus()


func disable_language():
	lang_options.disabled = true


func _language_selected(index):
	Settings.change_language(TE.all_languages[index].id)
	TE.ui_strings.translate(TE.current_scene)


func _window_mode_selected(selection):
	if selection == WM_FULLSCREEN:
		Settings.change_fullscreen(true)
	else:
		Settings.change_fullscreen(false)


func _change_theme_settings():
	TETheme.force_change_settings(
		gui_scale.selected as Settings.GUIScale,
		dyslexic_font.button_pressed
	)


func _gui_scale_selected(selection):
	_change_theme_settings()
	await get_tree().process_frame
	scroll.ensure_control_visible(gui_scale)


func _dyslexic_font_toggled(pressed):
	_change_theme_settings()
	await get_tree().process_frame
	scroll.ensure_control_visible(dyslexic_font)


func _save_exit():
	TE.settings.music_volume = music_volume.value
	TE.settings.sfx_volume = sfx_volume.value
	TE.settings.text_speed = text_speed.value
	TE.settings.dynamic_text_speed = dyn_text_speed.button_pressed
	TE.settings.lang_id = TE.language.id
	TE.settings.gui_scale = gui_scale.selected as Settings.GUIScale
	TE.settings.dyslexic_font = dyslexic_font.button_pressed
	
	if not TE.is_mobile():
		TE.settings.fullscreen = window_options.selected == WM_FULLSCREEN
	
	TE.settings.save_to_file()
	_exit()


func _discard():
	# switch language back in case it was changed
	if TE.settings.change_language(TE.settings.lang_id):
		TE.ui_strings.translate(TE.current_scene)
	# reset changes by implementing saved settings
	TE.settings.change_settings()
	_exit()


func _exit():
	discard.disabled = true
	save_exit.disabled = true
	_close_overlay()
