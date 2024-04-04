extends MarginContainer


var toast_queue: Array[Dictionary] # queue of toast notifications to show


func _ready():
	%ToastClose.icon = get_theme_icon('close', 'Toast')
	%ToastClose.connect('mouse_entered', func(): %ToastClose.icon = get_theme_icon('close_hover', 'Toast'))
	%ToastClose.connect('mouse_exited', func(): %ToastClose.icon = get_theme_icon('close', 'Toast'))
	_adjust_toast_size()
	TE.connect('toast_notification', func(toast): toast_queue.append(toast))


func _adjust_toast_size():
	%ToastIcon.custom_minimum_size.x = get_theme_constant('height', 'Toast')
	# BUG: Godot doesn't recalc the sizes of the controls for whatever reason
	# no idea how to fix, toggling visiblity etc didn't work :(
	%ToastPanel.custom_minimum_size = Vector2(
		get_theme_constant('width', 'Toast'),
		get_theme_constant('height', 'Toast')
	)


func _process(_delta):
	if len(toast_queue) != 0 and not self.visible:
		show_toast(toast_queue.pop_front())


func show_toast(toast: Dictionary):
	self.visible = true
	self.modulate.a = 1.0
	%ToastText.text = toast['bbcode']
	%ToastClose.icon = get_theme_icon('close', 'Toast')
	
	if 'icon' in toast:
		%ToastIcon.custom_minimum_size.x = get_theme_constant('height', 'Toast')
		%ToastIcon.texture = load(toast['icon'])
	else:
		%ToastIcon.texture = null
		%ToastIcon.custom_minimum_size.x = 0
	
	var tween: Tween = create_tween()
	%ToastClose.connect('pressed', _toast_closed.bind(tween))
	
	# animate sliding in
	self.position.y = -self.size.y
	tween.tween_property(self, 'position:y', 0, 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	
	# animate fading out
	tween.tween_property(self, 'modulate:a', 0.0, 1).set_delay(3)
	tween.tween_callback(func(): self.visible = false)
	tween.tween_callback(func(): %ToastClose.disconnect('pressed', _toast_closed))


func _toast_closed(tween: Tween):
	tween.set_speed_scale(INF)
