class_name UIStrings extends Resource
# stores localized strings used in the UI
# _get is overriden, enabling them to be accessed via field reference


# functions that translate the given Control type
var TRANSLATORS: Dictionary = {
	'Button': func(b: Button): b.text = translate_text(b.text),
	'Label': func(l: Label): l.text = translate_text(l.text),
	'CheckBox': func(c: CheckBox): c.text = translate_text(c.text)
}


var strings: Dictionary


func _init(dict):
	strings = dict


func _get(string):
	if not string in strings:
		push_error('unknown ui string: %s' % [string])
		return '%' + string + '%'
	return strings[string]


# translates every applicable node in the tree
func translate(node: Control):
	var cls: String = node.get_class()
	node.tooltip_text = translate_text(node.tooltip_text)
	
	if cls in TRANSLATORS:
		TRANSLATORS[cls].call(node)
	
	for child in node.get_children():
		translate(child)


# returns translation of the given string if it is of the form %uistring%
# otherwise returns the string
func translate_text(text: String):
	if text.begins_with('%') and text.ends_with('%'):
		return _get(text.substr(1, len(text)-2))
	return text
