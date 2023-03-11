class_name VNStage extends Node
# responsible for displaying and keeping track of game objects such as
# the background and foreground layers and sprites


var bg_id: String = ''
var TRANSPARENT: Color = Color(0, 0, 0, 0)


# transitions to a new background with the given Transition
func set_background(new_id: String, transition: Definitions.Transition):
	bg_id = new_id
	return _set_layer($BG,  _get_layer_node(new_id), transition)


# loads a suitable back/foreground Node based on the given id
func _get_layer_node(id: String) -> Node:
	var definition = Global.definitions.backgrounds[id]
	
	if definition is Color:
		var rect: ColorRect = ColorRect.new()
		rect.color = definition
		return rect
	elif definition is String:
		var rect: TextureRect = TextureRect.new()
		rect.texture = Assets.bgs.get_resource('res://assets/bgs' + definition)
		return rect
	elif definition is Tag:
		match definition.name:
			'localize':
				var rect: TextureRect = TextureRect.new()
				rect.texture = Assets.bgs.get_resource(Assets.in_lang(definition.get_string()))
				return rect
			_:
				Global.log_error('cannot handle background: %s' % [ definition ])
				return null
	else:
		Global.log_error('cannot handle background: %s' % [ definition ])
		return null


# transitions the given node to the new one with the given Transition
func _set_layer(layer: Node, new_layer: Node, transition: Definitions.Transition):
	new_layer.size = layer.size
	new_layer.position = layer.position
	new_layer.name = layer.name
	
	# skip tween in this case
	if transition.duration == 0:
		_replace_with(layer, new_layer)
		return null
	
	layer.add_child(new_layer)
	new_layer.modulate = Color(1, 1, 1, 0)
	var tween = create_tween()
	var tweener: PropertyTweener = tween.tween_property(new_layer, 'modulate:a', 1.0, transition.duration)
	tweener.set_ease(transition.ease_type)
	tweener.set_trans(transition.trans_type)
	
	# schedule replacing the old layer with the new one
	tween.parallel().tween_callback(Callable(self, '_replace_with').bind(layer, new_layer)).set_delay(transition.duration)
	
	return tween

func _replace_with(layer: Node, new_layer: Node):
	if layer.is_ancestor_of(new_layer):
		layer.remove_child(new_layer)
	
	var old_pos: int = get_children().find(layer)
	remove_child(layer)
	add_child(new_layer)
	move_child(new_layer, old_pos)
	
	layer.queue_free()
