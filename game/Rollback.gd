class_name Rollback extends RefCounted
# maintains a list of save states that can be used to go back with
# the Back button


# amount of rollback entries to keep
const ROLLBACK_SIZE: int = 100


# array of rollback entries; new are added to the end
var entries: Array[Dictionary] = []
# the in-game Back button; this class will update its enabled state
var back_button: Button


func _init(_back_button: Button):
	self.back_button = _back_button
	back_button.disabled = true


# adds a rollback entry, clearing older ones if necessary
func push(save: Dictionary):
	entries.push_back(save)
	back_button.disabled = false
	
	while len(entries) > ROLLBACK_SIZE:
		entries.pop_front()


# returns whether rollback is empty
func is_empty() -> bool:
	return entries.is_empty()


# removes and returns the latest entry
func pop() -> Dictionary:
	if entries.is_empty():
		TE.log_error('rollback is empty')
	
	var entry = entries.pop_back()
	back_button.disabled = is_empty()
	return entry


# sets the rollback entries; used to preserve them when loading from a save state
func set_rollback(new_entries: Array[Dictionary]):
	entries = new_entries
	back_button.disabled = is_empty()
