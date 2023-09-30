class_name VNStage extends Node
# responsible for displaying and keeping track of game objects such as
# the background and foreground layers and sprites


var bg_id: String = ''
var fg_id: String = ''
var TRANSPARENT: Color = Color(0, 0, 0, 0)


# transitions to a new background with the given transition
# a Tween can be given to do so in parallel; otherwise, a new one is created
func set_background(new_id: String, transition: String, tween: Tween) -> Tween:
	bg_id = new_id
	return _set_layer($BG, _get_layer_node(new_id), TE.defs.transition(transition), tween, false)


# transitions to a new foreground with the given transition
# a Tween can be given to do so in parallel; otherwise, a new one is created
func set_foreground(new_id: String, transition: String, tween: Tween) -> Tween:
	fg_id = new_id
	return _set_layer($FG, _get_layer_node(new_id), TE.defs.transition(transition), tween, true)


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


# adds a sprite to the stage
# path is the full path to the sprite folder
# at is the initial position descriptor or null
# with is a transition descriptor or null
# by is an alternative id to give to the sprite or null
# tween is the tween to use or null, in case it will be created; returned for chaining
func enter_sprite(id: String, at: Variant, with: Variant, by: Variant, tween: Tween) -> Tween:
	var sprite: VNSprite = _create_sprite(Assets._resolve(TE.defs.sprites[id], 'res://assets/sprites'))
	if by != null:
		sprite.id = by as String
	else:
		sprite.id = id
	
	$Sprites.add_child(sprite)
	sprite.enter_stage(null)
	sprite.move_to(_parse_position_descriptor(at), Definitions.instant(), null)
	
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
	# TODO: implement registering of custom sprite providers
	if resource.tag.name == 'simple_sprite':
		sprite = SimpleSprite.new(resource)
		sprite.path = path
		# default id to being last part of sprite folder's path
		sprite.id = path.split('/')[-1]
	else:
		TE.log_error(TE.Error.SCRIPT_ERROR, 'sprite provider for %s not implemented' % path)
	
	return sprite


# moves a sprite to the given location (a position descriptor String)
# with is the optional transition and tween is the optional Tween (returned for chaining)
func move_sprite(id: String, to: String, with: Variant, tween: Tween) -> Tween:
	var sprite: VNSprite = find_sprite(id)
	
	if tween == null:
		tween = create_tween()
	
	if with == null:
		with = TE.defs.instant()
	else:
		with = TE.defs.transition(with)
	sprite.move_to(_parse_position_descriptor(to), with, tween)
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
	sprite.add_sibling(new_sprite, false)
	new_sprite.enter_stage(_as)
	new_sprite.move_to(sprite.sprite_position, Definitions.instant())
	
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


# parses a sprite position descriptor:
# – if given null, it is 0.5
# – if given a String of form "n of m", it is n / (m+1)
# – else, it is the argument parsed as a float
func _parse_position_descriptor(desc: Variant) -> float:
	if desc == null:
		return 0.5
	
	desc = desc as String
	
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


# returns current state as a Dict
func get_state() -> Dictionary:
	var sprites: Array = []
	for sprite in $Sprites.get_children():
		sprites.append({
			'x' : sprite.sprite_position,
			'path' : sprite.path,
			'id' : sprite.id,
			'state' : sprite.get_sprite_state()
		})
	return {
		'bg' : bg_id,
		'fg' : fg_id,
		'sprites' : sprites
	}


# sets state from a Dict
func set_state(state: Dictionary):
	set_background(state['bg'], '', null)
	set_foreground(state['fg'], '', null)
	
	for sprite_data in state['sprites']:
		var sprite = _create_sprite(sprite_data['path'])
		$Sprites.add_child(sprite)
		sprite.enter_stage()
		sprite.id = sprite_data.id
		sprite.set_sprite_state(sprite_data['state'])
		sprite.move_to(sprite_data['x'], TE.defs.instant())


# clears the stage, returning it to the empty initial state
func clear():
	set_background('', '', null)
	set_foreground('', '', null)
	
	for sprite in $Sprites.get_children():
		_remove_sprite(sprite)
