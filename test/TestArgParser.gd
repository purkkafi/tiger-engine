class_name TestArgParser extends TETest


func test_string_arg():
	var parser: ArgParser = ArgParser.new()
	parser.register('--test', ArgParser.Type.STRING)
	
	assert_equals(parser.parse(['--test', 'value']), { '--test': 'value' })


func test_string_arg_error_nothing_given():
	var parser: ArgParser = ArgParser.new()
	parser.register('--test', ArgParser.Type.STRING)
	
	assert_equals(parser.parse(['--test']), { 'error': 'expected value for --test' })


func test_flag():
	var parser: ArgParser = ArgParser.new()
	parser.register('--empty', ArgParser.Type.FLAG)
	
	assert_equals(parser.parse(['--empty']), { '--empty': null })


func test_final_args():
	var parser: ArgParser = ArgParser.new()
	parser.register('--empty', ArgParser.Type.FLAG)
	
	assert_equals(
		parser.parse(['--empty', '1', '2', '3']),
		{ '--empty': null, '': ['1', '2', '3'] }
	)


func test_flag_error_something_given():
	var parser: ArgParser = ArgParser.new()
	parser.register('--empty', ArgParser.Type.FLAG)
	parser.register('--test', ArgParser.Type.STRING)
	
	assert_equals(
		parser.parse(['--empty', 'badvalue', '--test', 'goodvalue']),
		{ 'error': 'misplaced argument: --test' }
	)


func test_string_array_arg():
	var parser: ArgParser = ArgParser.new()
	parser.register('--array', ArgParser.Type.STRING_ARRAY)
	
	assert_equals(parser.parse(['--array', 'a', 'b', 'c']), { '--array': ['a', 'b', 'c'] })


func test_aliases():
	var parser: ArgParser = ArgParser.new()
	parser.register('--arg', ArgParser.Type.STRING, ['--alias', '-a'])
	
	assert_equals(parser.parse(['--arg', 'val']), { '--arg': 'val' })
	assert_equals(parser.parse(['--alias', 'val']), { '--arg': 'val' })
	assert_equals(parser.parse(['-a', 'val']), { '--arg': 'val' })


func test_unknown_argument():
	var parser: ArgParser = ArgParser.new()
	
	assert_equals(parser.parse(['--bad']), { 'error': 'unknown argument: --bad' })


func test_complex_argument_series():
	var parser: ArgParser = ArgParser.new()
	parser.register('--flag', ArgParser.Type.FLAG)
	parser.register('--aliased-array', ArgParser.Type.STRING_ARRAY, ['--aa'])
	parser.register('--aliased-flag', ArgParser.Type.FLAG, ['-a'])
	parser.register('--value', ArgParser.Type.STRING)
	
	assert_equals(
		parser.parse(['--flag', '--aa', 'A', 'B', 'C', '-a', '--value', 'VAL', 'FIN' ]),
		{ '--flag': null, '--aliased-array': ['A', 'B', 'C'], '--aliased-flag': null, '--value': 'VAL', '': ['FIN'] }
	)


func test_exclusivity():
	var parser: ArgParser = ArgParser.new()
	parser.register('--flag1', ArgParser.Type.FLAG)
	parser.register('--flag2', ArgParser.Type.FLAG, ['--F2'])
	parser.register('--flag3', ArgParser.Type.FLAG)
	
	parser.set_as_exclusive(['--flag1', '--flag2'])
	
	assert_equals(
		parser.parse(['--flag1', '--F2', '--flag3']),
		{ 'error': 'only one of --flag1, --flag2 is allowed' }
	)


# TODO support in the future
"""
func test_equals_syntax():
	var parser: ArgParser = ArgParser.new()
	parser.register('--test', ArgParser.Type.STRING)
	
	assert_equals(parser.parse(['--test=VAL']), { '--test': 'VAL'})
"""


# TODO support in the future
"""
func test_flag_bundle_syntax():
	var parser: ArgParser = ArgParser.new()
	parser.register('-A', ArgParser.Type.FLAG)
	parser.register('-B', ArgParser.Type.FLAG)
	parser.register('-C', ArgParser.Type.FLAG)
	
	assert_equals(parser.parse(['-ABC']), { '-A': null, '-B': null, '-C': null})
"""
