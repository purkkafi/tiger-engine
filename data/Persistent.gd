class_name Persistent extends RefCounted
# data that persists across save files


# dict of unlockable ids to bools representing whether they are unlocked or not
# normally, only true values are present; the file may be edited manually to
# contain false values, in which case the unlockable is counted as not unlocked
# and cannot be unlocked with unlock()
# do not access directly, use unlock()
var _unlocked: Dictionary = {}
# absolute file paths of previously loaded mods
var mods: Array[String] = []
# game-specific data
var custom: Dictionary = {}


# path of file to store
const PERSISTENT_PATH = 'user://persistent.json'


# unlocks the given unlockable, sends a toast, and saves persistent.json to the disk
# does nothing if it was already present
func unlock(unlockable_id: String, no_toasts: bool = false):
	if not unlockable_id in TE.defs.unlockables:
		TE.log_error(TE.Error.ENGINE_ERROR, 'unknown unlockable: %s' % unlockable_id)
		return
	
	if not unlockable_id in _unlocked:
		_unlock_recursively(unlockable_id)
		TE.log_info('unlocked %s' % unlockable_id)
		
		if ':' in unlockable_id:
			var parts = unlockable_id.split(':', false, 2)
			var _namespace: String = parts[0]
			var id: String = parts[1]
			
			TE.emit_signal('unlockable_unlocked', _namespace, id)
			
			if _namespace in TE.opts.notify_on_unlock and not no_toasts:
				var noun: String = TE.localize['toast_unlocked_' + _namespace]
				var toast_title: String = TE.localize.toast_unlocked.replace('[]', noun)
				var toast_description: String = TE.localize['%s_%s' % [_namespace, id]]
				
				TE.send_toast_notification(toast_title, toast_description)
		else:
			TE.log_error(TE.Error.ENGINE_ERROR, 'unlockable not namespaced: %s' % unlockable_id)
		
		save_to_file()


# internally unlocks given unlockable & others depending on it
func _unlock_recursively(unlockable_id: String):
	_unlocked[unlockable_id] = true
	
	if unlockable_id in TE.defs.automatically_unlocks:
		for dependent in TE.defs.automatically_unlocks[unlockable_id]:
			if not dependent in _unlocked:
				_unlock_recursively(dependent)


# returns whether the given unlockable is unlocked
func is_unlocked(unlockable_id: String) -> bool:
	if not unlockable_id in TE.defs.unlockables:
		TE.log_error(TE.Error.ENGINE_ERROR, 'unknown unlockable: %s' % unlockable_id)
		return false
	return unlockable_id in _unlocked and _unlocked[unlockable_id]


# loads the Persistent instance from disk or, if absent, returns an empty one
static func load_from_file() -> Persistent:
	var file: FileAccess = FileAccess.open(PERSISTENT_PATH, FileAccess.READ)
	
	if file == null:
		return Persistent.new()
	
	var json: JSON = JSON.new()
	if json.parse(file.get_as_text()) != OK:
		TE.log_warning('persistent file cannot be parsed')
		return Persistent.new()
	
	var instance: Persistent = Persistent.new()
	
	# all fields optional
	if '_unlocked' in json.data:
		instance._unlocked = json.data['_unlocked']
	if 'custom' in json.data:
		instance.custom = json.data['custom']
	if 'mods' in json.data:
		instance.mods.append_array(json.data['mods'])
	
	return instance


# writes to the file
func save_to_file() -> void:
	var file: FileAccess = FileAccess.open(PERSISTENT_PATH, FileAccess.WRITE)
	
	if file == null:
		TE.log_error(TE.Error.ENGINE_ERROR, 'cannot write persistent.json: %d' % file.get_error())
		return
	
	file.store_line(JSON.stringify({
		'_unlocked': _unlocked,
		'mods': mods,
		'custom': custom
	}, '  '))
