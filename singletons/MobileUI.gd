extends Node


var large_theme: Theme
const FONT_SIZE_INCREASE: int = 10

# constructs a theme with larger UI elements
static func _construct_large_theme():
	var default: Theme = load(ProjectSettings.get_setting('gui/theme/custom'))
	var large: Theme = Theme.new()
	
	for type in default.get_font_size_type_list():
		for name in default.get_font_size_list(type):
			
			var size = default.get_font_size(name, type)
			large.set_font_size(name, type, size+FONT_SIZE_INCREASE)
	
	return large


# sets the appropriate GUI scale based on current Settings & OS
func initialize_gui(node: Control):
	if Global.is_large_gui():
		change_gui_scale(node, Settings.GUIScale.LARGE)


# force changes GUI scale
func change_gui_scale(node: Control, scale: Settings.GUIScale):
	if scale == Settings.GUIScale.LARGE:
		if large_theme == null:
			large_theme = _construct_large_theme()
		node.theme = large_theme
	else:
		node.theme = null
