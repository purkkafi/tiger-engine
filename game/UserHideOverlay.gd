# spawned when the user presses the hide button
# covers the entire screen and deletes itself in response to any input
# (more precisely, mouse click/touch press or key press)
class_name UserHideOverlay extends ColorRect


var game: TEGame


# adds the overlay as TEGame's child and sets its state
func initialize_for(_game: TEGame):
	self.game = _game
	self.size = game.size
	game.set_user_hide_controls(true)
	game.add_child(self)
	


func _input(event: InputEvent) -> void:
	get_viewport().set_input_as_handled()
	if event is InputEventMouseButton:
		_close()
	elif event is InputEventKey and (event as InputEventKey).pressed:
		_close()


func _close():
	game.set_user_hide_controls(false)
	game.remove_child(self)
	self.queue_free()
