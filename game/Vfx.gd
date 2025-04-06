class_name Vfx extends RefCounted
# visual effect that can be applied to stage objects


func apply(target: CanvasItem, initial_state: Dictionary, _tween: Tween) -> Tween:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'apply()'")
	return null


func clear(target: CanvasItem, _tween: Tween) -> Tween:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'remove()'")
	return null


func persistent() -> bool:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'persistent()'")
	return false


func get_state(target: CanvasItem) -> Dictionary:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'get_state()'")
	return {}


@warning_ignore("unused_parameter")
func set_state(target: CanvasItem, new_state: Dictionary, _tween: Tween) -> Tween:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'set_state()'")
	return null
