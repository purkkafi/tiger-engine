class_name CompositeSprite extends VNSprite


# dict of attribute ids to Arrays of possible values
# attribute values are strings with ':' separating parts
# or ghost values (as returned by _ghost_value())
var attributes: Dictionary = {}
# the state; dict of attribute ids to current values
var state: Dictionary = {}
var layers: Array[Layer] = []
# dict of shorthand ids to Arrays of Predicates
var shorthands: Dictionary = {}
var resource: SpriteResource
var sprite_scale: float = 1.0

# downwad vertical displacement of the sprite as a % of stage height
var y_offset: float = 0.0


# debug rect disabled
const NO_DEBUG_RECT: Rect2 = Rect2(Vector2(0, 0), Vector2(0, 0))
# indicates a case where a match signifies the layer should be empty
static var EMPTY_CASE: EmptyCase = EmptyCase.new()
# constant instances
static var TRUE_PREDICATE: TruePredicate = TruePredicate.new()
static var SHOW_AS_CURRENT: Tag = Tag.new('as', [])


func _init(_resource: SpriteResource):
	self.resource = _resource
	
	for tag in resource.tag.get_tags():
		match tag.name:
			'attribute':
				if len(tag.args) != 2:
					TE.log_error(TE.Error.FILE_ERROR,
						'illegal attribute declaration (expected id and values): %s' % tag)
					continue
				
				var attr_id = tag.get_string_at(0)
				
				if attr_id == null:
					TE.log_error(TE.Error.FILE_ERROR,
						'illegal attribute id (expected string): %s' % tag)
					continue
				
				attributes[attr_id] = []
				_read_attribute(attr_id, '', tag.get_tags_at(1))
			
			'layer':
				if len(tag.args) != 2:
					TE.log_error(TE.Error.FILE_ERROR,
						'illegal layer declaration (expected id and tree): %s' % tag)
				
				var layer_id = tag.get_string_at(0)
				
				if layer_id == null:
					TE.log_error(TE.Error.FILE_ERROR,
						'illegal layer id (expected string): %s' % tag)
					continue
				
				layers.append(Layer.new(layer_id, tag.get_tags_at(1), self))
			
			'shorthand':
				if len(tag.args) < 2:
					TE.log_error(TE.Error.FILE_ERROR,
						"\\shorthand requires id and effect(s), got '%s'" % tag)
					continue
				
				var shorthand_id = tag.get_string_at(0)
				if shorthand_id == null:
					TE.log_error(TE.Error.FILE_ERROR,
						"shorthand id should be string, got '%s'" % tag)
					continue
				
				var effects: Array[Predicate] = []
				
				for i in len(tag.args)-1:
					var effect = tag.get_string_at(1+i)
					if effect == null:
						TE.log_error(TE.Error.FILE_ERROR,
							"shorthand effect should be string, got '%s'" % tag)
						continue
					effects.append(_parse_predicate(effect))
				
				shorthands[shorthand_id] = effects
			
			'y_offset':
				if tag.get_string() == null:
					TE.log_error(TE.Error.FILE_ERROR,
						"\\y_offset requires float, got '%s'" % tag)
					continue
				y_offset = float(tag.get_string())
			
			'scale':
				if tag.get_string() == null:
					TE.log_error(TE.Error.FILE_ERROR,
						"\\scale requires float, got '%s'" % tag)
					continue
				sprite_scale = float(tag.get_string())
			
			_:
				TE.log_error(TE.Error.FILE_ERROR,
					"unrecognized tag in CompositeSprite: '%s'" % tag.name)
	
	# initialize state to default values of each attribute
	for attr in attributes:
		for val in attributes[attr]:
			if val is String: # skip ghost values
				state[attr] = val
				break
		if attr not in state:
			TE.log_error(TE.Error.FILE_ERROR, "attribute '%s' has no possible values" % attr)
	
	# remove invalid layers to reduce runtime errors
	# errors should already be reported during parsing
	layers = layers.filter(func(l: Layer): return l._is_valid())


# recursively resolves an attribute declaration
func _read_attribute(attr_id: String, prefix: String, tags: Array):
	for tag in tags:
		if len(tag.args) == 0:
			attributes[attr_id].append(prefix + tag.name)
		elif len(tag.args) == 1:
			attributes[attr_id].append(_ghost_value(prefix + tag.name))
			var sub_tags: Array = tag.get_tags()
			
			if len(sub_tags) == 0:
				TE.log_error(TE.Error.FILE_ERROR,
					"invalid attribute value (no possible values): '%s' (hint: remove the innermost braces)" % (prefix + tag.name))
			
			_read_attribute(attr_id, prefix + ('%s:' % tag.name), sub_tags)
		else:
			TE.log_error(TE.Error.FILE_ERROR,
				'invalid attribute value (expected empty tag or nested attribute): %s' % tag)


func enter_stage(initial_state: Variant = null):
	for layer in layers:
		layer.rect = TextureRect.new()
		add_child(layer.rect)
		layer.rect.position.y = _stage_size().y * y_offset
		layer.rect.scale = Vector2(sprite_scale, sprite_scale)
	
	if initial_state != null:
		show_as(initial_state)
	else:
		show_as(SHOW_AS_CURRENT)


func show_as(tag: Tag):
	for cmd in tag.get_strings():
		if cmd in shorthands:
			for effect in shorthands[cmd]:
				if effect._is_valid():
					effect.apply()
		else: # is raw predicate
			var predicate: Predicate = _parse_predicate(cmd)
			if predicate._is_valid():
				predicate.apply()
	
	var layer_size = null
	
	for layer in layers:
		var _match: Variant
		
		_match = layer.root_case.match()
		
		if _match == null:
			TE.log_error(TE.Error.FILE_ERROR,
				"cannot display layer '%s': nothing matches (state: '%s')" % [layer.id, state])
		elif _match is EmptyCase:
			layer.rect.texture = null
			layer.debug_rect = NO_DEBUG_RECT
		else:
			layer.rect.texture = resource.textures[_match]
			
			var y_offset_vec = Vector2(0, _stage_size().y * y_offset)
			layer.debug_rect = Rect2(
				layer.rect.texture.margin.position * sprite_scale + y_offset_vec,
				layer.rect.texture.region.size * sprite_scale
			)
			
			if layer_size == null:
				layer_size = layer.rect.texture.get_size()
			elif layer_size != layer.rect.texture.get_size():
				TE.log_error(TE.Error.FILE_ERROR,
					"inconsistent layer size: '%s' does not match expected size (%d, %d)"
					% [_match, layer_size.x, layer_size.y])
	
	self.size = Vector2(
		sprite_scale * layer_size.x,
		sprite_scale * layer_size.y
	)


func get_sprite_state() -> Variant:
	return state


func set_sprite_state(_state: Variant):
	state = _state
	show_as(SHOW_AS_CURRENT)


func _draw():
	super._draw()
	
	if TE.draw_debug:
		var font = TETheme.current_theme.default_font
		var font_size = int(TETheme.current_theme.default_font_size * 0.75)
		var text_offset = Vector2(0, int(font_size) * 0.5)
		
		for layer in layers:
			if layer.debug_rect != NO_DEBUG_RECT:
				draw_rect(layer.debug_rect, Color.BLUE, false)
				draw_string(font, layer.debug_rect.position - text_offset, layer.id,
					HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color.BLUE)


func stage_editor_hints() -> Array:
	var hints: Array = []
	
	hints.append_array(shorthands.keys().map(func(s): return '\\as{%s}' % s))
	
	for attr in attributes:
		for val in attributes[attr]:
			if val is String: # no ghost values
				hints.append('\\as{%s=%s}' % [attr, val])
	return hints


class Layer extends RefCounted:
	var id: String
	var root_case: Case
	var rect: TextureRect
	var debug_rect: Rect2
	
	
	func _init(_id: String, _case_tags: Array, sprite: CompositeSprite):
		self.id = _id
		
		var cases: Array = []
		
		for case in _case_tags:
			if case.name == 'case':
				cases.append(Case.of_tag(case, sprite))
			else:
				TE.log_error(TE.Error.FILE_ERROR,
					"illegal layer component '%s'" % case.name)
		
		root_case = Case.new(CompositeSprite.TRUE_PREDICATE, cases, sprite)
	
	
	# returns whether every case is valid
	func _is_valid() -> bool:
		return root_case._is_valid()
	
	
	func _to_string():
		return 'Layer(%s, %s)' % [id, root_case.content]


class EmptyCase extends RefCounted:
	pass


class Case extends RefCounted:
	var predicate: Predicate
	# either a String, indicating it is the result of this Case,
	# EMPTY_CASE, or an Array of nested Case instances
	var content: Variant
	var sprite: CompositeSprite
	
	func _init(_predicate: Predicate, _content: Variant, _sprite: CompositeSprite):
		self.predicate = _predicate
		self.content = _content
		self.sprite = _sprite
		
		if content is Array:
			# validate not without inner cases (would always produce an error)
			if len(content) == 0:
				TE.log_error(TE.Error.FILE_ERROR,
					"case with predicate '%s' has no result or inner cases (always errors)" % predicate)
				pass
			
			# validate predicates aren't repeated (latter ones would never match)
			var used_predicates: Array[String] = []
			for case in content:
				var predicate_string: String = str(case.predicate)
				
				if predicate_string in used_predicates:
					TE.log_error(TE.Error.FILE_ERROR,
						"duplicate case predicate: '%s' (never matches)" % predicate_string)
					continue
				
				used_predicates.append(predicate_string)
	
	
	static func of_tag(from_tag: Tag, _sprite: CompositeSprite) -> Case:
		if len(from_tag.args) != 2:
			TE.log_error(TE.Error.FILE_ERROR,
				"case should have predicate and contents, got '%s'" % from_tag)
			return
		
		@warning_ignore("shadowed_variable")
		var predicate: Predicate = _sprite._parse_predicate(from_tag.get_string_at(0))
		@warning_ignore("shadowed_variable")
		var content: Variant
		
		if from_tag.get_string_at(1) != null: # is the result
			content = from_tag.get_string_at(1)
			if content not in _sprite.resource.textures.keys():
				TE.log_error(TE.Error.FILE_ERROR,
					"case result file does not exist: %s" % content)
		elif from_tag.get_tag_at(1) != null and from_tag.get_tag_at(1).name == 'empty':
			# is a single \empty tag
			content = CompositeSprite.EMPTY_CASE
		else: # is nested cases
			var nested_cases: Array = from_tag.get_tags_at(1)
			content = []
			
			for nested_case_tag in nested_cases:
				content.append(Case.of_tag(nested_case_tag, _sprite))
		
		return Case.new(predicate, content, _sprite)
	
	
	# matches against this case recursively
	# returns either null or the content of the matching case (String or EmptyCase)
	func match() -> Variant:
		if not predicate.evaluate():
			return null
		
		if content is String or content is EmptyCase:
			return content
		else:
			for nested_case in content:
				var _match = nested_case.match()
				if _match != null:
					return _match
		
		return null
	
	
	# returns whether this case is valid, checking that:
	# – the predicate is valid
	# – if 'content' is a String, it refers to an existing image
	# – if 'content' is an Array of sub-cases, they are all valid
	func _is_valid() -> bool:
		if not predicate._is_valid():
			return false
		if content is String:
			if content not in sprite.resource.textures.keys():
				return false
		elif content is EmptyCase:
			return true
		else:
			for subcase in (content as Array):
				if not (subcase as Case)._is_valid():
					return false
		return true
	
	
	func _to_string():
		return 'Case(%s, %s)' % [predicate, content]


func _parse_predicate(string: String) -> Predicate:
	var parts = string.split('=')
	if len(parts) != 2:
		TE.log_error(TE.Error.FILE_ERROR,
			"predicate should be of form 'attribute=value', got '%s'" % string)
	return EqPredicate.new(parts[0].strip_edges(), parts[1].strip_edges(), self)


func _ghost_value(of: String) -> Dictionary:
	return { 'ghost': true, 'value': of }


# a logical predicate about the sprite's state with some operations
class Predicate extends RefCounted:
	# evaluates the predicate, returning its truth value
	func evaluate() -> bool:
		assert(false, "Predicate doesn't override evaluate()")
		return false
	
	
	# applies this predicate, modifying the state to make it true
	# allowed to error if the predicate doesn't support this
	func apply():
		assert(false, "Predicate doesn't override apply()")
	
	
	# returns whether this predicate is valid (its value can be
	# meaningfully tested; evaluate() will not cause an error)
	func _is_valid() -> bool:
		assert(false, "Predicate doesn't override _is_valid()")
		return false


# trivial placeholder predicate; always true
class TruePredicate extends Predicate:
	func evaluate() -> bool: return true
	func apply(): TE.log_error(TE.Error.ENGINE_ERROR, "TruePredicate can't be applied")
	func _is_valid() -> bool: return true


# a predicate about an attribute and an associated value
# performs self-validation, assuming both are meaningful in
# the context of the given CompositeSprite
class EqPredicate extends Predicate:
	var attribute: String = ''
	var value: Variant = '' # String or ghost value dict
	var sprite: CompositeSprite
	
	
	# matches everything before the last ':' character
	var BEFORE_LAST_COLON = RegEx.create_from_string('(.+):')
	
	
	func _init(_attr: String, _val: Variant, forSprite: CompositeSprite):
		if _attr not in forSprite.attributes:
			TE.log_error(TE.Error.FILE_ERROR, "invalid attribute id: '%s'" % _attr)
			return
		
		var partial_value: String = _val
		var value_is_valid: bool = false
		while true:
			if partial_value in forSprite.attributes[_attr]:
				value_is_valid = true
				break
			if forSprite._ghost_value(partial_value) in forSprite.attributes[_attr]:
				value_is_valid = true
				_val = forSprite._ghost_value(partial_value)
				break
			
			if partial_value.find(':') != -1:
				partial_value = BEFORE_LAST_COLON.search(partial_value).strings[1]
			else:
				break
		
		if not value_is_valid:
			TE.log_error(TE.Error.FILE_ERROR, "invalid value for attribute '%s': '%s'" % [_attr, str(_val)])
			return
		
		self.sprite = forSprite
		self.attribute = _attr
		self.value = _val
	
	
	func evaluate() -> bool:
		if value is String: # check for exact match
			return sprite.state[attribute] == value
		else: # ghost value, check that state starts with it
			return sprite.state[attribute].begins_with(value['value'])
	
	
	func apply():
		if value not in sprite.attributes[attribute]:
			TE.log_error(TE.Error.FILE_ERROR,
				"cannot set attribute '%s' to invalid value '%s'" % [attribute, value])
		else:
			sprite.state[attribute] = value
	
	
	func _is_valid() -> bool:
		return attribute != '' and (value is Dictionary or value != '')
	
	
	func _to_string():
		return '%s=%s' % [attribute, value]
