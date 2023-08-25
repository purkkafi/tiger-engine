class_name LogOverlay extends Overlay
# responsible for displaying a Log to the user


var gamelog: Log = null # set this to the log before spawning the overlay


func _initialize_overlay():
	var text: String = ''
	
	for line in gamelog.lines:
		if line is String: # log line is a plain String
			text += line + '\n\n'
		else: # log line has a speaker object
			var speaker: Speaker = line['speaker']
			
			var name_label = '[color=%s][b]%s[/b][/color]    ' % [speaker.log_color.to_html(), speaker.name]
			text += name_label + line['line'] + '\n\n'
	
	%Text.bbcode_enabled = true
	%Text.text = text.strip_edges()
	# scroll to the end
	%Text.scroll_to_line(%Text.get_line_count())
	
	%Exit.grab_focus()


func _exit():
	_close_overlay()
