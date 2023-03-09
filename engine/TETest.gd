class_name TETest extends RefCounted
# base class for tests


# emitted on failed assertions
signal test_failed


# holds error messages encountered while running current test
var _errors: Array[String] = []


# runs the given test, returning an array of error messages
# (which is empty on success)
func run_test(method: String) -> Array[String]:
	_errors = []
	var on_fail = func(msg): self._errors.append(msg)
	
	self.connect('test_failed', on_fail)
	Callable(self, method).call()
	self.disconnect('test_failed', on_fail)
	
	return _errors


func fail_test(msg: String):
	emit_signal('test_failed', msg)


func assert_equals(a: Variant, b: Variant):
	if a != b:
		fail_test('Assertion failed: \n   ' + str(a) + '\n  ==\n   '  + str(b))
