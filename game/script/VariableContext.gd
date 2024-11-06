class_name VariableContext extends ControlExpr.BaseContext
# a context used for storing and interacting with variables
# supports _assign & _get_var by maintaining internal state


var var_names: Array[String]
var var_values: Array[Variant]


func _init(names: Array[String], values: Array[Variant]):
	self.var_names = names
	self.var_values = values


func _variable_names() -> Array[String]:
	return var_names


func _variable_values() -> Array[Variant]:
	return var_values


func _assign(variable: String, value: Variant) -> Error:
	for i in range(len(var_names)):
		if var_names[i] == variable:
			var_values[i] = value
			return OK
	
	return FAILED


func _get_var(variable: String) -> Variant:
	for i in range(len(var_names)):
		if var_names[i] == variable:
			return var_values[i]
	push_error('variable "%s" not found in this context' % variable)
	return null
