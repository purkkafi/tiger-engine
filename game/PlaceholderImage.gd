extends ColorRect
# placeholder image for unimplemented backgrounds;
# displays a debug text


func set_text(text: String) -> void:
	for label in %Grid.get_children():
		label.text = text
