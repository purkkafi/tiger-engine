class_name SuggestLineEdit extends MenuButton
# a LineEdit which shows the user a list of pre-defined suggestions while typing


# callback that returns Array of suggestions
var suggestion_provider: Callable = func(): return [] as Array

var line_edit: LineEdit = LineEdit.new()


@warning_ignore("unused_signal")
signal text_changed(new_text: String)


func _ready():
	add_child(line_edit)
	self.custom_minimum_size = line_edit.size
	line_edit.position = self.position
	
	line_edit.connect('focus_entered', _show_menu)
	line_edit.connect('focus_exited', _hide_menu)
	line_edit.connect('gui_input', _line_edit_gui_input)
	line_edit.connect('text_changed', func(new_text): emit_signal('text_changed', new_text))
	
	connect('resized', func(): line_edit.custom_minimum_size = size)
	
	get_popup().connect('index_pressed', func(index): line_edit.text = get_popup().get_item_text(index))


func set_edit_text(new_text: String):
	line_edit.text = new_text


func edit_text() -> String:
	return line_edit.text


func _show_menu():
	get_popup().clear()
	for suggestion in suggestion_provider.call():
		get_popup().add_item(suggestion)
	show_popup()
	get_popup().visible = true


func _hide_menu():
	get_popup().visible = false


func _line_edit_gui_input(event: InputEvent):
	if event is InputEventMouseButton and event.pressed and event.button_index == 1:
		if get_popup().visible:
			_hide_menu()
		else:
			_show_menu()
