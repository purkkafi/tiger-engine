class_name Tag extends RefCounted
# a basic data holder consisting of a name and arguments
# every argument is a taglist – an array that may contain:
# – strings (represented as Godot Strings)
# – other tags
# – breaks (represented by the type Tag.Break)


# special object used in taglists as a separator
class Break extends RefCounted:
	func _to_string() -> String:
		return '<break>'


var name: String
var args: Array[Variant]


func _init(_name: String,_args):
	self.name = _name
	self.args = _args


# TODO add methods codifying the idioms for accessng data in Tags


func _to_string() -> String:
	return "\\%s%s" % [name, args]
