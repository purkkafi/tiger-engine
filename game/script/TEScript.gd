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


class BaseInstruction extends RefCounted:
	
	
	# returns a string id that is used to determine if the same instruction
	# is already being handled
	# can be overridden to allow instructions to be repeated based on their args
	# an empty return value is ignored (the instruction can be repeated freely)
	func repeat_id() -> String:
		return self.name


class IBlock extends BaseInstruction:
	const name: String = 'Block'
	var block_id: String
	
	
	func _init(_block_id: String):
		self.block_id = _block_id
	
	
	func _to_string() -> String:
		return 'block %s' % [block_id]


class IView extends BaseInstruction:
	const name: String = 'View'
	var view_id: String
	var options: Array[Tag]
	
	
	func _init(_view_id: String, _options: Array[Tag]):
		self.view_id = _view_id
		self.options = _options
	
	
	func _to_string() -> String:
		return 'view %s %s' % [view_id, options]


class IPause extends BaseInstruction:
	const name: String = 'Pause'
	var duration: float
	
	
	func _init(_duration: float):
		self.duration = _duration
	
	
	func _to_string() -> String:
		return 'pause %f' % [duration]


class IHideUI extends BaseInstruction:
	const name: String = 'HideUI'
	var transition_id: String
	
	
	func _init(_transition_id: String):
		self.transition_id = _transition_id
	
	
	func _to_string() -> String:
		return 'hideui %s' % [transition_id]


class IPlaySound extends BaseInstruction:
	const name: String = 'PlaySound'
	var sound_id: String
	
	
	func _init(_sound_id: String):
		self.sound_id = _sound_id
	
	
	func _to_string() -> String:
		return 'playsound %s' % [sound_id]


class IPlaySong extends BaseInstruction:
	const name: String = 'PlaySong'
	var song_id: String
	var transition_id: String
	var local_volume: float
	
	
	func _init(_song_id: String, _transition_id: String, _local_volume):
		self.song_id = _song_id
		self.transition_id = _transition_id
		self.local_volume = _local_volume
	
	
	func _to_string() -> String:
		return 'playsong %s, %s, %s' % [song_id, transition_id, local_volume]


class IBG extends BaseInstruction:
	const name: String = 'BG'
	var bg_id: String
	var transition_id: String
	
	
	func _init(_bg_id: String, _transition_id: String):
		self.bg_id = _bg_id
		self.transition_id = _transition_id
	
	
	func _to_string() -> String:
		return 'bg %s, %s' % [bg_id, transition_id]


class IFG extends BaseInstruction:
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


class IMeta extends BaseInstruction:
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


class IBreak extends BaseInstruction:
	const name: String = 'Break'
	func _to_string() -> String:
		return 'break'


class IEnter extends BaseInstruction:
	const name: String = 'Enter'
	var sprite: String
	var at: Variant # null or a sprite position descriptor String
	var with: Variant # null or a transition id String
	var by: Variant # null or String
	
	
	func _init(_sprite: String, _at: Variant, _with: Variant, _by: Variant):
		self.sprite = _sprite
		self.at = _at
		self.with = _with
		self.by = _by
	
	
	func repeat_id() -> String:
		return 'Enter_%s_%s' % [sprite, by]
	
	
	func _to_string() -> String:
		return 'enter %s at %s with %s by %s' % [sprite, at, with, by]


class IMove extends BaseInstruction:
	const name: String = 'Move'
	var sprite: String
	var to: Variant # null or a sprite position descriptor String
	var with: Variant # null or a transition id String
	
	
	func _init(_sprite: String, _to: Variant, _with: Variant):
		self.sprite = _sprite
		self.to = _to
		self.with = _with
	
	
	func repeat_id() -> String:
		return 'Move_%s' % sprite
	
	
	func _to_string() -> String:
		return 'move %s to %s with %s' % [sprite, to, with]


class IShow extends BaseInstruction:
	const name: String = 'Show'
	var sprite: String
	var _as: String
	var with: Variant # null or a transition id String
	
	
	func _init(_sprite: String, __as: String, _with: Variant):
		self.sprite = _sprite
		self._as = __as
		self.with = _with
	
	
	func repeat_id() -> String:
		return 'Show_%s' % sprite
	
	
	func _to_string() -> String:
		return 'show %s as %s with %s' % [sprite, _as, with]


class IExit extends BaseInstruction:
	const name: String = 'Exit'
	var sprite: String
	var with: Variant # null or transition id String
	
	
	func _init(_sprite: String, _with: Variant):
		self.sprite = _sprite
		self.with = _with
	
	
	func repeat_id() -> String:
		return 'Exit_%s' % sprite
	
	
	func _to_string() -> String:
		return 'exit %s with %s' % [sprite, with]


class IControlExpr extends BaseInstruction:
	const name: String = 'ControlExpr'
	var string: String
	
	
	func _init(_string: String):
		self.string = _string
	
	
	func repeat_id() -> String: return ''
	
	
	func _to_string() -> String:
		return 'expr {{%s}}' % [string]


class IJmpIf extends BaseInstruction:
	const name: String = 'JmpIf'
	var condition: String
	var to: String
	
	
	func _init(_condition: String, _to: String):
		self.condition = _condition
		self.to = _to
	
	
	func _to_string() -> String:
		return 'jmpif {{%s}} to %s' % [condition, to]


class IJmp extends BaseInstruction:
	const name: String = 'Jmp'
	var to: String
	var in_file: Variant # null or String
	
	
	func _init(_to: String, _in_file = null):
		self.to = _to
		self.in_file = _in_file
	
	
	func _to_string() -> String:
		return 'jmp %s %s' % [to, in_file]
