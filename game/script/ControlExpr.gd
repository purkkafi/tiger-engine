class_name ControlExpr extends RefCounted
# class that implements the in-game expression language used  to interface with variables
# implemented (hackily) with Godot's Expression class for now


var string: String # the evaluated string
var context: BaseContext # the context of the evaluation
var assign_to: String = '' # if non-empty, contains the variable the result will be assigned to


func _init(_string: String, _context: Variant):
	self.string = _string
	self.context = _context
	
	var is_assign = RegEx.create_from_string('\\s*([[:alnum:]_]+)\\s*:=(.+)')
	
	var assign = is_assign.search(self.string)
	if assign != null:
		assign_to = assign.strings[1] # the var to assign
		self.string = assign.strings[2] # the rest of the expression
	

func _execute() -> Variant:
	var expr: Expression = Expression.new()
	
	if expr.parse(string, context._variable_names()) != OK:
		push_error('control expression "%s" failed: %s' % [string, expr.get_error_text()])
		return null
	
	var result: Variant = expr.execute(context._variable_values(), context)
	
	if expr.has_execute_failed():
		push_error('control expression "%s" failed: %s' % [string, expr.get_error_text()])
		return null
	
	
	if assign_to != '':
		if context._assign(assign_to, result) != OK:
			push_error('control expression "%s" failed: cannot assign to "%s" in this context' % [string, assign_to])
			return null
	
	return result


# evaluates a control expression in some context, returning the result
static func exec(string: String, ctxt: BaseContext) -> Variant:
	return ControlExpr.new(string, ctxt)._execute()


# evaluates a control expression in a dummy context
# this means that variables cannot be accessed or set
static func exec_contextless(string: String) -> Variant:
	return ControlExpr.new(string, BaseContext.new())._execute()


# base class for contexts, can also be used as an empty context
# contains no variables and errors on all operations
class BaseContext extends RefCounted:
	
	
	# returns a string array of names of defined variables
	func _variable_names() -> Array[String]:
		return []
	
	
	# returns the values for the variables; indices correspond to _variable_names()
	func _variable_values() -> Array[Variant]:
		return []
	
	
	# assigns the given variable, returning an Error indicating success/failure
	func _assign(variable: String, value: Variant) -> Error:
		return FAILED
	
	
	# convenience method for getting a variable
	func _get_var(variable: String) -> Variant:
		push_error('cannot get variable "%s" in this context' % variable)
		return null


# a context with pre-defined variables
# supports _assign & _get_var
class GameContext extends BaseContext:
	
	
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
