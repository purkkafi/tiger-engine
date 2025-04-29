extends Node
# code for managing themes and variations applied to them


const od_regular: Font = preload('res://tiger-engine/resources/opendyslexic-0.910.12-rc2-2019.10.17/OpenDyslexic-Regular.otf')
const od_bold: Font = preload('res://tiger-engine/resources/opendyslexic-0.910.12-rc2-2019.10.17/OpenDyslexic-Bold.otf')
const od_italic: Font = preload('res://tiger-engine/resources/opendyslexic-0.910.12-rc2-2019.10.17/OpenDyslexic-Italic.otf')
const od_bold_italic: Font = preload('res://tiger-engine/resources/opendyslexic-0.910.12-rc2-2019.10.17/OpenDyslexic-Bold-Italic.otf')


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
var animations = null # reference to object that holds the animations
var anim_overlay_in: Callable = NO_ANIM
var anim_overlay_out: Callable = NO_ANIM
var anim_shadow_in: Callable = NO_ANIM
var anim_shadow_out: Callable = NO_ANIM
var anim_full_image_in: Callable = NO_ANIM


# signal emitted when the variable current_theme is changed
# clients can connect to this to reinitialize themselves if they need to
@warning_ignore("unused_signal")
signal theme_changed


# changes the base theme
# this will also update current_theme
func set_theme(theme_id: String):
	_base_theme = _resolve_base_theme(theme_id)
	_large_theme = _resolve_large_theme(theme_id)
	
	# load animations, which are funcs in 'animations.gd' in theme folder
	if animations != null:
		self.remove_child(animations)
		animations.queue_free()
	
	animations = _resolve_animations(theme_id)
	
	if animations != null:
		self.add_child(animations)
		
		var overlay_in = Callable(animations, 'overlay_in')
		anim_overlay_in = overlay_in if overlay_in.is_valid() else NO_ANIM
		
		var overlay_out = Callable(animations, 'overlay_out')
		anim_overlay_out = overlay_out if overlay_out.is_valid() else NO_ANIM
		
		var shadow_in = Callable(animations, 'shadow_in')
		anim_shadow_in = shadow_in if shadow_in.is_valid() else NO_ANIM
		
		var shadow_out = Callable(animations, 'shadow_out')
		anim_shadow_out = shadow_out if shadow_out.is_valid() else NO_ANIM
		
		var full_image_in = Callable(animations, 'full_image_in')
		anim_full_image_in = full_image_in if full_image_in.is_valid() else NO_ANIM
	else:
		anim_overlay_in = NO_ANIM
		anim_overlay_out = NO_ANIM
		anim_shadow_in = NO_ANIM
		anim_shadow_out = NO_ANIM
		anim_full_image_in = NO_ANIM
	
	background_color = _base_theme.get_color('background_color', 'Global')
	shadow_color = _base_theme.get_color('shadow_color', 'Global')
	default_text_color = _base_theme.get_color('font_color', 'Label')
	
	_apply_variations()


# constructs a new current_theme instance from the base theme and applies variations
# by default, variations are based on current settings; parameters can be passed to force changes
func _apply_variations(force_gui_scale = null, force_dyslexic_font = null):
	current_theme = Theme.new()
	current_theme.merge_with(_base_theme)
	
	_copy_default_values(current_theme, _base_theme)
	
	# applies large theme variant
	var is_large_gui = TE.is_large_gui()
	if force_gui_scale != null:
		is_large_gui = force_gui_scale == Settings.GUIScale.LARGE
	
	if is_large_gui:
		current_theme.merge_with(_large_theme)
		_copy_default_values(current_theme, _large_theme)
	
	# applies OpenDyslexic
	var is_dyslexic_font = TE.settings != null and TE.settings.dyslexic_font
	if force_dyslexic_font != null:
		is_dyslexic_font = force_dyslexic_font
	
	if is_dyslexic_font:		
		# convert every theme font to OpenDyslexic equivalent
		for tp in current_theme.get_type_list():
			
			# the default font for this type; by default the default font
			var default_font = current_theme.get_font(tp, '')
			
			for fn in current_theme.get_font_list(tp):
				# do not replace line end symbol font
				if tp == 'Global' and fn == 'line_end_symbol':
					continue
				
				var font: Font = current_theme.get_font(fn, tp)
				var style = font.get_font_style()
				
				var replacement: Font
				match style:
					TextServer.FONT_BOLD | TextServer.FONT_ITALIC:
						replacement = od_bold_italic
					TextServer.FONT_ITALIC:
						replacement = od_italic
					TextServer.FONT_BOLD:
						replacement = od_bold
					_:
						replacement = od_regular
						default_font = font # use this as the default font
				
				current_theme.set_font(fn, tp, replacement)
			
			# find appropriate replacement font sizes
			for fs in current_theme.get_font_size_list(tp):
				var base_size: int = current_theme.get_font_size(fs, tp)
				current_theme.set_font_size(fs, tp, _find_od_size(default_font, base_size, od_regular))
		
		# finally, chabge the default font, if any
		if current_theme.has_default_font() and current_theme.has_default_font_size():
			current_theme.default_font_size = _find_od_size(current_theme.default_font, current_theme.default_font_size, od_regular)
			current_theme.default_font = od_regular
	
	get_tree().root.theme = current_theme
	emit_signal('theme_changed')


# finds a font size for an OpenDyslexic font that matches the given font at the given size
func _find_od_size(base_font: Font, base_size: int, od_font: Font) -> int:
	var target_height: float = base_font.get_height(base_size)
	var od_size: int = 12 # start search from an arbitrary small size
	while od_font.get_height(od_size) < target_height:
		od_size = od_size + 2
	return od_size


# GODOT BUG: merge_with() ignres default base scale, font, and font size
func _copy_default_values(to: Theme, from: Theme):
	if from.has_default_base_scale():
		to.default_base_scale = from.default_base_scale
	if from.has_default_font():
		to.default_font = from.default_font
	if from.has_default_font_size():
		to.default_font_size = from.default_font_size


# returns the Theme from the themes folder specified by the given id
func _resolve_base_theme(id: String) -> Theme:
	var path = 'res://assets/themes/%s/theme.tres' % id
	var theme: Theme = load(path)
	if theme == null:
		TE.log_error(TE.Error.FILE_ERROR, 'theme resource not found: %s' % path)
	return theme


func _resolve_large_theme(id: String) -> Theme:
	var path = 'res://assets/themes/%s/theme_large.tres' % id
	var theme: Theme = load(path)
	if theme == null:
		TE.log_error(TE.Error.FILE_ERROR, 'theme resource not found: %s' % path)
	return theme


func _resolve_animations(id: String) -> Variant:
	var path = 'res://assets/themes/%s/animations.gd' % id
	if ResourceLoader.exists(path):
		return (load(path) as GDScript).new()
	return null


# applies the given settings to the theme
func force_change_settings(gui_scale: Settings.GUIScale, dyslexic_font: bool):
	_apply_variations(gui_scale, dyslexic_font)
