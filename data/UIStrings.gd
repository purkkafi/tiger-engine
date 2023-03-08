class_name UIStrings extends Resource
# stores localized strings used in the UI
# _get is overriden, enabling them to be accessed via field reference


var strings: Dictionary


# functions that translate the given Control type
var TRANSLATORS: Dictionary = {
	'Button': Callable(self, '_translate_node_text'),
	'Label': Callable(self, '_translate_node_text'),
	'CheckBox': Callable(self, '_translate_node_text'),
	'CheckButton': Callable(self, '_translate_node_text'),
	'OptionButton': Callable(self, '_translate_option_button'),
	'TextureRect': Callable(self, '_translate_texture_rect')
}


const meta_missing: String = '!!!<UISTRING_METADATA_NOT_SET>!!!'


# translates any Control that has a 'text' property
func _translate_node_text(btn: Control):
	if btn.get_meta('uistring_text_id', meta_missing) != meta_missing:
		btn.text = translate_text(btn.get_meta('uistring_text_id'))
	else:
		btn.set_meta('uistring_text_id', btn.text)
		btn.text = translate_text(btn.text)


func _translate_option_button(btn: OptionButton):
	for i in range(0, btn.item_count):
		var meta: String = 'uistring_item_' + str(i) + '_id'
		if btn.get_meta(meta, meta_missing) != meta_missing:
			btn.set_item_text(i, translate_text(btn.get_meta(meta)))
		else:
			btn.set_meta(meta, btn.get_item_text(i))
			btn.set_item_text(i, translate_text(btn.get_item_text(i)))


func _translate_texture_rect(tex: TextureRect):
	if tex.get_meta('uistring_texture_path', meta_missing) != meta_missing:
		tex.texture = load(translate_text(tex.get_meta('uistring_texture_path')))


func _init(dict):
	strings = dict


func _get(string):
	if not string in strings:
		push_error('unknown ui string: %s' % [string])
		return '%' + string + '%'
	return strings[string]


# translates every applicable node in the tree
# if the translation id is set in the metadata, it's read from there;
# else, it's read from the node text/tooltip/etc and inserted into the metadata
# this allows retranslation if the language changes
func translate(node: Control):
	var cls: String = node.get_class()
	
	if node.get_meta('uistring_tooltip_id', meta_missing) != meta_missing:
		node.tooltip_text = translate_text(node.get_meta('uistring_tooltip_id'))
	else:
		node.set_meta('uistring_tooltip_id', node.tooltip_text)
		node.tooltip_text = translate_text(node.tooltip_text)
	
	if cls in TRANSLATORS:
		TRANSLATORS[cls].call(node)
	
	for child in node.get_children(true):
		if child is Control:
			translate(child)


# returns translation of the given string if it is of the form %uistring%
# otherwise returns the string
func translate_text(text: String):
	if text.begins_with('%') and text.ends_with('%'):
		return _get(text.substr(1, len(text)-2))
	return text