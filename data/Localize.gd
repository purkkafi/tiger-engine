class_name Localize extends RefCounted
# stores localized strings used in the UI
# _get is overriden, enabling them to be accessed via field reference


var strings: Dictionary


# functions that translate the given Control type
var TRANSLATORS: Dictionary = {
	'Button': _translate_node_text,
	'Label': _translate_node_text,
	'RichTextLabel' : _translate_node_text,
	'CheckBox': _translate_node_text,
	'CheckButton': _translate_node_text,
	'OptionButton': _translate_option_button,
	'TextureRect': _translate_texture_rect
}


const meta_missing: String = '!!!<LOCALIZE_STRING_METADATA_NOT_SET>!!!'


# returns the Localize object for a certain language id
# it is constructed from reading and merging all files in the folder
# assets/lang/<lang id>/localize/
static func of_lang(lang: String):
	@warning_ignore("shadowed_variable")
	var strings: Dictionary = {}
	
	var dir_path: String = 'res://assets/lang/%s/localize' % lang
	var dir: DirAccess = DirAccess.open(dir_path)
	
	for file in dir.get_files():
		if file == '' or file.ends_with('.uid'):
			continue
		# TODO: this just indiscriminantly merges files, should there be
		# checks for duplicate localize ids?
		strings.merge((load(dir_path + '/' + file) as LocalizeResource).content)
	
	return Localize.new(strings)


# translates any Control that has a 'text' property
func _translate_node_text(ctrl: Control):
	if ctrl.get_meta('uistring_text_id', meta_missing) != meta_missing:
		ctrl.text = translate_text(ctrl.get_meta('uistring_text_id'))
	else:
		ctrl.set_meta('uistring_text_id', ctrl.text)
		ctrl.text = translate_text(ctrl.text)


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
		push_error('unknown localize string: %s' % [string])
		return '%' + string + '%'
	return strings[string]


# translates every applicable node in the tree
# if the localize id is set in the metadata, it's read from there;
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


# returns translation of the given string if it is of the form %localize_id%
# otherwise returns the string
func translate_text(text: String) -> String:
	if text.begins_with('%') and text.ends_with('%'):
		return _get(text.substr(1, len(text)-2))
	return text


# returns whether a translation for the given id is available
func has_translation(text: String) -> bool:
	if text.begins_with('%') and text.ends_with('%'):
		return text.substr(1, len(text)-2) in strings
	return false


# if strings autoquote_left and autoquote_right are defined, surrounds the
# given text with them; otherwise, returns it as-is
static func autoquote(text: String):
	if TE.localize and 'autoquote_left' in TE.localize.strings and 'autoquote_right' in TE.localize.strings:
		return TE.localize._get('autoquote_left') + text + TE.localize._get('autoquote_right')
	return text
