class_name Definitions extends Resource
# maps ids of game assets to resources


# a map of ids to images, which are paths relative to the 'assets/bg' folder
var imgs: Dictionary = {}
# a map of transition ids to Transition objects
# users should not access directly, use Definitions.transition()
var _transitions: Dictionary = {}
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
# map of img ids to Array of unlockable ids unlocked when the image is shown
var unlocked_by_img: Dictionary = {}
# map of speaker ids to Speaker objects
var speakers: Dictionary = {}
# map of color ids to Color objects
# should not be accessed directly; use Definitions.color() to allow inline colors
var _colors: Dictionary = {}
# map of sprite ids to sprite paths
var sprites: Dictionary = {}


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


# returns the corresponding color or null if the given value does not represent one
# a valid color can be:
# – the id of a color definition
# – a String that matches Color.html_is_valid()
func color(color_id: String) -> Variant:
	if color_id in _colors:
		return _colors[color_id]
	if Color.html_is_valid(color_id):
		return Color.html(color_id)
	return null


# returns the corresponding Transition object, which can be:
# – the transition matching the definition, if an id is given
# – the result of parsing the given string as a Transition
func transition(trans_id: String) -> Transition:
	if trans_id in _transitions:
		return _transitions[trans_id]
	return Transition.new(trans_id)


# returns an instant transition
static func instant() -> Transition:
	return Transition.new('QUAD EASE_IN 0s')


class Transition extends RefCounted:
	var trans_type # TransitionType from Tween
	var ease_type # EaseType from Tween
	var duration: float # the duration, in seconds
	
	
	# parses transition from string where the 3 parts are separated by a space
	func _init(string: String):
		var parts: PackedStringArray = string.split(' ')
		# special case: definition with only duration
		if len(parts) == 1:
			if not parts[0].ends_with('s'):
				push_error('transition duration should end in s: %s' % string)
			self.duration = float(parts[0].trim_suffix('s'))
			self.trans_type = Tween.TRANS_LINEAR
			self.ease_type = Tween.EASE_IN
			return
			
		if len(parts) != 3:
			push_error('illegal transition: %s (should be of form DURATION | TRANS_TYPE EASE_TYPE DURATION)' % string)
		
		if parts[0] not in trans_types:
			push_error('not a TRANS_TYPE: %s' % parts[0])
		self.trans_type = trans_types[parts[0]]
		
		if parts[1] not in ease_types:
			push_error('not an EASE_TYPE: %s' % parts[1])
		self.ease_type = ease_types[parts[1]]
		
		if not parts[2].ends_with('s'):
			push_error('transition duration should end in s: %s' % parts[2])
		self.duration = float(parts[2].trim_suffix('s'))
	
	
	func _to_string() -> String:
		return 'Transition(%s %s %s)' % [trans_type, ease_type, duration]


class Speaker extends RefCounted:
	var id: String
	var name: String
	var color: Color
