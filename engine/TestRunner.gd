class_name TestRunner extends Object


# finds and runs all tests
# returns 0 if all passed, a nonzero value otherwise
static func run_tests() -> int:
	TE.log_info('Running tests...')
	
	var failed: bool = false
	
	for cls in 	ProjectSettings.get_global_class_list():
		if cls['base'] == 'TETest':
			var succ: int = 0
			var fail: int = 0
			var instance: TETest = load(cls['path']).new()
			var tests = instance.get_method_list().map(func(m): return m['name']).filter(func(m): return m.begins_with('test'))
			
			for test in tests:
				var result = instance.run_test(test)
				if len(result) != 0:
					fail += 1
					var string = 'Test failed: ' + cls['class'] + '/' + test + ': '
					for err in result:
						string += '\n – ' + err
					TE.log_error(TE.Error.TEST_FAILED, string)
				else:
					succ += 1
					failed = true
			
			TE.log_info('%s: %d/%d passed' % [cls['class'], succ, (succ+fail)])
	
	return 1 if failed else 0
