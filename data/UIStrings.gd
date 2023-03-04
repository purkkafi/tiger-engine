class_name UIStrings extends Resource
# stores localized strings used in the UI
# _get is overriden, enabling them to be accessed via field reference


var strings: Dictionary


func _init(dict):
	strings = dict


func _get(string):
	if not string in strings:
		push_error('unknown ui string: %s' % [string])
		return '%' + string + '%'
	return strings[string]
