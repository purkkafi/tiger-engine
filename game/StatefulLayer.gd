class_name StatefulLayer extends Node2D
# TODO deprecate, superseded by effects system
# background/foreground that maintains an internal state


func get_state() -> Dictionary:
	push_error('StatefulLayer needs to override get_state()')
	return {}


func set_state(_new_state: Dictionary) -> void:
	push_error('StatefulLayer needs to override set_state()')
