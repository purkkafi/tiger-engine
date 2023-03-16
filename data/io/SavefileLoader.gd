class_name SavefileLoader extends ResourceFormatLoader
# loads Savefiles from json


func _get_recognized_extensions():
	return [ 'sav' ]


func _get_resource_type(path: String):
	if path.ends_with('.sav'):
		return 'Resource'
	else:
		return ''


func _handles_type(typename):
	return typename == 'Resource'


func _load(path: String, _original_path, _use_sub_threads, _cache_mode):
	var file: FileAccess = FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error('cannot load saves: %s' % [path])
	
	var json = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		push_error('error reading saves: %s' % json.get_error_message())
		return null
	
	var savefile: Savefile = Savefile.new()
	savefile.banks = []
	savefile.banks.append_array(json.data as Array[Dictionary])
	
	return savefile
