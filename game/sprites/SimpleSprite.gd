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
# the texture used to display the sprite
var rect: TextureRect


func _init(_resource: SpriteResource):
	resource = _resource
	
	for framedef in resource.tag.get_tags():
		if framedef.name != 'frame':
			TE.log_error(TE.Error.FILE_ERROR, 'unknown tag in SimpleSprite: %s' % framedef)
		var frame_id: String = framedef.get_string_at(0)
		var texture_path: String = framedef.get_string_at(1)
		paths[frame_id] = texture_path
		
		# set default frame to the first frame
		if default_frame == '':
			default_frame = frame_id


func enter_stage(initial_state: Variant = null):
	rect = TextureRect.new()
	add_child(rect)
	
	if initial_state != null:
		show_as(initial_state)
	else:
		show_as(default_frame)
	move_to(sprite_position, Definitions.instant(), null)


func _sprite_width() -> float:
	return rect.texture.get_width()


func show_as(frame: String):
	current_frame = frame
	rect.texture = resource.files[paths[frame]]
	self.position.y = get_parent().size.y - rect.texture.get_height()
	move_to(sprite_position, Definitions.instant(), null)


func get_sprite_state() -> Variant:
	return current_frame


func set_sprite_state(state: Variant):
	show_as(state as String)
