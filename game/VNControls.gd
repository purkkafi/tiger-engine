class_name VNControls extends Control
# contains the bottom row of buttons found in the typical VN interface
# they exist in a normally invisible ScrollContainer to prevent overflow


@onready var panel: PanelContainer = %Panel
@onready var hbox: HBoxContainer = %HBox

@onready var btn_back: Button = %Back
@onready var btn_save: Button = %Save
@onready var btn_load: Button = %Load
@onready var btn_log: Button = %Log
@onready var btn_skip: Button = %Skip
@onready var btn_settings: Button = %Settings
@onready var btn_quit: Button = %Quit


func _ready():
	hbox.add_theme_constant_override('separation', get_theme_constant('separation', 'VNControlsPanel'))
	
	if 'game_back_icon' in TE.localize.strings:
		btn_back.icon = load(TE.localize.game_back_icon)
		btn_back.text = ''
		btn_back.tooltip_text = TE.localize.game_back
	if 'game_save_icon' in TE.localize.strings:
		btn_save.icon = load(TE.localize.game_save_icon)
		btn_save.text = ''
		btn_save.tooltip_text = TE.localize.game_save
	if 'game_load_icon' in TE.localize.strings:
		btn_load.icon = load(TE.localize.game_load_icon)
		btn_load.text = ''
		btn_load.tooltip_text = TE.localize.game_load
	if 'game_log_icon' in TE.localize.strings:
		btn_log.icon = load(TE.localize.game_log_icon)
		btn_log.text = ''
		btn_log.tooltip_text = TE.localize.game_log
	if 'game_skip_icon' in TE.localize.strings:
		btn_skip.icon = load(TE.localize.game_skip_icon)
		btn_skip.text = ''
		btn_skip.tooltip_text = TE.localize.game_skip
	if 'game_settings_icon' in TE.localize.strings:
		btn_settings.icon = load(TE.localize.game_settings_icon)
		btn_settings.text = ''
		btn_settings.tooltip_text = TE.localize.game_settings
	if 'game_quit_icon' in TE.localize.strings:
		btn_quit.icon = load(TE.localize.game_quit_icon)
		btn_quit.text = ''
		btn_quit.tooltip_text = TE.localize.game_quit
	
	adjust_size()


func adjust_size():
	# centers controls to bottom center of the screen and sets sizes:
	# width is 'width' as defined in 'VNControlsPanel'
	# height is 'bottom_offset' + 'height' + 'top_offset'
	
	var w: float = get_theme_constant('width', 'VNControlsPanel')
	var h: float =  get_theme_constant('height', 'VNControlsPanel')
	var bottom_offset: float = get_theme_constant('bottom_offset', 'VNControlsPanel')
	var top_offset: float = get_theme_constant('top_offset', 'VNControlsPanel')
	
	panel.size.x = w
	panel.size.y = h
	
	self.size.x = w
	self.size.y = bottom_offset + h + top_offset
	self.position.x = (TE.SCREEN_WIDTH - w)/2
	self.position.y = TE.SCREEN_HEIGHT - bottom_offset - h


# disables or enables all buttons
# when disabling and then enabling, their previous state will be restored
# this avoids errors with the back button (its state is managed by Rollback)
func set_buttons_disabled(disabled: bool):
	for btn in hbox.get_children():
		if disabled: # record current state into metadata when disabling
			btn.set_meta('disabled_state', btn.disabled)
			btn.disabled = true
			btn.focus_mode = FOCUS_NONE
		else: # when enabling, read previous state from metadata
			if btn.has_meta('disabled_state'):
				btn.disabled = btn.get_meta('disabled_state')
			else:
				btn.disabled = false
			btn.focus_mode = FOCUS_ALL
