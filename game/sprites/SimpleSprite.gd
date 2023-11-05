class_name SimpleSprite extends VNSprite
# simple sprite with a list of states corresponding to different images it shows


# the SpriteResource containing the files for this sprite
var resource: SpriteResource
# map of frame ids to the corresponding paths
var paths: Dictionary = {}
# the default frame of the sprite
var default_frame: String = ''
# currently shown frame
var current_frame: String = ''
# vertical offset down from bounding box, as percentage of stage height
var y_offset: float = 0.0
# constant factor by which the sprite is scaled
var sprite_scale: float = 1.0
# the texture used to display the sprite
var rect: TextureRect


func _init(_resource: SpriteResource):
	resource = _resource
	
	for tag in resource.tag.get_tags():
		match tag.name:
			'frame':
				if tag.length() != 2:
					TE.log_error(TE.Error.FILE_ERROR, 'SimpleSprite \\tag requires 2 args, got %s' % tag)
					continue
				
				var frame_id: String = tag.get_string_at(0)
				var texture_path: String = tag.get_string_at(1)
				paths[frame_id] = texture_path
				
				# set default frame to the first frame
				if default_frame == '':
					default_frame = frame_id
				
			'y_offset':
				y_offset = float(tag.get_string())
			
			'scale':
				sprite_scale = float(tag.get_string())
			
			_:
				TE.log_error(TE.Error.FILE_ERROR, 'unknown tag in SimpleSprite: %s' % tag)


func enter_stage(initial_state: Variant = null):
	rect = TextureRect.new()
	add_child(rect)
	rect.position.y = _stage_size().y * y_offset
	rect.scale = Vector2(sprite_scale, sprite_scale)
	
	if initial_state != null:
		show_as(initial_state)
	else:
		show_as_frame(default_frame)


func show_as(tag: Tag):
	show_as_frame(tag.get_string())


func show_as_frame(frame: String):
	if not frame in paths:
		TE.log_error(TE.Error.SCRIPT_ERROR, 'invalid SimpleSprite frame: %s' % frame)
		# set to default frame to stop everything from blowing up
		frame = default_frame
	
	current_frame = frame
	rect.texture = resource.files[paths[frame]]
	self.size = Vector2(
		sprite_scale * rect.texture.get_width(),
		sprite_scale * rect.texture.get_height()
	)


func get_sprite_state() -> Variant:
	return current_frame


func set_sprite_state(state: Variant):
	show_as_frame(state as String)


func stage_editor_hints() -> Variant:
	return paths.keys().map(func(s): return '\\as{%s}' % s)
