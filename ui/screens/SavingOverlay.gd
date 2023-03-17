class_name SavingOverlay extends Overlay


# properties of the thumbnails
const THUMB_WIDTH = 480
const THUMB_HEIGHT = 270
const THUMB_FORMAT = Image.FORMAT_RGB8


var saved_callback: Variant = null # Callable; when saved, called with the new save
var warn_about_progress = false # whether to warn that progress will be lost
var additional_navigation = false # additional "Return to title" and "Quit game" buttons
var mode = null # enum SavingMode
var screenshot: Image = null # the screenshot to use when saving
var save: Dictionary # the savefile to save
var thumbnails: Image = null # image containing the thumbnails for current page of saves
var last_clicked_tab: int = -1 # used to detect when tab should be renamed
@onready var header: Label = %Header
@onready var back: Button = %Back
@onready var to_title: Button = %ToTitle
@onready var quit_game: Button = %QuitGame
@onready var tabs: TabContainer = %Tabs


enum SavingMode { SAVE, LOAD }


func _initialize_overlay():
	tabs.connect('tab_changed', Callable(self, '_load_tab'))
	tabs.connect('tab_selected', Callable(self, '_rename_tab'))
	
	for i in len(TE.savefile.banks):
		tabs.add_child(get_empty_bank())
		tabs.set_tab_title(i, trim_tab_name(TE.savefile.banks[i]['name']))
	
	# find out which bank to display based on utimes
	var max_utime: int = -1
	var selected_bank = 0
	
	for i in len(TE.savefile.banks):
		for a in len(TE.savefile.banks[i]['saves']):
			var this_save = TE.savefile.get_save(i, a)
			if this_save != null:
				if int(this_save['save_utime']) > max_utime:
					max_utime = int(this_save['save_utime'])
					selected_bank = i
	
	# select the correct tab, also loading its content
	self._select_initial_tab.call_deferred(selected_bank)
	
	if mode == SavingMode.SAVE:
		header.text = TE.ui_strings.saving_save
	elif mode == SavingMode.LOAD:
		header.text = TE.ui_strings.saving_load
	else:
		TE.log_error('SavingOverlay must be in mode SAVE or LOAD')
		return
	
	back.connect('pressed', Callable(self, '_back'))
	back.grab_focus()
	
	if additional_navigation:
		quit_game.connect('pressed',Callable(self, '_quit_game'))
		to_title.connect('pressed',Callable(self, '_to_title'))
	else:
		quit_game.visible = false
		to_title.visible = false


func _select_initial_tab(initial_bank: int):
	tabs.current_tab = initial_bank

# tabs are filled with empty MarginContainers by default; as it is an expensive
# operation, the relevant GridContainer is filled in when needed
func get_empty_bank() -> MarginContainer:
	return MarginContainer.new()


# loads the given tab, adding the GridContainer to its MarginContainer if it's empty
func _load_tab(index: int):
	var bank = tabs.get_child(index)
	if bank.get_child_count() == 0:
		var grid = get_bank_grid(index)
		bank.add_child(grid)


func _rename_tab(index: int):
	if last_clicked_tab == index:
		var edit: LineEdit = LineEdit.new()
		edit.text = TE.savefile.banks[index]['name']
		var popup: AcceptDialog = Popups.text_entry_dialog(TE.ui_strings.saving_rename_bank, edit)
		popup.connect('confirmed', Callable(self, '_do_tab_rename').bind(index, edit))
	last_clicked_tab = index


func _do_tab_rename(index: int, edit: LineEdit):
	if edit.text == '':
		return
	var text: String = edit.text
	tabs.set_tab_title(index, SavingOverlay.trim_tab_name(text))
	TE.savefile.banks[index]['name'] = text
	TE.savefile.write_saves()


static func trim_tab_name(tab: String) -> String:
	if len(tab) > 20:
		return tab.substr(0, 20) + '...'
	return tab


# returns a GridContainer that contains the save icons
func get_bank_grid(bank: int) -> GridContainer:
	if FileAccess.file_exists(TE.savefile.thumbs_path(bank)):
		thumbnails = Image.new()
		thumbnails.load(TE.savefile.thumbs_path(bank))
	else:
		thumbnails = Image.create(THUMB_WIDTH, 12 * THUMB_HEIGHT, false, THUMB_FORMAT)
		thumbnails.fill(Color.BLACK)
	
	var grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	
	for i in range(12):
		grid.add_child(_new_save_button(bank, i))
	
	return grid


func _new_save_button(bank: int, index: int):
	var icon: Image = Image.create(THUMB_WIDTH, THUMB_HEIGHT, false, THUMB_FORMAT)
	icon.blit_rect(thumbnails, Rect2(0, THUMB_HEIGHT * index, THUMB_WIDTH, THUMB_HEIGHT), Vector2(0, 0))
	
	var texture: ImageTexture = ImageTexture.create_from_image(icon)
	
	var button = SaveButton.new(bank, index, texture,
				Callable(self, '_reload_save_button'),
				Callable(self, '_save_icon_clicked'))
	
	if mode == SavingMode.LOAD and TE.savefile.get_save(bank, index) == null:
		button.focus_mode = FOCUS_NONE
	else:
		button.focus_mode = FOCUS_ALL
	
	return button


func _reload_save_button(bank: int, index: int):
	var grid: GridContainer = tabs.get_child(bank).get_child(0)
	var old = grid.get_child(index)
	grid.remove_child(old)
	old.queue_free()
	
	var new: SaveButton = _new_save_button(bank, index)
	grid.add_child(new)
	grid.move_child(new, index)
	new.grab_focus()


func _save_icon_clicked(bank: int, index: int):
	if mode == SavingMode.LOAD:
		if TE.savefile.get_save(bank, index) != null:
			if warn_about_progress:
				var popup = Popups.warning_dialog(TE.ui_strings.saving_progress_lost)
				popup.get_ok_button().connect('pressed', Callable(self, '_do_load').bind(bank, index))
			else:
				_do_load(bank, index)
		
	elif mode == SavingMode.SAVE:
		if TE.savefile.get_save(bank, index) != null:
			var popup = Popups.warning_dialog(TE.ui_strings.saving_overwrite)
			popup.get_ok_button().connect('pressed', Callable(self, '_do_save').bind(bank, index))
		else:
			_do_save(bank, index)


func _do_load(bank: int, index: int):
	TE.load_from_save(TE.savefile.get_save(bank, index))


func _do_save(bank, index):
	# write timestamp
	save['save_datetime'] = Time.get_datetime_string_from_datetime_dict(Time.get_datetime_dict_from_system(), true)
	save['save_utime'] = str(Time.get_unix_time_from_system())
	
	# write thumbnails
	thumbnails.blit_rect(screenshot, Rect2(0, 0, THUMB_WIDTH, THUMB_HEIGHT), Vector2(0, THUMB_HEIGHT * index))
	var error = thumbnails.save_png(TE.savefile.thumbs_path(bank))
	if error != OK:
		TE.log_error("can't write thumbnails: " + TE.savefile.thumbs_path(bank))
	
	TE.savefile.set_save(save.duplicate(true), screenshot, bank, index)
	warn_about_progress = false
	_reload_save_button(bank, index)
	
	if saved_callback != null:
		saved_callback.call(save)


func _back():
	_close_overlay()
	animating_out_callback.call()
	back.disabled = true


func _quit_game():
	if warn_about_progress:
		var popup = Popups.warning_dialog(TE.ui_strings.saving_progress_lost)
		popup.get_ok_button().connect('pressed', Callable(self, '_do_quit'))
	else:
		_do_quit()


func _do_quit():
	get_tree().quit()


func _to_title():
	if warn_about_progress:
		var popup = Popups.warning_dialog(TE.ui_strings.saving_progress_lost)
		popup.get_ok_button().connect('pressed', Callable(self, '_do_title'))
	else:
		_do_title()


func _do_title():
	TE.switch_scene(load(TE.opts.title_screen).instantiate())