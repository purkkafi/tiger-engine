extends Node
# used for caching resources and queuing them to be loaded in the background
# contains specific Cache instances for different resources


var songs: Cache = Cache.new('songs', 3)
var sounds: Cache = Cache.new('sounds', 5)
var bgs: Cache = Cache.new('bgs', 5)
var blockfiles: Cache = Cache.new('blockfiles', 20)
var scripts: Cache = Cache.new('scripts', 20)
# for misc resources that don't have to be cached
var noncached: Cache = Cache.new('noncached', 0)
# for resources that are cached permanently
# should only be used for small or frequently accessed resources
var permanent: Cache = Cache.new('permanent', 99999)


func _ready():
	blockfiles.hash_function = Callable(self, '_blockfile_hash')


static func in_lang(path: String) -> String:
	return 'res://assets/lang/' + TE.language.id + path


# calculates the hash of every Block in the given BlockFile
func _blockfile_hash(blockfile: BlockFile) -> Dictionary:
	var hashes: Dictionary = {}
	for block_id in blockfile.blocks.keys():
		var hashcode: String = blockfile.blocks[block_id].resolve_hash()
		hashes[block_id] = hashcode
	return hashes


func _debug_message() -> String:
	var msg: String = ''
	msg += 'Songs:\n' + songs._debug_message() + '\n'
	msg += 'Sounds:\n' + sounds._debug_message() + '\n'
	msg += 'Bgs:\n' + bgs._debug_message() + '\n'
	msg += 'Blockfiles:\n' + blockfiles._debug_message() + '\n'
	msg += 'Scripts:\n' + scripts._debug_message() + '\n'
	msg += 'Permanent:\n' + permanent._debug_message() + '\n'
	return msg


# an entry in a Cache, identified by the path to its resource
# holds a reference to its resource or null if queued or not accessed yet
class Entry:
	var path: String
	var resource = null
	
	
	func _init(_path: String):
		self.path = _path
	
	
	func _to_string() -> String:
		return '[%s: %s]' % [path, '<not in cache>' if resource == null else resource.get_class()]


class Cache:
	var id: String # identifier of this cache
	var size: int # size of this cache
	# cache of entries; larger indices are newer
	var cache: Array[Entry]
	# function that is used to calculate the hashes of loaded
	# Resources (current and previous) if set
	var hash_function = null
	# Dictionary of Resource paths to calculated hashes
	# they may be Strings or more complex objects containing the sub-hashes
	# of the constituent parts of the object
	var hashes: Dictionary
	
	
	func _init(_id, _size: int):
		self.id = _id
		self.size = _size
	
	
	func _to_string():
		return str(cache)
	
	
	# caches the hash of the given Resource if hash_function is set
	func _set_hash(resource: Resource):
		if hash_function == null:
			return
		TE.log_info('[Assets/%s] calculated hash of: %s' % [id, resource.resource_path])
		hashes[resource.resource_path] = hash_function.call(resource)
	
	
	# adds entry to cache, moving it to the front if it already is there
	func _add_to_cache(new_entry: Entry):
		if size == 0:
			return
		
		var i: int = 0
		while i < len(cache):
			# resource is already in cache, move to front
			var entry = cache[i]
			if entry.path == new_entry.path:
				cache.remove_at(i)
				# remember the entry that holds a reference to the resource, if any
				if entry.resource == null:
					cache.append(new_entry)
				else:
					cache.append(entry)
				return
			i += 1
		
		# resource not in cache
		cache.append(new_entry)
		# remove oldest entry if too large
		if len(cache) > size:
			cache.pop_front()
	
	
	# queues a resource for loading in the background and adds it to
	# the front of the cache
	func queue(path: String):
		# don't queue if already in cache/queued
		for entry in cache:
			if entry.path == path:
				return
		
		TE.log_info('[Assets/%s] queued: %s' % [id, path])
		var err = ResourceLoader.load_threaded_request(path)
		_add_to_cache(Entry.new(path))
		return err
	
	
	# gets the given resource. it may be:
	# – returned from the cache, if in there
	# – loaded now and added to the cache
	# if a resource hasn't been queued with queue() or if loading is in progress, the method blocks
	func get_resource(path: String):
		for entry in cache:
			if entry.path == path and entry.resource != null:
				TE.log_info('[Assets/%s] get cached: %s' % [id, path])
				return entry.resource
		
		# resource was not queued, load and add to cache
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			TE.log_info('[Assets/%s] get not queued: %s ' % [id, path])
			var resource = ResourceLoader.load(path)
			var entry = Entry.new(path)
			entry.resource = resource
			_add_to_cache(entry)
			_set_hash(entry.resource)
			return resource
		else: # queued or already loaded, get it now anyway
			if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
				TE.log_info('[Assets/%s] get loaded: %s' % [id, path])
			else:
				TE.log_info('[Assets/%s] get loading in progress: %s' % [id, path])
			var resource = ResourceLoader.load_threaded_get(path)
			var entry = Entry.new(path)
			entry.resource = resource
			_add_to_cache(entry)
			_set_hash(entry.resource)
			return resource
	
	
	func _debug_message() -> String:
		var msg: String = ''
		for entry in cache:
			msg += '  ' + entry.path + ': ' + entry.get_class()
			if entry.path in hashes:
				msg += ' (hash calculated)'
			msg += '\n'
		return msg
