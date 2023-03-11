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

# will be set to the calculated width and the height of the controls
var width: float
var height: float


func _ready():
	# centers controls to bottom center of the screen and sets sizes:
	# width is 'width' as defined in 'VNControlsPanel'
	# height is 'bottom_offset' + 'height' + 'top_offset'
	# mobile size options are also factored in
	
	width = get_theme_constant('width', 'VNControlsPanel')
	if Global.is_large_gui():
		width += get_theme_constant('mobile_width_offset', 'VNControlsPanel')
	
	panel.size.x = width
	panel.position.x = (1920-width)/2
	
	var btm_offset: float = get_theme_constant('bottom_offset', 'VNControlsPanel')
	var self_height: float =  get_theme_constant('height', 'VNControlsPanel')
	if Global.is_large_gui():
		self_height += get_theme_constant('mobile_height_offset', 'VNControlsPanel')
	
	panel.size.y = self_height
	panel.position.y = 1080-self_height-btm_offset
	height = get_theme_constant('top_offset', 'VNControlsPanel') + self_height + btm_offset
	
	hbox.add_theme_constant_override('separation', get_theme_constant('separation', 'VNControlsPanel'))


func set_buttons_disabled(disabled: bool):
	for btn in hbox.get_children():
		btn.disabled = disabled
