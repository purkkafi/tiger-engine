@tool
class_name TESpriteAtlasLoader extends ResourceFormatLoader
# loads TESpriteAtlas instances from json


func _get_recognized_extensions():
	return [ 'atlas' ]


func _get_resource_type(path: String):
	if path.ends_with('.atlas'):
		return 'Resource'
	else:
		return ''


func _handles_type(typename):
	return typename == 'Resource'


func _load(path: String, _original_path, _use_sub_threads, _cache_mode):
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error('cannot load .atlas file: %s' % [path])
		return FileAccess.get_open_error()
	
	var json = JSON.new()
	var _err = json.parse(file.get_as_text())
	if _err != OK:
		push_error('error parsing .atlas file: %s' % json.get_error_message())
		return _err
	
	var te_sprite_atlas = TESpriteAtlas.new()
	te_sprite_atlas.file_names = json.data['file_names']
	te_sprite_atlas.points = str_to_var(json.data['points'])
	te_sprite_atlas.sizes = str_to_var(json.data['sizes'])
	te_sprite_atlas.margins = str_to_var(json.data['margins'])
	te_sprite_atlas.sprite_size = str_to_var(json.data['sprite_size'])
	
	return te_sprite_atlas
