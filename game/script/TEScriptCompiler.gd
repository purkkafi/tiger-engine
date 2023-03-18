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
				ins.append(TEScript.IPlaySong.new(tag.get_string_at(0), tag.get_string_at(1)))
			'bg':
				ins.append(TEScript.IBG.new(tag.get_string_at(0), tag.get_string_at(1)))
			'fg':
				ins.append(TEScript.IFG.new(tag.get_string_at(0), tag.get_string_at(1)))
			'meta':
				ins.append(TEScript.IMeta.new(tag.get_dict()))
			'break':
				ins.append(TEScript.IBreak.new())
			_:
				push_error('unknown instruction: %s' % [tag])
	
	scripts[script_id] = TEScript.new(script_id, ins)
