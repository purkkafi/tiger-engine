class_name VNStage extends Node
# responsible for displaying and keeping track of game objects such as
# the background and foreground layers and sprites


var bg_id: String = ''
var fg_id: String = ''
var TRANSPARENT: Color = Color(0, 0, 0, 0)
var INSTANT: Definitions.Transition = Definitions.Transition.new('QUAD EASE_IN 0s')


# transitions to a new background with the given Transition
# a Tween can be given to do so in parallel; otherwise, a new one is created
func set_background(new_id: String, transition: Definitions.Transition, tween: Tween) -> Tween:
	bg_id = new_id
	return _set_layer($BG, _get_layer_node(new_id), transition, tween, false)


# transitions to a new foreground with the given Transition
# a Tween can be given to do so in parallel; otherwise, a new one is created
func set_foreground(new_id: String, transition: Definitions.Transition, tween: Tween) -> Tween:
	fg_id = new_id
	return _set_layer($FG, _get_layer_node(new_id), transition, tween, true)


# loads a suitable back/foreground Node based on the given id
func _get_layer_node(id: String) -> Node:
	if id == '': # id represents an empty layer
		var empty: ColorRect = ColorRect.new()
		empty.color = Color.TRANSPARENT
		return empty
	
	elif TE.defs.color(id) != null: # id represents a color
		var rect: ColorRect = ColorRect.new()
		rect.color = TE.defs.color(id)
		return rect
		
	else: # id represents a path
		# unlock possible unlockable
		if id in TE.defs.unlocked_by_img:
			for unlockable in TE.defs.unlocked_by_img[id]:
				TE.settings.unlock(unlockable)
				
		var path: String = TE.defs.imgs[id]
		if path.ends_with('.tscn'): # is animation scene
			var scene: PackedScene = Assets.imgs.get_resource(path, 'res://assets/img')
			return scene.instantiate()
		else: # assumed to be some kind of image
			var rect: TextureRect = TextureRect.new()
			rect.texture = Assets.imgs.get_resource(path, 'res://assets/img')
			return rect


# transitions the given node to the new one with the given Transition
# fade_old determines whether the old layer will be faded out in a reverse of the transition
func _set_layer(layer: Node, new_layer: Node, transition: Definitions.Transition, tween: Tween, fade_old: bool):
	if new_layer is Control: # not needed for animations, which are Node2D's
		new_layer.size = Vector2(TE.SCREEN_WIDTH, TE.SCREEN_HEIGHT)
		new_layer.position = Vector2(0, 0)
	new_layer.name = 'New' + layer.name
	layer.add_sibling(new_layer)
	
	# skip tween in this case
	if transition.duration == 0:
		_replace_with(layer, new_layer)
		return tween
	
	if tween == null:
		tween = create_tween()
	
	new_layer.modulate = Color(1, 1, 1, 0)
	var tweener: PropertyTweener = tween.parallel().tween_property(new_layer, 'modulate:a', 1.0, transition.duration)
	tweener.set_ease(transition.ease_type)
	tweener.set_trans(transition.trans_type)
	
	if fade_old:
		layer.modulate.a = 1.0
		var old_tweener: PropertyTweener = tween.parallel().tween_property(layer, 'modulate:a', 0.0, transition.duration)
		old_tweener.set_ease(transition.ease_type)
		old_tweener.set_trans(transition.trans_type)
	
	# schedule replacing the old layer with the new one
	tween.parallel().tween_callback(Callable(self, '_replace_with').bind(layer, new_layer)).set_delay(transition.duration)
	
	return tween


func _replace_with(layer: Node, new_layer: Node):
	var old_pos: int = get_children().find(layer)
	remove_child(layer)
	move_child(new_layer, old_pos)
	new_layer.name = layer.name
	
	layer.queue_free()


# returns current state as a Dict
func get_state() -> Dictionary:
	return {
		'bg' : bg_id,
		'fg' : fg_id
	}


# sets state from a Dict
func set_state(state: Dictionary):
	set_background(state['bg'], INSTANT, null)
	set_foreground(state['fg'], INSTANT, null)
