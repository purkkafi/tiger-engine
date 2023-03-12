class_name SettingsOverlay extends PanelContainer


const WM_FULLSCREEN: int = 0
const WM_WINDOWED: int = 1


# callback for when the overlay is closed
var animating_out_callback: Callable = func(): pass
@onready var scroll: ScrollContainer = %Scroll
@onready var window_mode_container: HBoxContainer = %WindowModeContainer
@onready var window_options: OptionButton = %WindowOptions
@onready var music_volume: Slider = %MusicVolSlider
@onready var sfx_volume: Slider = %SFXVolSlider
@onready var text_speed: Slider = %TextSpeedSlider
@onready var dyn_text_speed: CheckButton = %DynTextSpeed
@onready var lang_options: OptionButton = %LangOptions
@onready var gui_scale_container: HBoxContainer = %GUIScaleContainer
@onready var gui_scale: OptionButton = %GUIScale
@onready var save_exit: Button = %SaveExit
@onready var discard: Button = %Discard


func _ready():
	TE.ui_strings.translate(self)
	
	if TE.is_mobile(): # no fullscreen setting on mobile
		window_mode_container.get_parent().remove_child(window_mode_container)
	else:
		window_options.add_item(TE.ui_strings.settings_window_fullscreen, WM_FULLSCREEN)
		window_options.add_item(TE.ui_strings.settings_window_windowed, WM_WINDOWED)
		
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
	
	# no GUI scale setting on mobile
	if TE.is_mobile():
		gui_scale_container.get_parent().remove_child(gui_scale_container)
	else:
		gui_scale.selected = TE.settings.gui_scale
	
	save_exit.grab_focus()
	
	await get_tree().process_frame
	TE.opts.animate_overlay_in.call(self)


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


func _gui_scale_selected(selection):
	Settings.change_gui_scale(selection)
	await get_tree().process_frame
	scroll.ensure_control_visible(gui_scale)


func _save_exit():
	TE.settings.music_volume = music_volume.value
	TE.settings.sfx_volume = sfx_volume.value
	TE.settings.text_speed = text_speed.value
	TE.settings.dynamic_text_speed = dyn_text_speed.button_pressed
	TE.settings.lang_id = TE.language.id
	
	if not TE.is_mobile():
		TE.settings.fullscreen = window_options.selected == WM_FULLSCREEN
		TE.settings.gui_scale = gui_scale.selected as Settings.GUIScale
	
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
	animating_out_callback.call()
	discard.disabled = true
	save_exit.disabled = true
	
	var tween = TE.opts.animate_overlay_out.call(self)
	if tween == null:
		_animated_out()
	else:
		tween.tween_callback(Callable(self, '_animated_out'))


func _animated_out():
	get_parent().remove_child(self)
	queue_free()
