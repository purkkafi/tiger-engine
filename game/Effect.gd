class_name Effect extends RefCounted
# visual effect that can be applied to stage objects


func apply(_to: CanvasItem, _tween: Tween) -> Tween:
	TE.log_error(TE.Error.FILE_ERROR, "Effect doesn't override 'apply()'")
	return null


func remove(_from: CanvasItem, _tween: Tween) -> Tween:
	TE.log_error(TE.Error.FILE_ERROR, "Effect doesn't override 'remove()'")
	return null
