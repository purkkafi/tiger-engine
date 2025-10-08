class_name VNSprite extends Node2D
# base class for sprites
#
# every sprite is a folder containing a sprite.tef file and
# its associated resources. a sprite is first created with the
# constructor and then added to the VNStage; finally, enter_stage() is called
#
# a sprite has an implementation-defined internal state. it is set (as a String)
# by enter_stage() and show_as(), while get_sprite_state() and set_sprite_state()
# return and set it as a JSON object for serialization purposes
#
# subclasses need to declare their size by updating the 'size' variable
# but should not touch any other Node2D variables directly

# relative horizontal position of the sprite on the stage in range [0, 1]
# 0.5 (the default) is the middle
var horizontal_position: float = 0.5
# relative vertical position the bottom of the sprite touches on the stage
# 0 (the default) corresponds to the bottom of the screen, 1 is the top
# if negative, the sprite is cut from the bottom
var vertical_position: float = 0

# size of the sprite
# subclasses need to update this to keep themselves positioned gracefully
var size: Vector2 = Vector2(0, 0):
	set(new_size):
		size = new_size
		_recalc()

# how the sprite is zoomed, corresponding to Node2D's scale
var zoom: float = 1.0

# draw order, relative to other sprites in the scene
var draw_order: int = 0:
	set(new_draw_order):
		if new_draw_order != draw_order:
			draw_order = new_draw_order
			emit_signal('draw_order_changed')

# internal debug outline, subclasses should not change
var _debug_outline: Rect2 = Rect2(0, 0, 0, 0)
# set by whoever is loading the sprite
var id: String # id the sprite is referred to with
var path: String # path of the sprite folder
var associated_speaker: String # speaker id this sprite is associated with


# signal for stage to rearrange sprites
@warning_ignore("unused_signal")
signal draw_order_changed


# calculates this sprite's position
func _recalc():
	position.x = _stage_x(horizontal_position)
	position.y = _stage_y(vertical_position)
	_debug_outline = Rect2(Vector2(-1, -1), size + Vector2(2, 2))


# construct this sprite from its SpriteResource
func _init(_resource: SpriteResource):
	TE.log_error(TE.Error.ENGINE_ERROR, "VNSprite doesn't override constructor")


# initializes the sprite, called after the sprite is added to the VNStage
# initial_state is null or a String id describing the initial state
func enter_stage(_initial_state: Variant = null):
	TE.log_error(TE.Error.ENGINE_ERROR, "VNSprite doesn't override enter_stage()")


# shows the sprite according to the given String describing its state
func show_as(_as: Tag):
	TE.log_error(TE.Error.ENGINE_ERROR, "VNSprite doesn't override show_as()")


# returns the sprite state (any valid JSON object); used for saving the game
func get_sprite_state() -> Variant:
	TE.log_error(TE.Error.ENGINE_ERROR, "VNSprite doesn't override get_sprite_state()")
	return ''


# sets the sprite state (see get_sprite_state())
func set_sprite_state(_state: Variant):
	TE.log_error(TE.Error.ENGINE_ERROR, "VNSprite doesn't override set_sprite_state()")


# returns a (possibly empty) array containing suggested states for the stage editor
# every state should be of form "\as{...}", mimicing what you'd write in the script
func stage_editor_hints() -> Array:
	return []


# moves the sprite to the given coordinates and sets the draw order
# if the duration of the transition is not 0 and a tween is provided,
# the movement will be animated with the tween
# values are floats/ints or null (meaning they will be ignored)
func move_to(to_x: Variant, to_y: Variant, to_zoom: Variant, to_order: Variant, trans: Definitions.Transition, tween: Tween = null):
	var x0: float = horizontal_position
	if to_x != null:
		horizontal_position = to_x as float
	
	var y0: float = vertical_position
	if to_y != null:
		vertical_position = to_y as float
	
	if to_zoom != null:
		zoom = to_zoom as float
	
	if to_order != null:
		draw_order = to_order as int
	
	if trans.duration == 0 or tween == null:
		scale = Vector2(zoom, zoom)
		position.x = _stage_x(horizontal_position)
		position.y = _stage_y(vertical_position)
	else:
		var zoom_tweener = tween.parallel().tween_property(self, 'scale', Vector2(zoom, zoom), trans.duration)
		zoom_tweener.set_ease(trans.ease_type)
		zoom_tweener.set_trans(trans.trans_type)
		
		var x_tweener = tween.parallel().tween_method(func(_x): position.x = _stage_x(_x), x0, horizontal_position, trans.duration)
		x_tweener.set_ease(trans.ease_type)
		x_tweener.set_trans(trans.trans_type)
		
		var y_tweener = tween.parallel().tween_method(func(_y): position.y = _stage_y(_y), y0, vertical_position, trans.duration)
		y_tweener.set_ease(trans.ease_type)
		y_tweener.set_trans(trans.trans_type)


# the size of the stage this sprite is on
# TODO rethink this design, possibly to allow for resizing the stage?
func _stage_size():
	return (get_parent().get_parent() as VNStage).size


# converts a relative x coordinate to stage pixels
func _stage_x(rel_x: float):
	return (_stage_size().x * rel_x) - (size.x * scale.x)/2


# converts a relative y coordinate to stage pixels
func _stage_y(rel_y: float):
	return _stage_size().y * (1.0 - rel_y) - size.y * scale.y


func _draw():
	if TE.draw_debug:
		var font = TETheme.current_theme.default_font
		var font_size = int(TETheme.current_theme.default_font_size * 0.75)
		var text_offset = Vector2(0, int(font_size) * 0.5)
		
		draw_rect(_debug_outline, Color.RED, false)
		draw_string(font, -text_offset, id, HORIZONTAL_ALIGNMENT_LEFT,
			-1, font_size, Color.RED)
