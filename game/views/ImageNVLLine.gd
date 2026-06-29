class_name ImageNVLLine extends VBoxContainer


var rect: TextureRect
var next_label: RichTextLabel


func _init(texture: Texture2D, label_provider: Callable = func(): return RichTextLabel.new()) -> void:
	self.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	self.add_theme_constant_override('separation', 0)
	
	var initial_blank_line: RichTextLabel = label_provider.call()
	initial_blank_line.fit_content = true
	initial_blank_line.text = ' '
	add_child(initial_blank_line)
	
	rect = TextureRect.new()
	rect.texture = texture
	rect.expand_mode = TextureRect.EXPAND_FIT_HEIGHT_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(rect)
	
	next_label = label_provider.call()
	next_label.fit_content = true
	add_child(next_label)
