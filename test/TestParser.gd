class_name TestParser extends TETest


var lexer: Lexer = Lexer.new()
var parser: Parser = Parser.new()


func parse(str: String):
	return normalize(parser.parse(lexer.tokenize_string(str, '<test>')))


func normalize(taglist: Variant):
	if taglist is String:
		return taglist
	if taglist is Tag:
		return { 'name' : taglist.name, 'args' : taglist.args.map(func(a): return normalize(a)) }
	if taglist is Array:
		var arr: Array[Variant] = []
		for t in taglist:
			arr.append(normalize(t))
		return arr
	if taglist == null:
		return null
	else:
		push_error('cannot normalize ' + str(taglist))


func test_parsing_single_string():
	assert_equals(
		parse('a string'),
		[ 'a string' ]
	)


func test_parsing_multiple_strings():
	assert_equals(
		parse('string\n\n\nanother\nthird'),
		[ 'string', 'another', 'third' ]
	)


func test_parsing_single_tag():
	assert_equals(
		parse('\\tag{}'),
		[ { 'name' : 'tag', 'args' : [[]] } ]
	)


func test_parsing_argless_tag():
	assert_equals(
		parse('\\tag'),
		[ { 'name' : 'tag', 'args' : [] } ]
	)


func test_parsing_tag_with_args():
	assert_equals(
		parse('\\tag{1}{2}'),
		[ { 'name' : 'tag', 'args' : [ ['1'], ['2'] ] } ]
	)


func test_parsing_consecutive_tags():
	assert_equals(
		parse('\\a{v}\\b{}'),
		[ { 'name' : 'a', 'args' : [['v']] },
		{ 'name' : 'b', 'args' : [[]] } ]
	)


func test_parsing_nested_tags():
	assert_equals(
		parse('\\a{\\b{}}'),
		[ { 'name' : 'a', 'args' : [[ { 'name' : 'b', 'args' : [[]] } ]] } ]
	)


func test_parsing_tag_with_prose():
	assert_equals(
		parse('\\tag{line\n\nanother}'),
		[ { 'name' : 'tag', 'args' : [['line', 'another']] } ]
	)


func test_stripping_whitespace():
	var text = """
			
			Line
			
			and another
			third
			
	"""
	
	assert_equals(
		parse(text),
		[ 'Line', 'and another', 'third' ]
	)


func test_unclosed_brace_error():
	assert_equals(parse('\\no{wrong'), null)
	
	assert_equals(
		parser.error_message,
		'syntax error: expected } or value, got <eof> at <test>:1'
	)


func test_unclosed_brace_error_at_eof():
	assert_equals(parse('\\bad{'), null)
	
	assert_equals(
		parser.error_message,
		'syntax error: expected } or value, got <eof> at <test>:1'
	)


func test_stray_brace():
	assert_equals(parse('there are { problems }'), null)
	
	assert_equals(
		parser.error_message,
		'syntax error: expected value, got BRACE_OPEN at <test>:1'
	)


func test_escaping_braces():
	assert_equals(
		parse('\\tag\\{\\}'),
		[ { 'name' : 'tag', 'args' : [] }, '{}' ]
	)
