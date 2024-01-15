class_name GameContext extends ControlExpr.BaseContext
# a context used in-game for storing and interacting with game state
# supports _assign & _get_var by maintaining internal variables
# and contains useful functions intended to be used by scripts


var var_names: Array[String]
var var_values: Array[Variant]
var view_result: Variant = null # result of last View or null


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

# functions available for use in the control expression

func result() -> Variant:
	if view_result == null:
		push_error('result() called when last View did not produce a result')
	return view_result


func unlock(unlockable: String):
	TE.persistent.unlock(unlockable)


func is_unlocked(unlockable: String) -> bool:
	return TE.persistent.is_unlocked(unlockable)


func show_toast(title: String, description: String, icon = null):
	TE.send_toast_notification(title, description, icon)


func localize(id: String):
	return TE.localize[id]
