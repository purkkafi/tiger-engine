class_name Vfx extends RefCounted
# visual effect that can be applied to stage objects


@warning_ignore("unused_parameter")
func apply(target: CanvasItem, initial_state: Dictionary, tween: Tween) -> Tween:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'apply()'")
	return null


@warning_ignore("unused_parameter")
func clear(target: CanvasItem, tween: Tween) -> Tween:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'remove()'")
	return null


@warning_ignore("unused_parameter")
func persistent() -> bool:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'persistent()'")
	return false


@warning_ignore("unused_parameter")
func get_state(target: CanvasItem) -> Dictionary:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'get_state()'")
	return {}


@warning_ignore("unused_parameter")
func set_state(target: CanvasItem, new_state: Dictionary, _tween: Tween) -> Tween:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'set_state()'")
	return null
