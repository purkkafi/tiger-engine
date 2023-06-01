class_name ADVView extends View


@onready var box: PanelContainer = %TextBox
@onready var speaker_panel: PanelContainer = %SpeakerPanel
@onready var speaker_name: Label = %SpeakerName
var label: RichTextLabel

@onready var width: float = get_theme_constant('width', 'ADVView')
@onready var height: float = get_theme_constant('height', 'ADVView')
@onready var mobile_offset_x: float = get_theme_constant('mobile_offset_x', 'ADVView')
@onready var mobile_offset_y: float = get_theme_constant('mobile_offset_y', 'ADVView')
@onready var speaker_offset_x: float = get_theme_constant('speaker_offset_x', 'ADVSpeaker')
@onready var speaker_offset_y: float = get_theme_constant('speaker_offset_y', 'ADVSpeaker')

@onready var speaker_font: Font = get_theme_font('font', 'ADVSpeaker')
@onready var speaker_font_size: int = get_theme_font_size('font_size', 'ADVSpeaker')
@onready var speaker_font_shadow_color: Color = get_theme_color('font_shadow_color', 'ADVSpeaker')
@onready var speaker_shadow_offset_x: int = get_theme_constant('shadow_offset_x', 'ADVSpeaker')
@onready var speaker_shadow_offset_y: int = get_theme_constant('shadow_offset_y', 'ADVSpeaker')

@onready var default_speaker_name_color: Color = Color(speaker_name.get_theme_color('font_color'))
var default_speaker_panel_bg_color: Color = Color.TRANSPARENT


func _ready():
	label = create_label()
	box.add_child(label)
	
	# sensible default values if without theme
	if width == 0:
		width = 1000
		height = 200
	
	if TE.is_large_gui():
		speaker_font_size += TETheme.FONT_SIZE_INCREASE
	
	speaker_panel.visible = false
	speaker_name.add_theme_font_override('font', speaker_font)
	speaker_name.add_theme_font_size_override('font_size', speaker_font_size)
	speaker_name.add_theme_color_override('font_shadow_color', speaker_font_shadow_color)
	speaker_name.add_theme_constant_override('shadow_offset_x', speaker_shadow_offset_x)
	speaker_name.add_theme_constant_override('shadow_offset_y', speaker_shadow_offset_y)
	
	if speaker_panel.get_theme_stylebox('panel', 'ADVSpeaker') is StyleBoxFlat:
		default_speaker_panel_bg_color = speaker_panel.get_theme_stylebox('panel', 'ADVSpeaker').bg_color


func adjust_size(controls: VNControls, gui_scale: Settings.GUIScale):
	var controls_height: float = controls.size.y if controls != null else 0.0
	var w: float = width
	var h: float = height
	
	if gui_scale == Settings.GUIScale.LARGE:
		w += mobile_offset_x
		h += mobile_offset_y
	
	box.size.x = w
	box.size.y = h
	box.position.x = (TE.SCREEN_WIDTH - w)/2 
	box.position.y = TE.SCREEN_HEIGHT - h - controls_height
	
	speaker_panel.position.x = box.position.x + speaker_offset_x
	speaker_panel.position.y = box.position.y - speaker_panel.size.y + speaker_offset_y


func _game_paused():
	box.visible = false


func _next_line(line: String, speaker: Definitions.Speaker = null):
	box.visible = true
	label.text = line
	
	if speaker != null:
		speaker_panel.visible = true
		speaker_name.text = Blocks._resolve_parts(speaker.name, game.context)[0]
		box.theme_type_variation = 'ADVViewWithSpeaker'
		
		if speaker.variation != '':
			speaker_panel.theme_type_variation = speaker.variation
		else:
			speaker_panel.theme_type_variation = 'ADVSpeaker'
		
		# if speaker panel has a StyleBoxFlat, set its background color
		var sb: StyleBox = speaker_panel.get_theme_stylebox('panel', 'ADVSpeaker')
		if sb is StyleBoxFlat:
			if speaker.bg_color != Color.TRANSPARENT:
				sb.bg_color = speaker.bg_color
			else:
				sb.bg_color = default_speaker_panel_bg_color
			# in case previous speaker has the same name – it wouldn't redraw automatically
			speaker_panel.queue_redraw()
		
		# add speaker name color override if specified, else remove the previous one (if any)
		if speaker.name_color != Color.TRANSPARENT:
			speaker_name.add_theme_color_override('font_color', speaker.name_color)
		elif speaker_name.has_theme_color_override('font_color'):
			speaker_name.remove_theme_color_override('font_color')
		
	else:
		speaker_panel.visible = false
		box.theme_type_variation = 'ADVView'


func _current_label() -> RichTextLabel:
	return label


func _get_scene_path():
	return 'res://tiger-engine/game/views/ADVView.tscn'
