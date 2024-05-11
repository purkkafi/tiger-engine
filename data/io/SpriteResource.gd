class_name SpriteResource extends Resource
# describes a sprite: a folder with a sprite.tef file and other, arbitrary resources
# loading a sprite.tef file returns a SpriteResource


# the tag read from sprite.tef
var tag: Tag = null
# texture containing the atlas the TextureAtlases refer to
var atlas: Texture2D
# map of file paths relative to the sprite folder to TextureAtlas instances
var textures: Dictionary = {}
