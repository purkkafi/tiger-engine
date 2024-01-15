class_name Persistent extends RefCounted
# data that persists across save files


# dict of unlockable ids to bools representing whether they are unlocked or not
# normally, only true values are present; the file may be edited manually to
# contain false values, in which case the unlockable is counted as not unlocked
# and cannot be unlocked with unlock()
# do not access directly, use unlock()
var _unlocked: Dictionary = {}
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
		_unlocked[unlockable_id] = true
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
	instance._unlocked = json.data['_unlocked']
	instance.custom = json.data['custom']
	return instance


# writes to the file
func save_to_file() -> void:
	var file: FileAccess = FileAccess.open(PERSISTENT_PATH, FileAccess.WRITE)
	
	if file == null:
		TE.log_error(TE.Error.ENGINE_ERROR, 'cannot write persistent.json: %d' % file.get_error())
		return
	
	file.store_line(JSON.stringify({
		'_unlocked': _unlocked,
		'custom': custom
	}, '  '))
