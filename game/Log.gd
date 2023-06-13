class_name Log extends RefCounted
# maintains a list of previously encountered lines of text displayed
# with LogOverlay


const LOG_SIZE: int = 50 # amount of lines to keep
# the log
# every line is either:
# – a String
# – a dict of form { speaker: [speaker object], line: [line] }
var lines: Array[Variant] = []


# adds a line to the log, removing old ones if necessary
# speaker is either the speaker object or null
func add_line(line: String, speaker: Variant = null):
	if speaker == null:
		lines.push_back(line)
	else:
		lines.push_back({ 'speaker': (speaker as Speaker), 'line': line })
	while len(lines) > LOG_SIZE:
		lines.pop_front()


# removes the last line; used on rollback
func remove_last():
	lines.pop_back()
