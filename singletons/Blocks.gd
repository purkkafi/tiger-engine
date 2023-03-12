class_name Blocks extends Node
# utility class for stringifying Blocks; methods have to exist here because
# of class resolution problems


# resolves this Block into a String, with paragraphs being separated with
# the given separator (two newlines by default)
func resolve_string(block: Block, paragraph_separator: String = '\n\n') -> String:
	var text: String = ''
	
	for part in resolve_parts(block):
		text += part + paragraph_separator
	
	return text.strip_edges(true, true)


# resolves this Block into an array of its parts, separated by Break objects
# in the original taglist
func resolve_parts(block: Block) -> Array[String]:
	return _resolve_parts(block.taglist)


func _resolve_parts(taglist: Array[Variant]) -> Array[String]:
	var parts: Array[String] = []
	parts.append('') # start building the first string
	
	for node in taglist:
		if node is Tag.Break:
			# starts a new String
			parts.push_back('')
		elif node is String:
			# appends to the current String
			parts.push_back(parts.pop_back() + node)
		elif node is Tag.ControlTag:
			# TODO implement handling of ControlTags
			push_error('NYI: cannot stringify control tag: %s' % node)
			parts.push_back(parts.pop_back() + str(node))
		elif node is Tag:
			# basic formatting
			if node.name == 'i':
				parts.push_back(parts.pop_back() + '[i]' + node.args[0][0] + '[/i]')
			elif node.name == 'b':
				parts.push_back(parts.pop_back() + '[b]' + node.args[0][0] + '[/b]')
			elif node.name == 'link':
				parts.push_back(parts.pop_back() + '[url=' + node.args[1][0] + ']' + node.args[0][0] + '[/url]')
			elif node.name in Global.definitions.speakers: # is a speaker declaration?
				# TODO implement arguments, such as using another name
				
				# erase previous empty string, if any
				var prev = parts.pop_back()
				if prev != null and prev != '':
					parts.push_back(prev)
				
				var contents: Array[String] = _resolve_parts(node.args[0])
				for line in contents:
					parts.push_back('[speaker]%s[/speaker]%s' % [node.name, line])
			else: # unknown tag
				Global.log_error('cannot stringify tag: %s' % [node])
				parts.push_back(str(node))
	
	return parts
