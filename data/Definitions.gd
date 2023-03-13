class_name Definitions extends Resource
# maps ids of game assets to resources


# a map of ids to backgrounds, which can be:
# – a Color, representing a solid background of the given color
# - a String starting with '/', representing a file in the 'bgs' folder
# - an AnimatedCG
var backgrounds: Dictionary = {}
# a map of transition ids to Transition objects
var transitions: Dictionary = {}
# a map of song ids to paths relative to the 'assets/music' folder
var songs: Dictionary = {}
# a map of sound effect ids to paths relative to the 'assets/sound' folder
var sounds: Dictionary = {}
# array of ids of unlockables
var unlockables: Array[String] = []
# ids of unlockables that should be unlocked automatically
var unlocked_from_start: Array[String] = []
# map of song ids to Array of unlockable ids that should be unlocked when the song is played
var unlocked_by_song: Dictionary = {}
# a map of speaker ids to Speaker objects
var speakers: Dictionary = {}

const trans_types = {
	'QUART': Tween.TRANS_QUART,
	'ELASTIC': Tween.TRANS_ELASTIC,
	'BOUNCE': Tween.TRANS_BOUNCE,
	'SINE': Tween.TRANS_SINE,
	'QUAD': Tween.TRANS_QUAD,
	'CUBIC': Tween.TRANS_CUBIC,
	'BACK': Tween.TRANS_BACK,
	'QUINT': Tween.TRANS_QUINT,
	'EXPO': Tween.TRANS_EXPO,
	'CIRC': Tween.TRANS_CIRC,
	'LINEAR': Tween.TRANS_LINEAR
}


const ease_types = {
	'EASE_IN': Tween.EASE_IN,
	'EASE_OUT': Tween.EASE_OUT,
	'EASE_IN_OUT': Tween.EASE_IN_OUT,
	'EASE_OUT_IN': Tween.EASE_OUT_IN
}


class Transition extends RefCounted:
	var trans_type # TransitionType from Tween
	var ease_type # EaseType from Tween
	var duration: float # the duration, in seconds
	
	
	# parses transition from string where the 3 parts are separated by a space
	func _init(string: String):
		var parts: PackedStringArray = string.split(' ')
		if len(parts) != 3:
			push_error('transition should be of form TRANS_TYPE EASE_TYPE DURATION, got %s' % string)
		
		if parts[0] not in trans_types:
			push_error('not a TRANS_TYPE: %s' % parts[0])
		self.trans_type = trans_types[parts[0]]
		
		if parts[1] not in ease_types:
			push_error('not an EASE_TYPE: %s' % parts[1])
		self.ease_type = ease_types[parts[1]]
		
		if not parts[2].ends_with('s'):
			push_error('duraton should end in s: %s' % parts[2])
		self.duration = float(parts[2].trim_suffix('s'))
	
	
	func _to_string() -> String:
		return 'Transition(%s %s %s)' % [trans_type, ease_type, duration]


class Speaker extends RefCounted:
	var id: String
	var name: String
	var color: Color
