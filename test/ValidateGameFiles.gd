class_name ValidateGameFiles extends TETest
# integration test that checks that all files in the assets folder
# parse correctly


func test_loading_game_files():
	var files: Array[String] = get_tef_files_in('res://assets')
	var lexer: Lexer = Lexer.new()
	var parser: Parser = Parser.new()
	
	for file in files:
		var tokens = lexer.tokenize_file(file)
		if tokens == null:
			fail_test('lexer error: %s' % [ lexer.error_message ])
			continue
		
		var result = parser.parse(tokens)
		if result == null:
			fail_test('parser error: %s' % [ parser.error_message ])
		
		# TODO: also test loading them as Resources to ensure integrity


func get_tef_files_in(path):
	var files: Array[String] = []
	var directory: DirAccess = DirAccess.open(path)
	
	for file in directory.get_files():
		if file.ends_with('.tef'):
			files.append(path + '/' + file)
	
	for dir in directory.get_directories():
		files.append_array(get_tef_files_in(path + '/' + dir))
	
	return files


# ensures that all translations have all uistrings
func test_uistrings_translations():
	var keys: Dictionary = {}
	var all_keys: Array = []
	var languages = TEInitScreen.get_languages()
	
	for lang in languages:
		var localize: Localize = Localize.of_lang(lang.id)
		
		var this_keys = Array(localize.strings.keys())
		keys[lang.id] = this_keys
		
		for key in this_keys:
			if key not in all_keys:
				all_keys.append(key)
	
	for key in all_keys:
		for lang in languages:
			if key not in keys[lang.id]:
				fail_test("uistring translation error: %s missing string '%s'" % [lang.id, key])


# ensures that all files definitions.tef refers to exist in the project
func test_definition_files_exist():
	pass # TODO implement
