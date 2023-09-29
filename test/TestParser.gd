class_name TestParser extends TETest


var lexer: Lexer = Lexer.new()
var parser: Parser = Parser.new()


func parse(str: String):
	return normalize(parser.parse(lexer.tokenize_string(str, '<test>')))


# converts a taglist into nested Arrays and Dictionaries of Strings,
# making testing for equality work
func normalize(taglist: Variant):
	if taglist is String:
		return taglist
	if taglist is Tag.Break:
		return '<break>'
	if taglist is Tag:
		return { 'name' : taglist.name, 'args' : taglist.args.map(func(a): return normalize(a)) }
	if taglist is Tag.ControlTag:
		return { 'control' : taglist.string }
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
		[ 'string', '<break>', 'another', '<break>', 'third' ]
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
		[ { 'name' : 'tag', 'args' : [['line', '<break>', 'another']] } ]
	)


func test_stripping_whitespace():
	var text = """
			
			Line
			
			and another
			third
			
	"""
	
	assert_equals(
		parse(text),
		[ 'Line', '<break>', 'and another', '<break>', 'third' ]
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


func test_inline_control_tag():
	assert_equals(
		parse('{{kis{sa}}'),
		[ { 'control' : 'kis{sa' } ]
	)


func test_control_tag_as_tag_argument():
	assert_equals(
		parse('\\tag{{ a={} b="\\n" }}'),
		[ { 'name' : 'tag', 'args' : [[
			{ 'control': ' a={} b="\\n" ' }
		]]} ]
	)


func test_multiple_control_tags_as_tag_arguments():
	assert_equals(
		parse('\\a{{b}}{{c}}'),
		[ { 'name' : 'a', 'args' : [
			[ { 'control' : 'b' } ],
			[ { 'control' : 'c' } ] ]
		} ]
	)


func test_normal_and_control_tag_args():
	assert_equals(
		parse('\\tag{1}{{2}}{3}'),
		[ { 'name' : 'tag', 'args': [
			[ '1' ],
			[ { 'control' : '2' } ],
			[ '3' ]
		] } ]
	)


func test_inline_control_tag_in_tag():
	assert_equals(
		parse('\\a{1\n{{2}}\n3}'),
		[ { 'name' : 'a', 'args' : [[
			'1',
			'<break>',
			{ 'control' : '2' },
			'<break>',
			'3'
		]] } ]
	)


func test_empty_strings_removed_from_nested_tags():
	assert_equals(
		parse('\\outer{ \\inner{} }'),
		[ { 'name' : 'outer', 'args' : [[
			{ 'name' : 'inner', 'args' : [[]] }
		]] }]
	)
