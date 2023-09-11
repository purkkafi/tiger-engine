class_name CmdArgs extends Node
# implements command line options


# parses cmd args, setting game options or executing an additional task and quitting
static func handle_args():
	var args: Array = Array(OS.get_cmdline_user_args())
	
	var i: int = 0
	while i < len(args):
		match args[i]:
			'--run-tests':
				TE.quit_game(TestRunner.run_tests())
			'--debug', '-d':
				TE._force_debug = true
			'--no-debug':
				TE._force_debug = false
			'--mobile', '-m':
				TE._force_mobile = true
			'--no-mobile':
				TE._force_mobile = false
			'--word-count', '-wc':
				i += 1
				var lang: String = args[i]
				_word_count(lang)
				TE.quit_game()
			'--help', '-h':
				print("""
					supported arguments:
					--run-tests
						run the engine's unit & integration tests and quit
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


# regex that matches if a word has any alphanumeric charcters and
# should therefore be counted as a word
static var IS_WORD: RegEx = RegEx.create_from_string('\\w+')


# implements the --word-count cmd option, printing block word counts and quitting
# TODO: deal with bbcode tags in a more graceful way
static func _word_count(lang: String):
	var folder_path: String = 'assets/lang/%s/text/' % lang
	var folder: DirAccess = DirAccess.open(folder_path)
	
	if folder == null:
		push_error('cannot open text folder for language: %s' % lang)
		return
	
	folder.list_dir_begin()
	var file: String = folder.get_next()
	var counts: Dictionary = {}
	
	while file != '':
		var path = '%s%s' % [folder_path, file]
		var blockfile: BlockFile = Assets.blockfiles.get_unqueued(path)
		
		var count: int = 0
		for block in blockfile.blocks.values():
			for par in Blocks.resolve_parts(block):
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
