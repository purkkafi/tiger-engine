class_name Savefile extends Resource
# savefiles contain the saves for a specific language
# a save is identified by its bank & index


# banks of save data
# dictionaries with the fields 'name' (of the bank) & 'saves' (array of saves)
var banks: Array[Dictionary] = []
# the language id of these saves; used to determine the path
var lang_id: String


const default_bank_names: Array = [ 'A', 'B', 'C', 'D', 'E', 'F', 'G', 'H', 'I', 'J' ]
const empty_bank: Array = [ null, null, null, null,
							null, null, null, null,
							null, null, null, null ]
# fields to ignore when comparing saves for game progress
const TRANSIENT_FIELDS: Array = [
	'save_datetime', 'save_utime', 'save_name', 'game_name', 'game_version', # not in-game data
	'stage', 'song_id', 'variables' # depend strictly on other values
]


func _init():
	# fill initially with empty saves
	for name in default_bank_names:
		banks.append({ 'name' : name, 'saves' : empty_bank.duplicate() })


# replaces the save file in the given bank and index
# and writes the thumbline to the disk
func set_save(save: Dictionary, thumb: Image, bank: int, index: int):
	banks[bank]['saves'][index] = save
	thumb.resize(480, 270, Image.INTERPOLATE_BILINEAR)
	# TODO implement for new thumb code
	# thumb.save_png(_icon_path(bank, index))
	write_saves()


# returns the save at the given index in the given bank, may be null for empty save
func get_save(bank: int, index: int) -> Variant:
	return banks[bank]['saves'][index]


# returns the file path of the image containing thumbnails for the given bank
func thumbs_path(bank: int) -> String:
	return 'user://' + lang_id + '/thumbs_' + (str(bank)) + '.png'


# saves the contents of this savefile to disk
func write_saves():
	ResourceSaver.save(self, path())


# the file path of this savefile
func path():
	return 'user://' + lang_id + '/saves.sav'


# returns whether progress was made between saves
# (generally meaning: are their gameplay-related values different)
# if either argument is null (i.e. game was not saved), returns true
static func is_progress_made(save1, save2):
	if save1 == null or save2 == null:
		return true
	
	# duplicate to avoid messing with the arguments
	save1 = save1.duplicate(true)
	save2 = save2.duplicate(true)
	
	# remove irrelevant fields
	for field in TRANSIENT_FIELDS:
		save1.erase(field)
		save2.erase(field)
	
	var result: bool = !Savefile._deep_equals(save1, save2)
	return result


# deeply compares dicts
static func _deep_equals(d1: Dictionary, d2: Dictionary):
	var keys1: Array = d1.keys()
	var keys2: Array = d2.keys()
	keys1.sort()
	keys2.sort()
	
	if keys1 != keys2:
		return false
	
	for k in d1.keys():
		if d1[k] is Dictionary and d2[k] is Dictionary:
			if !_deep_equals(d1[k], d2[k]):
				return false
		elif d1[k] is float and d2[k] is float:
			if d1[k] - d2[k] > 0.00001:
				return false
		else:
			if d1[k] != d2[k]:
				return false
	return true
