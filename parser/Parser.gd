class_name Parser extends RefCounted


var index: int = 0
var tokens: Array[Lexer.Token] = []
var tree: Array[Variant]
var BREAK: Tag.Break = Tag.Break.new()
# will contain error message in case of parsing error
var error_message: String = ''


# parses the given tokens
# returns a list of strings and Tags, if successfull, null otherwise
# in case of failure, error_message contains the error message
func parse(_tokens: Array[Lexer.Token]):
	self.error_message = ''
	self.tokens = _tokens
	tree = []
	index = 0
	
	# consume tokens as long as there are more to parse & do transformations on them
	while index < len(self.tokens):
		var value = _parse_value()
		if value == null:
			return null
		tree.append(value)
	
	return _fix_tree(tree)


# applies transformations on a list of nodes, fixing whitespace & breaks
func _fix_tree(nodes: Array[Variant]) -> Array[Variant]:
	var new_nodes = []
	var last = null
	var _index: int = 0 # named this to avoid shadowing the member variable
	
	while _index < len(nodes):
		var value = nodes[_index]
		
		if value is String:
			# trim strings after Break or at start of file
			if last == null or last is Tag.Break:
				value = value.strip_edges(true, false)
				if len(value) == 0:
					_index += 1
					continue
			
			# trim strings at end of file
			if _index == len(nodes)-1:
				value = value.strip_edges(false, true)
		
		if value is Tag.Break:
			# don't repeat breaks
			if last == null or last is Tag.Break:
				_index += 1
				continue
			
			# trim strings before Break
			if last is String:
				last = last.strip_edges(false, true)
				new_nodes.remove_at(len(new_nodes)-1)
				new_nodes.append(last)
			
			# no break at the end
			if _index == len(nodes)-1:
				_index += 1
				continue
		
		new_nodes.append(value)
		last = new_nodes[len(new_nodes)-1]
		_index += 1
	
	return new_nodes


func _parse_value():
	match tokens[index].type:
		Lexer.TokenType.TAG:
			return _parse_tag()
		Lexer.TokenType.STRING:
			var string = tokens[index].value
			index += 1
			return string
		Lexer.TokenType.NEWLINE:
			index += 1
			return BREAK
		Lexer.TokenType.RAW_STRING:
			return _parse_control_tag()
		_:
			error_message = 'syntax error: expected value, got %s at %s' % [str(tokens[index]), tokens[index].where()]
			return null


func _is_tag_argument_start(token_type: Lexer.TokenType):
	return token_type == Lexer.TokenType.BRACE_OPEN or token_type == Lexer.TokenType.RAW_STRING


func _parse_tag():
	var name = tokens[index].value
	var args = []
	index += 1
	
	if index >= len(tokens):
		return Tag.new(name, args)
	
	while index < len(tokens) and _is_tag_argument_start(tokens[index].type):
		match tokens[index].type:
			Lexer.TokenType.RAW_STRING:
				args.append([ _parse_control_tag() ])
			Lexer.TokenType.BRACE_OPEN:
				index += 1
				
				var arg = []
				
				if not index < len(tokens):
					error_message = 'syntax error: expected } or value, got <eof> at %s' % [tokens[index-1].where()]
					return null
				
				while tokens[index].type != Lexer.TokenType.BRACE_CLOSE:
					var value = _parse_value()
					if value == null:
						return null
					
					arg.append(value)
					
					if not index < len(tokens):
						error_message = 'syntax error: expected } or value, got <eof> at %s' % [tokens[index-1].where()]
						return null
				
				args.append(_fix_tree(arg))
				index += 1
	
	return Tag.new(name, args)


func _parse_control_tag():
	var tag: Tag.ControlTag = Tag.ControlTag.new(tokens[index].value)
	index += 1
	return tag
