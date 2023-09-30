class_name TEScriptCompiler extends RefCounted


var scripts: Dictionary
# number of branches generated for each script; dict of script name -> int
# used by generate_label()
var branch_count: Dictionary
# error messages caused during compilation
var errors: Array[String] = []


func compile_script(script_tag: Tag):
	var script_id: String = script_tag.get_string_at(0)
	var tags: Array = script_tag.get_tags_at(1)
	
	var ins = to_instructions(tags, script_id)
	scripts[script_id] = TEScript.new(script_id, ins)


func has_errors():
	return len(errors) != 0


# registers an error message encountered during compilation
func error(msg: String):
	errors.append(msg)


# returns a suitable, unused name for a subscript
# note: the caller needs to fill in the script, as otherwise
# a problematic null value remains as a placeholder
func generate_label(base: String):
	if '$' in base: # remove everything after first $, if any
		base = base.substr(0, base.find('$'))
	
	if base in branch_count:
		var i = branch_count[base]+1
		branch_count[base] = i
		return '%s$%d' % [base, i]
	
	branch_count[base] = 1
	return '%s$1' % base


# parses a \bg or \fg tag. tag_name must be "bg" or "fg"
func parse_bg_or_fg(tag: Tag, tag_name: String) -> Variant:
	var id: String = ''
	var trans: String = ''
	
	match tag.length():
		1:
			pass
		2:
			var args: Array = tag.get_tags_at(1)
			
			if len(args) == 0:
				error('expected args in index 1 of \\%s, got %s' % [tag_name, tag])
				return null
			
			for arg in args:
				match arg.name:
					'with':
						if arg.get_string() is String:
							trans = arg.get_string()
						else:
							error('expected transition for \\with, got %s' % tag)
							return null
					_:
						error("unknown argument '%s' for \\%s: %s" % [arg.name, tag_name, tag])
						return null
		_:
			error('expected 1 or 2 arguments for \\%s, got %s' % [tag_name, tag])
			return null
	
	var value0 = tag.get_value_at(0)
	if value0 is String:
		id = value0
	elif value0 is Tag and value0.name == 'clear' and value0.length() == 0:
		id = ''
	else:
		error('expected id or \\clear in index 0 of \\%s, got %s' % [tag_name, tag])
		return null
	
	match tag_name:
		'bg':
			return TEScript.IBG.new(id, trans)
		'fg':
			return TEScript.IFG.new(id, trans)
		_:
			push_error('parse_fg_or_bg called with illegal tag_name: %s' % tag_name)
			return null


# parses \music tag
func parse_music(tag: Tag) -> Variant:
	var song_id: String = ''
	var transition: String = ''
	var local_volume: float = 1.0
	
	match tag.length():
		1:
			pass
		2:
			var args = tag.get_tags_at(1)
			
			if len(args) == 0:
				error('expected args in index 1 of \\music, got %s' % [tag])
				return null
			
			for arg in args:
				match arg.name:
					'with':
						if arg.get_string() is String:
							transition = arg.get_string()
						else:
							error('expected transition for \\with, got %s' % tag)
							return null
					'volume':
						if not arg.get_string().is_valid_float():
							error('expected float for \\volume, got %s' % tag)
							return null
						local_volume = float(arg.get_string())
					_:
						error("unknown argument '%s' for \\music: %s" % [arg.name, tag])
						return null
		_:
			error('expected 1 or 2 arguments for \\music, got %s' % tag)
			return null
	
	var value0 = tag.get_value_at(0)
	if value0 is String:
		song_id = value0
	elif value0 is Tag and value0.name == 'clear' and value0.length() == 0:
		song_id = ''
	else:
		error('expected id or \\clear in index 0 of \\music, got %s' % tag)
		return null
	
	return TEScript.IMusic.new(song_id, transition, local_volume)


# parses \enter
func parse_enter(tag: Tag):
	var sprite_id: String
	var at: Variant = null
	var with: Variant = null
	var by: Variant = null
	
	match tag.length():
		1:
			pass
		2:
			var args = tag.get_tags_at(1)
			
			if len(args) == 0:
				error('expected args in index 1 of \\enter, got %s' % tag)
				return null
			
			for arg in args:
				match arg.name:
					'with':
						if arg.get_string() is String:
							with = arg.get_string()
						else:
							error('expected transition for \\with, got %s' % tag)
							return null
					'at':
						if arg.get_string() is String:
							at = arg.get_string()
						else:
							error('expected location descriptor for \\at, got %s' % tag)
							return null
					'by':
						if arg.get_string() is String:
							by = arg.get_string()
						else:
							error('expected id for \\by, got %s' % tag)
							return null
					_:
						error("unknown argument '%s' for \\enter: %s" % [arg.name, tag])
						return null
		_:
			error('expected 1 or 2 arguments for \\enter, got %s' % tag)
			return null
	
	if tag.get_string_at(0) is String:
		sprite_id = tag.get_string_at(0)
	else:
		error('expected sprite id in index 0 of \\enter, got %s' % tag)
		return null
	
	return TEScript.IEnter.new(sprite_id, at, with, by)


# parses \move
func parse_move(tag: Tag):
	var sprite_id: String
	var to: Variant = null
	var with: Variant = null
	
	match tag.length():
		2:
			var args = tag.get_tags_at(1)
			
			if len(args) == 0:
				error('expected args in index 1 of \\move, got %s' % tag)
				return null
			
			for arg in args:
				match arg.name:
					'with':
						if arg.get_string() is String:
							with = arg.get_string()
						else:
							error('expected transition for \\with, got %s' % tag)
							return null
					'to':
						if arg.get_string() is String:
							to = arg.get_string()
						else:
							error('expected location descriptor for \\to, got %s' % tag)
							return null
					_:
						error("unknown argument '%s' for \\move: %s" % [arg.name, tag])
						return null
		_:
			error('expected 2 arguments for \\move, got %s' % tag)
			return null
	
	if tag.get_string_at(0) is String:
		sprite_id = tag.get_string_at(0)
	else:
		error('expected sprite id in index 0 of \\move, got %s' % tag)
		return null
	
	if to == null:
		error('expected \\move to specify \\to, got %s' % tag)
		return null
	
	return TEScript.IMove.new(sprite_id, to, with)


# parses \show
func parse_show(tag: Tag):
	var sprite_id: String
	var _as: Tag
	var with: Variant = null
	
	match tag.length():
		2:
			var args = tag.get_tags_at(1)
			
			if len(args) == 0:
				error('expected args in index 1 of \\show, got %s' % tag)
				return null
			
			for arg in args:
				match arg.name:
					'with':
						if arg.get_string() is String:
							with = arg.get_string()
						else:
							error('expected transition for \\with, got %s' % tag)
							return null
					'as':
						_as = arg
					_:
						error("unknown argument '%s' for \\show: %s" % [arg.name, tag])
						return null
		_:
			error('expected 2 arguments for \\show, got %s' % tag)
			return null
	
	if tag.get_string_at(0) is String:
		sprite_id = tag.get_string_at(0)
	else:
		error('expected sprite id in index 0 of \\show, got %s' % tag)
		return null
	
	if _as == null:
		error('expected \\show to specify \\as, got %s' % tag)
		return null
	
	return TEScript.IShow.new(sprite_id, _as, with)


# parses \exit
func parse_exit(tag: Tag):
	var sprite_id: String
	var with: Variant = null
	
	match tag.length():
		1:
			pass
		2:
			var args = tag.get_tags_at(1)
			
			if len(args) == 0:
				error('expected args in index 1 of \\exit, got %s' % tag)
				return null
			
			for arg in args:
				match arg.name:
					'with':
						if arg.get_string() is String:
							with = arg.get_string()
						else:
							error('expected transition for \\with, got %s' % tag)
							return null
					_:
						error("unknown argument '%s' for \\exit: %s" % [arg.name, tag])
						return null
		_:
			error('expected 1 or 2 arguments for \\exit, got %s' % tag)
			return null
	
	var value0 = tag.get_value_at(0)
	if value0 is String:
		sprite_id = tag.get_string_at(0)
	elif value0 is Tag and value0.length() == 0 and value0.name == 'all':
		sprite_id = ''
	else:
		error('expected sprite id or \\all in index 0 of \\exit, got %s' % tag)
		return null
	
	return TEScript.IExit.new(sprite_id, with)


func to_instructions(tags: Array, script_id: String) -> Array[TEScript.BaseInstruction]:
	var ins: Array[TEScript.BaseInstruction] = []
	
	for index in range(len(tags)):
		var tag = tags[index]
		
		if tag is Tag.ControlTag:
			var string = tag.string
			ins.append(TEScript.IControlExpr.new(string))
			continue
		
		# else is tag
		tag = tag as Tag
		match tag.name:
			'block':
				if tag.length() != 1 or not tag.get_string() is String:
					error('expected block id for \\block, got %s' % tag)
				else:
					ins.append(TEScript.IBlock.new(tag.get_string()))
				
			'pause':
				if tag.length() != 1 or not tag.get_string() is String:
					error('expected transition for \\pause, got %s' % tag)
				else:
					ins.append(TEScript.IPause.new(tag.get_string()))
				
			'hideui':
				if tag.length() != 1 or not tag.get_string() is String:
					error('expected transition for \\hideui, got %s' % tag)
				else:
					ins.append(TEScript.IHideUI.new(tag.get_string()))
				
			'sound':
				if tag.length() != 1 or not tag.get_string() is String:
					error('expected sound id for \\sound, got %s' % tag)
				else:
					ins.append(TEScript.ISound.new(tag.get_string()))
			
			'music':
				var parsed = parse_music(tag)
				if parsed != null:
					ins.append(parsed)
				
			'bg':
				var parsed = parse_bg_or_fg(tag, 'bg')
				if parsed != null:
					ins.append(parsed)
				
			'fg':
				var parsed = parse_bg_or_fg(tag, 'fg')
				if parsed != null:
					ins.append(parsed)
				
			'meta':
				# TODO should maybe validate this or rework it in general
				ins.append(TEScript.IMeta.new(tag.get_dict()))
				
			'break':
				if tag.length() != 0:
					error('expected \\break to have no arguments, got %s' % tag)
				else:
					ins.append(TEScript.IBreak.new())
				
			'enter':
				var parsed = parse_enter(tag)
				if parsed != null:
					ins.append(parsed)
				
			'move':
				var parsed = parse_move(tag)
				if parsed != null:
					ins.append(parsed)
			
			'show':
				var parsed = parse_show(tag)
				if parsed != null:
					ins.append(parsed)
			
			'exit':
				var parsed = parse_exit(tag)
				if parsed != null:
					ins.append(parsed)
			
			'if':
				if tag.length() != 2:
					error('expected \\if to have condition and branch, got %s' % tag)
					return ins
				
				if tag.get_control_at(0) == null:
					error("expected index 0 of \\if to be control tag, got %s" % tag)
					return ins
				
				# generate a script to jump to if the condition is true
				
				# name of the script containing the rest of the instructions
				var rest_name = generate_label(script_id) + '_after_if'
				
				var condition: String = tag.get_control_at(0)
				var branch_tags: Array = tag.get_tags_at(1)
				var branch_name = generate_label(script_id) + '_if'
				var branch_ins: Array[TEScript.BaseInstruction] = to_instructions(branch_tags, branch_name)
				# move on after the branch is over
				branch_ins.append(TEScript.IJmp.new(rest_name))
				
				scripts[branch_name] = TEScript.new(branch_name, branch_ins)
				
				# generate a script for the rest of the instructions
				var rest_tags = tags.slice(index+1)
				var rest_ins: Array[TEScript.BaseInstruction] = to_instructions(rest_tags, rest_name)
				
				scripts[rest_name] = TEScript.new(rest_name, rest_ins)
				
				# the instructions for the current script
				ins.append(TEScript.IJmpIf.new(condition, branch_name))
				ins.append(TEScript.IJmp.new(rest_name))
				
				return ins
			
			'match':
				if tag.length() != 2:
					error('expected \\match to have condition and arms, got %s' % tag)
					return ins
				
				if tag.get_control_at(0) == null:
					error("expected index 0 of \\match to be control tag, got %s" % tag)
					return ins
				
				var expr: String = tag.get_control_at(0)
				# where every branch will jump to
				var rest_name = generate_label(script_id) + '_after_match'
				
				for arm in tag.get_tags_at(1):
					# compile the contents of the branch
					var branch_tags = arm.get_tags_at(len(arm.args)-1)
					var branch_name = generate_label(script_id) + ('_%s' % arm.name)
					var branch_ins: Array[TEScript.BaseInstruction] = to_instructions(branch_tags, branch_name)
					branch_ins.append(TEScript.IJmp.new(rest_name))
					scripts[branch_name] = TEScript.new(branch_name, branch_ins)
					
					if arm.name == 'case':
						if arm.length() != 2:
							error('expected \\case arm of \\match to have condition and body, got %s' % tag)
							return ins
						
						# generate JmpIf for each value given to the case
						for i in range(len(arm.args)-1):
							if arm.get_control_at(i) == null:
								error('expected control tag in index 0 of \\match arm, got %s' % tag)
								return ins
							
							var cond: String = '(%s) == (%s)' % [expr, arm.get_control_at(i)]
							ins.append(TEScript.IJmpIf.new(cond, branch_name))
					elif arm.name == 'default':
						if arm.length() != 1:
							error('expected \\default arm of \\match to have body, got %s' % tag)
							return ins
						
						# generate unconditional jump to the branch
						ins.append(TEScript.IJmp.new(branch_name))
					else:
						error('unknown arm type for \\match, expected case or default: %s' % arm.name)
						return ins
				
				# jump to after branch; will be executed if there is no match and no default arm
				ins.append(TEScript.IJmp.new(rest_name))
				
				# finally, generate branch for the rest of the instructions in the script
				var rest_tags = tags.slice(index+1)
				var rest_ins: Array[TEScript.BaseInstruction] = to_instructions(rest_tags, rest_name)
				scripts[rest_name] = TEScript.new(rest_name, rest_ins)
				return ins
			
			'jmp':
				if tag.get_string() == null:
					error('expected \\jmp to have destination, got %s' % tag)
					continue
				
				var to: String = tag.get_string()
				if ':' in to:
					var parts = to.split(':')
					if len(parts) != 2:
						error("bad \\jmp destination '%s' in %s" % [to, tag])
					else:
						ins.append(TEScript.IJmp.new(parts[1], parts[0]))
				else:
					ins.append(TEScript.IJmp.new(to))
			
			_:
				# interpret as the declaration of a View
				# TODO think about how to implement this properly
				if len(tag.args) == 0:
					ins.append(TEScript.IView.new(tag.name, []))
				else:
					var options: Array[Tag] = []
					for opt in tag.get_tags():
						options.append(opt)
					ins.append(TEScript.IView.new(tag.name, options))
	
	return ins
