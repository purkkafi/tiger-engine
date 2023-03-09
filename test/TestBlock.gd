class_name TestBlock extends TETest


func hashed(content: Array):
	return Block.new(content).resolve_hash()


# TODO: tests for resolve_string and resolve_parts?


func test_hashing_stable():
	assert_equals(
		hashed([ 'a string to hash' ]),
		hashed([ 'a string to hash' ])
	)


func test_hashing_strings():
	assert_not_equals(
		hashed([ 'a string', 'another' ]),
		hashed([ 'a string', 'not the same string'])
	)


func test_hashing_breaks():
	assert_not_equals(
		hashed([ 'a', 'b' ]),
		hashed([ 'a', Tag.Break.new(), 'b' ])
	)


func test_hashing_tags():
	assert_not_equals(
		hashed([ Tag.new('a', []) ]),
		hashed([ Tag.new('b', []) ])
	)


func test_hashing_tags_with_args():
	assert_not_equals(
		hashed([ Tag.new('tag', [[ 'a' ]]) ]),
		hashed([ Tag.new('tag', [[ 'b' ]]) ])
	)


func test_hashing_control_tags():
	assert_not_equals(
		hashed([ Tag.ControlTag.new('a') ]),
		hashed([ Tag.ControlTag.new('b') ])
	)
