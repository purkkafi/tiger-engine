class_name TEScriptVM extends RefCounted
# executes TEScript code


var scriptfile: ScriptFile
var current_script: TEScript
var index: int = 0
var BLOCKING_INSTRUCTIONS: Array[String] = [ 'Block', 'Pause', 'Break',  'View' ]


func _init(_scriptfile: ScriptFile, script: String):
	self.scriptfile = _scriptfile
	self.current_script = scriptfile.scripts[script]


func is_end_of_script() -> bool:
	return _current() == null


# returns the current instruction
func _current() -> Variant:
	if index >= len(current_script.instructions):
		return null
		#push_error('unexpected end of script: index %d of %d' % [index, len(current_script.instructions)])
		#Popups.error_dialog(Popups.GameError.SCRIPT_ERROR)
	return current_script.instructions[index]


func _is_blocking(instruction) -> bool:
	return instruction.name in BLOCKING_INSTRUCTIONS


# proceeds to the next blocking instruction, returning an Array
# of instructions that should be handled by the executor
# after this, the next call of next_blocking() will return the blocking instruction
func to_next_blocking() -> Array[Variant]:
	var handle_ins: Array[Variant] = []
	
	while _current() != null and not _is_blocking(_current()):
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
	Assets.scripts.get_resource(scriptfile.resource_path) # ensure hash is calculated
	var _hash = Assets.scripts.hashes[scriptfile.resource_path + ':' + current_script.name]
	return {
		'current_script' : current_script.name,
		'scriptfile' : scriptfile.resource_path,
		'index' : index,
		'hash' : _hash
	}


# returns a VM instance that has the given state (as obtained from get_state())
static func from_state(state: Dictionary) -> TEScriptVM:
	if !FileAccess.file_exists(state['scriptfile']):
		TE.log_error('scriptfile not found: %s' % state['scriptfile'])
		Popups.error_dialog(Popups.GameError.BAD_SAVE)
		return
	
	var _scriptfile: ScriptFile = Assets.scripts.get_resource(state['scriptfile'])
	var script: String = state['current_script']
	
	if script not in _scriptfile.scripts:
		TE.log_error('script %s not found in scriptfile %s' % [script, _scriptfile.id])
		Popups.error_dialog(Popups.GameError.BAD_SAVE)
		return
	
	var vm: TEScriptVM = TEScriptVM.new(_scriptfile, script)
	vm.index = state['index']
	
	if vm.index > len(vm.current_script.instructions):
		TE.log_error('instruction index out of range')
		Popups.error_dialog(Popups.GameError.BAD_SAVE)
		return
	
	return vm
