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
var last_clicked_tab: int = -1 # used to detect when tab should be renamed
@onready var header: Label = %Header
@onready var back: Button = %Back
@onready var to_title: Button = %ToTitle
@onready var quit_game: Button = %QuitGame
@onready var tabs: TabContainer = %Tabs


enum SavingMode { SAVE, LOAD }


# represents the contents of a tab: a grid of SaveButtons
# will initially have no children; they will be added as the bank is loaded
class SaveBank extends MarginContainer:
	var index: int # the index of this SaveBank in the TabContainer
	var thumbnails: Image = null # the Image containing the thumbnails for this SaveBank
	
	
	func _init(_index: int):
		self.index = _index


func _initialize_overlay():
	for i in len(TE.savefile.banks):
		tabs.add_child(SaveBank.new(i))
		tabs.set_tab_title(i, SavingOverlay.trim_tab_name(TE.savefile.banks[i]['name']))
	
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
	# it will be prepared after animation is finished to prevent lag
	tabs.current_tab = selected_bank
	animated_in_callback = Callable(self, '_prepare_initial_tab').bind(selected_bank)
	
	if mode == SavingMode.SAVE:
		header.text = TE.localize.saving_save
	elif mode == SavingMode.LOAD:
		header.text = TE.localize.saving_load
	else:
		TE.log_error(TE.Error.ENGINE_ERROR, 'SavingOverlay must be in mode SAVE or LOAD')
		return
	
	back.connect('pressed', Callable(self, '_back'))
	back.grab_focus()
	
	if additional_navigation:
		quit_game.connect('pressed',Callable(self, '_quit_game'))
		to_title.connect('pressed',Callable(self, '_to_title'))
	else:
		quit_game.visible = false
		to_title.visible = false


# loads the initially selected tab
func _prepare_initial_tab(initial_bank: int):
	tabs.connect('tab_changed', Callable(self, '_load_tab'))
	tabs.connect('tab_selected', Callable(self, '_rename_tab'))
	_load_tab(initial_bank)


# loads the given tab, adding the GridContainer to its SaveBank if it's empty
func _load_tab(index: int):
	var bank: SaveBank = tabs.get_child(index)
	if bank.get_child_count() == 0:
		var grid = get_bank_grid(bank)
		bank.add_child(grid)


func _rename_tab(index: int):
	if last_clicked_tab == index:
		var edit: LineEdit = LineEdit.new()
		edit.text = TE.savefile.banks[index]['name']
		var popup: AcceptDialog = Popups.text_entry_dialog(TE.localize.saving_rename_bank, edit)
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
func get_bank_grid(bank: SaveBank) -> GridContainer:
	if FileAccess.file_exists(TE.savefile.thumbs_path(bank.index)):
		bank.thumbnails = Image.new()
		bank.thumbnails.load(TE.savefile.thumbs_path(bank.index))
	else:
		bank.thumbnails = Image.create(THUMB_WIDTH, 12 * THUMB_HEIGHT, false, THUMB_FORMAT)
		bank.thumbnails.fill(Color.BLACK)
	
	var grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = SIZE_EXPAND_FILL
	grid.size_flags_vertical = SIZE_EXPAND_FILL
	
	for i in range(12):
		grid.add_child(_new_save_button(bank, i))
	
	return grid


func _new_save_button(bank: SaveBank, index: int):
	var icon: Image = Image.create(THUMB_WIDTH, THUMB_HEIGHT, false, THUMB_FORMAT)
	icon.blit_rect(bank.thumbnails, Rect2(0, THUMB_HEIGHT * index, THUMB_WIDTH, THUMB_HEIGHT), Vector2(0, 0))
	
	var texture: ImageTexture = ImageTexture.create_from_image(icon)
	
	var button = SaveButton.new(bank, index, texture,
				_reload_save_button,
				_save_icon_clicked)
	
	if mode == SavingMode.LOAD and not button.is_loadable():
		button.focus_mode = FOCUS_NONE
	else:
		button.focus_mode = FOCUS_ALL
	
	return button


func _reload_save_button(bank: SaveBank, index: int):
	var grid: GridContainer = tabs.get_child(bank.index).get_child(0)
	var old = grid.get_child(index)
	grid.remove_child(old)
	old.queue_free()
	
	var new: SaveButton = _new_save_button(bank, index)
	grid.add_child(new)
	grid.move_child(new, index)
	new.grab_focus()


func _save_icon_clicked(btn: SaveButton):
	if mode == SavingMode.LOAD:
		if btn.is_loadable():
			if warn_about_progress:
				var popup = Popups.warning_dialog(TE.localize.saving_progress_lost)
				popup.get_ok_button().connect('pressed', _do_load.bind(btn.bank, btn.index))
			else:
				_do_load(btn.bank, btn.index)
		else:
			if btn.continue_point == SaveButton.ContinuePoint.UNCONTINUABLE:
				var label: Label = Label.new()
				label.text = TE.localize.saving_uncontinuable
				var _popup = Popups.info_dialog(TE.localize.saving_future_continue_point, label)
		
	elif mode == SavingMode.SAVE:
		if not btn.is_empty:
			var popup = Popups.warning_dialog(TE.localize.saving_overwrite)
			popup.get_ok_button().connect('pressed', _do_save.bind(btn.bank, btn.index))
		else:
			_do_save(btn.bank, btn.index)


func _do_load(bank: SaveBank, index: int):
	TE.load_from_save(TE.savefile.get_save(bank.index, index))


func _do_save(bank: SaveBank, index: int):
	# write timestamp
	save['save_datetime'] = Time.get_datetime_string_from_datetime_dict(Time.get_datetime_dict_from_system(), true)
	save['save_utime'] = str(Time.get_unix_time_from_system())
	
	# write thumbnails
	bank.thumbnails.blit_rect(screenshot, Rect2(0, 0, THUMB_WIDTH, THUMB_HEIGHT), Vector2(0, THUMB_HEIGHT * index))
	var error = bank.thumbnails.save_png(TE.savefile.thumbs_path(bank.index))
	if error != OK:
		TE.log_error(TE.Error.ENGINE_ERROR, "can't write thumbnails: " + TE.savefile.thumbs_path(bank.index))
	
	TE.savefile.set_save(save.duplicate(true), screenshot, bank.index, index)
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
		var popup = Popups.warning_dialog(TE.localize.saving_progress_lost)
		popup.get_ok_button().connect('pressed', Callable(self, '_do_quit'))
	else:
		_do_quit()


func _do_quit():
	TE.quit_game()


func _to_title():
	if warn_about_progress:
		var popup = Popups.warning_dialog(TE.localize.saving_progress_lost)
		popup.get_ok_button().connect('pressed', Callable(self, '_do_title'))
	else:
		_do_title()


func _do_title():
	TE.switch_scene(load(TE.opts.title_screen).instantiate())
