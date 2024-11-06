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
	var transition: String # transition id used for duration
	
	
	func _init(_transition: String):
		self.transition = _transition
	
	
	func _to_string() -> String:
		return 'pause %s' % [transition]


class IHideUI extends BaseInstruction:
	const name: String = 'HideUI'
	var transition_id: String
	
	
	func _init(_transition_id: String):
		self.transition_id = _transition_id
	
	
	func _to_string() -> String:
		return 'hideui %s' % [transition_id]


class ISound extends BaseInstruction:
	const name: String = 'Sound'
	var sound_id: String
	
	
	func _init(_sound_id: String):
		self.sound_id = _sound_id
	
	
	func _to_string() -> String:
		return 'sound %s' % [sound_id]


class IMusic extends BaseInstruction:
	const name: String = 'Music'
	var song_id: String # song id or the empty string to clear
	var transition_id: String
	var local_volume: float # local volume to play song with in range [0, 1]
	
	
	func _init(_song_id: String, _transition_id: String, _local_volume):
		self.song_id = _song_id
		self.transition_id = _transition_id
		self.local_volume = _local_volume
	
	
	func _to_string() -> String:
		return 'playsong %s, %s, %s' % [song_id, transition_id, local_volume]


class IBG extends BaseInstruction:
	const name: String = 'BG'
	var bg_id: String # id of background; "" for clear
	var transition_id: String # id of transition; "" for none (instant transition)
	
	
	func _init(_bg_id: String, _transition_id: String):
		self.bg_id = _bg_id
		self.transition_id = _transition_id
	
	
	func _to_string() -> String:
		return 'bg %s, %s' % [bg_id, transition_id]


class IFG extends BaseInstruction:
	const name: String = 'FG'
	var fg_id: String # id of foreground; "" for clear
	var transition_id: String # id of transition; "" for none (instant transition)
	
	
	func _init(_fg_id: String, _transition_id: String):
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
	var _as: Variant # null or Tag
	var at_x: Variant # null or a String
	var at_y: Variant # null or a String
	var at_zoom: Variant # null or a String
	var at_order: Variant # null or a String
	var with: Variant # null or a transition id String
	var by: Variant # null or String
	
	
	func _init(_sprite: String, __as: Variant, _at_x: Variant, _at_y: Variant, _at_zoom: Variant, _at_order: Variant, _with: Variant, _by: Variant):
		self.sprite = _sprite
		self._as = __as
		self.at_x = _at_x
		self.at_y = _at_y
		self.at_zoom = _at_zoom
		self.at_order = _at_order
		self.with = _with
		self.by = _by
	
	
	func repeat_id() -> String:
		return 'Enter_%s_%s' % [sprite, by]
	
	
	func _to_string() -> String:
		return 'enter %s as %s at %s %s %s %s with %s by %s' % [sprite, _as, at_x, at_y, at_zoom, at_order, with, by]


class IMove extends BaseInstruction:
	const name: String = 'Move'
	var sprite: String
	var to_x: Variant # null or String
	var to_y: Variant # null or String
	var to_zoom: Variant # null or String
	var to_order: Variant # null or String
	var with: Variant # null or a transition id String
	
	
	func _init(_sprite: String, _to_x: Variant, _to_y: Variant, _to_zoom: Variant, _to_order: Variant, _with: Variant):
		self.sprite = _sprite
		self.to_x = _to_x
		self.to_y = _to_y
		self.to_zoom = _to_zoom
		self.to_order = _to_order
		self.with = _with
	
	
	func repeat_id() -> String:
		return 'Move_%s' % sprite
	
	
	func _to_string() -> String:
		return 'move %s to %s %s %s %s with %s' % [sprite, to_x, to_y, to_zoom, to_order, with]


class IShow extends BaseInstruction:
	const name: String = 'Show'
	var sprite: String
	var _as: Tag
	var with: Variant # null or a transition id String
	
	
	func _init(_sprite: String, __as: Tag, _with: Variant):
		self.sprite = _sprite
		self._as = __as
		self.with = _with
	
	
	func repeat_id() -> String:
		return 'Show_%s' % sprite
	
	
	func _to_string() -> String:
		return 'show %s as %s with %s' % [sprite, str(_as), with]


class IExit extends BaseInstruction:
	const name: String = 'Exit'
	var sprite: String # sprite id or empty string for \all
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


class IEffect extends BaseInstruction:
	const name: String = 'Effect'
	# target of the effect, can be:
	# – \stage, \fg, \bg, \sprites
	# – a sprite id
	var target: String
	var apply: Array[String]
	var remove: Array[String]
	
	
	func _init(_target: String, _apply: Array[String], _remove: Array[String]):
		self.target = _target
		self.apply = _apply
		self.remove = _remove
	
	
	func repeat_id() -> String:
		return 'Effect_%s' % [target]
	
	
	func _to_string() -> String:
		return 'target %s apply %s remove %s' % [target, apply, remove]
