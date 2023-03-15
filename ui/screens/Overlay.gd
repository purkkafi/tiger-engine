class_name Overlay extends Control
# handles general logic for overlays, UI components that can be placed on top of
# arbitrary screens, which should extend this class
# subclasses should:
# – override _initialize_overlay() to setup their UI, if needed
# – call _close_overlay() to handle animations and callbacks when overlay is closed


# shadow added behind this overlay
var shadow: ColorRect = ColorRect.new()
# callback to call when the overlay is closed
var animating_out_callback: Callable = func(): pass


func _ready():
	# let subclass initialize the overlay
	_initialize_overlay()
	
	# then translate it (in this order in case new nodes are added in initialization)
	TE.ui_strings.translate(self)
	
	# setup animations
	await get_tree().process_frame
	TE.opts.animate_overlay_in.call(self)
	_add_shadow()


# subclasses should override this to initialize the overlay
# called from _ready()
func _initialize_overlay():
	pass


# subclasses should call this whenever the overlay is being prepared
# for being closed
func _close_overlay():
	animating_out_callback.call()
	
	_remove_shadow()
	
	var tween = TE.opts.animate_overlay_out.call(self)
	if tween == null:
		_animated_out()
	else:
		tween.tween_callback(Callable(self, '_animated_out'))


func _animated_out():
	get_parent().remove_child(self)
	queue_free()



func _add_shadow():
	shadow.position = Vector2(0, 0)
	shadow.size = Vector2(TE.SCREEN_WIDTH, TE.SCREEN_HEIGHT)
	shadow.color = TE.opts.shadow_color
	shadow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	
	self.add_sibling(shadow)
	self.z_index += 1
	TE.opts.animate_shadow_in.call(shadow)


func _remove_shadow():
	var tween: Tween = TE.opts.animate_shadow_out.call(shadow)
	if tween == null:
		self.get_parent().remove_child(shadow)
		shadow.queue_free()
	else:
		tween.tween_callback(func(): self.get_parent().remove_child(shadow))
		tween.tween_callback(func(): shadow.queue_free())
