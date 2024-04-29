class_name CmdArgs extends Node
# implements command line options


static var cmd_task_screen: PackedScene = preload('res://tiger-engine/ui/screens/CmdTaskScreen.tscn')


# parses cmd args, setting game options or executing an additional task and quitting
static func handle_args() -> Variant:
	var args: Array = Array(OS.get_cmdline_user_args())
	var instead = null
	
	var i: int = 0
	while i < len(args):
		match args[i]:
			'--run-tests':
				instead = cmd_task_screen.instantiate()
				instead.task = TestRunner.run_tests
			'--extract-language':
				i += 1
				var lang: String = args[i]
				i += 1
				var to: String = args[i]
				instead = cmd_task_screen.instantiate()
				instead.task = CmdArgs._extract_language.bind(lang, to)
			'--debug', '-d':
				TE._force_debug = true
			'--no-debug':
				TE._force_debug = false
			'--mobile', '-m':
				TE._force_mobile = true
			'--no-mobile':
				TE._force_mobile = false
			'--stage-editor', '-se':
				instead = preload('res://tiger-engine/engine/StageEditor.tscn').instantiate()
			'--word-count', '-wc':
				i += 1
				var lang: String = args[i]
				instead = cmd_task_screen.instantiate()
				instead.task = _word_count.bind(lang)
			'--help', '-h':
				print("""
					supported arguments:
					--run-tests
						run the engine's unit & integration tests and quit
					--extract-language <lang> <target>
						creates translation project, extracting the given language to the target folder
					-d, --debug
						force enable the engine's debug mode (by default enabled if Godot's is)
					--no-debug
						force disable the engine's debug mode
					-m, --mobile
						force enable mobile mode, i.e. pretend game is run on android
					--no-mobile
						force disable mobile mode, i.e. pretend game is run on desktop
					-wc, --word-count <lang>
						print block word counts and quit
					-h, --help
						print this message and quit
				""".dedent().trim_prefix('\n').trim_suffix('\n')) # this is so ugly lol
				TE.quit_game()
			_:
				print("error: unknown command line argument: '%s'" % args[i])
				print("run with '-- --help' for help")
				TE.quit_game()
		
		i += 1
	
	return instead


# regex that matches if a word has any alphanumeric charcters and
# should therefore be counted as a word
static var IS_WORD: RegEx = RegEx.create_from_string('\\w+')


# implements the --word-count cmd option, printing block word counts and quitting
# TODO: deal with bbcode tags in a more graceful way
static func _word_count(lang: String) -> int:
	var folder_path: String = 'assets/lang/%s/text/' % lang
	var folder: DirAccess = DirAccess.open(folder_path)
	
	if folder == null:
		push_error('cannot open text folder for language: %s' % lang)
		return 1
	
	folder.list_dir_begin()
	var file: String = folder.get_next()
	var counts: Dictionary = {}
	
	# construct VariableContext to support variables
	var var_names: Array[String] = []
	var_names.append_array(TE.defs.variables.keys())
	var var_def_values: Array[Variant] = var_names.map(func(v): return TE.defs.variables[v])
	var game_ctxt: VariableContext = VariableContext.new(var_names, var_def_values)
	
	while file != '':
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
	
	var max_len: int = max(5, counts.keys().map(func(k): return len(k)).max())
	
	for counted_file in counts.keys():
		print('%-*s   %d' % [max_len, counted_file, counts[counted_file]])
	
	var total: int = 0
	for count in counts.values():
		total += count
	
	print('\n%-*s   %d' % [max_len, 'TOTAL', total])
	
	return 0


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
