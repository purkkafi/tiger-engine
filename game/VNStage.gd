class_name VNStage extends Node
# responsible for displaying and keeping track of game objects such as
# the background and foreground layers and sprites


var bg_id: String = ''
var fg_id: String = ''
var active_vfxs: Array[ActiveVfx] = []
const TRANSPARENT: Color = Color(0, 0, 0, 0)


# currently active Vfx instance applied to a specific target 
class ActiveVfx:
	var vfx: Vfx
	var target: String
	var _as: String
	
	
	func _init(_vfx: Vfx, _target: String, __as: Variant):
		self.vfx = _vfx
		self.target = _target
		self._as = __as if __as is String else ''
	
	
	func path() -> String:
		return vfx.get_script().resource_path
	
	
	func verify_vfx_arguments(state: Dictionary):
		var recognized_args = vfx.recognized_arguments()
		for key in state.keys():
			if key not in recognized_args:
				TE.log_error(TE.Error.FILE_ERROR, "Unknown argument '%s' for vfx '%s'" % [key, _as])
	
	
	func apply(_target: CanvasItem, initial_state: Dictionary, tween: Tween) -> Tween:
		verify_vfx_arguments(initial_state)
		return vfx.apply(_target, initial_state, tween)
	
	
	func set_state(_target: CanvasItem, new_state: Dictionary, tween: Tween) -> Tween:
		verify_vfx_arguments(new_state)
		return vfx.set_state(_target, new_state, tween)


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
		tween.set_parallel(true)
	
	new_layer.modulate = Color(1, 1, 1, 0)
	var tweener: PropertyTweener = tween.tween_property(new_layer, 'modulate:a', 1.0, transition.duration)
	tweener.set_ease(transition.ease_type)
	tweener.set_trans(transition.trans_type)
	
	if fade_old:
		layer.modulate.a = 1.0
		var old_tweener: PropertyTweener = tween.tween_property(layer, 'modulate:a', 0.0, transition.duration)
		old_tweener.set_ease(transition.ease_type)
		old_tweener.set_trans(transition.trans_type)
	
	# schedule replacing the old layer with the new one
	tween.tween_callback(_replace_with.bind(layer, new_layer)).set_delay(transition.duration)
	
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
			tween.set_parallel(true)
			
		var trans: Definitions.Transition = TE.defs.transition(with as String)
		sprite.modulate.a = 0.0
		var tweener = tween.tween_property(sprite, 'modulate:a', 1.0, trans.duration)
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
			tween.set_parallel(true)
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
		tween.set_parallel(true)
	
	with = TE.defs.transition(with)
	
	var new_sprite = _create_sprite(sprite.path)
	new_sprite.id = sprite.id
	sprite.add_sibling(new_sprite, false)
	new_sprite.enter_stage()
	new_sprite.set_sprite_state(sprite.get_sprite_state())
	new_sprite.show_as(_as)
	new_sprite.move_to(sprite.horizontal_position, sprite.vertical_position, sprite.zoom, sprite.draw_order, Definitions.INSTANT)
	
	new_sprite.modulate.a = 0.0
	var tweener = tween.tween_property(new_sprite, 'modulate:a', 1.0, with.duration)
	tweener.set_ease(with.ease_type)
	tweener.set_trans(with.trans_type)
	tween.tween_callback(_finish_sprite_transition.bind(sprite)).set_delay(with.duration)
	
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
		tween.set_parallel(true)
	
	if with == null:
		_remove_sprite(sprite)
	else:
		with = TE.defs.transition(with as String)
		var tweener = tween.tween_property(sprite, 'modulate:a', 0.0, with.duration)
		tweener.set_ease(with.ease_type)
		tweener.set_trans(with.trans_type)
		tween.tween_callback(_remove_sprite.bind(sprite)).set_delay(with.duration)
	
	return tween


func _remove_sprite(sprite: VNSprite):
	$Sprites.remove_child(sprite)
	
	# remove effects affecting this sprite
	# TODO implement and cleanup removed effects
	
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


func get_vfx_target(target_descriptor: String) -> CanvasItem:
	match target_descriptor:
		'\\stage':
			push_error('effects on \\stage NYI')
			return null
		'\\bg':
			return bg()
		'\\fg':
			return fg()
		'\\sprites':
			return %Sprites
		_:
			return find_sprite(target_descriptor)


func find_active_vfx(id: String) -> ActiveVfx:
	var found: ActiveVfx
	for avfx in active_vfxs:
		if avfx._as == id:
			found = avfx
			break
	
	if found == null:
		TE.log_error(TE.Error.ENGINE_ERROR, 'vfx not found: %s' % id)
	
	return found


func add_vfx(vfx_id: String, to: String, _as: Variant, initial_state: Dictionary, tween: Tween) -> Tween:
	if tween == null:
		tween = create_tween()
		tween.set_parallel(true)
	
	if vfx_id not in TE.opts.vfx_registry:
		TE.log_error(TE.Error.FILE_ERROR, 'unknown vfx: %s' % vfx_id)
		return tween
	
	var instance: Vfx = (load(TE.opts.vfx_registry[vfx_id]) as GDScript).new() as Vfx
	var avfx: ActiveVfx = ActiveVfx.new(instance, to, _as)
	avfx.apply(get_vfx_target(to), initial_state, tween)
	
	if instance.persistent():
		if not _as is String:
			TE.log_error(TE.Error.FILE_ERROR, "vfx '%s' is persistent but \\as not specified" % vfx_id)
			return tween
		active_vfxs.append(avfx)
	
	return tween


func set_vfx_state(avfx_id: String, state: Dictionary, tween: Tween) -> Tween:
	var avfx: ActiveVfx = find_active_vfx(avfx_id)
	if tween == null:
		tween = create_tween()
		tween.set_parallel(true)
	
	return avfx.set_state(get_vfx_target(avfx.target), state, tween)


func clear_vfx(avfx_id: String, tween: Tween) -> Tween:
	var avfx: ActiveVfx = find_active_vfx(avfx_id)
	if tween == null:
		tween = create_tween()
		tween.set_parallel(true)
	
	avfx.vfx.clear(get_vfx_target(avfx.target), tween)
	
	tween.chain().tween_callback(active_vfxs.erase.bind(avfx))
	return tween


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
	
	var active_vfxs_json: Array = []
	for avfx in active_vfxs:
		active_vfxs_json.append({
			'path': avfx.path(),
			'target': avfx.target,
			'as': avfx._as,
			'state': avfx.vfx.get_state()
		})
	
	@warning_ignore("incompatible_ternary")
	return {
		'bg': { 'id': bg_id, 'state': $BG.get_state() } if $BG is StatefulLayer else bg_id,
		'fg': { 'id': fg_id, 'state': $FG.get_state() } if $FG is StatefulLayer else fg_id,
		'sprites': sprites,
		'vfx': active_vfxs_json
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
	
	for avfx in active_vfxs:
		cache['vfx:%s:%s' % [avfx.path(), avfx._as]] = avfx
		active_vfxs.erase(avfx)
	
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
	
	for vfx_data in state['vfx']:
		var vfx_from_cache: String = 'vfx:%s:%s' % [vfx_data['path'], vfx_data.as]
		var avfx: ActiveVfx
		var tween = create_tween()
		
		# get vfx from cache or create a fresh object
		if vfx_from_cache in node_cache:
			avfx = node_cache[vfx_from_cache]
			avfx.set_state(get_vfx_target(avfx.target), vfx_data['state'], tween)
		else:
			var vfx: Vfx = load(vfx_data['path']).new() as Vfx
			avfx = ActiveVfx.new(vfx, vfx_data['target'], vfx_data['as'])
			avfx.apply(get_vfx_target(avfx.target), vfx_data['state'], tween)
		
		active_vfxs.append(avfx)
		tween.tween_callback(func(): pass) # fix potentially empty tween
		tween.custom_step(INF)
	
	# free unused cache objects
	for cached_obj in node_cache.values():
		if cached_obj is Node and (cached_obj as Node).get_parent() == null:
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
