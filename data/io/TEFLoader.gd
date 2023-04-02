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
	return _resolve_top_level(tree[0])


# resolves a Tag, returning a matching top-level object
func _resolve_top_level(node: Tag):
	match node.name:
		'lang':
			return _resolve_lang(node)
		'ui_strings':
			return _resolve_ui_strings(node)
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


func _resolve_ui_strings(node: Tag):
	var tags = node.get_tags()
	var dict = {}
	
	for tag in tags:
		dict[tag.name] = tag.get_text()
	
	return UIStrings.new(dict)


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
				var id: String = node.get_string_at(0)
				var path: String = node.get_string_at(1)
				defs.songs[id] = path
				
			'song_unlockable':
				var id: String = node.get_string_at(0)
				var path: String = node.get_string_at(1)
				defs.songs[id] = path
				
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
				var speaker: Definitions.Speaker = Definitions.Speaker.new()
				for tag in node.get_tags():
					match tag.name:
						'id':
							speaker.id = tag.get_string()
						'name':
							speaker.name = tag.get_string()
						'color':
							speaker.color = Color(tag.get_string())
						_:
							push_error('unknown value in speaker definition: %s' % tag)
				
				if speaker.id == null:
					push_error('must specify speaker id')
				defs.speakers[speaker.id] = speaker
				
			'sprite':
				# just put the sprite path in there, it will be resolved later
				var folder_path: String = node.get_string_at(1)
				if not folder_path.ends_with('/'):
					push_error('sprite paths must end in /: %s' % folder_path)
				defs.sprites[node.get_string_at(0)] = folder_path
			
			'var':
				var name: String = node.get_string_at(0)
				var ctrl: String = node.get_control_at(1)
				var default_val: Variant = ControlExpr.exec_contextless(ctrl)
				
				defs.variables[name] = default_val
				
			_:
				push_error('unknown definition: %s' % [node])

	return defs


func _resolve_options(tree: Tag):
	var opts = Options.new()
	
	for node in tree.get_tags():
		match node.name:
			'title_screen':
				opts.title_screen = node.get_string()
			'background_color':
				opts.background_color = Color.html(node.get_string())
			'shadow_color':
				opts.shadow_color = Color.html(node.get_string())
			'animate_overlay_in':
				opts.animate_overlay_in = Callable(load(node.get_string_at(0)), node.get_string_at(1))
			'animate_overlay_out':
				opts.animate_overlay_out = Callable(load(node.get_string_at(0)), node.get_string_at(1))
			'animate_shadow_in':
				opts.animate_shadow_in = Callable(load(node.get_string_at(0)), node.get_string_at(1))
			'animate_shadow_out':
				opts.animate_shadow_out = Callable(load(node.get_string_at(0)), node.get_string_at(1))
			'version_callback':
				opts.version_callback = Callable(load(node.get_string_at(0)), node.get_string_at(1))
			_:
				push_error('unknown option: %s' % [node])
	
	return opts
