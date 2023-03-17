class_name NVLView extends View
# TODO scrolling text smoothly


# constants from theme used to calculate size
var top_margin: float = get_theme_constant('top_margin', 'NVLView')
var bottom_margin: float = get_theme_constant('bottom_margin', 'NVLView')
var width: float = get_theme_constant('width', 'NVLView')
var mobile_offset_x: float = get_theme_constant('mobile_offset_x', 'NVLView')


# RichTextLabels containing the displayed lines
@onready var paragraphs: VBoxContainer = %Paragraphs


# indent that appears at the start of lines after the first
const INDENT: String = '        '


func _ready():
	paragraphs.add_theme_constant_override('separation', 4)
	# set sensible default value if running without theme
	if width == 0:
		width = 1000
	
	super._ready()


func adjust_size(controls: VNControls, gui_scale: Settings.GUIScale):
	var controls_height = controls.size.y if controls != null else 0.0
	$Scroll.size.y = (TE.SCREEN_HEIGHT - controls_height - top_margin - bottom_margin)
	$Scroll.position.y = top_margin
	
	var w = width
	if gui_scale == Settings.GUIScale.LARGE:
		w += mobile_offset_x
	$Scroll.size.x = w
	$Scroll.position.x = (TE.SCREEN_WIDTH - w)/2


func _next_block():
	# erase current paragraphs
	for par in paragraphs.get_children():
		paragraphs.remove_child(par)
		par.queue_free()


# Speakers are not handled right now
func _next_line(line: String, _speaker: Definitions.Speaker = null):
	var label: RichTextLabel = create_label()
	
	# if not first paragraph
	if paragraphs.get_child_count() == 0:
		# first paragraph is normal
		label.text = line
	else:
		# add indent
		label.text = INDENT + line
		var old_par: RichTextLabel = paragraphs.get_child(-1)
		# remove the '[next] ▶[/next]' from previous paragraph
		old_par.text = old_par.text.replace(View.LINE_END, '')
	
	paragraphs.add_child(label)


func _current_label() -> RichTextLabel:
	if paragraphs.get_child_count() == 0:
		return null
	return paragraphs.get_child(-1)


func _get_scene_path():
	return 'res://tiger-engine/game/views/NVLView.tscn'
