class_name CmdArgs extends Node
# implements command line options


static var cmd_task_screen: PackedScene = preload('res://tiger-engine/ui/screens/CmdTaskScreen.tscn')


# parses cmd args, setting game options or executing an additional task and quitting
static func handle_args() -> Variant:
	var instead: Variant = null
	var parser: ArgParser = ArgParser.new()
	
	parser.register('--debug', ArgParser.Type.FLAG, ['-d'], 'Run in debug mode.')
	parser.register('--ignore-settings', ArgParser.Type.FLAG, ['-i'], 'Ignore local settings file if it exists.')
	
	parser.register('--mobile', ArgParser.Type.FLAG, ['-m'], 'Run as if on mobile.')
	parser.register('--web', ArgParser.Type.FLAG, ['-w'], 'Run as if on the browser.')
	parser.set_as_exclusive(['--mobile', '--web'])
	
	parser.register('--help', ArgParser.Type.FLAG, ['-h'], 'Display help and quit.')
	parser.register('--run-tests', ArgParser.Type.FLAG, ['--rt', '-T'], "Run the engine's test suite.")
	parser.register('--stage-editor', ArgParser.Type.FLAG, ['--se', '-S'], 'Run the interactive stage editor.')
	parser.register('--word-count', ArgParser.Type.STRING, ['--wc', '-W'], 'Save word count data to file.', 'FILE')
	parser.set_as_exclusive(['--help', '--run-tests', '--stage-editor', '--word-count'])
	# TODO reimplement '--extract-language'
	
	var parsed: Dictionary = parser.parse(OS.get_cmdline_user_args())
	
	if 'error' in parsed:
		push_error(parsed['error'])
		parser.print_help()
		TE.quit_game(1)
	
	if '--debug' in parsed:
		TE._force_debug = true
	
	if '--ignore-settings' in parsed:
		TE.ignore_settings = true
	
	if '--mobile' in parsed:
		TE._force_mobile = true
	
	if '--web' in parsed:
		TE._force_web = true
	
	if '--run-tests' in parsed:
		instead = cmd_task_screen.instantiate()
		instead.task = TestRunner.run_tests
		return instead
	
	if '--stage-editor' in parsed:
		instead = preload('res://tiger-engine/engine/StageEditor.tscn').instantiate()
		return instead
	
	if '--word-count' in parsed:
		var out: String = parsed['--word-count']
		instead = cmd_task_screen.instantiate()
		instead.task = _word_count.bind(out)
		return instead
	
	if '--help' in parsed:
		parser.print_help()
		TE.quit_game()
	
	return null


# regex that matches if a word has any alphanumeric charcters and
# should therefore be counted as a word
static var IS_WORD: RegEx = RegEx.create_from_string('\\w+')


# performs a word count across languages and saves the result to the given file
static func _word_count(out: String) -> int:
	var wc: Dictionary = {}
	
	for lang in TE.all_languages:
		wc[lang.id] = _word_count_lang(lang.id)
	
	var output: String = JSON.stringify(wc, '  ')
	var outfile: FileAccess = FileAccess.open(out as String, FileAccess.WRITE_READ)
	if outfile == null:
		print(FileAccess.get_open_error())
		return 1
	
	outfile.store_string(output)
	outfile.close()
	
	return 0


# TODO: deal with bbcode tags in a more graceful way
static func _word_count_lang(lang: String) -> Dictionary:
	var folder_path: String = 'res://assets/lang/%s/text/' % lang
	var folder: DirAccess = DirAccess.open(folder_path)
	
	if folder == null:
		push_error('cannot open text folder for language: %s' % lang)
		return {}
	
	folder.list_dir_begin()
	var file: String = folder.get_next()
	var counts: Dictionary = {}
	
	# construct VariableContext to support variables
	var var_names: Array[String] = []
	var_names.append_array(TE.defs.variables.keys())
	var var_def_values: Array[Variant] = var_names.map(func(v): return TE.defs.variables[v])
	var game_ctxt: VariableContext = VariableContext.new(var_names, var_def_values)
	
	while file != '':
		if file.ends_with('.tef'):
			var path = '%s%s' % [folder_path, file]
			var blockfile: BlockFile = Assets.blockfiles.get_unqueued(path)
			
			var count: int = 0
			for block in blockfile.blocks.values():
				for par in Blocks.resolve_parts(block, game_ctxt):
					var words = par.split(' ', false)
					
					for word in words:
						if IS_WORD.search(word) != null:
							count += 1
			
			counts[file] = count
		
		file = folder.get_next()
	
	var total: int = 0
	for count in counts.values():
		total += count
	counts['total'] = total
	
	return counts


static func _extract_language(lang_id: String, where: String) -> int:
	var base_dir_path: String = 'res://' if OS.has_feature('editor') else OS.get_executable_path().get_base_dir()
	var base_dir: DirAccess = DirAccess.open(base_dir_path)
	if base_dir == null:
		printerr('Cannot open current folder')
		return 1
	
	if base_dir.make_dir_recursive(where) != OK:
		printerr("Cannot create target directory '%s'" % where)
		return 1
	
	var to_dir_path: String = base_dir_path + '/' + where
	var to_dir: DirAccess = DirAccess.open(to_dir_path)
	
	if len(to_dir.get_files()) != 0 or len(to_dir.get_directories()) != 0:
		printerr("Target directory '%s' is non-empty" % where)
		return 1
	
	# save project.godot
	var project_template: FileAccess = FileAccess.open('res://tiger-engine/resources/tr_project.godot_template.txt', FileAccess.READ)
	var project: FileAccess = FileAccess.open(to_dir_path + '/project.godot', FileAccess.WRITE)
	project.store_string(project_template.get_as_text().replace('[[NAME]]', '"' + TE.localize.game_title + ' (translation)"'))
	
	# save export_presets.cfg
	var export_presets_template: FileAccess = FileAccess.open('res://tiger-engine/resources/tr_export_presets.cfg_template.txt', FileAccess.READ)
	var export_presets: FileAccess = FileAccess.open(to_dir_path + '/export_presets.cfg', FileAccess.WRITE)
	export_presets.store_string(export_presets_template.get_as_text())
	
	# save README.txt
	var readme_template: FileAccess = FileAccess.open('res://tiger-engine/resources/tr_README.txt', FileAccess.READ)
	var readme: FileAccess = FileAccess.open(to_dir_path + '/README.txt', FileAccess.WRITE)
	readme.store_string(readme_template.get_as_text().replace('[[NAME]]', TE.localize.game_title).replace('[[LANG]]', lang_id))
	
	var to_lang_path: String = to_dir_path + '/assets/lang/' + lang_id
	to_dir.make_dir_recursive(to_lang_path)
	var to_lang: DirAccess = DirAccess.open(to_lang_path)
	
	var from_lang_path: String = 'res://assets/lang/' + lang_id
	var files = _crawl_lang_dir(from_lang_path, '', to_lang)
	if files == null:
		printerr("Cannot load language: '%s'" % lang_id)
		return 1
	
	for file in files as Array[String]:
		match file.get_extension():
			'tef':
				var from: FileAccess = FileAccess.open(from_lang_path + file, FileAccess.READ)
				var to: FileAccess = FileAccess.open(to_lang_path + file, FileAccess.WRITE)
				to.store_string(from.get_as_text())
			'import':
				if !file.ends_with('.png.import'):
					printerr("Currently only imported .png is supported, got '%s'" % file)
					continue
				var tex: Texture2D = load(from_lang_path + file.trim_suffix('.import')) as Texture2D
				tex.get_image().save_png(to_lang_path + file.trim_suffix('.import'))
				
			'png':
				pass # stray PNGs may be found if running from editor
			_:
				printerr("Bad file, expected .tef or .png: %s" % file)
	
	print("Exported translation project to '%s'" % to_dir_path)
	return 0


# crawls 'base_folder' recursively, returning all found files as relative paths,
# and creates corresponding subfolders in 'create_dirs_in'
static func _crawl_lang_dir(base_folder: String, path: String, create_dirs_in: DirAccess) -> Variant:
	var access: DirAccess = DirAccess.open(base_folder + '/' + path)
	if access == null:
		return null
	
	var files: Array[String] = []
	for file in access.get_files():
		files.append(path + '/' + file)
	
	for subdir in access.get_directories():
		create_dirs_in.make_dir_recursive((path + '/' + subdir).trim_prefix('/'))
		files.append_array(_crawl_lang_dir(base_folder, path + '/' + subdir, create_dirs_in))
	
	return files
