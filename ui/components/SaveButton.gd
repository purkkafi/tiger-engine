class_name SaveButton extends VBoxContainer
# component that forms the grid in SavingOverlay
# contains an icon (a screenshot of the save) that can be clicked,
# its label (that can be clicked to rename the save), and possibly
# a warning icon if save is unsafe to load


var save: Variant
var bank: SavingOverlay.SaveBank
var index: int
var icon: TextureRect = TextureRect.new()
var name_label: Label = Label.new()
var reload_callback: Callable # callback for when this SaveButton should be reloaded
var clicked_callback: Callable # callback for when the icon is clicked
var icon_warn: TextureRect
var is_hovered: bool
var continue_point: ContinuePoint # whether this save has a continue point
var is_empty: bool # whether the save is empty


enum ContinuePoint {
	NO_CONTINUE_POINT, # save does not refer to a continue point
	CONTINUABLE, # save refers to a point that can be loaded
	UNCONTINUABLE # save refers to a point that cannot be loaded
}


func _init(_bank: SavingOverlay.SaveBank, _index: int, _icon: Texture2D, _reload_callback: Callable, _clicked_callback: Callable):
	self.bank = _bank
	self.index = _index
	self.icon.texture = _icon
	self.reload_callback = _reload_callback
	self.clicked_callback = _clicked_callback
	add_theme_constant_override('separation', 5)
	self.mouse_filter = Control.MOUSE_FILTER_STOP
	self.connect('mouse_entered', func(): is_hovered = true; queue_redraw())
	self.connect('mouse_exited', func(): is_hovered = false; queue_redraw())
	
	self.save = TE.savefile.get_save(bank.index, index)
	self.is_empty = save == null
	
	if not is_empty:
		if 'continue_point' in save:
			if TEScriptVM.is_continue_point_valid(save['continue_point']):
				self.continue_point = ContinuePoint.CONTINUABLE
			else:
				self.continue_point =  ContinuePoint.UNCONTINUABLE
		else:
			self.continue_point = ContinuePoint.NO_CONTINUE_POINT
			

func _ready():
	name_label.theme_type_variation = 'SaveLabel'
	
	if is_empty:
		name_label.text = TE.localize.saving_empty
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
		name_label.tooltip_text = TE.localize.saving_rename_tooltip
		
		var icon_tooltip = ''
		if save['save_name'] != null:
			icon_tooltip += save['save_name'] + '\n'
		if 'game_name' in save and save['game_name'] != null and save['game_name'] != '':
			icon_tooltip += save['game_name'] + '\n'
		if 'game_version' in save and save['game_version'] != null and save['game_version'] != '':
			icon_tooltip += save['game_version'] + '\n'
		icon_tooltip += save['save_datetime']
		icon.tooltip_text = icon_tooltip
		
		if continue_point == ContinuePoint.NO_CONTINUE_POINT:
			check_hashes.call_deferred()
		elif continue_point == ContinuePoint.CONTINUABLE:
			icon.tooltip_text = '%s\n\n%s' % [TE.localize.saving_continuable, icon_tooltip]
			name_label.add_theme_color_override('font_color', get_theme_color('continuable', 'SaveBox'))
			self.icon.texture = get_theme_icon('continuable_icon', 'SaveBox')
		elif continue_point == ContinuePoint.UNCONTINUABLE:
			icon.tooltip_text = '%s\n\n%s' % [TE.localize.saving_uncontinuable, icon_tooltip]
			name_label.add_theme_color_override('font_color', get_theme_color('uncontinuable', 'SaveBox'))
			self.icon.texture = get_theme_icon('uncontinuable_icon', 'SaveBox')
	
	icon.expand = true
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = SIZE_EXPAND_FILL
	icon.size_flags_horizontal = SIZE_EXPAND_FILL
	icon.connect('gui_input', Callable(self, '_icon_clicked'))
	add_child(icon)
	
	name_label.size_flags_horizontal = SIZE_SHRINK_CENTER
	add_child(name_label)
	
	self.size_flags_horizontal = SIZE_EXPAND_FILL
	self.size_flags_vertical = SIZE_EXPAND_FILL


# returns whether the save button can be clicked to load it in load mode
func is_loadable():
	return (not is_empty) and continue_point != ContinuePoint.UNCONTINUABLE


# checks if the save file's hashes match with game files and adds a warning icon
# if they do not
func check_hashes():
	var script_hashes_match: bool = false
	var block_hashes_match: bool = false
	var vm: Dictionary = save['vm']
	var view: Dictionary = save['view']
	
	if FileAccess.file_exists(vm['scriptfile']):
		# ensure game has loaded files & calculated hashes
		Assets.scripts.get_unqueued(vm['scriptfile'])
		var script_hash_key = vm['scriptfile'] + ':' + vm['current_script']
		
		if script_hash_key in Assets.scripts.hashes:
			if vm['hash'] == Assets.scripts.hashes[script_hash_key]:
				script_hashes_match = true
	
	# save may not have block data if the View isn't used to show blocks
	if 'block' in save['view'] and FileAccess.file_exists(view['blockfile']):
		Assets.blockfiles.get_unqueued(view['blockfile'])
		var block_hash_key = view['blockfile'] + ':' + view['block']
		
		if block_hash_key in Assets.blockfiles.hashes:
			if view['hash'] == Assets.blockfiles.hashes[block_hash_key]:
				block_hashes_match = true
	else:
		block_hashes_match = true # nothing to compare to
	
	if not (script_hashes_match and block_hashes_match):
		# add warning to text
		icon.tooltip_text = '%s\n\n%s' % [icon.tooltip_text, TE.localize.saving_bad_hash]
		
		# set name color
		if has_theme_color('hash_mismatch', 'SaveBox'):
			var mismatch_color: Color = get_theme_color('hash_mismatch', 'SaveBox')
			name_label.add_theme_color_override('font_color', mismatch_color)
			var ms2 = mismatch_color.blend(Color(1, 1, 1, 0.5))
			icon.modulate = ms2
		
		# place warning icon
		# TODO re-implement properly
		"""
		icon_warn = TextureRect.new()
		icon_warn.texture = get_theme_icon('image', 'SaveWarningIcon')
		icon_warn.tooltip_text = TE.localize.saving_bad_hash
		icon_warn.anchor_top = 0.5
		icon_warn.anchor_bottom = 0.5
		icon_warn.anchor_left = 0.75
		icon_warn.anchor_right = 0.75
		icon.add_child(icon_warn)
		"""


# when the save's name is clocked
func _label_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var edit = LineEdit.new()
		
		var previous_name = TE.savefile.get_save(bank.index, index)['save_name']
		if previous_name != null:
			edit.text = previous_name
		
		var popup: AcceptDialog = Popups.text_entry_dialog(TE.localize.saving_rename, edit)
		popup.connect('confirmed', Callable(self, '_renamed').bind(edit))


func _renamed(edit: LineEdit):
	if edit.text == '':
		TE.savefile.get_save(bank.index, index)['save_name'] = null
	else:
		TE.savefile.get_save(bank.index, index)['save_name'] = edit.text
	TE.savefile.write_saves()
	reload_callback.call(bank, index)


# when the save's image is clicked
func _icon_clicked(event):
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clicked_callback.call(self)


func _input(event: InputEvent):
	if has_focus() and event is InputEventKey and event.pressed and\
			(event.keycode == KEY_ENTER or event.keycode == KEY_SPACE):
		clicked_callback.call(self)


func _draw():
	if is_hovered:
		draw_style_box(get_theme_stylebox('hover', 'SaveBox'), Rect2(Vector2(-5, -5), self.size + Vector2(10, 10)))
	if has_focus():
		draw_style_box(get_theme_stylebox('focus', 'SaveBox'), Rect2(Vector2(-5, -5), self.size + Vector2(10, 10)))
