extends Node
# used for caching resources and queuing them to be loaded in the background
# contains specific Cache instances for different resources


var songs: Cache = Cache.new(3)
var sounds: Cache = Cache.new(5)
var bgs: Cache = Cache.new(5)
var blockfiles: Cache = Cache.new(10)
var scripts: Cache = Cache.new(10)

# for misc resources that don't have to be cached
var noncached: Cache = Cache.new(0)
# for resources that are cached permanently
# should only be used for small or frequently accessed resources
var permanent: Cache = Cache.new(99999)


static func localize_path(path):
	var try_path: String = Global.language.path + path
	
	if ResourceLoader.exists(try_path):
		return try_path
	
	return FAILED


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
	var size: int # size of this cache
	# cache of entries; larger indices are newer
	var cache: Array[Entry]
	
	
	func _init(_size: int):
		self.size = _size
	
	
	func _to_string():
		return str(cache)
	
	
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
		
		print('[Assets] queued %s' % path)
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
				print('[Assets] get cached: %s' % path)
				return entry.resource
		
		# resource was not queued, load and add to cache
		if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
			print('[Assets] get not queued %s ' % path)
			var resource = ResourceLoader.load(path)
			var entry = Entry.new(path)
			entry.resource = resource
			_add_to_cache(entry)
			return resource
		else: # queued or already loaded, get it now anyway
			if ResourceLoader.load_threaded_get_status(path) == ResourceLoader.THREAD_LOAD_LOADED:
				print('[Assets] get loaded: %s' % path)
			else:
				print('[Assets] get loading in progress: %s' % path)
			var resource = ResourceLoader.load_threaded_get(path)
			var entry = Entry.new(path)
			entry.resource = resource
			_add_to_cache(entry)
			return resource
	
	func _debug_message() -> String:
		var msg: String = ''
		for entry in cache:
			msg += '  ' + entry.path + ': ' + entry.get_class()
		return msg
