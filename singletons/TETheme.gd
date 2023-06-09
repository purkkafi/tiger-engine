extends Node
# code for managing themes and variations applied to them


# the current base Theme, on top of which variations may be applied
var _base_theme: Theme = Theme.new()
# the Theme instance representing the current base theme with variations applied
var current_theme: Theme = Theme.new()
# global values retreived from the theme
var background_color: Color = Color.BLACK
var shadow_color: Color = Color.TRANSPARENT


# signal emitted when force_change_gui_scale() is called
# clients can connect to this if they need to do their own calculations
# about the sizes of their UI
# it will be called with the relevant Settings.GUIScale value
signal gui_scale_changed


# changes the base theme
# this will also update current_theme
func set_theme(base_theme: Theme):
	_base_theme = base_theme
	
	background_color = _base_theme.get_color('background_color', 'Global')
	shadow_color = _base_theme.get_color('shadow_color', 'Global')
	
	_apply_variations()


# constructs a new current_theme instance from the base theme and applies variations
# by default, variations are based on current settings; parameters can be passed to force changes
func _apply_variations(gui_scale = null):
	current_theme = Theme.new()
	current_theme.merge_with(_base_theme)
	
	# GODOT BUG: merge_with() ignres default base scale, font, and font size
	# this ensures they are copied from the base theme
	current_theme.default_base_scale = _base_theme.default_base_scale
	current_theme.default_font = _base_theme.default_font
	current_theme.default_font_size = _base_theme.default_font_size
	
	# applies large font size
	var is_large_gui = TE.is_large_gui()
	if gui_scale != null:
		is_large_gui = gui_scale == Settings.GUIScale.LARGE
	
	if is_large_gui:
		for type in _base_theme.get_font_size_type_list():
			for _name in _base_theme.get_font_size_list(type):
				var size = _base_theme.get_font_size(_name, type)
				current_theme.set_font_size(_name, type, size+FONT_SIZE_INCREASE)
		
		if current_theme.has_default_font_size():
			current_theme.default_font_size = _base_theme.default_font_size + FONT_SIZE_INCREASE
	
	TE.current_scene.theme = current_theme


# returns the Theme from the themes folder specified by the given id
static func resolve_theme_id(id: String) -> Theme:
	return load('res://assets/themes/%s/theme.tres' % id)


# TODO specify this in the theme
const FONT_SIZE_INCREASE: int = 10


# force changes GUI scale, ignoring settings
func force_change_gui_scale(scale: Settings.GUIScale):
	emit_signal('gui_scale_changed', scale)
	_apply_variations(scale)
