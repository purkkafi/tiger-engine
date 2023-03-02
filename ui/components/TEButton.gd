class_name TEButton extends Button
# button that translates its name 

# Called when the node enters the scene tree for the first time.
func _ready():
	self.text = Global.ui_strings[self.text]
