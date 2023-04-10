class_name TEScriptCompiler extends RefCounted


var scripts: Dictionary
# number of branches generated for each script; dict of script name -> int
# used by generate_label()
var branch_count: Dictionary


func compile_script(script_tag: Tag):
	var script_id: String = script_tag.get_string_at(0)
	var tags: Array = script_tag.get_tags_at(1)
	
	var ins = to_instructions(tags, script_id)
	scripts[script_id] = TEScript.new(script_id, ins)


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


func to_instructions(tags: Array, script_id: String) -> Array[TEScript.BaseInstruction]:
	var ins: Array[TEScript.BaseInstruction] = []
	
	for index in range(len(tags)):
		var tag = tags[index]
		
		if tag is Tag.ControlTag:
			var string = tag.string
			ins.append(TEScript.IControlExpr.new(string))
			continue
		
		# is Tag
		match tag.name:
			'block':
				ins.append(TEScript.IBlock.new(tag.get_string()))
			'pause':
				ins.append(TEScript.IPause.new(float(tag.get_string().trim_suffix('s'))))
			'hideui':
				ins.append(TEScript.IHideUI.new(tag.get_string()))
			'playsound':
				ins.append(TEScript.IPlaySound.new(tag.get_string()))
			'playsong':
				var value = tag.get_value_at(0)
				if value is String:
					ins.append(TEScript.IPlaySong.new(value, tag.get_string_at(1)))
				elif value is Tag and value.name == 'clear':
					ins.append(TEScript.IPlaySong.new('', tag.get_string_at(1)))
				else:
					push_error('unknown argument for \\playsong: %s' % value)
			'bg':
				ins.append(TEScript.IBG.new(tag.get_string_at(0), tag.get_string_at(1)))
			'fg':
				ins.append(TEScript.IFG.new(tag.get_string_at(0), tag.get_string_at(1)))
			'meta':
				ins.append(TEScript.IMeta.new(tag.get_dict()))
			'break':
				ins.append(TEScript.IBreak.new())
			'enter':
				for command in tag.args:
					var sprite: String = ''
					var at: Variant = null
					var with: Variant = null
					var by: Variant = null
					
					for arg in command:
						if arg is String and sprite == '':
							sprite = arg.strip_edges()
						elif arg is Tag:
							match arg.name:
								'at':
									at = arg.get_string()
								'with':
									with = arg.get_string()
								'by':
									by = arg.get_string()
								_:
									push_error('unknown argument for \\enter: %s' % arg)
					
					ins.append(TEScript.IEnter.new(sprite, at, with, by))
			
			'move':
				for command in tag.args:
					var sprite: String = ''
					var to: String = ''
					var with: Variant = null
					
					for arg in command:
						if arg is String and sprite == '':
							sprite = arg.strip_edges()
						elif arg is Tag:
							match arg.name:
								'to':
									to = arg.get_string()
								'with':
									with = arg.get_string()
								_:
									push_error('unknown argument for \\move: %s' % arg)
					
					if to == '':
						push_error('argument \\to must be provided for \\move: %s' % tag)
					
					ins.append(TEScript.IMove.new(sprite, to, with))
			
			'show':
				for command in tag.args:
					var sprite: String = ''
					var _as: String = ''
					var with: Variant = null
					
					for arg in command:
						if arg is String and sprite == '':
							sprite = arg.strip_edges()
						elif arg is Tag:
							match arg.name:
								'as':
									_as = arg.get_string()
								'with':
									with = arg.get_string()
								_:
									push_error('unknown argument for \\show: %s' % arg)
					
					if _as == '':
						push_error('argument \\as must be provided for \\show: %s' % tag)
					
					ins.append(TEScript.IShow.new(sprite, _as, with))
			
			'exit':
				for command in tag.args:
					var sprite: String = ''
					var with: Variant = null
					
					for arg in command:
						if arg is String and sprite == '':
							sprite = arg.strip_edges()
						elif arg is Tag:
							match arg.name:
								'with':
									with = arg.get_string()
								_:
									push_error('unknown argument for \\exit: %s' % arg)
					
					ins.append(TEScript.IExit.new(sprite, with))
			
			'if':
				# name of the script containing the rest of the instructions
				var rest_name = generate_label(script_id) + '_after_if'
				
				# generate a script to jump to if the condition is true
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
						# generate JmpIf for each value given to the case
						for i in range(len(arm.args)-1):
							var cond: String = '(%s) == (%s)' % [expr, arm.get_control_at(i)]
							ins.append(TEScript.IJmpIf.new(cond, branch_name))
					elif arm.name == 'default':
						# generate unconditional jump to the branch
						ins.append(TEScript.IJmp.new(branch_name))
					else:
						push_error('unknown arm for match: %s' % arm.name)
				
				# jump to after branch; will be executed if there is no match and no default arm
				ins.append(TEScript.IJmp.new(rest_name))
				
				# finally, generate branch for the rest of the instructions in the script
				var rest_tags = tags.slice(index+1)
				var rest_ins: Array[TEScript.BaseInstruction] = to_instructions(rest_tags, rest_name)
				scripts[rest_name] = TEScript.new(rest_name, rest_ins)
				return ins
			
			_:
				# interpret as the declaration of a View
				if len(tag.args) == 0:
					ins.append(TEScript.IView.new(tag.name, []))
				else:
					var options: Array[Tag] = []
					for opt in tag.get_tags():
						options.append(opt)
					ins.append(TEScript.IView.new(tag.name, options))
	
	return ins
