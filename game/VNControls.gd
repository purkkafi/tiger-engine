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
		else: # when enabling, read previous state from metadata
			if btn.has_meta('disabled_state'):
				btn.disabled = btn.get_meta('disabled_state')
			else:
				btn.disabled = false
