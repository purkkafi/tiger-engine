class_name ADVView extends View


@onready var box: PanelContainer = %TextBox
@onready var decoration: Panel = %Decoration
@onready var speaker_panel: PanelContainer = %SpeakerPanel
@onready var speaker_name: Label = %SpeakerName
var label: RichTextLabel

@onready var default_speaker_name_color: Color = Color(speaker_name.get_theme_color('font_color'))
var default_speaker_panel_bg_color: Color = Color.TRANSPARENT


func _ready():
	label = create_label()
	
	box.add_child(label)
	
	connect('game_paused', _game_paused)
	
	speaker_panel.visible = false
	
	if speaker_panel.get_theme_stylebox('panel', 'ADVSpeaker') is StyleBoxFlat:
		default_speaker_panel_bg_color = speaker_panel.get_theme_stylebox('panel', 'ADVSpeaker').bg_color


func initialize(ctxt: View.InitContext):
	# hide self automatically
	# this fixes the UI flashing with empty ADVViews that are only
	# used to display a transition
	if ctxt == View.InitContext.NEW_VIEW:
		self.modulate.a = 0


func adjust_size(controls: VNControls):
	var controls_height: float = controls.size.y if controls != null else 0.0
	
	var w: float = 1200
	if has_theme_constant('width', 'ADVView'):
		w = get_theme_constant('width', 'ADVView')
	
	var h: float = 300
	if has_theme_constant('height', 'ADVView'):
		h = get_theme_constant('height', 'ADVView')
	
	box.size.x = w
	box.size.y = h
	box.position.x = (TE.SCREEN_WIDTH - w)/2 
	box.position.y = TE.SCREEN_HEIGHT - h - controls_height
	
	decoration.position = box.position
	decoration.size = box.size
	
	if has_theme_stylebox('decoration', 'ADVView'):
		decoration.add_theme_stylebox_override('panel', get_theme_stylebox('decoration', 'ADVView'))
	else:
		decoration.visible = false
	
	if speaker_panel.visible:
		_adjust_speaker_panel()


func _adjust_speaker_panel():
	var speaker_offset_x: float = get_theme_constant('speaker_offset_x', 'ADVSpeaker')
	var speaker_offset_y: float = get_theme_constant('speaker_offset_y', 'ADVSpeaker')
	
	if has_theme_constant('min_width', 'ADVSpeaker'):
		speaker_panel.custom_minimum_size.x = get_theme_constant('min_width', 'ADVSpeaker')
	
	# BUGFIX: godot seems to report 'speaker_panel.size' wrong unless position is "refreshed" first
	# i don't know why but this works
	speaker_panel.position = Vector2(0,0)
	
	if has_theme_constant('center_horizontally', 'ADVSpeaker') and get_theme_constant('center_horizontally', 'ADVSpeaker') == 1:
		speaker_panel.position.x = (TE.SCREEN_WIDTH - speaker_panel.size.x)/2
		speaker_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	else:
		speaker_panel.position.x = box.position.x + speaker_offset_x
		speaker_name.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	
	speaker_panel.position.y = box.position.y - speaker_panel.size.y + speaker_offset_y


func _game_paused():
	box.visible = false
	decoration.visible = false
	speaker_panel.visible = false


func _display_line(line: String, speaker: Speaker = null):
	box.visible = true
	decoration.visible = true
	speaker_panel.visible = true
	label.text = line
	
	if speaker != null:
		speaker_panel.visible = true
		speaker_name.text = speaker.name
		
		if speaker.textbox_variation != '':
			box.theme_type_variation = speaker.textbox_variation
		else:
			box.theme_type_variation = 'ADVView'
		
		if speaker.label_variation != '':
			speaker_panel.theme_type_variation = speaker.label_variation
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
		
		_adjust_speaker_panel()
		
	else:
		speaker_panel.visible = false
		box.theme_type_variation = 'ADVView'


func _current_label() -> RichTextLabel:
	return label
