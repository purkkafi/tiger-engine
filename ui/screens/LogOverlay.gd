class_name LogOverlay extends Overlay
# responsible for displaying a Log to the user


var gamelog: Log = null # set this to the log before spawning the overlay


func _initialize_overlay():
	var text: String = ''
	
	for line in gamelog.lines:
		if line is String: # log line is a plain Strng
			text += line + '\n\n'
		else: # log line has a speaker object
			var speaker = line['speaker']
			
			# try to get color from 1) name_color 2) bg_color in this order
			var color: Color = Color.WHITE
			if speaker.name_color != Color.TRANSPARENT:
				color = speaker.name_color
			elif speaker.bg_color != Color.TRANSPARENT:
				color = speaker.bg_color
			
			var name_label = '[color=%s][b]%s[/b][/color]    ' % [color.to_html(), speaker.name]
			text += name_label + line['line'] + '\n\n'
	
	%Text.bbcode_enabled = true
	%Text.text = text.strip_edges()
	# scroll to the end
	%Text.scroll_to_line(%Text.get_line_count())


func _exit():
	_close_overlay()
