class_name Lang extends Resource
# a translation of the game
# refers to a specific subfolder [id] in 'assets/lang'


var name: String # the name  (e.g. "English", "Suomi")
var translation_by: String # the name of the translator(s) (empty for default langs)
var id: String = '' # the id, set dynamically when game is initialized
var path: String = '' # the file path, set dynamically when game is initialized
# the icon file's path relative to the lang folder or '' if there is no icon
var icon_path: String = ''


func _init(_name: String, _by: String, _icon_path: String):
	name = _name
	translation_by = _by
	icon_path = _icon_path


# returns the full name of this language, containing its
# name and the translator (unless it is empty)
func full_name() -> String:
	if translation_by == '':
		return name
	else:
		return name + ' (' + translation_by + ')'


func _to_string() -> String:
	return "Lang(id=%s)" % [id]
