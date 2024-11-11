class_name LogOverlay extends Overlay
# responsible for displaying a Log to the user


# regexes for removing [dropcap] bbcode
static var DROPCAP_START: RegEx = RegEx.create_from_string('\\[dropcap.*?\\]')
static var DROPCAP_END: RegEx = RegEx.create_from_string('\\[\\/dropcap\\]')


var gamelog: Log = null # set this to the log before spawning the overlay


func _initialize_overlay():
	size_to_small()
	
	%Text.get_v_scroll_bar().custom_step = 3 * TETheme.current_theme.default_font_size
	
	var text: String = ''
	
	for line in gamelog.lines:
		if line is String: # log line is a plain String
			text += line + '\n\n'
		else: # log line has a speaker object
			var speaker: Speaker = line['speaker']
			
			var name_label = '[color=%s][b]%s[/b][/color]    ' % [speaker.log_color.to_html(), speaker.name]
			text += name_label + line['line'] + '\n\n'
	
	text = DROPCAP_START.sub(text, '', true)
	text = DROPCAP_END.sub(text, '', true)
	text = text.strip_edges()
	
	%Text.bbcode_enabled = true
	%Text.text = text
	# scroll to the end
	%Text.scroll_to_line(%Text.get_line_count())
	
	%Exit.grab_focus()


func _exit():
	_close_overlay()
