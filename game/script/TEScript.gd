class_name TEScript extends RefCounted
var name: String # name of this script
var instructions: Array[Variant] # Array of instruction objects


func _init(_name: String, _instructions: Array):
	name = _name
	instructions = _instructions


func _to_string() -> String:
	return 'VTScript(%s)' % [name]


# calculates hash code for the script
# uses the string representation of each instruction object
func hashcode() -> String:
	var ctxt = HashingContext.new()
	ctxt.start(HashingContext.HASH_MD5)
	
	# warning-ignore:return_value_discarded
	ctxt.update(name.md5_buffer())
	
	for ins in instructions:
		ctxt.update(str(ins).md5_buffer())
	
	return ctxt.finish().hex_encode()


class IBlock extends RefCounted:
	const name: String = 'Block'
	var blockfile_id: String
	var block_id: String
	
	
	func _init(_blockfile_id: String, _block_id: String):
		self.blockfile_id = _blockfile_id
		self.block_id = _block_id
	
	
	func _to_string() -> String:
		return 'block %s, %s' % [blockfile_id, block_id]


class INvl extends RefCounted:
	const name: String = 'Nvl'
	var options: Dictionary = {}
	
	
	func _init(opts: Variant):
		if opts == null:
			return
		for opt in opts:
			match opt.name:
				'hcenter':
					options['hcenter'] = true
				'vcenter':
					options['vcenter'] = true
				'outline':
					options['outline'] = [ opt.get_string_at(0), opt.get_string_at(1) ]
	
	
	func _to_string() -> String:
		return 'nvl %s' % options


class IAdv extends RefCounted:
	const name: String = 'Adv'
	func _to_string() -> String:
		return 'adv'


class IPause extends RefCounted:
	const name: String = 'Pause'
	var duration: float
	
	
	func _init(_duration: float):
		self.duration = _duration
	
	
	func _to_string() -> String:
		return 'pause %f' % [duration]


class IHideUI extends RefCounted:
	const name: String = 'HideUI'
	var transition_id: String
	
	
	func _init(_transition_id: String):
		self.transition_id = _transition_id
	
	
	func _to_string() -> String:
		return 'hideui %s' % [transition_id]


class IPlaySound extends RefCounted:
	const name: String = 'PlaySound'
	var sound_id: String
	
	
	func _init(_sound_id: String):
		self.sound_id = _sound_id
	
	
	func _to_string() -> String:
		return 'playsound %s' % [sound_id]


class IPlaySong extends RefCounted:
	const name: String = 'PlaySong'
	var song_id: String
	var transition_id: String
	
	
	func _init(_song_id: String, _transition_id: String):
		self.song_id = _song_id
		self.transition_id = _transition_id
	
	
	func _to_string() -> String:
		return 'playsong %s, %s' % [song_id, transition_id]


class IBG extends RefCounted:
	const name: String = 'BG'
	var bg_id: String
	var transition_id: String
	
	
	func _init(_bg_id: String, _transition_id: String):
		self.bg_id = _bg_id
		self.transition_id = _transition_id
	
	
	func _to_string() -> String:
		return 'bg %s, %s' % [bg_id, transition_id]


class IFG extends RefCounted:
	const name: String = 'FG'
	var fg_id: String
	var transition_id: String
	
	
	func _init(_fg_id: String, _transition_id: String):
		if _fg_id == 'clear':
			self.fg_id = ''
		else:
			self.fg_id = _fg_id
		self.transition_id = _transition_id
	
	
	func _to_string() -> String:
		return 'fg %s, %s' % [fg_id, transition_id]


class IMeta extends RefCounted:
	const name: String = 'Meta'
	var game_name_uistring: String
	
	
	func _init(meta: Dictionary):
		for key in meta.keys():
			match key:
				'game_name':
					game_name_uistring = meta[key].get_string()
				_:
					push_error('unknown meta field: %s' % key)
	
	
	func _to_string() -> String:
		return 'meta %s' % [game_name_uistring]


class IBreak extends RefCounted:
	const name: String = 'Break'
	func _to_string() -> String:
		return 'break'
