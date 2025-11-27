class_name Log extends RefCounted
# maintains a list of previously encountered lines of text displayed
# with LogOverlay


const LOG_SIZE: int = 30 # amount of blocks to keep


# an entry in the log, representing a specific Block up until a line
class Entry extends RefCounted:
	var blockfile: String
	var block: String
	var line: int
	
	
	func _init(_blockfile: String, _block: String, _line: int):
		self.blockfile = _blockfile
		self.block = _block
		self.line = _line
	
	
	func _to_string() -> String:
		return '%s:%s:%s' % [ blockfile, block, line ]
	
	
	static func of_string(string: String) -> Entry:
		var parts: PackedStringArray = string.rsplit(':', false, 2)
		
		if not (len(parts) == 3 and parts[2].is_valid_int()):
			print(parts)
			TE.log_error(TE.Error.BAD_SAVE, 'bad Log.Entry: "%s"' % string)
			return null
		
		return Entry.new(parts[0], parts[1], int(parts[2]))


var entries: Array[Log.Entry] = []


func update_log(blockfile: String, block: String, line: int):
	# possibly update last entry
	if len(entries) > 0:
		var last: Log.Entry = entries.back()
		if last.blockfile == blockfile and last.block == block and last.line <= line:
			last.line = line
			return
	
	# else add new entry
	entries.push_back(Log.Entry.new(blockfile, block, line))
	
	# don't exceed LOG_SIZE
	while len(entries) > LOG_SIZE:
		entries.pop_front()


# turns this Log into an array of strings
func serialize() -> Array[String]:
	var array: Array[String] = []
	for entry in entries:
		array.append(entry.to_string())
	return array


# recovers a Log from an array of strings
static func deserialize(from: Array) -> Log:
	var gamelog: Log = Log.new()
	for entry_string in from:
		var entry = Log.Entry.of_string(entry_string as String)
		if entry != null:
			gamelog.entries.append(entry)
	
	return gamelog
