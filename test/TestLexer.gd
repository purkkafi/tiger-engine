class_name TestLexer extends TETest


var lexer = Lexer.new()


func string(str: String) -> Lexer.Token:
	return Lexer.Token.string(str, '<debug>', -1)


func tag(str: String) -> Lexer.Token:
	return Lexer.Token.tag(str, '<debug>', -1)


func brace_open() -> Lexer.Token:
	return Lexer.Token.brace_open('<debug>', -1)


func brace_close() -> Lexer.Token:
	return Lexer.Token.brace_close('<debug>', -1)


func newline() -> Lexer.Token:
	return Lexer.Token.newline('<debug>', -1)


func raw_string(str: String) -> Lexer.Token:
	return Lexer.Token.raw_string(str, '<debug>', -1)


func tokenize(str: String):
	return lexer.tokenize_string(str, '<test>')


# tests that given Tokens are equal, ignoring file and line
func assert_token_contents_equal(t1: Array[Lexer.Token], t2: Array[Lexer.Token]):
	var d1 = []
	for t in t1:
		d1.append(str(t))
	var d2 = []
	for t in t2:
		d2.append(str(t))
	assert_equals(d1, d2)


func test_lexing_string():
	assert_token_contents_equal(
		tokenize('kissa'),
		[ string('kissa') ]
	)


func test_lexing_braces():
	assert_token_contents_equal(
		tokenize('{}}{'),
		[ brace_open(), brace_close(), brace_close(), brace_open() ]
	)


func test_lexing_newlines():
	assert_token_contents_equal(
		tokenize('a\n\n   \t   \nb'),
		[ string('a'), newline(), string('b') ]
	)


func test_newlines_stripped():
	assert_token_contents_equal(
		tokenize('\n\n   \n  a\n\n  \n'),
		[ string('a') ]
	)


func test_lexing_tags():
	assert_token_contents_equal(
		tokenize('\\tag{}'),
		[ tag('tag'), brace_open(), brace_close() ]
	)


func test_lexing_double_tag():
	assert_token_contents_equal(
		tokenize('\\a\\b'),
		[ tag('a'), tag('b') ]
	)


func test_lexing_nested_tags():
	assert_token_contents_equal(
		tokenize('\\a{ \\b }'),
		[ tag('a'), brace_open(), string(' '), tag('b'), string(' '), brace_close() ]
	)


func test_escaping_backslash():
	assert_token_contents_equal(
		tokenize('kissa\\\\hauska'),
		[ string('kissa\\hauska') ]
	)


func test_escaping_braces():
	assert_token_contents_equal(
		tokenize('{\\{\\}}a\\{'),
		[ brace_open(), string('{}'), brace_close(), string('a{') ]
	)


func test_ending_backslash():
	var tokens = tokenize('problematic final backslash should cause an error message\\')
	
	assert_equals(tokens, null)
	
	assert_equals(
		lexer.error_message,
		'trailing empty tag in <test>:1'
	)


func test_stray_backslash():
	assert_equals(tokenize('this is \\ wrong'), null)
	
	assert_equals(
		lexer.error_message,
		'trailing empty tag in <test>:1'
	)


func test_line_numbers():
	var tokens = lexer.tokenize_file('res://tiger-engine/test/lexer_linenro_test.tef')
	assert_equals(
		tokens[26].where(),
		'res://tiger-engine/test/lexer_linenro_test.tef:25'
	)


func test_raw_string():
	assert_token_contents_equal(
		tokenize('\\raw{{string}}'),
		[ tag('raw'), raw_string('string') ]
	)


func test_special_characters_in_raw_string():
	assert_token_contents_equal(
		tokenize('{{raw{string}cool\\kissa}}'),
		[ raw_string('raw{string}cool\\kissa') ]
	)


func test_raw_string_line_numbers():
	var tokens: Array = lexer.tokenize_file('res://tiger-engine/test/lexer_raw_string_linenro_test.tef')
	
	assert_equals(
		tokens[1].where(), # the raw string
		'res://tiger-engine/test/lexer_raw_string_linenro_test.tef:1'
	)
	
	assert_equals(
		tokens[3].where(), # the next tag
		'res://tiger-engine/test/lexer_raw_string_linenro_test.tef:10'
	)


func test_unterminated_raw_string():
	assert_equals(tokenize('oh {{no'), null)
	
	assert_equals(
		lexer.error_message,
		'unterminated raw string in <test>:1'
	)


func test_empty_raw_string():
	assert_token_contents_equal(
		tokenize('{{}}'),
		[ raw_string('') ]
	)
