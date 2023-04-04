class_name ScriptFile extends Resource
# represents the scripts in a loaded ScriptFile

# id of this file; the last part of the filename without the extension
var id: String
# a Dictionary of script ids to TEScript objects
var scripts: Dictionary


func _init(_id: String, _scripts: Dictionary):
	id = _id
	scripts = _scripts
	
	for script in scripts.keys():
		print(script + ':')
		for i in scripts[script].instructions:
			print(i)
		print('\n')


func _to_string() -> String:
	return "ScriptFile(%s)" % [id]
