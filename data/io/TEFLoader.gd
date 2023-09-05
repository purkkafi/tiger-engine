class_name TEFLoader extends ResourceFormatLoader
# loader for .tef files
# returns pre-defined objects for files with recognized top-level tags;
# otherwise, returns a TagResource, letting clients handle the rest


func _get_recognized_extensions():
	return [ 'tef' ]


func _get_resource_type(path: String):
	if path.ends_with('.tef'):
		return 'Resource'
	else:
		return ''


func _handles_type(typename):
	return typename == 'Resource'


# loads the resource at the given path, returning either a built-in
# object or a TagResource if the file contains an unknown
# top-level tag
func _load(path, _original_path, _use_sub_threads, _cache_mode):
	if !FileAccess.file_exists(path):
		return ERR_FILE_NOT_FOUND
	
	var lexer: Lexer = Lexer.new()
	var parser: Parser = Parser.new()
	
	var tokens = lexer.tokenize_file(path)
	if tokens == null:
		push_error(lexer.error_message)
		return FAILED
	
	var tree = parser.parse(tokens)
	if tree == null:
		push_error(parser.error_message)
		return FAILED
	
	# remove comments
	tree = tree.filter(func(n): return n is Tag or n is Tag.ControlTag)
	
	# extract file type from first Tag
	var type = tree[0].name
	
	if len(tree) == 0:
		push_error('no objects in %s' % [path])
		return FAILED
	
	# special handling for blockfiles because they consist of multiple top-level objects
	if type == 'block':
		var blocks = {}
		for node in tree:
			var parts = _resolve_top_level(node)
			blocks[parts[0]] = parts[1]
		
		# extracts the 'NAME' part of 'path/to/file/NAME.tef'
		var id: String = path.substr(path.rfind('/')+1)
		id = id.substr(0, len(id)-4)
		
		var blockfile = BlockFile.new(id, blocks)
		
		for block in blocks.keys():
			blocks[block].blockfile_path = path
			blocks[block].id = block
		
		return blockfile
		
	# special handling for scriptfiles
	elif type == 'script':
		var compiler: TEScriptCompiler = TEScriptCompiler.new()
		for script in tree:
			compiler.compile_script(script)
		
		# extracts the 'NAME' part of 'path/to/file/NAME.tef'
		var id: String = path.substr(path.rfind('/')+1)
		id = id.substr(0, len(id)-4)
		
		return ScriptFile.new(id, compiler.scripts)
	
	if len(tree) != 1:
		push_error('single top-level tag required for %s in %s' % [type, path])
		return FAILED
	
	# special handling for sprites
	if path.ends_with('/sprite.tef'):
		return _resolve_sprite(path, tree[0])
	
	return _resolve_top_level(tree[0])


# resolves a Tag, returning a matching top-level object
func _resolve_top_level(node: Tag):
	match node.name:
		'lang':
			return _resolve_lang(node)
		'localize':
			return _resolve_localize(node)
		'block':
			return _resolve_block(node)
		'definitions':
			return _resolve_definitions(node)
		'options':
			return _resolve_options(node)
		_:
			# unknown object, return it as a TagResource
			return TagResource.new(node)


func _resolve_lang(tree: Tag):
		var name: String
		var translation_by: String = ''
		
		for tag in tree.get_tags():
			match tag.name:
				'name':
					name = tag.get_string()
				'translation_by':
					translation_by = tag.get_string()
				_:
					push_error('unknown lang file tag: %s' % tag)
		
		return Lang.new(name, translation_by)


func _resolve_localize(node: Tag):
	var tags = node.get_tags()
	var dict = {}
	
	for tag in tags:
		dict[tag.name] = tag.get_text()
	
	return LocalizeResource.new(dict)


# resolves a singular block definition
func _resolve_block(tag: Tag):
	var name = tag.get_string_at(0)
	var nodes = tag.args[1]
	
	return [name, Block.new(nodes)]


func _resolve_definitions(tree: Tag):
	var defs = Definitions.new()
	
	for node in tree.get_tags():
		var type: String = node.name
		
		match type:
			'color':
				var id: String = node.get_string_at(0)
				var value: Color = Color.html(node.get_string_at(1))
				defs._colors[id] = value
				
			'img':
				var id: String = node.get_string_at(0)
				var value: String = node.get_string_at(1)
				defs.imgs[id] = value
			
			'img_unlockable':
				var id: String = node.get_string_at(0)
				var value: String = node.get_string_at(1)
				defs.imgs[id] = value
				
				var unlockable_id = 'img:%s' % id
				defs.unlockables.append(unlockable_id)
				if id not in defs.unlocked_by_img:
					defs.unlocked_by_img[id] = []
				defs.unlocked_by_img[id].append(unlockable_id)
				
			'trans':
				var id: String = node.get_string_at(0)
				var trans = Definitions.Transition.new(node.get_value_at(1))
				
				defs._transitions[id] = trans
				
			'song':
				_parse_song_definition(defs, node)
				
			'song_unlockable':
				var id: String = _parse_song_definition(defs, node)
				
				var unlockable_id = 'song:%s' % id
				defs.unlockables.append(unlockable_id)
				if id not in defs.unlocked_by_song:
					defs.unlocked_by_song[id] = []
				defs.unlocked_by_song[id].append(unlockable_id)
				
			'sound':
				var id: String = node.get_string_at(0)
				var path: String = node.get_string_at(1)
				
				defs.sounds[id] = path
			
			'unlockable':
				var id: String = node.get_string_at(0)
				var trigger: Tag = node.get_tag_at(1) 
				
				defs.unlockables.append(id)
				
				match trigger.name:
					'from_start':
						defs.unlocked_from_start.append(id)
					'manual':
						pass
					'by_song':
						var song_id: String = trigger.get_string()
						if song_id not in defs.unlocked_by_song:
							defs.unlocked_by_song[song_id] = []
						defs.unlocked_by_song[song_id].append(id)
					'by_img':
						var img_id: String = trigger.get_string()
						if img_id not in defs.unlocked_by_img:
							defs.unlocked_by_img[img_id] = []
						defs.unlocked_by_img[img_id].append(id)
					_:
						push_error('unknown trigger for unlockable %s: %s' % [id, trigger.name])
			
			'speaker':
				var speaker: Definitions.SpeakerDef = Definitions.SpeakerDef.new()
				for tag in node.get_tags():
					match tag.name:
						'id':
							speaker.id = tag.get_string()
						'name':
							var name = tag.get_value()
							if name is String or name is Tag.ControlTag:
								speaker.name = name
							else:
								push_error('illegal name in speaker definition (expected string or control tag): %s' % tag)
						'bg_color':
							speaker.bg_color = Color(tag.get_string())
						'name_color':
							speaker.name_color = Color(tag.get_string())
						'variation':
							speaker.variation = tag.get_string()
						_:
							push_error('unknown value in speaker definition: %s' % tag)
				
				var error = speaker.error_message()
				if error != '':
					push_error('error with speaker %s: %s' % [node, error])
				
				defs.speakers[speaker.id] = speaker
				
			'sprite':
				# just put the sprite path in there, it will be resolved later
				var folder_path: String = node.get_string_at(1)
				if folder_path.ends_with('/'):
					push_error('sprite paths must not end in /: %s' % folder_path)
				defs.sprites[node.get_string_at(0)] = folder_path
			
			'var':
				var name: String = node.get_string_at(0)
				var ctrl: String = node.get_control_at(1)
				var default_val: Variant = ControlExpr.exec_contextless(ctrl)
				
				defs.variables[name] = default_val
				
			_:
				push_error('unknown definition: %s' % [node])

	return defs


func _parse_song_definition(defs: Definitions, node: Tag) -> String:
	node.expect_length(2, 3)
	var id: String = node.get_string_at(0)
	var path: String = node.get_string_at(1)
	
	if node.has_index(2):
		for option in node.get_dict_at(2).values():
			match option.name:
				'volume':
					defs.song_custom_volumes[id] = float(option.get_string())
				_:
					push_error('unknown option in song definition: %s' % option)
	
	defs.songs[id] = path
	return id


func _resolve_options(tree: Tag):
	var opts = Options.new()
	
	for node in tree.get_tags():
		match node.name:
			'title_screen':
				opts.title_screen = node.get_string()
			'splash_screen':
				opts.splash_screen = node.get_string()
			'version_callback':
				opts.version_callback = Callable(load(node.get_string_at(0)), node.get_string_at(1))
			'notify_on_unlock':
				opts.notify_on_unlock.append_array(node.get_strings())
			'register_view':
				opts.custom_views[node.get_string_at(0)] = node.get_string_at(1)
			'default_theme':
				opts.default_theme = node.get_string()
			'bug_report_url':
				opts.bug_report_url = node.get_string()
			_:
				push_error('unknown option: %s' % [node])
	
	return opts


# resolves a folder containing a sprite.tef file into a SpriteResource
func _resolve_sprite(path: String, sprite_tef: Tag) -> SpriteResource:
	var sprite: SpriteResource = SpriteResource.new()
	var dir_path: String = path.trim_suffix('/sprite.tef')
	var dir: DirAccess = DirAccess.open(dir_path)
	
	sprite.tag = sprite_tef
	
	for file in dir.get_files():
		if file.ends_with('.import') or file == 'sprite.tef':
			continue
		sprite.files[file] = load(dir_path + '/' + file)
	
	return sprite
	
	
