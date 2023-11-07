class_name CompositeSprite extends VNSprite


# dict of attribute ids to Arrays of possible values
# attribute values are strings with ':' separating parts
# or ghost values (as returned by _ghost_value())
var attributes: Dictionary = {}
# the state; dict of attribute ids to current values
var state: Dictionary = {}
var layers: Array[Layer] = []
var resource: SpriteResource
var sprite_scale: float = 1.0 # TODO
var y_offset: float = 0 # TODO


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
				pass # TODO
			
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
		show_as(Tag.new('as', []))


func show_as(tag: Tag):
	for cmd in tag.args:
		pass # TODO implement
	
	var layer_size = null
	
	for layer in layers:
		var _match: Variant
		
		for case in layer.cases:
			var test = case.match()
			if test != null:
				_match = test
				break
		
		if _match == null:
			TE.log_error(TE.Error.FILE_ERROR,
				"cannot display layer '%s': nothing matches (state: '%s')" % [layer.id, state])
		else:
			layer.rect.texture = resource.textures[_match]
			
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


class Layer extends RefCounted:
	var id: String
	var cases: Array[Case]
	var rect: TextureRect
	
	
	func _init(_id: String, _case_tags: Array, sprite: CompositeSprite):
		self.id = _id
		
		for case in _case_tags:
			if case.name == 'case':
				cases.append(Case.new(case, sprite))
			else:
				TE.log_error(TE.Error.FILE_ERROR,
					"illegal layer component '%s'" % case.name)
	
	
	# returns whether every case is valid
	func _is_valid() -> bool:
		for case in cases:
			if not case._is_valid():
				return false
		return true
	
	
	func _to_string():
		return 'Layer(%s, %s)' % [id, cases]


class Case extends RefCounted:
	var predicate: Predicate
	# either a String, indicating it is the result of this Case,
	# or an Array of nested Case instances
	var content: Variant
	var sprite: CompositeSprite
	
	
	func _init(from_tag: Tag, _sprite: CompositeSprite):
		if len(from_tag.args) != 2:
			TE.log_error(TE.Error.FILE_ERROR,
				"case should have predicate and contents, got '%s'" % from_tag)
			return
		
		predicate = _sprite._parse_predicate(from_tag.get_string_at(0))
		
		if from_tag.get_string_at(1) != null: # is the result
			content = from_tag.get_string_at(1)
			if content not in _sprite.resource.textures.keys():
				TE.log_error(TE.Error.FILE_ERROR,
					"case result file does not exist: %s" % content)
		else: # is nested cases
			var nested_cases: Array = from_tag.get_tags_at(1)
			content = []
			for nested_case in nested_cases:
				content.append(Case.new(nested_case, _sprite))
		
		self.sprite = _sprite
	
	
	# matches against this case recursively
	# returns either null or the content of the matching case (String)
	func match() -> Variant:
		if not predicate.evaluate():
			return null
		
		if content is String:
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
	return Predicate.new(parts[0], parts[1], self)


func _ghost_value(of: String) -> Dictionary:
	return { 'ghost': true, 'value': of }


# a predicate about an attribute and an associated value
# performs self-validation, assuming both are meaningful in
# the context of the given CompositeSprite
class Predicate extends RefCounted:
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
	
	
	# returns the truth value of the predicate
	func evaluate() -> bool:
		if value is String: # check for exact match
			return sprite.state[attribute] == value
		else: # ghost value, check that state starts with it
			return sprite.state[attribute].begins_with(value['value'])
	
	
	# returns whether this predicate has a valid attribute & value
	func _is_valid() -> bool:
		return attribute != '' and (value is Dictionary or value != '')
	
	
	func _to_string():
		return 'Predicate(%s=%s)' % [attribute, value]
