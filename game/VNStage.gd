class_name VNStage extends Node
# responsible for displaying and keeping track of game objects such as
# the background and foreground layers and sprites


var bg_id: String = ''
var fg_id: String = ''
const TRANSPARENT: Color = Color(0, 0, 0, 0)


# transitions to a new background with the given transition
# a Tween can be given to do so in parallel; otherwise, a new one is created
func set_background(new: Variant, transition: String, tween: Tween) -> Tween:
	var to_state = null
	
	if new is String:
		bg_id = new
	else: # is Dictionary
		bg_id = new['id']
		to_state = new['state']
	
	var result = _set_layer($BG, _get_layer_node(bg_id), TE.defs.transition(transition), tween, false)
	
	if to_state != null:
		$BG.set_state(to_state)
	
	return result


# transitions to a new foreground with the given transition
# a Tween can be given to do so in parallel; otherwise, a new one is created
func set_foreground(new: Variant, transition: String, tween: Tween) -> Tween:
	var to_state = null
	
	if new is String:
		fg_id = new
	else: # is Dictionary
		fg_id = new['id']
		to_state = new['state']
	
	var result = _set_layer($FG, _get_layer_node(fg_id), TE.defs.transition(transition), tween, true)
	
	if to_state != null:
		$FG.set_state(to_state)
	
	return result


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
				TE.persistent.unlock(unlockable)
		
		if id not in TE.defs.imgs:
			TE.log_error(TE.Error.FILE_ERROR, "Layer object not found: '%s'" % id)
		
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
	layer.set_meta('transitioning_into', new_layer)
	
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


# adds a sprite to the stage
# path is the full path to the sprite folder
# _as is the Tag describing the initial state or null
# at_x, at_y, at_zoom are initial position descriptors or null
# at_order is the draw order int or null
# with is a transition descriptor or null
# by is an alternative id to give to the sprite or null
# tween is the tween to use or null, in case it will be created; returned for chaining
func enter_sprite(id: String, _as: Variant, at_x: Variant, at_y: Variant, at_zoom: Variant, at_order: Variant, with: Variant, by: Variant, tween: Tween) -> Tween:
	var sprite: VNSprite = _create_sprite(Assets._resolve(TE.defs.sprites[id], 'res://assets/sprites'))
	if by != null:
		sprite.id = by as String
	else:
		sprite.id = id
	
	if sprite.id in get_sprite_ids():
		TE.log_error(TE.Error.FILE_ERROR, 'sprite already on stage: %s' % sprite.id)
		sprite.queue_free()
		return tween
	
	$Sprites.add_child(sprite)
	_sort_sprites()
	sprite.enter_stage(_as)
	
	if at_x != null:
		at_x = _parse_x_position_descriptor(at_x)
	
	if at_y != null:
		at_y = float(at_y as String)
	
	if at_zoom != null:
		at_zoom = float(at_zoom as String)
	
	sprite.move_to(at_x, at_y, at_zoom, at_order, Definitions.INSTANT, null)
	
	if with != null:
		if tween == null:
			tween = create_tween()
		var trans: Definitions.Transition = TE.defs.transition(with as String)
		sprite.modulate.a = 0.0
		var tweener = tween.parallel().tween_property(sprite, 'modulate:a', 1.0, trans.duration)
		tweener.set_ease(trans.ease_type)
		tweener.set_trans(trans.trans_type)
		
	return tween


# creats a sprite object when given the full path of the sprite folder
func _create_sprite(path: String) -> VNSprite:
	var resource: SpriteResource = Assets.sprites.get_resource('sprite.tef', path)
	var sprite: VNSprite
	
	if resource.tag.name in TE.defs.sprite_object_registry.keys():
		var sprite_object: GDScript = TE.defs.sprite_object_registry[resource.tag.name]
		sprite = sprite_object.new(resource)
	else:
		TE.log_error(TE.Error.SCRIPT_ERROR, 'sprite provider for %s not implemented' % path)
	
	sprite.path = path
	# default id to being last part of sprite folder's path
	sprite.id = path.split('/')[-1]
	
	sprite.connect('draw_order_changed', _sort_sprites)
	return sprite


# moves a sprite according to the given values
# with is the optional transition and tween is the optional Tween (returned for chaining)
func move_sprite(id: String, to_x: Variant, to_y: Variant, to_zoom: Variant, to_order: Variant, with: Variant, tween: Tween) -> Tween:
	var sprite: VNSprite = find_sprite(id)
	
	if with == null:
		with = Definitions.INSTANT
	else:
		if tween == null:
			tween = create_tween()
		with = TE.defs.transition(with)
	
	if to_x != null:
		to_x = _parse_x_position_descriptor(to_x)
	
	if to_y != null:
		to_y = float(to_y as String)
	
	if to_zoom != null:
		to_zoom = float(to_zoom as String)
	
	sprite.move_to(to_x, to_y, to_zoom, to_order, with, tween)
	
	return tween


# shows the sprite with the specified sprite state
# if with (a transition descriptor) is given, the new state will fade in on
# top of the sprite (animated with the tween, if given)
func show_sprite(id: String, _as: Tag, with: Variant, tween: Tween) -> Tween:
	var sprite: VNSprite = find_sprite(id)
	
	if with == null:
		sprite.show_as(_as)
		return tween
	
	if tween == null:
		tween = create_tween()
	
	with = TE.defs.transition(with)
	
	var new_sprite = _create_sprite(sprite.path)
	new_sprite.id = sprite.id
	sprite.add_sibling(new_sprite, false)
	new_sprite.enter_stage()
	new_sprite.set_sprite_state(sprite.get_sprite_state())
	new_sprite.show_as(_as)
	new_sprite.move_to(sprite.horizontal_position, sprite.vertical_position, sprite.zoom, sprite.draw_order, Definitions.INSTANT)
	
	new_sprite.modulate.a = 0.0
	var tweener = tween.parallel().tween_property(new_sprite, 'modulate:a', 1.0, with.duration)
	tweener.set_ease(with.ease_type)
	tweener.set_trans(with.trans_type)
	tween.parallel().tween_callback(Callable(self, '_finish_sprite_transition').bind(sprite)).set_delay(with.duration)
	
	return tween


func _finish_sprite_transition(old: VNSprite):
	$Sprites.remove_child(old)
	old.queue_free()


# removes the given sprite from the stage
# if with (a transition) is given, it will be faded out
func exit_sprite(id: String, with: Variant, tween: Tween) -> Tween:
	var sprite: VNSprite = find_sprite(id)
	if tween == null:
		tween = create_tween()
	
	if with == null:
		_remove_sprite(sprite)
	else:
		with = TE.defs.transition(with as String)
		var tweener = tween.parallel().tween_property(sprite, 'modulate:a', 0.0, with.duration)
		tweener.set_ease(with.ease_type)
		tweener.set_trans(with.trans_type)
		tween.parallel().tween_callback(Callable(self, '_remove_sprite').bind(sprite)).set_delay(with.duration)
	
	return tween


func _remove_sprite(sprite: VNSprite):
	$Sprites.remove_child(sprite)
	sprite.queue_free()


# parses a sprite x position descriptor
# – if given a String of form "n of m", it is n / (m+1)
# – else, it is the argument parsed as a float
func _parse_x_position_descriptor(desc: String) -> float:
	if desc.contains('of'):
		var parts = desc.split('of', false, 2)
		return float(parts[0]) / (float(parts[1]) + 1)
	
	return float(desc)


# returns the sprite object with the given id
func find_sprite(id: String) -> VNSprite:
	var sprite: VNSprite
	for child in $Sprites.get_children():
		if child.id == id:
			sprite = child
	
	if sprite == null:
		TE.log_error(TE.Error.ENGINE_ERROR, 'sprite not found: %s' % id)
	
	return sprite


# returns an array containing the ids of all sprite objects on the stage
func get_sprite_ids() -> Array[String]:
	var ids: Array[String] = []
	for child in $Sprites.get_children():
		ids.append(child.id)
	return ids


# sorts the sprites to make sure draw order is respected
func _sort_sprites():
	var og_order = $Sprites.get_children().duplicate()
	var new_order = $Sprites.get_children().duplicate()
	new_order.sort_custom(_cmp_sprites.bind(og_order))
	
	for child in og_order:
		$Sprites.move_child(child, new_order.find(child))


func _cmp_sprites(a: VNSprite, b: VNSprite, og_order: Array):
	# we have to do this because sort_custom() isn't stable
	if a.draw_order == b.draw_order:
		return og_order.find(a) < og_order.find(b)
	return a.draw_order < b.draw_order


# returns current state as a Dict
func get_state() -> Dictionary:
	var sprites: Array = []
	for sprite in $Sprites.get_children():
		sprites.append({
			'x' : sprite.horizontal_position,
			'y' : sprite.vertical_position,
			'zoom' : sprite.zoom,
			'order' : sprite.draw_order,
			'path' : sprite.path,
			'id' : sprite.id,
			'state' : sprite.get_sprite_state()
		})
	
	@warning_ignore("incompatible_ternary")
	return {
		'bg' : { 'id': bg_id, 'state': $BG.get_state() } if $BG is StatefulLayer else bg_id,
		'fg' : { 'id': fg_id, 'state': $FG.get_state() } if $FG is StatefulLayer else fg_id,
		'sprites' : sprites
	}


# returns a cache containing stage objects to be be reused later
# this removes all objects from the stage and whoever uses the cache
# must free them manually
func get_node_cache() -> Dictionary:
	var cache: Dictionary = {
		'BG:%s' % bg_id: $BG,
		'FG:%s' % fg_id: $FG
	}
	remove_child($BG)
	remove_child($FG)
	
	for sprite in $Sprites.get_children():
		cache['sprite:%s:%s' % [sprite.id, sprite.path]] = sprite
		$Sprites.remove_child(sprite)
	
	return cache


# sets state from a Dict, using the objects in the cache if possible
func set_state(state: Dictionary, node_cache: Dictionary = {}):
	# retrieve BG from cache or create a fresh object
	var bg_from_cache: String = 'BG:%s' % state['bg']
	if bg_from_cache in node_cache:
		bg_id = state['bg']
		$BG.add_sibling(node_cache[bg_from_cache])
		_replace_with($BG, node_cache[bg_from_cache])
	else:
		set_background(state['bg'], '', null)
	
	# retrieve FG from cache or create a fresh object
	var fg_from_cache: String = 'FG:%s' % state['fg']
	if fg_from_cache in node_cache:
		fg_id = state['fg']
		$FG.add_sibling(node_cache[fg_from_cache])
		_replace_with($FG, node_cache[fg_from_cache])
	else:
		set_foreground(state['fg'], '', null)
	
	for sprite_data in state['sprites']:
		var sprite_from_cache: String = 'sprite:%s:%s' % [sprite_data['id'], sprite_data['path']]
		var sprite: VNSprite
		
		# get sprite from cache or create fresh object
		if sprite_from_cache in node_cache:
			sprite = node_cache[sprite_from_cache]
			$Sprites.add_child(sprite)
		else:
			sprite = _create_sprite(sprite_data['path'])
			$Sprites.add_child(sprite)
			sprite.enter_stage()
			sprite.id = sprite_data.id
		
		sprite.set_sprite_state(sprite_data['state'])
		sprite.move_to(sprite_data['x'], sprite_data['y'], sprite_data['zoom'], sprite_data['order'], Definitions.INSTANT)
	
	# free unused cache objects
	for cached_obj in node_cache.values():
		if (cached_obj as Node).get_parent() == null:
			cached_obj.queue_free()


# clears the stage, returning it to the empty initial state
func clear():
	set_background('', '', null)
	set_foreground('', '', null)
	
	for sprite in $Sprites.get_children():
		_remove_sprite(sprite)


func bg() -> Node:
	if $BG.has_meta('transitioning_into'):
		return $BG.get_meta('transitioning_into')
	return $BG


func fg() -> Node:
	if $FG.has_meta('transitioning_into'):
		return $FG.get_meta('transitioning_into')
	return $FG


func _sprite_debug_msg() -> String:
	var msg: String = ''
	for sprite in $Sprites.get_children():
		msg += '%s (x=%.3f, y=%.3f, zm=%.3f, ord=%d): %s\n' % [
			sprite.id,
			sprite.horizontal_position,
			sprite.vertical_position,
			sprite.zoom,
			sprite.draw_order,
			str(sprite.get_sprite_state())
		]
	return msg.strip_edges()
