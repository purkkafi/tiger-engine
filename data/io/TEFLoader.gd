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
		var blocks: Dictionary[String, Block] = {}
		
		for node in tree:
			var resolved = _resolve_top_level(node)
			if resolved is ParsedBlock:
				blocks[resolved.name] = resolved.content
		
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
		
		return ScriptFile.new(id, compiler.scripts, compiler.errors)
	
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


class ParsedBlock:
	var name: String
	var content: Block


# resolves a singular block definition
func _resolve_block(tag: Tag) -> ParsedBlock:
	var block: ParsedBlock = ParsedBlock.new()
	block.name = tag.get_string_at(0)
	block.content = Block.new(tag.args[1])
	
	return block


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
				_parse_img_definition(defs, node)
			
			'img_unlockable':
				var id: String = _parse_img_definition(defs, node)
				
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
				_parse_sound_definition(defs, node)
			
			'unlockable':
				var id: String = node.get_string_at(0)
				var triggers: Array = []
				
				if node.length() == 2:
					triggers = node.get_tags_at(1)
				elif node.length() > 2:
					push_error('unlockable should be given 1–2 arguments: %s' % id)
				
				defs.unlockables.append(id)
				
				for trigger in triggers:
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
						'by_other':
							var other_id: String = trigger.get_string()
							if other_id not in defs.automatically_unlocks:
								defs.automatically_unlocks[other_id] = []
							defs.automatically_unlocks[other_id].append(id)
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
							if name is String:
								# implement shortcut that %id% --> {{ localize("id") }}
								if name.begins_with('%') and name.ends_with('%'):
									speaker.name = Tag.ControlTag.new('localize("%s")' % name.substr(1, len(name)-2))
								else:
									speaker.name = name
							elif name is Tag.ControlTag:
								speaker.name = name
							elif name is Tag: # implement shortcut that \VAR --> {{ VAR }}
								speaker.name = Tag.ControlTag.new(name.name)
							else:
								push_error('illegal name in speaker definition (expected string or variable tag or control tag): %s' % tag)
						'bg_color':
							speaker.bg_color = Color(tag.get_string())
						'name_color':
							speaker.name_color = Color(tag.get_string())
						'label_variation':
							speaker.label_variation = tag.get_string()
						'textbox_variation':
							speaker.textbox_variation = tag.get_string()
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
			
			'text_style':
				var id: String = node.get_string_at(0)
				var formatting: Array = node.args[1]
				
				var bad_tags: Array[Tag]
				for part in formatting:
					if part is Tag and not part.name.is_valid_int():
						bad_tags.append(part)
						push_error('text style arguments need to be numeric: \\%s' % part.name)
				
				for bad_tag in bad_tags:
					formatting.erase(bad_tag)
				
				defs.text_styles[id] = formatting
			
			_:
				push_error('unknown definition: %s' % [node])

	return defs


func _parse_meta(id: String, option: Tag, metadata: Dictionary):
	var dict: Dictionary = option.get_dict(func(t): return t.get_string())
	
	if id not in metadata:
		metadata[id] = dict
	elif metadata[id] is Array:
		metadata[id].append(dict)
	else: # turn into list if meta already specified
		metadata[id] = [ metadata[id] ]
		metadata[id].append(dict)


func _parse_sound_definition(defs: Definitions, node: Tag):
	node.expect_length(2, 3)
	var id: String = node.get_string_at(0)
	var path: String = node.get_string_at(1)
	
	if node.has_index(2):
		for option in node.get_tags_at(2):
			match option.name:
				'meta':
					_parse_meta(id, option, defs.sound_metadata)
				'volume':
					defs.sound_custom_volumes[id] = float(option.get_string())
				_:
					push_error('unknown option in sound definition: %s' % option)
	
	defs.sounds[id] = path


func _parse_song_definition(defs: Definitions, node: Tag) -> String:
	node.expect_length(2, 3)
	var id: String = node.get_string_at(0)
	var path: String = node.get_string_at(1)
	
	if node.has_index(2):
		for option in node.get_tags_at(2):
			match option.name:
				'volume':
					defs.song_custom_volumes[id] = float(option.get_string())
				'meta':
					_parse_meta(id, option, defs.song_metadata)
				_:
					push_error('unknown option in song definition: %s' % option)
	
	defs.songs[id] = path
	return id


func _parse_img_definition(defs: Definitions, node: Tag) -> String:
	node.expect_length(2, 3)
	var id: String = node.get_string_at(0)
	var value: Variant
	
	if node.get_string_at(1) != null:
		value = node.get_string_at(1)
	elif node.get_tag_at(1) != null and node.get_tag_at(1).name == 'placeholder':
		value = Definitions.PLACEHOLDER
	else:
		push_error('img definition must be string or \\placeholder, got %s' % node.get_value_at(1))
	
	if node.has_index(2):
		for option in node.get_tags_at(2):
			match option.name:
				'meta':
					_parse_meta(id, option, defs.img_metadata)
				_:
					push_error('unknown option in img definition: %s' % option)
	
	defs.imgs[id] = value
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
			'register_sprite_object':
				opts.custom_sprite_objects[node.get_string_at(0)] = node.get_string_at(1)
			'default_theme':
				opts.default_theme = node.get_string()
			'bug_report_url':
				opts.bug_report_url = node.get_string()
			'ingame_custom_controls':
				opts.ingame_custom_controls = node.get_string()
			'register_vfx':
				opts.vfx_registry[node.get_string_at(0)] = node.get_string_at(1)
			_:
				push_error('unknown option: %s' % [node])
	
	return opts


static var SPRITE_ID_FROM_SOURCE_FILE = RegEx.create_from_string('sprites/(.+)/sprite.atlas')
static var ATLAS_FOLDER: String = 'res://assets/generated/atlas'


# resolves a folder containing a sprite.tef file into a SpriteResource
func _resolve_sprite(path: String, sprite_tef: Tag) -> SpriteResource:
	var sprite: SpriteResource = SpriteResource.new()
	var dir_path: String = path.trim_suffix('/sprite.tef')
	
	sprite.tag = sprite_tef
	
	var te_sprite_atlas_path: String = '%s/sprite.atlas' % dir_path
	var te_sprite_atlas: TESpriteAtlas = load(te_sprite_atlas_path)
	var sprite_id: String = SPRITE_ID_FROM_SOURCE_FILE.search(te_sprite_atlas_path).strings[1]
	var sheet_texture: Texture2D = load('%s/%s.png' % [ATLAS_FOLDER, sprite_id])
	
	var file_names: Array = te_sprite_atlas.file_names
	var points: Array = te_sprite_atlas.points
	var sizes: Array = te_sprite_atlas.sizes
	var margins: Array = te_sprite_atlas.margins
	
	
	for i in len(file_names):
		var atlas_tex = AtlasTexture.new()
		
		atlas_tex.region = Rect2(points[i], sizes[i])
		atlas_tex.margin = margins[i]
		sprite.textures[file_names[i]] = atlas_tex
	
	sprite.atlas = sheet_texture
	sprite.size = te_sprite_atlas.sprite_size
	
	for texture in sprite.textures.values():
		texture.atlas = sprite.atlas
	
	return sprite
