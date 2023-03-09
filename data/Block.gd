class_name Block extends RefCounted
# represents a taglist (see Tag) that can be turned into a textual form


var taglist: Array[Variant]


func _init(_taglist: Array[Variant]):
	self.taglist = _taglist


# resolves this Block into a String, with paragraphs being separated with
# the given separator (two newlines by default)
func resolve_string(paragraph_separator: String = '\n\n') -> String:
	var text: String = ''
	
	for part in resolve_parts():
		text += part + paragraph_separator
	
	return text.strip_edges(true, true)


# resolves this Block into an array of its parts, separated by Break objects
# in the original taglist
# basic formatting tags (\b, \i, and \link) are supported
# implementation of other tags & control tags is in progress
func resolve_parts() -> Array[String]:
	var parts: Array[String] = []
	parts.push_back('')
	
	for node in taglist:
		if node is Tag.Break:
			# starts a new String
			parts.push_back('')
		elif node is String:
			# appends to the current String
			parts.push_back(parts.pop_back() + node)
		elif node is Tag.ControlTag:
			# TODO implement handling of ControlTags
			push_error('cannot stringify control tag: %s' % node)
			parts.push_back(parts.pop_back() + str(node))
		elif node is Tag:
			# basic formatting
			if node.name == 'i':
				parts.push_back(parts.pop_back() + '[i]' + node.args[0][0] + '[/i]')
			elif node.name == 'b':
				parts.push_back(parts.pop_back() + '[b]' + node.args[0][0] + '[/b]')
			elif node.name == 'link':
				parts.push_back(parts.pop_back() + '[url=' + node.args[1][0] + ']' + node.args[0][0] + '[/url]')
			else:
				# TODO implement handling of custom tags
				push_error('cannot stringify tag: %s' % node)
				parts.push_back(parts.pop_back() + str(node))
	
	return parts


# calculates the hash code of this block
func resolve_hash() -> String:
	var ctxt = HashingContext.new()
	ctxt.start(HashingContext.HASH_MD5)
	Block._hash_taglist(taglist, ctxt)
	
	return ctxt.finish().hex_encode()


# hashes a taglist recursively, updating the given Context
static func _hash_taglist(_taglist: Array[Variant], ctxt: HashingContext):
	for node in _taglist:
		if node is String:
			ctxt.update(node.md5_buffer())
		elif node is Tag.Break:
			ctxt.update('\n\n'.md5_buffer())
		elif node is Tag.ControlTag:
			ctxt.update(node.string.md5_buffer())
		else: # node is Tag
			ctxt.update(node.name.md5_buffer())
			for arg in node.args:
				_hash_taglist(arg, ctxt)
