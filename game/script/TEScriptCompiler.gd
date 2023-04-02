class_name TEScriptCompiler extends RefCounted


var scripts: Dictionary


func compile_script(script_tag: Tag):
	var script_id: String = script_tag.get_string_at(0)
	var tags: Array = script_tag.get_tags_at(1)
	var ins: Array = []
	
	for tag in tags:
		if tag is Tag.ControlTag:
			push_error('TEScriptCompiler: control tags NYI')
			continue
		
		# is Tag
		match tag.name:
			'block':
				ins.append(TEScript.IBlock.new(tag.get_string_at(0), tag.get_string_at(1)))
			'nvl':
				if len(tag.args) == 0:
					ins.append(TEScript.INvl.new(null))
				else:
					ins.append(TEScript.INvl.new(tag.get_tags()))
			'adv':
				ins.append(TEScript.IAdv.new())
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
			
			_:
				push_error('unknown instruction: %s' % [tag])
	
	scripts[script_id] = TEScript.new(script_id, ins)
