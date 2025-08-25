class_name SeenBlocks extends RefCounted
# keeps track of the blocks the user has seen
# hashes are stored; as a result, the contents of a Block changing
# mark it as unread


# dict of strings in form '<blockfile path>:<block id>' to dicts with keys:
# – hash: the calculated hash of the block
# – line: how far the block has been read
var data: Dictionary
var lang_id: String


# creates an instance representing the stored data for the given language,
# either reading it from the disk or creating a blank cache
func _init(_lang_id: String):
	lang_id = _lang_id
	if FileAccess.file_exists(_path()):
		data = (load(_path()) as JSON).data
	else:
		data = {}
		write_to_disk()


# marks the given Block & line as read, updating the hash
# if game has been read past where it was originally saved
func mark_read(block: Block, line: int):
	var id: String = block.full_id()
	@warning_ignore("shadowed_global_identifier")
	var hash: String = Assets.blockfiles.hashes[id]
	
	if id in data:
		var old_line: int = data[id]['line']
		
		# if hash matches, increase line index, else start from new line
		if hash == data[id]['hash']:
			line = max(line, old_line)
	
	data[id] = { 'line': line, 'hash': hash }


# returns whether the given Block & line have been read before
# hashes have to match for this to be true
func is_read(block: Block, line: int) -> bool:
	var id: String = block.full_id()
	
	if id not in data:
		return false
	
	if data[id]['hash'] != Assets.blockfiles.hashes[id]:
		return false
	
	if line > data[id]['line']:
		return false
	
	return true


func write_to_disk():
	var file: FileAccess = FileAccess.open(_path(), FileAccess.WRITE)
	file.store_line(JSON.stringify(data))


func _path():
	return 'user://%s/seen_blocks.json' % lang_id
