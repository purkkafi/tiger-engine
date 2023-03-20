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

var width: float = get_theme_constant('width', 'VNControlsPanel')
var height: float =  get_theme_constant('height', 'VNControlsPanel')
var mobile_offset_x: float = get_theme_constant('mobile_offset_x', 'VNControlsPanel')
var mobile_offset_y: float = get_theme_constant('mobile_offset_y', 'VNControlsPanel')
var bottom_offset: float = get_theme_constant('bottom_offset', 'VNControlsPanel')
var top_offset: float = get_theme_constant('top_offset', 'VNControlsPanel')


func _ready():
	hbox.add_theme_constant_override('separation', get_theme_constant('separation', 'VNControlsPanel'))
	
	# provide default values if running without a theme
	if width == 0:
		width = 1000
	if height == 0:
		height = 80
	
	_set_gui_size(TE.settings.gui_scale)


func _set_gui_size(gui_scale: Settings.GUIScale):
	# centers controls to bottom center of the screen and sets sizes:
	# width is 'width' as defined in 'VNControlsPanel'
	# height is 'bottom_offset' + 'height' + 'top_offset'
	# mobile size options are also factored in
	
	var w: float = width
	var h: float = height
	if gui_scale == Settings.GUIScale.LARGE:
		w += mobile_offset_x
		h += mobile_offset_y
	
	panel.size.x = w
	panel.size.y = h
	
	self.size.x = w
	self.size.y = bottom_offset + h + top_offset
	self.position.x = (TE.SCREEN_WIDTH - w)/2
	self.position.y = TE.SCREEN_HEIGHT - bottom_offset - h


func set_buttons_disabled(disabled: bool):
	for btn in hbox.get_children():
		btn.disabled = disabled
