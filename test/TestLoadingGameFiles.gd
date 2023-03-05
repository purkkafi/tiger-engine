class_name ValidateGameFiles extends TETest
# integration test that checks that all files in the assets folder
# parse correctly


func test_loading_game_files():
	var files: Array[String] = get_files_in('res://assets')
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


func get_files_in(path):
	var files: Array[String] = []
	var directory: DirAccess = DirAccess.open(path)
	
	for file in directory.get_files():
		if file.ends_with('.tef'):
			files.append(path + '/' + file)
	
	for dir in directory.get_directories():
		files.append_array(get_files_in(path + '/' + dir))
	
	return files
