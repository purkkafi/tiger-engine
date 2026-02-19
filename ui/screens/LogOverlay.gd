class_name LogOverlay extends Overlay
# responsible for displaying a Log to the user


# regexes for removing [dropcap] bbcode
static var DROPCAP_START: RegEx = RegEx.create_from_string('\\[dropcap.*?\\]')
static var DROPCAP_END: RegEx = RegEx.create_from_string('\\[\\/dropcap\\]')


var gamelog: Log = null # set this to the log before spawning the overlay
var context: InGameContext = null # set this to the game context before spawning the overlay


func _initialize_overlay():
	size_to_small()
	
	%Text.get_v_scroll_bar().custom_step = 3 * TETheme.current_theme.default_font_size
	
	# TODO show in a grid instead?
	var text: String = '\n\n'.join(gamelog.entries.map(func(entry): return format_entry(entry)))
	
	text = DROPCAP_START.sub(text, '', true)
	text = DROPCAP_END.sub(text, '', true)
	text = text.strip_edges()
	
	%Text.bbcode_enabled = true
	%Text.text = text
	# scroll to the end
	%Text.scroll_to_line(%Text.get_line_count())
	
	%Exit.grab_focus()


# formats an entry for the log
# TODO refactor speaker parsing, remove duplicate functionality from View
func format_entry(entry: Log.Entry) -> String:
	var bf: BlockFile = Assets.blockfiles.get_unqueued(entry.blockfile)
	
	if bf == null or not entry.block in bf.blocks:
		return ''
	
	var block: Block = bf.blocks[entry.block]
	var parts: Array[String] = Blocks.resolve_parts(block, context)
	var texts: Array[String] = []
	
	for index in min(entry.line+1, len(parts)):
		var part: String = parts[index]
		var tag_bbcode: RegExMatch = View.GET_BBCODE.search(part)
		
		if tag_bbcode != null and tag_bbcode.get_string('tag') == 'speaker':
			var _result: Dictionary  = View._parse_speaker_line(part, tag_bbcode, context)
			var line = _result['line']
			var speaker = _result['speaker']
			texts.append('[color=%s][b]%s[/b][/color]    %s' % [speaker.log_color.to_html(), speaker.name, line])
		else:
			texts.append(part)
	
	return '\n\n'.join(texts)


func _exit():
	_close_overlay()
