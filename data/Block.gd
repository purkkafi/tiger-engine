class_name Block extends RefCounted
# represents a taglist (see Tag) that can be turned into a textual form
# see the TEBlocks singleton for useful operations


var taglist: Array[Variant]
var blockfile_path: String # the blockfile this Block is from
var id: String # the id of this Block in its blockfile


func _init(_taglist: Array[Variant]):
	self.taglist = _taglist


# calculates the hash code of this block
func resolve_hash() -> String:
	var ctxt: HashingContext = HashingContext.new()
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
