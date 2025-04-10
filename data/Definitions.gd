class_name Definitions extends Resource
# maps ids of game assets to resources


# a map of ids to images, which are paths relative to the 'assets/bg' folder
var imgs: Dictionary = {}
var img_metadata: Dictionary = {} # metadata specified with \meta{}
# a map of transition ids to Transition objects
# users should not access directly, use Definitions.transition()
var _transitions: Dictionary = {}
# a map of song ids to paths relative to the 'assets/music' folder
var songs: Dictionary = {}
# a map of song ids to custom volumes, which are in range [0, 1]
var song_custom_volumes: Dictionary = {}
var song_metadata: Dictionary = {} # metadata specified with \meta{}
# a map of sound effect ids to paths relative to the 'assets/sound' folder
var sounds: Dictionary = {}
var sound_custom_volumes: Dictionary = {} # custom volumes in range [0, 1]
var sound_metadata: Dictionary = {} # metadata specified with \meta{}
# array of ids of unlockables
var unlockables: Array[String] = []
# ids of unlockables that should be unlocked automatically
var unlocked_from_start: Array[String] = []
# map of song ids to Array of unlockable ids that should be unlocked when the song is played
var unlocked_by_song: Dictionary = {}
# map of img ids to Array of unlockable ids unlocked when the image is shown
var unlocked_by_img: Dictionary = {}
# map of unlockable ids to Array of other unlockables they silently & automatically unlock
var automatically_unlocks: Dictionary = {}
# map of speaker ids to Speaker objects
var speakers: Dictionary = {}
# map of color ids to Color objects
# should not be accessed directly; use Definitions.color() to allow inline colors
var _colors: Dictionary = {}
# map of sprite ids to sprite paths
var sprites: Dictionary = {}
# map of variable names to their default values
var variables: Dictionary = {}
# registry of Views recognized by the game
# dict of view ids to PackedScenes
var view_registry: Dictionary = {}
# registry of recognized sprite objects
# dict of sprite object ids to Godot scripts
var sprite_object_registry: Dictionary = {}
# registry of recognized text styles
# dict of text style ids to the replacement formatting,
# which is an Array of strings and Tag arguments in form \1, \2, etc
var text_styles: Dictionary[String, Array] = {}


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


# hardcoded instant transition
static var INSTANT = Transition.new('QUAD EASE_IN 0s')


# returns unlockables that belong in the given namespace
# (i.e. their name starts with the given prefix)
# idiomatically, unlockables are given ids of form namespace:unlockable_id
# and, as such, this method can be called with a string of form "[namespace]:"
func unlockables_in_namespace(prefix: String) -> Array[String]:
	var found: Array[String] = []
	for unlockable in unlockables:
		if unlockable.begins_with(prefix):
			found.append(unlockable)
	return found


# returns the volume at which the given song_id should be played
# this is the value in song_custom_volumes or 1.0 if not set
func song_volume(song_id: String) -> float:
	if song_id in song_custom_volumes:
		return song_custom_volumes[song_id]
	return 1.0


# like song_volume()but for sounds
func sound_volume(sound_id: String):
	if sound_id in sound_custom_volumes:
		return sound_custom_volumes[sound_id]
	return 1.0


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
# – the instant transition, if an empty String is given
# – the transition matching the definition, if an id is given
# – the result of parsing the given string as a Transition
func transition(trans_id: String) -> Transition:
	if trans_id == '':
		return INSTANT
	if trans_id in _transitions:
		return _transitions[trans_id]
	return Transition.new(trans_id)


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


class SpeakerDef extends RefCounted:
	var id: String
	# either String (used directly) or Tag.ControlTag
	var name: Variant
	# default to TRANSPARENT, which should be treated as unset
	var bg_color: Color = Color.TRANSPARENT
	var name_color: Color = Color.TRANSPARENT
	# default to the empty string, which should be treated as unset
	var label_variation: String = ''
	var textbox_variation: String = ''
	
	
	# validates this Speaker and returns a non-empty error message if it is invalid
	# otherwise, returns the empty string
	func error_message() -> String:
		if id == null or name == null:
			return 'speaker id and name required'
		return ''
