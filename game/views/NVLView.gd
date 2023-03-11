class_name NVLView extends View
# TODO scrolling text smoothly


# constants from theme used to calculate size
var top_margin: float = get_theme_constant('top_margin', 'NVLView')
var bottom_margin: float = get_theme_constant('bottom_margin', 'NVLView')
var width: float = get_theme_constant('width', 'NVLView')
var mobile_width_offset: float = get_theme_constant('mobile_width_offset', 'NVLView')


# RichTextLabels containing the displayed lines
@onready var paragraphs: VBoxContainer = %Paragraphs


# indent that appears at the start of lines after the first
const INDENT: String = '        '


func _enter_tree():
	# set sensible default value if running without theme
	if width == 0:
		width = 1000
	
	super._enter_tree()


func _ready():
	paragraphs.add_theme_constant_override('separation', 4)


func adjust_size(controls: VNControls):
	var controls_height = controls.height if controls != null else 0.0
	$Scroll.size.y = (1080 - controls_height - top_margin - bottom_margin)
	$Scroll.position.y = top_margin
	
	var w = width
	if Global.is_large_gui():
		w += mobile_width_offset
	$Scroll.size.x = w
	$Scroll.position.x = (1920 - w)/2


func _next_block():
	# erase current paragraphs
	for par in paragraphs.get_children():
		paragraphs.remove_child(par)
		par.queue_free()


func _next_line(line: String):
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
	
	label.fit_content = true
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	paragraphs.add_child(label)


func _current_label() -> RichTextLabel:
	return paragraphs.get_child(-1)
