class_name SaveButton extends VBoxContainer


var bank: int
var index: int
var icon: TextureRect = TextureRect.new()
var name_label: Label = Label.new()
var reload_callback: Callable
var clicked_callback: Callable
var icon_warn: TextureRect


# TODO make navigable via focus
# https://godotengine.org/qa/97343/visualize-selected-part-the-similar-itemlist-without-using


func _init(_bank: int, _index: int, _icon: Texture2D, _reload_callback: Callable, _clicked_callback: Callable):
	self.bank = _bank
	self.index = _index
	self.icon.texture = _icon
	self.reload_callback = _reload_callback
	self.clicked_callback = _clicked_callback
	add_theme_constant_override('separation', 5)


func _enter_tree():
	var save = TE.savefile.get_save(bank, index)
		# if represents an empty save
	if save == null:
		name_label.text = TE.ui_strings.saving_empty
		self.modulate = Color(1, 1, 1, 0.5)
	else:
		if save['save_name'] == null:
			# remove seconds from end, should be valid due to ISO 8601
			name_label.text = save['save_datetime'].substr(0, 16)
		else:
			name_label.text = save['save_name']
			if len(name_label.text) >= 15:
				name_label.text = name_label.text.substr(0, 14) + '...'
		
		name_label.connect('gui_input', Callable(self, '_label_clicked'))
		name_label.mouse_filter = Control.MOUSE_FILTER_STOP
		name_label.tooltip_text = TE.ui_strings.saving_rename_tooltip
		
		var icon_tooltip = ''
		if save['save_name'] != null:
			icon_tooltip += save['save_name'] + '\n'
		if 'game_name' in save and save['game_name'] != null:
			icon_tooltip += save['game_name'] + '\n'
		if 'game_version' in save and save['game_version'] != null:
			icon_tooltip += save['game_version'] + '\n'
		icon_tooltip += save['save_datetime']
		icon.tooltip_text = icon_tooltip
		
		# if hash is missing or doesn't match
		if not 'hash' in save or save['hash'] != ScriptFile.get_hash(save['script_file'], save['current_script']):
			icon_warn = TextureRect.new()
			icon_warn.texture = Assets.permanent.get_resource('res://ui/warning.png')
			icon_warn.anchor_top = 0.6
			icon_warn.anchor_left = 0.75
			icon_warn.tooltip_text = TE.ui_strings.saving_bad_hash
			icon.add_child(icon_warn)
		
	
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = SIZE_EXPAND_FILL
	icon.size_flags_horizontal = SIZE_EXPAND_FILL
	# warning-ignore:return_value_discarded
	icon.connect('gui_input',Callable(self,'_icon_clicked'))
	add_child(icon)
	
	name_label.size_flags_horizontal = SIZE_SHRINK_CENTER
	add_child(name_label)
	
	self.size_flags_horizontal = SIZE_EXPAND_FILL
	self.size_flags_vertical = SIZE_EXPAND_FILL


func _label_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var edit = LineEdit.new()
		
		var previous_name = TE.savefile.get_save(bank, index)['save_name']
		if previous_name != null:
			edit.text = previous_name
		
		var popup: AcceptDialog = Popups.text_entry_dialog(TE.ui_strings.saving_rename, edit)
		popup.connect('confirmed', Callable(self, '_renamed').bind(edit))


func _renamed(edit: LineEdit):
	if edit.text == '':
		TE.savefile.get_save(bank, index)['save_name'] = null
	else:
		TE.savefile.get_save(bank, index)['save_name'] = edit.text
	TE.savefile.write_saves()
	reload_callback.call(bank, index)


func _icon_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked_callback.call(bank, index)


func _input(event: InputEvent):
	if has_focus() and event is InputEventKey and event.pressed and\
			(event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
		clicked_callback.call(bank, index)


func _draw():
	if has_focus():
		draw_style_box(get_theme_stylebox('hover', 'Button'), Rect2(Vector2(-5, -5), self.size + Vector2(10, 10)))
