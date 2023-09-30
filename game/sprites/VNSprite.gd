class_name VNSprite extends Control
# base class for sprites
#
# every sprite is a folder containing a sprite.tef file and
# its associated resources. a sprite is first created with the
# constructor and then added to the VNStage; finally, enter_stage() is called
#
# a sprite has an implementation-defined internal state. it is set (as a String)
# by enter_stage() and show_as(), while get_sprite_state() and set_sprite_state()
# return and set it as a JSON object for serialization purposes


# relative position of the sprite on the stage in range [0, 1]
var sprite_position: float = 0.5
# set by whoever is loading the sprite
var id: String # id the sprite is referred to with
var path: String # path of the sprite folder


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


# returns the width of the sprite; used to calculate its position
func _sprite_width() -> float:
	TE.log_error(TE.Error.ENGINE_ERROR, "VNSprite doesn't override _sprite_width()")
	return 0


# moves the sprite to the given relative coordinate
# if the duration of the transition is not 0 and a tween is provided,
# the movement will be animated with the tween
func move_to(to: float, trans: Definitions.Transition, tween: Tween = null):
	sprite_position = to
	if trans.duration == 0 or tween == null:
		self.position.x = _stage_x(to)
	else:
		var tweener = tween.parallel().tween_property(self, 'position:x', _stage_x(to), trans.duration)
		tweener.set_ease(trans.ease_type)
		tweener.set_trans(trans.trans_type)


# converts a relative coordinate in range [0, 1] to stage coordinates in pixels
func _stage_x(rel_x: float):
	return (get_parent().size.x * rel_x) - _sprite_width()/2
