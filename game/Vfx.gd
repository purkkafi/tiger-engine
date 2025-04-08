class_name Vfx extends RefCounted
# visual effect that can be applied to stage objects


# applies this vfx to its target CanvasItem with the given arguments ('new_state')
# see persistent()
@warning_ignore("unused_parameter")
func set_state(target: CanvasItem, new_state: Dictionary, tween: Tween) -> Tween:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'set_state()'")
	return tween


# returns a snapshot of state that can be passed to set_state()
# to replicate the vfx for the purposes of saving/loading, etc
func get_state() -> Dictionary:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'get_state()'")
	return {}


# manually clears a persistent vfx, returning 'target' to its normal state
# and clening up any used resources
@warning_ignore("unused_parameter")
func clear(target: CanvasItem, tween: Tween) -> Tween:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'remove()'")
	return tween


# marks this vfx as persistent or transient
# transient vfxs:
# – will have their set_state() method called once and then discarded
# persistent vfxs:
# – will be saved on the stage until manually cleared
# – must support multiple calls to set_state()
# – must override get_state() and clear()
func persistent() -> bool:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'persistent()'")
	return false


# declares valid arguments for this vfx, which can then be
# passed to set_state() via the 'new_state' parameter
func recognized_arguments() -> Array[String]:
	TE.log_error(TE.Error.FILE_ERROR, "Vfx doesn't override 'recognized_arguments()'")
	return []
