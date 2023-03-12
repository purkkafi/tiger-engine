extends ColorRect
# empty screen used to display an error popup when the game is crashed
# due to unrecoverable errors (see TEPopups)


func _ready():
	self.color = TE.opts.background_color
