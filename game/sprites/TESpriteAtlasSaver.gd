@tool
class_name TESpriteAtlasSaver extends ResourceFormatSaver


func _get_recognized_extensions(_resource: Resource):
	return [ 'atlas' ]


func _recognize(resource: Resource):
	return resource is TESpriteAtlas


func _save(resource: Resource, path: String, _flags: int):
	var file = FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_error('cannot write TESpriteAtlas: %s' % [path])
		return FileAccess.get_open_error()
	
	file.store_line(JSON.stringify({
		'file_names': resource.file_names,
		'points': var_to_str(resource.points),
		'sizes': var_to_str(resource.sizes),
		'margins': var_to_str(resource.margins),
		'sprite_size': var_to_str(resource.sprite_size)
	}))
	
	return OK
