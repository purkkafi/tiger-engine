class_name NVLView extends View
# TODO scrolling text smoothly


# constants from theme used to calculate size
var top_margin: float = get_theme_constant('top_margin', 'NVLView')
var bottom_margin: float = get_theme_constant('bottom_margin', 'NVLView')
var width: float = get_theme_constant('width', 'NVLView')
var mobile_offset_x: float = get_theme_constant('mobile_offset_x', 'NVLView')
# RichTextLabels containing the displayed lines
@onready var paragraphs: VBoxContainer = %Paragraphs
@onready var scroll: ScrollContainer = %Scroll
# various options that determine the look of this view
var options: Dictionary = {}
# these will be set from options
var hcenter: bool = false
var vcenter: bool = false
var outline_size: float = 0
var outline_color: Variant = null # Color or null
var text_color: Variant = null # Color or null


# indent that appears at the start of lines after the first
var INDENT: String = '        '


func _ready():
	# set sensible default value if running without theme
	if width == 0:
		width = 1000
	
	if 'hcenter' in options:
		hcenter = options['hcenter']
	if 'vcenter' in options:
		vcenter = options['vcenter']
	if 'outline' in options:
		outline_color = TE.defs.color(str(options['outline'][0]))
		outline_size = float(options['outline'][1])
	if 'text_color' in options:
		text_color = TE.defs.color(str(options['text_color']))
	
	scroll.get_v_scroll_bar().connect('changed', Callable(self, '_scroll_to_bottom'))
	
	_apply_vcenter()
	
	super._ready()


func _apply_vcenter():
	if vcenter:
		paragraphs.alignment = BoxContainer.ALIGNMENT_CENTER   


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
	
	if outline_size != 0:
		line = '[outline_size=%s][outline_color=%s]%s[/outline_color][/outline_size]' % [outline_size, outline_color.to_html(), line]
	
	if text_color != null:
		line = '[color=%s]%s[/color]' % [text_color.to_html(), line]
	
	if hcenter: # if centered: no indent and lines are farther apart
		line = '[center]%s[/center]' % line
		label.visible_characters_behavior = TextServer.VC_CHARS_AFTER_SHAPING
		INDENT = ''
	else:
		# if not centered, there will be an indent & lines will be closer
		paragraphs.add_theme_constant_override('separation', 4)
	
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


func _scroll_to_bottom():
	scroll.get_v_scroll_bar().value = scroll.get_v_scroll_bar().max_value


func get_state() -> Dictionary:
	var state: Dictionary = super.get_state()
	if hcenter:
		state['hcenter'] = hcenter
	if vcenter:
		state['vcenter'] = vcenter
	if outline_color != null:
		state['outline_color'] = outline_color.to_html()
	if outline_size != 0:
		state['outline_size'] = outline_size
	if text_color != null:
		state['text_color'] = text_color.to_html()
	return state


func from_state(state: Dictionary, ctxt: ControlExpr.GameContext):
	if 'hcenter' in state:
		hcenter = state['hcenter']
	if 'vcenter' in state:
		vcenter = state['vcenter']
	if 'outline_color' in state:
		outline_color = Color.html(state['outline_color'])
	if 'outline_size' in state:
		outline_size = state['outline_size']
	if 'text_color' in state:
		text_color = Color.html(state['text_color'])
	# makes sure vcenter is applied since the option is not set in _ready()
	_apply_vcenter()
	super.from_state(state, ctxt)
