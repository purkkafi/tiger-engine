# line in NVL mode containing a speaker label and dialogue
class_name SpeakerNVLLine extends HBoxContainer


var speaker: Speaker
var line: String
var speaker_label: RichTextLabel
var line_label: RichTextLabel


func _init(_speaker: Speaker, _line: String, label_provider: Callable = func(): return RichTextLabel.new()):
	self.speaker = _speaker
	self.line = _line
	
	speaker_label = label_provider.call()
	speaker_label.text = '[color=%s][b]%s[/b][/color]' % [speaker.log_color.to_html(), speaker.name]
	self.add_child(speaker_label)
	
	line_label = label_provider.call()
	line_label.text = line
	self.add_child(line_label)


func _ready() -> void:
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	
	speaker_label.bbcode_enabled = true
	speaker_label.fit_content = true
	TETheme.theme_changed.connect(_recalc_speaker_label_size)
	_recalc_speaker_label_size()
	speaker_label.autowrap_mode = TextServer.AUTOWRAP_OFF
		
	line_label.bbcode_enabled = true
	line_label.fit_content = true
	line_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL


# (re)calculate how wide the speaker label should be based on theme constant
# 'speaker_label_width' in NVLView (or default value 150 if not defined)
func _recalc_speaker_label_size():
	var width = 150
	if has_theme_constant(&'speaker_label_width', &'NVLView'):
		width = get_theme_constant(&'speaker_label_width', &'NVLView')
	
	speaker_label.custom_minimum_size.x = 0
	if speaker_label.custom_minimum_size.x < width:
		speaker_label.custom_minimum_size.x = width


# adds a line break before this line
# the implementation is stupid but it works
func add_line_break():
	speaker_label.text = '[br]' + speaker_label.text
	line_label.text = '[br]' + line_label.text
