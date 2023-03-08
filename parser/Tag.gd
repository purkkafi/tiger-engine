class_name Tag extends RefCounted
# a basic data holder consisting of a name and arguments
# every argument is a taglist – an array that may contain:
# – strings (represented as Godot Strings)
# – other tags
# – breaks (represented by the type Tag.Break)
#
# there are several get_XXX methods for extracting the contents of
# a Tag that has an idiomatic form


# special object used in taglists as a separator
class Break extends RefCounted:
	func _to_string() -> String:
		return '<break>'


var name: String
var args: Array[Variant]


func _init(_name: String,_args):
	self.name = _name
	self.args = _args


func _to_string() -> String:
	return "\\%s%s" % [name, args]


# returns the single String this Tag contains or null
func get_string():
	if len(args) != 1 or len(args[0]) != 1 or !(args[0][0] is String):
		push_error('expected single string, got %s' % self)
		return null
	return args[0][0]


# returns the single String at the given argument or null
func get_string_at(index: int):
	if index >= len(args) or len(args[index]) != 1 or (!args[index][0] is String):
		push_error('expected string at index %d, got %s' % [index, self])
		return null
	return args[index][0]


# returns the single String or Tag at the given argument or null
func get_value_at(index: int):
	if index >= len(args) or len(args[index]) != 1 or (!args[index][0] is String and !args[index][0] is Tag):
		push_error('expected string or tag at index %d, got %s' % [index, self])
		return null
	return args[index][0]


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
			push_error('expected text, got %s' % self)
			return null
	
	return text


# returns an Array of Tags contained in the first argument or null
func get_tags():
	if len(args) != 1:
		push_error('expected tags, got %s' % self)
		return null
	return args[0].filter(func(n): return n is Tag)


# returns a Dictionary where keys are the names of tags the
# first argument contains and the values are the tags
func get_dict() -> Dictionary:
	var dict: Dictionary = {}
	for tag in get_tags():
		dict[tag.name] = tag
	return dict
