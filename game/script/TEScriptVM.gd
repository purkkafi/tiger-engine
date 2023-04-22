class_name TEScriptVM extends RefCounted
# executes TEScript code


var scriptfile: ScriptFile
var current_script: TEScript
var index: int = 0
var lookahead_index: int = 0
var BLOCKING_INSTRUCTIONS: Array[String] = [ 'Block', 'Pause', 'Break',  'View', 'Jmp', 'JmpIf' ]
var CONDITIONAL_INSTRUCTIONS: Array[String] = [ 'JmpIf' ]


func _init(_scriptfile: ScriptFile, script: String):
	self.scriptfile = _scriptfile
	self.current_script = scriptfile.scripts[script]


func jump_to(script: String):
	if not script in scriptfile.scripts:
		TE.log_error('tried to jump to unknown script: %s' % script)
	self.current_script = scriptfile.scripts[script]
	index = 0   
	lookahead_index = 0


func jump_to_file(file: ScriptFile, script: String):
	self.scriptfile = file
	jump_to(script)


func is_end_of_script() -> bool:
	return _current() == null


# returns the current instruction
func _current() -> Variant:
	if index >= len(current_script.instructions):
		return null
		#push_error('unexpected end of script: index %d of %d' % [index, len(current_script.instructions)])
		#Popups.error_dialog(Popups.GameError.SCRIPT_ERROR)
	return current_script.instructions[index]


func _is_blocking(instruction: TEScript.BaseInstruction) -> bool:
	return instruction.name in BLOCKING_INSTRUCTIONS


func _is_conditional(instruction: TEScript.BaseInstruction) -> bool:
	return instruction.name in CONDITIONAL_INSTRUCTIONS


# proceeds to the next blocking instruction, returning an Array
# of instructions that should be handled by the executor
# after this, the next call of next_blocking() will return the blocking instruction
func to_next_blocking() -> Array[Variant]:
	var handle_ins: Array[TEScript.BaseInstruction] = []
	
	while _current() != null and not _is_blocking(_current()):
		handle_ins.append(_current())
		index += 1
	
	queue_resources(lookahead())
	
	return handle_ins


# returns a list of instructions whose associated resources may be queued for loading
# in general, this method:
# – limits how far it looks with the help of several heuristics
# – will only return each instruction once
# – will stop at branches (i.e. every instruction returned will be encountered inevitably)
func lookahead() -> Array[TEScript.BaseInstruction]:
	var found: Array[TEScript.BaseInstruction] = []
	var blocking_count = 0
	
	while lookahead_index < len(current_script.instructions):
		var ins = current_script.instructions[lookahead_index]
		
		# limit how far ahead we look
		if lookahead_index > index+5:
			break 
		
		# limit the amount of blocking instructions we look past
		if _is_blocking(ins):
			blocking_count += 1
			if blocking_count >= 3:
				break
		
		# do not go past instructions that affect control flow unpredictably
		# (to not load assets that don't actually get used)
		# (might react badly with Godot's queue mechanism? not sure)
		if _is_conditional(ins):
			break
		
		found.append(ins)
		lookahead_index += 1
	
	return found


# queues the resources in the given instructions for loading
func queue_resources(instructions: Array[TEScript.BaseInstruction]):
	for ins in instructions:
		match ins.name:
			'Block':
				Blocks.find(ins.block_id, true)
			'Jmp':
				if ins.in_file != null:
					Assets.scripts.queue(ins.in_file + '.tef', 'res://assets/scripts')
			'BG':
				if ins.bg_id in TE.defs.imgs:
					Assets.imgs.queue(TE.defs.imgs[ins.bg_id], 'res://assets/img')
			'FG':
				if ins.fg_id in TE.defs.imgs:
					Assets.imgs.queue(TE.defs.imgs[ins.fg_id], 'res://assets/img')
			'PlaySong':
				if ins.song_id != '':
					Assets.songs.queue(TE.defs.songs[ins.song_id], 'res://assets/music')
			'PlaySound':
				Assets.sounds.queue(TE.defs.sounds[ins.sound_id], 'res://assets/sound')
			'Enter':
				Assets.sprites.queue(TE.defs.sprites[ins.sprite] + '/sprite.tef', 'res://assets/sprites')
			
			'View': # hardcode queuing resources for built-in Views
				# load the scene a CutsceneView shows
				if ins is TEScript.IView and ins.view_id == 'cutscene':
					for opt in ins.options:
						if opt.name == 'path':
							Assets.noncached.queue(opt.get_string())
			_: # do nothing, cannot handle this instruction
				pass


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
	vm.lookahead_index = state['index']
	
	if vm.index > len(vm.current_script.instructions):
		TE.log_error('instruction index out of range')
		Popups.error_dialog(Popups.GameError.BAD_SAVE)
		return
	
	return vm
