extends Node
# code for managing themes and variations applied to them


# the current base Theme, on top of which variations may be applied
var _base_theme: Theme = Theme.new()
# the current large theme variant
var _large_theme: Theme = Theme.new()
# the Theme instance representing the current base theme with variations applied
var current_theme: Theme = Theme.new()
# global values retreived from the theme
var background_color: Color = Color.BLACK
var shadow_color: Color = Color.TRANSPARENT
var default_text_color: Color = Color.WHITE # the color of Label's font
# animations
# empty animation used if animations aren't specified
var NO_ANIM: Callable = func(_target: Control) -> Tween: return null
var anim_overlay_in: Callable = NO_ANIM
var anim_overlay_out: Callable = NO_ANIM
var anim_shadow_in: Callable = NO_ANIM
var anim_shadow_out: Callable = NO_ANIM


# signal emitted when the variable current_theme is changed
# clients can connect to this to reinitialize themselves if they need to
signal theme_changed


# changes the base theme
# this will also update current_theme
func set_theme(theme_id: String):
	_base_theme = _resolve_base_theme(theme_id)
	_large_theme = _resolve_large_theme(theme_id)
	
	# load animations, which are static funcs in 'animations.gd'
	var animations = _resolve_animations(theme_id)
	if animations != null:
		# workaround for godot issue:
		# Callable.is_valid() doesn't understand static methods properly
		# using an instance as the object of Callable instead of the GDScript works
		animations = animations.new()
		
		var overlay_in = Callable(animations, 'overlay_in')
		anim_overlay_in = overlay_in if overlay_in.is_valid() else NO_ANIM
		
		var overlay_out = Callable(animations, 'overlay_out')
		anim_overlay_out = overlay_out if overlay_out.is_valid() else NO_ANIM
		
		var shadow_in = Callable(animations, 'shadow_in')
		anim_shadow_in = shadow_in if shadow_in.is_valid() else NO_ANIM
		
		var shadow_out = Callable(animations, 'shadow_out')
		anim_shadow_out = shadow_out if shadow_out.is_valid() else NO_ANIM
	else:
		anim_overlay_in = NO_ANIM
		anim_overlay_out = NO_ANIM
		anim_shadow_in = NO_ANIM
		anim_shadow_out = NO_ANIM
	
	background_color = _base_theme.get_color('background_color', 'Global')
	shadow_color = _base_theme.get_color('shadow_color', 'Global')
	default_text_color = _base_theme.get_color('font_color', 'Label')
	
	_apply_variations()


# constructs a new current_theme instance from the base theme and applies variations
# by default, variations are based on current settings; parameters can be passed to force changes
func _apply_variations(gui_scale = null, dyslexic_font = null):
	current_theme = Theme.new()
	current_theme.merge_with(_base_theme)
	
	_copy_default_values(current_theme, _base_theme)
	
	# applies large theme variant
	var is_large_gui = TE.is_large_gui()
	if gui_scale != null:
		is_large_gui = gui_scale == Settings.GUIScale.LARGE
	
	if is_large_gui:
		current_theme.merge_with(_large_theme)
		_copy_default_values(current_theme, _large_theme)
	
	# applies OpenDyslexic
	# also reduces font size of everything by 25 % because the font takes more space to display
	var is_dyslexic_font = TE.settings != null and TE.settings.dyslexic_font
	if dyslexic_font != null:
		is_dyslexic_font = dyslexic_font
	
	if dyslexic_font:
		var regular = load('res://tiger-engine/resources/opendyslexic-0.910.12-rc2-2019.10.17/OpenDyslexic-Regular.otf')
		var bold = load('res://tiger-engine/resources/opendyslexic-0.910.12-rc2-2019.10.17/OpenDyslexic-Bold.otf')
		var italic = load('res://tiger-engine/resources/opendyslexic-0.910.12-rc2-2019.10.17/OpenDyslexic-Italic.otf')
		var bold_italic = load('res://tiger-engine/resources/opendyslexic-0.910.12-rc2-2019.10.17/OpenDyslexic-Bold-Italic.otf')
		
		if current_theme.has_default_font():
			current_theme.default_font = regular
		if current_theme.has_default_font_size():
			current_theme.default_font_size = current_theme.default_font_size * 0.75
		
		for tp in current_theme.get_type_list():
			for fn in current_theme.get_font_list(tp):
				var normal: String = current_theme.get_font(fn, tp).resource_path.to_lower()
				
				if ('bold' in fn and 'italic' in fn) or ('bold' in normal and 'italic' in normal):
					current_theme.set_font(fn, tp, bold_italic)
				elif 'italic' in fn or 'italic' in normal:
					current_theme.set_font(fn, tp, italic)
				elif 'bold' in fn or 'bold' in normal:
					current_theme.set_font(fn, tp, bold)
				else:
					current_theme.set_font(fn, tp, regular)
			
			for fs in current_theme.get_font_size_list(tp):
				var size: int = current_theme.get_font_size(fs, tp)
				current_theme.set_font_size(fs, tp, size * 0.75)
	
	TE.current_scene.theme = current_theme
	emit_signal('theme_changed')


# GODOT BUG: merge_with() ignres default base scale, font, and font size
static func _copy_default_values(to: Theme, from: Theme):
	if from.has_default_base_scale():
		to.default_base_scale = from.default_base_scale
	if from.has_default_font():
		to.default_font = from.default_font
	if from.has_default_font_size():
		to.default_font_size = from.default_font_size


# returns the Theme from the themes folder specified by the given id
static func _resolve_base_theme(id: String) -> Theme:
	var path = 'res://assets/themes/%s/theme.tres' % id
	var theme: Theme = load(path)
	if theme == null:
		TE.log_error('theme resource not found: %s' % path)
	return theme


static func _resolve_large_theme(id: String) -> Theme:
	var path = 'res://assets/themes/%s/theme_large.tres' % id
	var theme: Theme = load(path)
	if theme == null:
		TE.log_error('theme resource not found: %s' % path)
	return theme


static func _resolve_animations(id: String) -> Variant:
	var path = 'res://assets/themes/%s/animations.gd' % id
	return load(path)


# applies the given settings to the theme
func force_change_settings(gui_scale: Settings.GUIScale, dyslexic_font: bool):
	_apply_variations(gui_scale, dyslexic_font)
