class_name Tag extends RefCounted
# a basic data holder consisting of a name and arguments
# every argument is a taglist – an array that may contain:
# – strings (represented as Godot Strings)
# – other tags
# – control tags (represented by the type ControlTag
# – breaks (represented by the type Tag.Break)
#
# there are several get_XXX methods for extracting the contents of
# a Tag that has an idiomatic form


var name: String
var args: Array[Array]


# special object used in taglists as a separator
class Break extends RefCounted:
	func _to_string() -> String:
		return '<break>'


class ControlTag extends RefCounted:
	var string: String
	
	
	func _init(_string: String):
		self.string = _string
	
	
	func _to_string() -> String:
		return "{{%s}}" % string


func _init(_name: String, _args: Array[Array]):
	self.name = _name
	self.args = _args


func _to_string() -> String:
	return "\\%s%s" % [name, args]


# returns the amount of arguments in this Tag
func length() -> int:
	return len(args)


# returns the single String this Tag contains or null
func get_string():
	if len(args) != 1 or len(args[0]) != 1 or !(args[0][0] is String):
		return null
	return args[0][0]


# returns the single String at the given argument or null
func get_string_at(index: int):
	if index >= len(args) or len(args[index]) != 1 or (!args[index][0] is String):
		return null
	return args[index][0]


# returns the arguments as a String array or null
func get_strings():
	var arr: Array[String] = []
	for arg in args:
		if len(arg) == 1 and arg[0] is String:
			arr.append(arg[0])
		else:
			return null
	return arr


# returns the single String or Tag at the given argument or null
func get_value():
	if len(args) != 1 or len(args[0]) != 1:
		return null
	var value = args[0][0]
	return value


# returns the single String or Tag at the given argument or null
func get_value_at(index: int):
	if index >= len(args) or len(args[index]) != 1 or (!args[index][0] is String and !args[index][0] is Tag):
		return null
	return args[index][0]


# returns the single Tag at the given argument or null
func get_tag_at(index: int):
	if index >= len(args) or len(args[index]) != 1 or (!args[index][0] is Tag):
		return null
	return args[index][0]


# returns the string of the ControlTag at the given argument or null
func get_control_at(index: int):
	if index >= len(args) or (!args[index][0] is ControlTag):
		return null
	return (args[index][0] as ControlTag).string


# returns the concatenated Strings and Breaks of the single argument or null
func get_text():
	if len(args) != 1:
		return null
	
	var text: String = ''
	
	for node in args[0]:
		if node is String:
			text += node
		elif node is Break:
			text += '\n'
		else:
			return null
	
	return text


# returns an Array of Tags contained in the first argument or null
func get_tags():
	if len(args) != 1:
		return null
	
	var tags: Array = args[0].filter(func(n): return n is Tag or n is ControlTag)
	return tags


# returns the Array of Tags contained at the given argument or null
func get_tags_at(index: int):
	if index >= len(args):
		return null
	
	var tags: Array = args[index].filter(func(n): return n is Tag or n is ControlTag)
	return tags


# returns a Dictionary where keys are the names of tags the
# first argument contains and the values are the tags
func get_dict() -> Dictionary:
	var dict: Dictionary = {}
	for tag in get_tags():
		dict[tag.name] = tag
	return dict


# like get_dict() but for the given index
func get_dict_at(index: int):
	if index >= len(args):
		return null
	
	var dict: Dictionary = {}
	for tag in get_tags_at(index):
		dict[tag.name] = tag
	
	return dict


# returns the only argument as a taglist or null 
func get_taglist():
	if len(args) != 1:
		return null
	return args[0]


# returns whether the given index is valud
func has_index(index: int) -> bool:
	return index >= 0 and index < len(args)


# pushes an error unless the length is:
# – if given one argument: the argument
# – if given two aguments: inclusively between the first and the second argument
func expect_length(a: int, b: int = -1):
	if b == -1:
		if len(args) != a:
			push_error('expected %s args, got %s' % [a, self])
	else:
		if not (len(args) >= a and len(args) <= b):
			push_error('expected from %s to %s args, got %s' % [a, b, self])
