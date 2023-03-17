class_name BlockFile extends Resource
# container object for Blocks


# the id of this blockfile; should be the last part of the file name without the extension
var id: String
# blocks in this blockfile; a Dictionary that maps block ids to Block objects
var blocks: Dictionary


func _init(_id: String, _blocks: Dictionary):
	id = _id
	blocks = _blocks


func _to_string() -> String:
	return "BlockFile(%s)" % [id]
