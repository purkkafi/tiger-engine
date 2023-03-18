class_name LogOverlay extends Overlay
# responsible for displaying a Log to the user


var gamelog: Log = null # set this to the log before spawning the overlay


func _initialize_overlay():
	var text: String = ''
	
	# TODO: handle speaker tags
	for line in gamelog.lines:
		text += line + '\n\n'
	
	%Text.bbcode_enabled = true
	%Text.text = text.strip_edges()
	# scroll to the end
	%Text.scroll_to_line(%Text.get_line_count())


func _exit():
	_close_overlay()
