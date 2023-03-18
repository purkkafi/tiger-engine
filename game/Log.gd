class_name Log extends RefCounted
# maintains a list of previously encountered lines of text displayed
# with LogOverlay


const LOG_SIZE: int = 50 # amount of lines to keep
var lines: Array[String] = [] # the log


# adds a line to the log, removing old ones if necessary
func add_line(line: String):
	lines.push_back(line)
	while len(lines) > LOG_SIZE:
		lines.pop_front()


# removes the last line; used on rollback
# actually removes the last two lines because the latter one will be
# added again when the save state is loaded
func remove_last():
	lines.pop_back()
	lines.pop_back()
