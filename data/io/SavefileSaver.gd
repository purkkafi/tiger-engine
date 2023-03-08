class_name SavefileSaver extends ResourceFormatSaver
# writes Savefiles into json


func _get_recognized_extensions(_resource: Resource):
	return [ 'sav' ]


func _recognize(resource: Resource):
	return resource is Savefile


func _save(resource: Resource, path: String, _flags: int):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error('cannot write save: %s' % [path])
		return FileAccess.get_open_error()
	
	file.store_line(JSON.stringify(resource.banks, '  '))
	
	return OK
