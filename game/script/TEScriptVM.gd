class_name TEScriptVM
# executes TEScript code


var scriptfile: ScriptFile
var current_script: TEScript
var index: int = 0


func _init(_scriptfile: ScriptFile, script: String):
	self.scriptfile = _scriptfile
	self.current_script = scriptfile.scripts[script]


# returns the current instruction
func _current() -> Variant:
	if index >= len(current_script.instructions)-1:
		push_error('unexpected end of script: index %d of %d' % [index, len(current_script.instructions)])
		Popups.error_dialog(Popups.GameError.SCRIPT_ERROR)
	return current_script.instructions[index]


func _is_blocking(instruction) -> bool:
	if instruction is TEScript.IBlock:
		return true
	if instruction is TEScript.IPause:
		return true
	if instruction is TEScript.IHideUI:
		return true
	if instruction is TEScript.IBG:
		return true
	if instruction is TEScript.IFG:
		return true
	return false


# proceeds to the next blocking instruction, returning an Array
# of instructions that should be handled by the executor
# after this, the next call of next_blocking() will return the blocking instruction
func to_next_blocking() -> Array[Variant]:
	var handle_ins: Array[Variant] = []
	
	while not _is_blocking(_current()):
		handle_ins.append(_current())
		index += 1
	
	return handle_ins


func next_blocking() -> Variant:
	if(!_is_blocking(_current())):
		push_error('illegal state: not on blocking instruction, got %s' % [_current()])
		return null
	var blocking = _current()
	index += 1
	return blocking


# returns the current state as a dict
func get_state() -> Dictionary:
	var _hash = Assets.scripts.hashes[scriptfile.resource_path][current_script.name]
	return {
		'current_script' : current_script.name,
		'index' : index,
		'hash' : _hash
	}
