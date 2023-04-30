class_name Overlay extends Control
# handles general logic for overlays, UI components that can be placed on top of
# arbitrary screens, which should extend this class
# subclasses should:
# – override _initialize_overlay() to setup their UI, if needed
# – call _close_overlay() to handle animations and callbacks when overlay is closed


# shadow added behind this overlay
var shadow: ColorRect
# callback to call when the overlay opening animation is finished
var animated_in_callback: Callable = func(): pass
# callback to call when the overlay is closed
var animating_out_callback: Callable = func(): pass


func _ready():
	# let subclass initialize the overlay
	_initialize_overlay()
	
	# then translate it (in this order in case new nodes are added in initialization)
	TE.ui_strings.translate(self)
	
	# setup animations
	await get_tree().process_frame
	var tween: Tween = TE.opts.animate_overlay_in.call(self)
	if tween != null:
		tween.tween_callback(animated_in_callback)
	else:
		animated_in_callback.call()
	
	shadow = add_shadow(self)


# subclasses should override this to initialize the overlay
# called from _ready()
func _initialize_overlay():
	pass


# subclasses should call this whenever the overlay is being prepared
# for being closed
func _close_overlay():
	animating_out_callback.call()
	
	remove_shadow(shadow)
	
	var tween = TE.opts.animate_overlay_out.call(self)
	if tween == null:
		_animated_out()
	else:
		tween.tween_callback(Callable(self, '_animated_out'))


func _animated_out():
	get_parent().remove_child(self)
	queue_free()



static func add_shadow(to_control: Control, skip_animation=false):
	var _shadow: ColorRect = ColorRect.new()
	_shadow.position = Vector2(0, 0)
	_shadow.size = Vector2(TE.SCREEN_WIDTH, TE.SCREEN_HEIGHT)
	_shadow.color = TE.opts.shadow_color
	_shadow.mouse_filter = Control.MOUSE_FILTER_STOP
	
	var parent = to_control.get_parent()
	var to_index = to_control.get_index()
	parent.add_child(_shadow)
	parent.move_child(_shadow, to_index)
	
	var tween: Tween = TE.opts.animate_shadow_in.call(_shadow)
	
	if skip_animation:
		# this is probably illegal but ACAB
		tween.set_speed_scale(INF)
	
	return _shadow


static func remove_shadow(_shadow: ColorRect, callback = null):
	var remove_callback: Callable = Callable(Overlay, '_do_remove_shadow').bind(_shadow)
	var tween: Tween = TE.opts.animate_shadow_out.call(_shadow)
	if tween == null:
		remove_callback.call()
		if callback != null:
			callback.call()
	else:
		tween.tween_callback(remove_callback)
		if callback != null:
			tween.tween_callback(callback)


static func _do_remove_shadow(_shadow: ColorRect):
	_shadow.get_parent().remove_child(_shadow)
	_shadow.queue_free()
