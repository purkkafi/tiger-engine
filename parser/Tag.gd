class_name Tag extends RefCounted
# a basic data holder consisting of a name and arguments
# every argument is an array that may contain:
# – strings
# – other tags
# multiple consecutive strings indicate an abstract break between them


var name: String
var args: Array[Variant]


func _init(_name: String,_args):
	self.name = _name
	self.args = _args


func _to_string() -> String:
	return "\\%s%s" % [name, args]
