class_name Rollback extends RefCounted
# maintains a list of save states that can be used to go back with
# the Back button


# amount of rollback entries to keep
const ROLLBACK_SIZE: int = 100


# array of rollback entries; new ones are added to the end
var rollback_entries: Array[Dictionary] = []
# array of rollforward entries; new ones are added to the end
var rollforward_entries: Array[Dictionary] = []
# the in-game Back button; this class will update its enabled state
var back_button: Button


func _init(_back_button: Button):
	self.back_button = _back_button
	back_button.disabled = true


# adds a rollback entry, clearing older ones if necessary
func push_rollback(save: Dictionary):
	rollback_entries.push_back(save)
	back_button.disabled = false
	
	while len(rollback_entries) > ROLLBACK_SIZE:
		rollback_entries.pop_front()


func is_rollback_empty() -> bool:
	return rollback_entries.is_empty()


# removes and returns the latest entry
func pop_rollback() -> Dictionary:
	if rollback_entries.is_empty():
		TE.log_error(TE.Error.ENGINE_ERROR, 'rollback is empty')
	
	var entry = rollback_entries.pop_back()
	back_button.disabled = is_rollback_empty()
	return entry


# adds rollforward entry
func push_rollforward(save: Dictionary):
	rollforward_entries.push_back(save)
	
	while len(rollforward_entries) > ROLLBACK_SIZE:
		rollforward_entries.pop_front()


func is_rollforward_empty() -> bool:
	return rollforward_entries.is_empty()


# removes and returns latest rollforward entry
func pop_rollforward() -> Dictionary:
	if rollforward_entries.is_empty():
		TE.log_error(TE.Error.ENGINE_ERROR, 'rollback is empty')
	
	return rollforward_entries.pop_back()


# sets the rollback & rollforward entries; used to preserve them when loading from a save state
func set_rollback(from: Rollback):
	rollback_entries = from.rollback_entries
	rollforward_entries = from.rollforward_entries
	back_button.disabled = is_rollback_empty()
