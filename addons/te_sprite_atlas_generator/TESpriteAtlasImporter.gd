@tool
class_name TESpriteAtlasImporter extends EditorImportPlugin


static var ATLAS_FOLDER: String = 'res://assets/generated/atlas'
static var SPRITE_ID_FROM_SOURCE_FILE = RegEx.create_from_string('sprites/(.+)/sprite.atlas')


func _get_importer_name():
	return 'te_sprite_atlas_generator'


func _get_visible_name():
	return 'Tiger Engine sprite atlas'


func _get_recognized_extensions():
	return ['atlas']


func _get_save_extension():
	return 'atlas'


func _get_resource_type():
	return 'Resource'


func _get_priority():
	return 1.0


func _get_preset_count():
	return 0


func _get_import_order():
	return 0


func _get_import_options(path, preset_index):
	return []


func _get_option_visibility(path, option_name, options):
	return true


func _import(source_file, save_path, options, r_platform_variants, r_gen_files):
	if not source_file.ends_with('/sprite.atlas'):
		push_error("expected file to be named 'sprite.atlas")
		return Error.FAILED
	
	var dir_path: String = source_file.trim_suffix('/sprite.atlas')
	var files: Dictionary = {}
	
	_load_sprite_folder(dir_path, '', files)
	
	var file_names: Array = files.keys().duplicate()
	var images = files.values()
	
	for i in range(len(images)):
		if not images[i] is Image:
			images[i] = (images[i] as Texture2D).get_image()
	
	var sprite_size: Vector2i = images[0].get_size()
	for i in range(len(images)):
		if images[i].get_size() != sprite_size:
			push_error("inconsistent size: '%s' was %s, expected %s" % [file_names[i], images[i].get_size(), sprite_size])
	
	# crop every image to remove transparent border, saving margin info
	var margins: Array = []
	for i in len(images):
		var image: Image = images[i]
		var used_rect: Rect2i = image.get_used_rect()
		
		margins.append(Rect2(used_rect.position,
			image.get_size() - used_rect.size
		))
		
		images[i] = image.get_region(used_rect)
	
	var sizes: Array = images.map(func(img: Image): return img.get_size())
	
	var atlas_data: Dictionary = Geometry2D.make_atlas(sizes)
	var atlas: Image = Image.create(atlas_data['size'][0], atlas_data['size'][1], false, Image.FORMAT_RGBA8)
	
	for i in len(images):
		var image: Image = images[i]
		image.decompress()
		image.convert(Image.FORMAT_RGBA8)
		
		var point: Vector2 = atlas_data['points'][i]
		
		atlas.blit_rect(image, Rect2i(Vector2i.ZERO, image.get_size()), point)
	
	# save sprite atlas image
	if not DirAccess.dir_exists_absolute(ATLAS_FOLDER):
		DirAccess.make_dir_recursive_absolute(ATLAS_FOLDER)
	
	var sprite_id: String = SPRITE_ID_FROM_SOURCE_FILE.search(source_file).strings[1]
	var atlas_image_path: String = '%s/%s.png' % [ATLAS_FOLDER, sprite_id]
	var _err = atlas.save_png(atlas_image_path)
	if _err != OK:
		return _err
	
	var editor_filesystem: EditorFileSystem = EditorInterface.get_resource_filesystem()
	editor_filesystem.update_file(ATLAS_FOLDER)
	editor_filesystem.update_file(atlas_image_path)
	
	append_import_external_resource(atlas_image_path)
	
	# save sprite atlas resource
	var te_sprite_atlas: TESpriteAtlas = TESpriteAtlas.new()
	te_sprite_atlas.file_names = file_names
	te_sprite_atlas.points = atlas_data['points']
	te_sprite_atlas.sizes = sizes
	te_sprite_atlas.margins = margins
	te_sprite_atlas.sprite_size = sprite_size
	var te_atlas_path = '%s.%s' % [save_path, _get_save_extension()]
	
	return ResourceSaver.save(te_sprite_atlas, te_atlas_path)


# recursively load resources in sprite folder
func _load_sprite_folder(path: String, prefix: String, files: Dictionary):
	var dir_access: DirAccess = DirAccess.open(path)
	
	for file in dir_access.get_files():
		# ignore non-image files
		if file == 'sprite.tef':
			continue
		elif file == 'sprite.atlas':
			continue
		
		# TODO: this is a hack
		# assume '.import' files correspond with a resource we want to load
		if file.ends_with('import') and 'sprite.atlas' not in file:
			var resource: String = file.rstrip('.import')
			var resource_id = resource if prefix == '' else '%s/%s' % [prefix, resource]
			files[resource_id] = load(path + '/' + resource)
	
	for subdir in dir_access.get_directories():
		var subpath: String = '%s/%s' % [path, subdir]
		var subprefix: String = subdir if prefix == '' else '%s/%s' % [prefix, subdir]
		_load_sprite_folder(subpath, subprefix, files)
