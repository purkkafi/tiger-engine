class_name Rollback extends RefCounted
# maintains a list of save states that can be used to go back with
# the Back button


# amount of rollback entries to keep
const ROLLBACK_SIZE: int = 100


# array of rollback entries; new are added to the end
var entries: Array[Dictionary] = []
# the in-game Back button; this class will update its enabled state
var back_button: Button


func _init( _back_button: Button):
	self.back_button = _back_button
	back_button.disabled = true


# adds a rollback entry, clearing older ones if necessary
func push(save: Dictionary):
	entries.push_back(save)
	
	while len(entries) > ROLLBACK_SIZE:
		entries.pop_front()
	
	if back_button.disabled:
		back_button.disabled = false


# returns whether rollback is empty
func is_empty():
	return entries.is_empty()


# removes and returns the latest entry
func pop() -> Dictionary:
	if entries.is_empty():
		TE.log_error('rollback is empty')
	elif len(entries) == 1:
		back_button.disabled = true
	
	return entries.pop_back()


func set_rollback(new_entries: Array[Dictionary]):
	entries = new_entries
	back_button.disabled = len(entries) == 0
