class_name TEButton extends Button
# button that translates its text 

func _ready():
	# get text from ui strings if it is of the form %ui_string%
	if self.text.begins_with('%') and self.text.ends_with('%'):
		self.text = Global.ui_strings[self.text.substr(1, len(self.text)-2)]
