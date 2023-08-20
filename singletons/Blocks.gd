extends Node
# utility class for stringifying Blocks; methods have to exist here because
# of class resolution problems


# a null object representing an empty block
static var EMPTY_BLOCK = Block.new([])


# initializes properties of EMPTY_BLOCK
func _ready():
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
	
	var blockfile: BlockFile = Assets.blockfiles.get_resource('lang:text/' + blockfile_id + '.tef')
	
	if blockfile != null and block_id in blockfile.blocks:
		return blockfile.blocks[block_id]
	else:
		TE.log_error(TE.Error.FILE_ERROR, "block '%s' not found in '%s'" % [block_id, blockfile_id], true)
		return EMPTY_BLOCK


# resolves this Block into a String, with paragraphs being separated with
# the given separator (two newlines by default)
func resolve_string(block: Block, paragraph_separator: String = '\n\n', ctxt: ControlExpr.BaseContext=null) -> String:
	var text: String = ''
	
	for part in resolve_parts(block, ctxt):
		text += part + paragraph_separator
	
	return text.strip_edges(true, true)


# resolves a Block into an array of its parts, which are separated by Break objects
# in the original taglist
# a context from which variables are resolved can optionally be provided
func resolve_parts(block: Block, ctxt: ControlExpr.BaseContext=null) -> Array[String]:
	return _resolve_parts(block.taglist, ctxt)


func _resolve_parts(taglist: Array[Variant], ctxt: ControlExpr.BaseContext=null) -> Array[String]:
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
			elif node.name == 'link':
				parts.push_back(parts.pop_back() + '[url=' + node.get_string_at(1) + ']' + node.get_string_at(0) + '[/url]')
			elif node.name == 'erase':
				var string: String = node.get_string()
				parts.push_back(parts.pop_back() + string + View.DEL.repeat(len(string)))
			elif node.name == 'include':
				var blockfile: BlockFile = Assets.blockfiles.get_unqueued(node.get_string_at(0))
				var included: String = Blocks.resolve_string(blockfile.blocks[node.get_string_at(1)])
				parts.push_back(parts.pop_back() + included)
				
			elif node.name in TE.defs.speakers: # is a speaker declaration?
				# TODO implement arguments, such as using another name
				
				# erase previous empty string, if any
				var prev = parts.pop_back()
				if prev != null and prev != '':
					parts.push_back(prev)
				
				var contents: Array[String] = _resolve_parts(node.args[0], ctxt)
				for line in contents:
					parts.push_back('[speaker]%s[/speaker]%s' % [node.name, line])
			elif ctxt != null: # try resolving from context
				var value = ctxt._get_var(node.name)
				if value != null:
					parts.push_back(parts.pop_back() + str(value))
			else: # unknown tag
				TE.log_error(TE.Error.FILE_ERROR, 'cannot stringify tag: %s' % [node])
				parts.push_back(str(node))
	
	return parts
