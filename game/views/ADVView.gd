class_name ADVView extends View


@onready var box: PanelContainer = %TextBox
@onready var speaker_panel: PanelContainer = %SpeakerPanel
@onready var speaker_name: Label = %SpeakerName
var label: RichTextLabel

var width: float = get_theme_constant('width', 'ADVView')
var height: float = get_theme_constant('height', 'ADVView')
var mobile_offset_x: float = get_theme_constant('mobile_offset_x', 'ADVView')
var mobile_offset_y: float = get_theme_constant('mobile_offset_y', 'ADVView')
var speaker_offset_x: float = get_theme_constant('speaker_offset_x', 'ADVSpeaker')
var speaker_offset_y: float = get_theme_constant('speaker_offset_y', 'ADVSpeaker')

var speaker_font: Font = get_theme_font('font', 'ADVSpeaker')
var speaker_font_size: int = get_theme_font_size('font_size', 'ADVSpeaker')
var speaker_font_shadow_color: Color = get_theme_color('font_shadow_color', 'ADVSpeaker')
var speaker_shadow_offset_x: int = get_theme_constant('shadow_offset_x', 'ADVSpeaker')
var speaker_shadow_offset_y: int = get_theme_constant('shadow_offset_y', 'ADVSpeaker')


func _ready():
	label = create_label()
	box.add_child(label)
	
	# sensible default values if without theme
	if width == 0:
		width = 1000
		height = 200
	
	speaker_panel.visible = false
	speaker_name.add_theme_font_override('font', speaker_font)
	speaker_name.add_theme_font_size_override('font_size', speaker_font_size)
	speaker_name.add_theme_color_override('font_shadow_color', speaker_font_shadow_color)
	speaker_name.add_theme_constant_override('shadow_offset_x', speaker_shadow_offset_x)
	speaker_name.add_theme_constant_override('shadow_offset_y', speaker_shadow_offset_y)
	
	super._ready()


func adjust_size(controls: VNControls):
	var controls_height: float = controls.size.y if controls != null else 0.0
	var w: float = width
	var h: float = height
	
	if Global.is_large_gui():
		w += mobile_offset_x
		h += mobile_offset_y
	
	box.size.x = w
	box.size.y = h
	box.position.x = (1920 - w)/2 
	box.position.y = 1080 - h - controls_height
	
	speaker_panel.position.x = box.position.x + speaker_offset_x
	speaker_panel.position.y = box.position.y - speaker_panel.size.y + speaker_offset_y


func _next_line(line: String, speaker: Definitions.Speaker = null):
	label.text = line
	
	if speaker != null:
		speaker_panel.visible = true
		speaker_name.text = speaker.name
		box.theme_type_variation = 'ADVViewWithSpeaker'
		
		var sb: StyleBox = speaker_panel.get_theme_stylebox('panel', 'ADVSpeaker')
		if sb is StyleBoxFlat:
			sb.bg_color = speaker.color
			# in case previous speaker has the same name – it wouldn't redraw automatically
			speaker_panel.queue_redraw()
	else:
		speaker_panel.visible = false
		box.theme_type_variation = 'ADVView'

func _current_label() -> RichTextLabel:
	return label
