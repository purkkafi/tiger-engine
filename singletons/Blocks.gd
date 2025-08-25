class_name Blocks extends Object
# utility class for stringifying Blocks; methods have to exist here because
# of class resolution problems


# meaningless string to mark a used argument to a custom text style
const USED_ARGUMENT_MARKER: String = '!!!<<[USED_ARGUMENT_MARKER]>>!!!'


# a null object representing an empty block
static var EMPTY_BLOCK = Block.new([])


# initializes properties of EMPTY_BLOCK
static func _static_init() -> void:
	EMPTY_BLOCK.id = ''
	EMPTY_BLOCK.blockfile_path = ''


# looks up a Block object by its id, a String of form "<blockfile_id>:<block_id>"
# for instance, given "a:b", the block b in the blockfile a.tef is returned
# EMPTY_BLOCK is returned if the Block cannot be found
# if queue_only is true, the blockfile is queued for loading and null is returned
static func find(id: String, queue_only = false) -> Variant:
	var parts = id.split(':')
	if len(parts) != 2:
		TE.log_error(TE.Error.FILE_ERROR, 'block id should be of form <file>:<block>, got %s' % id)
	
	var blockfile_id: String = parts[0]
	var block_id: String = parts[1]
	
	if queue_only:
		Assets.blockfiles.queue('lang:text/' + blockfile_id + '.tef')
		return null
	
	var blockfile: BlockFile = Assets.blockfiles.get_unqueued('lang:text/' + blockfile_id + '.tef')
	
	if blockfile != null and block_id in blockfile.blocks:
		return blockfile.blocks[block_id]
	else:
		TE.log_error(TE.Error.FILE_ERROR, "block '%s' not found in '%s'" % [block_id, blockfile_id], true)
		return EMPTY_BLOCK


# resolves this Block into a String, with paragraphs being separated with
# the given separator (two newlines by default)
static func resolve_string(block: Block, paragraph_separator: String = '\n\n', ctxt: ControlExpr.BaseContext=null) -> String:
	var text: String = ''
	
	for part in resolve_parts(block, ctxt):
		text += part + paragraph_separator
	
	return text.strip_edges(true, true)


# resolves a Block into an array of its parts, which are separated by Break objects
# in the original taglist
# a context from which variables are resolved can optionally be provided
static func resolve_parts(block: Block, ctxt: ControlExpr.BaseContext=null) -> Array[String]:
	return _resolve_parts(block.taglist, ctxt)


static func _resolve_parts(taglist: Array[Variant], ctxt: ControlExpr.BaseContext=null) -> Array[String]:
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
			var result = ControlExpr.exec(node.string, ctxt)
			parts.push_back(parts.pop_back() + str(result))
		elif node is Tag:
			# basic formatting
			if node.name == 'i':
				parts.push_back(parts.pop_back() + '[i]' + node.get_string() + '[/i]')
			elif node.name == 'b':
				parts.push_back(parts.pop_back() + '[b]' + node.get_string() + '[/b]')
			elif node.name == 'quote':
				parts.push_back(parts.pop_back() + Localize.autoquote(node.get_string()))
			elif node.name == 'link':
				parts.push_back(parts.pop_back() + '[url=' + node.get_string_at(1) + ']' + node.get_string_at(0) + '[/url]')
			elif node.name == 'erase':
				var string: String = node.get_string()
				parts.push_back(parts.pop_back() + string + View.DEL.repeat(len(string)))
			elif node.name == 'include':
				var blockfile: BlockFile = Assets.blockfiles.get_unqueued(node.get_string_at(0))
				var included: String = Blocks.resolve_string(blockfile.blocks[node.get_string_at(1)])
				parts.push_back(parts.pop_back() + included)
			
			# escape characters
			elif node.name == 'n' and len(node.args) == 0:
				parts.push_back(parts.pop_back() + '\n')
			
			# full image image declaration
			elif node.name == 'fullimg':
				var id: String = (node.args[0][0] as String).strip_edges()
				var width: float = 1.0
				for opt in node.get_tags():
					match opt.name:
						'width':
							width = float(opt.get_string())
						_:
							TE.log_error(TE.Error.FILE_ERROR, 'unknown argument for fullimg: %s' % opt.name)
				parts.push_back(parts.pop_back() + '[fullimg][id]%s[/id][width]%s[/width][/fullimg]' % [id, width])
			
			# is user-defined special formatting
			elif node.name in TE.defs.text_styles:
				var args: Array[String] = node.get_strings() as Array[String]
				var formatting: Array = TE.defs.text_styles[node.name]
				
				for part in formatting:
					if part is String:
						parts.push_back(parts.pop_back() + part)
					else:
						var tag: Tag = part as Tag
						var index: int = tag.name.to_int()
						
						if index > len(args):
							TE.log_error(TE.Error.FILE_ERROR,
								"text style format error: not enough arguments: %s" % [node])
							parts.push_back(parts.pop_back() + '\\' + tag.name)
						else:
							parts.push_back(parts.pop_back() + args[index-1])
							args[index-1] = USED_ARGUMENT_MARKER
				
				for i in range(len(args)):
					var arg: String = args[i]
					if arg != USED_ARGUMENT_MARKER:
						TE.log_error(TE.Error.FILE_ERROR,
							"text stype format error: argument %d left unused: %s" % [i+1, node])
			
			elif node.name in TE.defs.speakers: # is a speaker declaration?
				
				# erase previous empty string, if any
				var prev = parts.pop_back()
				if prev != null and prev != '':
					parts.push_back(prev)
				
				# parse arguments
				var _as: String = ''
				
				if node.has_index(1):
					var args: Dictionary = node.get_dict_at(1)
					for arg in args.keys():
						match arg:
							'as':
								var as_value = args[arg].get_value()
								if as_value is String:
									_as = '[as_name]%s[/as_name]' % as_value
								else:
									_as = '[as_ctrltag]%s[/as_ctrltag]' % (as_value as Tag.ControlTag).string
							_:
								TE.log_error(TE.Error.FILE_ERROR, 'unknown argument for speaker use: %s' % arg)
				
				var contents: Array[String] = _resolve_parts(node.args[0], ctxt)
				for line in contents:
					parts.push_back('[speaker]%s%s[/speaker] %s' % [node.name, _as, line])
			elif ctxt != null: # try resolving from context
				var value = ctxt._get_var(node.name)
				if value != null:
					parts.push_back(parts.pop_back() + str(value))
			else: # unknown tag
				TE.log_error(TE.Error.FILE_ERROR, 'cannot stringify tag: %s' % [node])
				parts.push_back(str(node))
	
	return parts
