class_name SpriteResource extends Resource
# describes a sprite: a folder with a sprite.tef file and other, arbitrary resources
# loading a sprite.tef file returns a SpriteResource


# the tag read from sprite.tef
var tag: Tag = null
# the resources in the sprite folder
# keys are the parts of the paths after the final slash, values are Resources
var files: Dictionary = {}
